import jwt from "jsonwebtoken";
import { pool } from "../db.js";
import { redis } from "../infra/redis.js";

export async function getTrackPayload(req, res) {
  try {
    const bookingId = Number(req.params.bookingId);
    const userId = req.user.userId ?? req.user.id;

    // 1) Verify booking belongs to user
    const q = await pool.query(
  `
  SELECT
    b.booking_id,
    b.trip_id,
    b.status AS booking_status,
    b.boarded_at,
    b.qr_scanned_at,

    t.status AS trip_status,
    t.departure_time AS scheduled_start_time,
    NULL::timestamp AS actual_start_time,

    r.route_name,

    bs.stop_name AS pickup_stop_name,
    bs.lat AS pickup_lat,
    bs.lon AS pickup_lng,

    ds.stop_name AS drop_stop_name

  FROM bookings b
  JOIN trips t ON t.trip_id = b.trip_id
  JOIN routes r ON r.route_id = t.route_id

  LEFT JOIN stops bs ON bs.stop_id = b.boarding_stop_id
  LEFT JOIN stops ds ON ds.stop_id = b.dropping_stop_id

  WHERE b.booking_id = $1 AND b.user_id = $2
  LIMIT 1
  `,
  [bookingId, userId]
);


    if (q.rowCount === 0) {
      return res.status(404).json({ message: "Booking not found" });
    }

    const row = q.rows[0];

    // 2) fetch realtime snapshot from redis
    const liveRaw = await redis.get(`trip:${row.trip_id}:live`);
    const etaRaw = await redis.get(`trip:${row.trip_id}:eta`);
    const healthRaw = await redis.get(`trip:${row.trip_id}:health`);

    const live = liveRaw ? JSON.parse(liveRaw) : null;
    const eta = etaRaw ? JSON.parse(etaRaw) : null;
    const health = healthRaw ? JSON.parse(healthRaw) : null;

    // 3) choose map mode
    const mapMode =
      row.booking_status === "boarded"
        ? "ONBOARD"
        : row.trip_status === "scheduled"
          ? "PRE_TRIP"
          : "LIVE_TO_PICKUP";

    return res.json({
      bookingId: row.booking_id,
      tripId: row.trip_id,
      bookingStatus: row.booking_status,
      tripStatus: row.trip_status,
      delayMinutes: row.delay_minutes ?? 0,
      routeName: row.route_name,
      scheduledStart: row.scheduled_start_time,
      actualStart: row.actual_start_time,
      pickupStop: row.pickup_stop_name
        ? { name: row.pickup_stop_name, lat: row.pickup_lat, lng: row.pickup_lng }
        : null,
      dropStop: row.drop_stop_name ? { name: row.drop_stop_name } : null,
      mapMode,
      realtime: { live, eta, health },
    });
  } catch (e) {
    return res.status(400).json({ message: e.message });
  }
}

export async function createWsToken(req, res) {
  try {
    const tripId = Number(req.params.tripId);

    // Keep WS tokens short-lived
    const token = jwt.sign(
      { tripId, typ: "ws" },
      process.env.WS_SECRET,
      { expiresIn: "15m" }
    );

    return res.json({ token });
  } catch (e) {
    return res.status(400).json({ message: e.message });
  }
}
