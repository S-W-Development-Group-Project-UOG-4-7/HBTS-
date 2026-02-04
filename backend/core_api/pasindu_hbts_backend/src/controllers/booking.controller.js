// src/controllers/booking.controller.js
import { pool } from "../db.js";
import { expirePendingBookingsOnce } from "../jobs/expirePendingBookings.job.js";
import { buildSeatChangePolicy } from "../utils/seatChangePolicy.js";
import { buildProgressIndexForTrip } from "../utils/polylineProgress.js";


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

    if (!tripId || !seatId || !paidVia) {
      return res.status(400).json({ message: "tripId, seatId, paidVia are required" });
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

    // Allow before cutoff and up to graceEnd; block strictly after graceEnd
    if (nowMs > graceEndMs) {
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
        b.trip_id,            
        b.seat_id,            
        t.bus_id,  
        b.status,
        b.paid_via,
        b.price,
        b.booking_time,
        b.qr_code,
        b.boarding_stop_id,
        bs.stop_name AS boarding_stop_name,
        bs.lat AS boarding_stop_lat,
        bs.lon AS boarding_stop_lon,
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
      JOIN stops bs ON bs.stop_id = b.boarding_stop_id
      WHERE b.user_id = $1
      ORDER BY b.booking_time DESC
      `,
      [userId]
    );

    return res.json(
  result.rows.map((row) => ({
    ...row,
    seatChange: buildSeatChangePolicy({
      departure_time: row.departure_time,
      trip_status: row.trip_status,
    }),
  }))
);
  } catch (err) {
    console.error("getMyBookings error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /api/bookings/:bookingId/boarding-stops
 */
export async function getChangeableBoardingStops(req, res) {
  const client = await pool.connect();
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const bookingId = Number(req.params.bookingId);
    if (!bookingId) return res.status(400).json({ message: "Invalid bookingId" });

    const bRes = await client.query(
      `
      SELECT b.booking_id, b.user_id, b.trip_id
      FROM bookings b
      WHERE b.booking_id = $1
      LIMIT 1
      `,
      [bookingId]
    );

    if (bRes.rowCount === 0) return res.status(404).json({ message: "Booking not found" });
    if (Number(bRes.rows[0].user_id) !== Number(userId)) {
      return res.status(403).json({ message: "Forbidden" });
    }

    const tripId = Number(bRes.rows[0].trip_id);
    const stops = await client.query(
      `
      SELECT
        ts.stop_id,
        s.stop_name,
        s.lat,
        s.lon,
        ts.stop_order
      FROM trip_stops ts
      JOIN stops s ON s.stop_id = ts.stop_id
      WHERE ts.trip_id = $1
        AND ts.is_boarding_allowed = true
      ORDER BY ts.stop_order ASC
      `,
      [tripId]
    );

    return res.json(stops.rows);
  } catch (err) {
    console.error("getChangeableBoardingStops error:", err);
    return res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
}

/**
 * PATCH /api/bookings/:bookingId/seat
 * body: { seatId }
 */
export async function changeBookingSeat(req, res) {
  const client = await pool.connect();
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const bookingId = Number(req.params.bookingId);
    const { seatId } = req.body;

    if (!bookingId || !seatId) {
      return res.status(400).json({ message: "bookingId and seatId are required" });
    }

    await expirePendingBookingsOnce();

    await client.query("BEGIN");

    // 1) Load booking and validate ownership
    const bRes = await client.query(
      `
      SELECT booking_id, user_id, trip_id, seat_id, status, booking_time
      FROM bookings
      WHERE booking_id = $1
      FOR UPDATE
      `,
      [bookingId]
    );

    if (bRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Booking not found" });
    }

    const b = bRes.rows[0];
    if (Number(b.user_id) !== Number(userId)) {
      await client.query("ROLLBACK");
      return res.status(403).json({ message: "Forbidden" });
    }

    // Disallow changing seat if already cancelled (if you use this status)
    if (String(b.status) === "cancelled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Booking is cancelled" });
    }

    // If same seat, no-op
    if (Number(b.seat_id) === Number(seatId)) {
      await client.query("ROLLBACK");
      return res.status(200).json({ message: "Seat unchanged", bookingId });
    }

    // 2) Trip status + booking window enforcement (same logic as createBooking)
    const tripRes = await client.query(
      `SELECT departure_time, status, bus_id FROM trips WHERE trip_id = $1`,
      [b.trip_id]
    );

    if (tripRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const trip = tripRes.rows[0];
    const tripStatus = String(trip.status);

    if (["cancelled", "completed"].includes(tripStatus)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Trip is not editable" });
    }

    if (tripStatus !== "scheduled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Seat change closed (trip started)" });
    }

    const seatChange = buildSeatChangePolicy({
  departure_time: trip.departure_time,
  trip_status: tripStatus,
});

if (!seatChange.canChangeSeat) {
  await client.query("ROLLBACK");
  return res.status(400).json({
    code: seatChange.code,
    message: seatChange.reason,
    seatChange,
  });
}


    // 3) Validate seat belongs to this trip bus
    const seatCheck = await client.query(
      `
      SELECT 1
      FROM seats s
      WHERE s.bus_id = $1 AND s.seat_id = $2
      `,
      [trip.bus_id, seatId]
    );

    if (seatCheck.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Invalid seat for this trip" });
    }

    // 4) Conflict check (TTL-aware pending)
    const conflict = await client.query(
      `
      SELECT 1
      FROM bookings
      WHERE trip_id = $1
        AND seat_id = $2
        AND booking_id <> $3
        AND (
          status = 'confirmed'
          OR (status = 'pending' AND booking_time >= NOW() - ($4::text || ' minutes')::interval)
        )
      LIMIT 1
      `,
      [b.trip_id, seatId, bookingId, String(TTL_MINUTES)]
    );

    if (conflict.rowCount > 0) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "Seat already booked" });
    }

    // 5) Update seat
    const upd = await client.query(
      `
      UPDATE bookings
      SET seat_id = $1
      WHERE booking_id = $2
      RETURNING booking_id, trip_id, seat_id, status
      `,
      [seatId, bookingId]
    );

    await client.query("COMMIT");

    return res.json({
      message: "Seat updated",
      booking: upd.rows[0],
    });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("changeBookingSeat error:", err);
    return res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
}

/**
 * PATCH /api/bookings/:bookingId/cancel
 */
export async function cancelBooking(req, res) {
  const client = await pool.connect();
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const bookingId = Number(req.params.bookingId);
    if (!bookingId) return res.status(400).json({ message: "bookingId is required" });

    await expirePendingBookingsOnce();

    await client.query("BEGIN");

    const bRes = await client.query(
      `
      SELECT booking_id, user_id, trip_id, status
      FROM bookings
      WHERE booking_id = $1
      FOR UPDATE
      `,
      [bookingId]
    );

    if (bRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Booking not found" });
    }

    const b = bRes.rows[0];
    if (Number(b.user_id) !== Number(userId)) {
      await client.query("ROLLBACK");
      return res.status(403).json({ message: "Forbidden" });
    }

    if (String(b.status) === "cancelled") {
      await client.query("ROLLBACK");
      return res.status(200).json({ message: "Already cancelled" });
    }

    // Trip status + cutoff rule
    const tripRes = await client.query(
      `SELECT departure_time, status FROM trips WHERE trip_id = $1`,
      [b.trip_id]
    );

    if (tripRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const trip = tripRes.rows[0];
    const tripStatus = String(trip.status);

    if (["cancelled", "completed"].includes(tripStatus)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Trip is not cancellable" });
    }

    if (tripStatus !== "scheduled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Cancel closed (trip started)" });
    }

    const depMs = new Date(trip.departure_time).getTime();
    const nowMs = Date.now();

    const cutoffMs = depMs - CUTOFF_MINUTES * 60 * 1000;
    const graceEndMs = depMs + GRACE_AFTER_MINUTES * 60 * 1000;

    // Allow up to graceEnd; block strictly after
    if (nowMs > graceEndMs) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Cancel window closed" });
    }

    // Cancel booking (assumes status column can store 'cancelled')
    const upd = await client.query(
      `
      UPDATE bookings
      SET status = 'cancelled'
      WHERE booking_id = $1
      RETURNING booking_id, trip_id, status
      `,
      [bookingId]
    );

    await client.query("COMMIT");
    return res.json({ message: "Booking cancelled", booking: upd.rows[0] });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("cancelBooking error:", err);
    return res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
}

export async function getBookingTracking(req, res) {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const bookingId = Number(req.params.bookingId);
    if (!bookingId) return res.status(400).json({ message: "Invalid bookingId" });

    const r = await pool.query(
      `
      SELECT
        b.booking_id,
        b.trip_id,
        b.status AS booking_status,
        bs.stop_id AS boarding_stop_id,
        bs.stop_name AS boarding_stop_name,
        bs.lat AS boarding_lat,
        bs.lon AS boarding_lon,
        ds.stop_id AS dropping_stop_id,
        ds.stop_name AS dropping_stop_name,
        ds.lat AS dropping_lat,
        ds.lon AS dropping_lon,
        t.status AS trip_status,
        tl.lat AS bus_lat,
        tl.lon AS bus_lon,
        tl.speed_mps AS bus_speed_mps,
        tl.heading AS bus_heading,
        tl.gps_at AS bus_gps_at,
        tl.updated_at AS bus_updated_at
      FROM bookings b
      JOIN trips t ON t.trip_id = b.trip_id
      JOIN stops bs ON bs.stop_id = b.boarding_stop_id
      JOIN stops ds ON ds.stop_id = b.dropping_stop_id
      LEFT JOIN trip_live tl ON tl.trip_id = b.trip_id
      WHERE b.booking_id = $1 AND b.user_id = $2
      LIMIT 1
      `,
      [bookingId, userId]
    );

    if (r.rowCount === 0) return res.status(404).json({ message: "Booking not found" });
    return res.json(r.rows[0]);
  } catch (err) {
    console.error("getBookingTracking error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function scanBookingQr(req, res) {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    // Optional: restrict to conductor/admin
    // if (!["conductor", "admin"].includes(req.user?.role)) {
    //   return res.status(403).json({ message: "Forbidden" });
    // }

    const { qrText } = req.body;
    if (!qrText) return res.status(400).json({ message: "qrText is required" });

    // 1) Parse QR payload
    let payload;
    try {
      payload = typeof qrText === "string" ? JSON.parse(qrText) : qrText;
    } catch {
      return res.status(400).json({ message: "Invalid QR format" });
    }

    const bookingId = Number(payload.bid);
    const sig = String(payload.sig || "");

    if (!bookingId || !sig) {
      return res.status(400).json({ message: "Invalid QR payload (bid, sig required)" });
    }

    // 2) Load booking + qr_secret (qr_secret must exist in DB)
    const bRes = await pool.query(
      `
      SELECT
        booking_id,
        user_id,
        trip_id,
        seat_id,
        boarding_stop_id,
        dropping_stop_id,
        status,
        payment_status,
        qr_secret
      FROM bookings
      WHERE booking_id = $1
      LIMIT 1
      `,
      [bookingId]
    );

    if (bRes.rowCount === 0) return res.status(404).json({ message: "Booking not found" });

    const b = bRes.rows[0];

    if (!b.qr_secret) {
      return res.status(500).json({ message: "Booking QR secret missing (DB not configured)" });
    }

    // 3) Verify signature: HMAC_SHA256(booking_id, qr_secret)
    const expected = crypto
      .createHmac("sha256", b.qr_secret)
      .update(String(b.booking_id))
      .digest("hex");

    if (expected !== sig) {
      return res.status(401).json({ message: "QR verification failed" });
    }

    // 4) Update scan metadata (you already have these columns)
    await pool.query(
      `
      UPDATE bookings
      SET
        qr_scanned_at = NOW(),
        last_scanned_by = $2,
        verification_source = 'qr'
      WHERE booking_id = $1
      `,
      [b.booking_id, userId]
    );

    // 5) Return CURRENT booking data (always latest)
    return res.json({
      booking_id: b.booking_id,
      trip_id: b.trip_id,
      passenger_user_id: b.user_id,
      seat_id: b.seat_id,
      boarding_stop_id: b.boarding_stop_id,
      dropping_stop_id: b.dropping_stop_id,
      status: b.status,
      payment_status: b.payment_status,
    });
  } catch (err) {
    console.error("scanBookingQr error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

// ✅ GET /api/bookings/:bookingId/boarding-stops
// GET /api/bookings/:bookingId/boarding-stops
/**
 * PATCH /api/bookings/:bookingId/boarding-stop
 * body: { boardingStopId }
 *
 * Rules:
 * - booking belongs to user
 * - booking not cancelled
 * - stop must be is_boarding_allowed=true for the trip
 * - if trip scheduled: allow any boarding-allowed stop
 * - if trip running: only stops ahead of bus, excluding next 2 stops (buffer)
 */
export async function changeBookingBoardingStop(req, res) {
  const client = await pool.connect();
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const bookingId = Number(req.params.bookingId);
    const boardingStopId = Number(req.body?.boardingStopId);

    if (!bookingId || !boardingStopId) {
      return res.status(400).json({ message: "bookingId and boardingStopId are required" });
    }

    await client.query("BEGIN");

    // Lock booking row for safe update
    const bRes = await client.query(
      `
      SELECT
        b.booking_id,
        b.user_id,
        b.trip_id,
        b.status AS booking_status
      FROM bookings b
      WHERE b.booking_id = $1
      FOR UPDATE
      `,
      [bookingId]
    );

    if (bRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Booking not found" });
    }

    const booking = bRes.rows[0];

    if (Number(booking.user_id) !== Number(userId)) {
      await client.query("ROLLBACK");
      return res.status(403).json({ message: "Forbidden" });
    }

    if (String(booking.booking_status).toLowerCase() === "cancelled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Booking is cancelled" });
    }

    // Load trip status + polyline + bus location
    const tRes = await client.query(
      `
      SELECT
        t.status AS trip_status,
        r.polyline AS polyline,
        tl.lat AS bus_lat,
        tl.lon AS bus_lon
      FROM trips t
      JOIN routes r ON r.route_id = t.route_id
      LEFT JOIN trip_live tl ON tl.trip_id = t.trip_id
      WHERE t.trip_id = $1
      LIMIT 1
      `,
      [booking.trip_id]
    );

    if (tRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const trip = tRes.rows[0];
    const tripStatus = String(trip.trip_status).toLowerCase();

    // Validate the requested stop is boarding-allowed for this trip
    const stopRes = await client.query(
      `
      SELECT ts.stop_id, ts.stop_order, s.stop_name, s.lat, s.lon
      FROM trip_stops ts
      JOIN stops s ON s.stop_id = ts.stop_id
      WHERE ts.trip_id = $1
        AND ts.stop_id = $2
        AND ts.is_boarding_allowed = true
      LIMIT 1
      `,
      [booking.trip_id, boardingStopId]
    );

    if (stopRes.rowCount === 0) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Boarding not allowed at this stop" });
    }

    // If scheduled: allow change (backend time-window rules could be added later)
    if (tripStatus === "scheduled") {
      const upd = await client.query(
        `
        UPDATE bookings
        SET boarding_stop_id = $1
        WHERE booking_id = $2
        RETURNING booking_id, boarding_stop_id
        `,
        [boardingStopId, bookingId]
      );

      await client.query("COMMIT");
      return res.json({ message: "Boarding stop updated", booking: upd.rows[0] });
    }

    // If running: enforce "not passed + hide next 2"
    const busLat = trip.bus_lat;
    const busLon = trip.bus_lon;
    const polyline = trip.polyline;

    // If no GPS/polyline, safest is to block changes while running
    if (busLat == null || busLon == null || !polyline) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Cannot change boarding stop while trip is running (missing live location)" });
    }

    const prog = buildProgressIndexForTrip(polyline);
    if (!prog) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Route polyline not available" });
    }

    const busIdx = prog.progressIndex(Number(busLat), Number(busLon));

    // Fetch all boarding-allowed stops to compute ordering along polyline
    const allStopsRes = await client.query(
      `
      SELECT ts.stop_id, ts.stop_order, s.stop_name, s.lat, s.lon
      FROM trip_stops ts
      JOIN stops s ON s.stop_id = ts.stop_id
      WHERE ts.trip_id = $1
        AND ts.is_boarding_allowed = true
      ORDER BY ts.stop_order ASC
      `,
      [booking.trip_id]
    );

    const allStops = allStopsRes.rows.map((st) => ({
      ...st,
      _idx: prog.progressIndex(Number(st.lat), Number(st.lon)),
    })).sort((a, b) => a._idx - b._idx);

    // Only stops strictly ahead of bus
    const aheadStops = allStops.filter((s) => s._idx > busIdx);

    // Hide next 2 stops ahead (buffer)
    const allowedStops = aheadStops.slice(2);
    const allowedIds = new Set(allowedStops.map((s) => Number(s.stop_id)));

    if (!allowedIds.has(boardingStopId)) {
      await client.query("ROLLBACK");
      return res.status(400).json({
        message: "Too late to select this stop (bus already passed/near it)",
        code: "BOARDING_STOP_TOO_LATE",
      });
    }

    // Update booking
    const upd = await client.query(
      `
      UPDATE bookings
      SET boarding_stop_id = $1
      WHERE booking_id = $2
      RETURNING booking_id, boarding_stop_id
      `,
      [boardingStopId, bookingId]
    );

    await client.query("COMMIT");
    return res.json({ message: "Boarding stop updated", booking: upd.rows[0] });
  } catch (err) {
    await client.query("ROLLBACK");
    console.error("changeBookingBoardingStop error:", err);
    return res.status(500).json({ message: "Server error" });
  } finally {
    client.release();
  }
}

