// src/controllers/trip.controller.js
import { pool } from "../db.js";
import { expirePendingBookingsOnce } from "../jobs/expirePendingBookings.job.js";
import { broadcastTripLocation } from "../ws/tracking.ws.js";


const TTL_MINUTES = Number(process.env.PENDING_TTL_MINUTES || 10);

/**
 * GET /api/trips?from=Colombo&to=Kandy&date=YYYY-MM-DD
 */
export async function searchTrips(req, res) {
  try {
    const { from, to, date } = req.query;

    if (!from || !to || !date) {
      return res.status(400).json({ message: "from, to and date are required" });
    }

    // Clean expired pending bookings so available seats are accurate
    await expirePendingBookingsOnce();

    const result = await pool.query(
      `
      SELECT
        t.trip_id AS id,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status,
        r.route_name,
        r.from_location,
        r.to_location,
        b.bus_id,
        b.capacity,
        b.service_type
      FROM trips t
      JOIN routes r ON t.route_id = r.route_id
      JOIN buses b ON t.bus_id = b.bus_id
      WHERE LOWER(r.from_location) = LOWER(TRIM($1))
  AND LOWER(r.to_location)   = LOWER(TRIM($2))
  AND t.trip_date            = $3::date

      ORDER BY t.departure_time
      `,
      [from, to, date]
    );

    return res.json(result.rows);
  } catch (err) {
    console.error("searchTrips error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /api/trips/:id
 */
export async function getTripById(req, res) {
  try {
    const { id } = req.params;

    await expirePendingBookingsOnce();

    const result = await pool.query(
      `
      SELECT
        t.trip_id AS id,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status,
        t.operator_id,
        t.bus_id,
        t.driver_id,
        r.route_name,
        r.from_location,
        r.to_location,
        r.distance_km,
        r.polyline,
        b.capacity,
        b.service_type,
        b.license_plate_no,
        b.model
      FROM trips t
      JOIN routes r ON t.route_id = r.route_id
      JOIN buses b ON t.bus_id = b.bus_id
      WHERE t.trip_id = $1
      `,
      [id]
    );

    if (result.rowCount === 0) {
      return res.status(404).json({ message: "Trip not found" });
    }

    return res.json(result.rows[0]);
  } catch (err) {
    console.error("getTripById error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /api/trips/:id/seats
 * Returns seat layout with booking status.
 */
export async function getTripSeats(req, res) {
  try {
    const { id: tripId } = req.params;

    // Clean expired pending holds
    await expirePendingBookingsOnce();

    const seats = await pool.query(
      `
      SELECT
        s.seat_id,
        s.seat_label,
        s.seat_row,
        s.seat_col,
        s.seat_type,
        CASE
          WHEN b.booking_id IS NULL THEN false
          ELSE true
        END AS is_booked
      FROM trips t
      JOIN seats s ON s.bus_id = t.bus_id
      LEFT JOIN bookings b
        ON b.trip_id = t.trip_id
       AND b.seat_id = s.seat_id
       AND (
         b.status = 'confirmed'
         OR (b.status = 'pending' AND b.booking_time >= NOW() - ($2::text || ' minutes')::interval)
       )
      WHERE t.trip_id = $1
      ORDER BY s.seat_row, s.seat_col
      `,
      [tripId, String(TTL_MINUTES)]
    );

    return res.json(seats.rows);
  } catch (err) {
    console.error("getTripSeats error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function pushTripLocation(req, res) {
  try {
    const tripId = Number(req.params.id);
    if (!tripId) return res.status(400).json({ message: "Invalid trip id" });

    // Role check (tune based on how your JWT stores role)
    const role = req.user?.role;
    const isStaff =
      role === "admin" ||
      role === "operator" ||
      role === "driver" ||
      role === "conductor" ||
      role === "2";

    if (!isStaff) return res.status(403).json({ message: "Forbidden" });

    const { lat, lon, speedMps, heading, gpsAt } = req.body;
    if (lat == null || lon == null) {
      return res.status(400).json({ message: "lat and lon are required" });
    }

    const latNum = Number(lat);
    const lonNum = Number(lon);
    if (!Number.isFinite(latNum) || !Number.isFinite(lonNum)) {
      return res.status(400).json({ message: "lat/lon must be numbers" });
    }

    const t = await pool.query(`SELECT trip_id, status FROM trips WHERE trip_id = $1`, [tripId]);
    if (t.rowCount === 0) return res.status(404).json({ message: "Trip not found" });

    const tripStatus = String(t.rows[0].status);
    if (["cancelled", "completed"].includes(tripStatus)) {
      return res.status(400).json({ message: "Trip is not trackable" });
    }

    const gpsAtTs = gpsAt ? new Date(gpsAt) : new Date();

    const up = await pool.query(
      `
      INSERT INTO trip_live (trip_id, lat, lon, speed_mps, heading, gps_at, updated_at)
      VALUES ($1,$2,$3,$4,$5,$6,NOW())
      ON CONFLICT (trip_id)
      DO UPDATE SET
        lat = EXCLUDED.lat,
        lon = EXCLUDED.lon,
        speed_mps = EXCLUDED.speed_mps,
        heading = EXCLUDED.heading,
        gps_at = EXCLUDED.gps_at,
        updated_at = NOW()
      RETURNING trip_id, lat, lon, speed_mps, heading, gps_at, updated_at
      `,
      [
        tripId,
        latNum,
        lonNum,
        speedMps != null ? Number(speedMps) : null,
        heading != null ? Number(heading) : null,
        gpsAtTs,
      ]
    );

    const loc = up.rows[0];

    await broadcastTripLocation(tripId, {
      trip_id: Number(loc.trip_id),
      lat: Number(loc.lat),
      lon: Number(loc.lon),
      speed_mps: loc.speed_mps != null ? Number(loc.speed_mps) : null,
      heading: loc.heading != null ? Number(loc.heading) : null,
      gps_at: loc.gps_at,
      updated_at: loc.updated_at,
    });

    return res.json({ ok: true, location: loc });
  } catch (err) {
    console.error("pushTripLocation error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}
