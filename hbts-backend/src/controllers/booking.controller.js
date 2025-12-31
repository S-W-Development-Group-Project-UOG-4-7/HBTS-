// src/controllers/booking.controller.js
import { pool } from "../db.js";
import { expirePendingBookingsOnce } from "../jobs/expirePendingBookings.job.js";

const TTL_MINUTES = Number(process.env.PENDING_TTL_MINUTES || 10);
const CUTOFF_MINUTES = Number(process.env.BOOKING_CUTOFF_MINUTES || 10);
const GRACE_AFTER_MINUTES = Number(process.env.BOOKING_GRACE_AFTER_MINUTES || 5);

/**
 * POST /api/bookings
 * body: { tripId, seatId, paidVia, boardingStopId?, droppingStopId? }
 * paidVia: 'cash' | 'online'
 */
export async function createBooking(req, res) {
  const client = await pool.connect();

  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const { tripId, seatId, paidVia, boardingStopId, droppingStopId } = req.body;

    if (!tripId || !seatId || !paidVia || !boardingStopId || !droppingStopId) {
      return res.status(400).json({
        message: "tripId, seatId, paidVia, boardingStopId, droppingStopId are required",
      });
    }

    if (!["cash", "online"].includes(paidVia)) {
      return res.status(400).json({ message: "paidVia must be 'cash' or 'online'" });
    }

    if (boardingStopId === droppingStopId) {
      return res.status(400).json({ message: "boardingStopId and droppingStopId must be different" });
    }

    // Clean expired pending bookings first (keeps availability accurate)
    await expirePendingBookingsOnce();

    // Booking status depends on payment method
    // cash = confirmed immediately, online = pending until payment success
    const bookingStatus = paidVia === "cash" ? "confirmed" : "pending";

    await client.query("BEGIN");

    // ====== 1) Trip status + booking window enforcement (FLEXIBLE) ======
    const tripRes = await client.query(
      `
      SELECT t.departure_time, t.status
      FROM trips t
      WHERE t.trip_id = $1
      `,
      [tripId]
    );

    if (tripRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const trip = tripRes.rows[0];
    const tripStatus = String(trip.status);

    // Not bookable states
    if (["cancelled", "completed"].includes(tripStatus)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Trip is not bookable" });
    }

    // Running trips not bookable (even if time window would allow)
    if (tripStatus !== "scheduled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Booking closed (trip started)" });
    }

    // Flexible time rule:
    // - booking closes 10 mins before departure
    // - but allow up to 5 mins after departure if still scheduled
    const depMs = new Date(trip.departure_time).getTime();
    const nowMs = Date.now();

    const cutoffMs = depMs - CUTOFF_MINUTES * 60 * 1000; // 10 mins before
    const graceEndMs = depMs + GRACE_AFTER_MINUTES * 60 * 1000; // 5 mins after

    // If we are between cutoff and graceEnd, we allow ONLY because we are still scheduled.
    // If we are after graceEnd, block.
    if (nowMs >= cutoffMs && nowMs > graceEndMs) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Booking window closed" });
    }

    // ====== 2) Validate seat belongs to the trip bus ======
    const seatCheck = await client.query(
      `
      SELECT 1
      FROM trips t
      JOIN seats s ON s.bus_id = t.bus_id
      WHERE t.trip_id = $1 AND s.seat_id = $2
      `,
      [tripId, seatId]
    );

    if (seatCheck.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Invalid seat for this trip" });
    }

    // ====== 3) Conflict check (TTL-aware for pending) ======
    const conflict = await client.query(
      `
      SELECT 1
      FROM bookings
      WHERE trip_id = $1
        AND seat_id = $2
        AND (
          status = 'confirmed'
          OR (status = 'pending' AND booking_time >= NOW() - ($3::text || ' minutes')::interval)
        )
      LIMIT 1
      `,
      [tripId, seatId, String(TTL_MINUTES)]
    );

    if (conflict.rowCount > 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "Seat already booked" });
    }

    // ====== 4) Price calculation (temporary) ======
    const priceRes = await client.query(
      `
      SELECT COALESCE(r.distance_km, 0) AS distance_km
      FROM trips t
      JOIN routes r ON t.route_id = r.route_id
      WHERE t.trip_id = $1
      `,
      [tripId]
    );

    const distance = Number(priceRes.rows[0]?.distance_km || 0);
    const price = Math.round(distance * 10);

    // ====== 5) Insert booking ======
    const insert = await client.query(
      `
      INSERT INTO bookings (
        user_id,
        trip_id,
        seat_id,
        boarding_stop_id,
        dropping_stop_id,
        price,
        status,
        paid_via,
        booking_time
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8,NOW())
      RETURNING booking_id, status, paid_via, price, booking_time
      `,
      [
        userId,
        tripId,
        seatId,
        boardingStopId,
        droppingStopId,
        price,
        bookingStatus,
        paidVia,
      ]
    );

    await client.query("COMMIT");

    // Return consistent keys for Flutter
    const row = insert.rows[0];
    return res.status(201).json({
      bookingId: row.booking_id,
      status: row.status,
      paidVia: row.paid_via,
      price: row.price,
      bookingTime: row.booking_time,
    });
  } catch (err) {
    await client.query("ROLLBACK");

    if (err?.code === "23505") {
      return res.status(409).json({ message: "Seat already booked" });
    }

    console.error("createBooking error:", err);
    return res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
}

/**
 * GET /api/bookings/me
 */
export async function getMyBookings(req, res) {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    await expirePendingBookingsOnce();

    const result = await pool.query(
      `
      SELECT
        b.booking_id,
        b.status,
        b.paid_via,
        b.price,
        b.booking_time,
        b.qr_code,
        r.route_name,
        r.from_location,
        r.to_location,
        s.seat_label,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status AS trip_status
      FROM bookings b
      JOIN trips t ON b.trip_id = t.trip_id
      JOIN routes r ON t.route_id = r.route_id
      JOIN seats s ON b.seat_id = s.seat_id
      WHERE b.user_id = $1
      ORDER BY b.booking_time DESC
      `,
      [userId]
    );

    return res.json(result.rows);
  } catch (err) {
    console.error("getMyBookings error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}
