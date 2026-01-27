import express from "express";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";

const router = express.Router();

const COLUMN_CACHE = {};

async function getColumns(table) {
  if (COLUMN_CACHE[table]) return COLUMN_CACHE[table];
  const { rows } = await pool.query(
    `
    SELECT column_name
    FROM information_schema.columns
    WHERE table_name = $1
    `,
    [table]
  );
  const set = new Set(rows.map((r) => r.column_name));
  COLUMN_CACHE[table] = set;
  return set;
}

function pickColumn(columns, candidates) {
  for (const candidate of candidates) {
    if (columns.has(candidate)) return candidate;
  }
  return null;
}

// All ticket validation routes require an operator token
router.use(operatorAuth);

/**
 * POST /operator/tickets/validate
 * Body: { bookingId?: number, qrCode?: string }
 * Either bookingId or qrCode is required. Validation is restricted to the
 * authenticated operator's trips.
 */
router.post("/validate", async (req, res) => {
  try {
    const { bookingId, qrCode } = req.body || {};

    const routeColumns = await getColumns("routes");
    const seatColumns = await getColumns("seats");
    const userColumns = await getColumns("users");

    const routeNameCol = pickColumn(routeColumns, ["route_name", "name"]);
    const routeFromCol = pickColumn(routeColumns, ["from_location", "origin", "from"]);
    const routeToCol = pickColumn(routeColumns, ["to_location", "destination", "to"]);
    const seatLabelCol = pickColumn(seatColumns, ["seat_label", "seat_no", "seat_number"]);
    const userNameCol = pickColumn(userColumns, ["name", "full_name"]);
    const userEmailCol = pickColumn(userColumns, ["email"]);

    const routeNameSelect = routeNameCol ? `r.${routeNameCol} AS route_name` : "NULL AS route_name";
    const routeFromSelect = routeFromCol ? `r.${routeFromCol} AS from_location` : "NULL AS from_location";
    const routeToSelect = routeToCol ? `r.${routeToCol} AS to_location` : "NULL AS to_location";
    const seatLabelSelect = seatLabelCol ? `s.${seatLabelCol} AS seat_label` : "NULL AS seat_label";
    const userNameSelect = userNameCol ? `u.${userNameCol} AS passenger_name` : "NULL AS passenger_name";
    const userEmailSelect = userEmailCol ? `u.${userEmailCol} AS passenger_email` : "NULL AS passenger_email";

    const filters = [];
    const params = [req.operatorId];

    if (bookingId !== undefined && bookingId !== null && bookingId !== "") {
      const idNum = Number(bookingId);
      if (!Number.isInteger(idNum)) {
        return res.status(400).json({ message: "bookingId must be an integer" });
      }
      params.push(idNum);
      filters.push(`b.booking_id = $${params.length}`);
    }

    if (qrCode) {
      params.push(String(qrCode).trim());
      filters.push(`b.qr_code = $${params.length}`);
    }

    if (!filters.length) {
      return res.status(400).json({ message: "bookingId or qrCode is required" });
    }

    const { rows } = await pool.query(
      `
      SELECT
        b.booking_id,
        b.status          AS booking_status,
        b.paid_via,
        b.price,
        b.booking_time,
        b.qr_code,
        b.seat_id,
        t.trip_id,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status          AS trip_status,
        t.operator_id,
        t.bus_id,
        t.driver_id,
        ${routeNameSelect},
        ${routeFromSelect},
        ${routeToSelect},
        ${seatLabelSelect},
        u.user_id         AS passenger_id,
        ${userNameSelect},
        ${userEmailSelect}
      FROM bookings b
      JOIN trips   t ON t.trip_id = b.trip_id
      JOIN routes  r ON r.route_id = t.route_id
      LEFT JOIN seats s ON s.seat_id = b.seat_id
      LEFT JOIN users u ON u.user_id = b.user_id
      WHERE t.operator_id = $1
        AND (${filters.join(" OR ")})
      LIMIT 1
      `,
      params
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Ticket not found for this operator" });
    }

    const row = rows[0];
    return res.json({
      bookingId: row.booking_id,
      bookingStatus: row.booking_status,
      paidVia: row.paid_via,
      price: row.price,
      bookingTime: row.booking_time,
      qrCode: row.qr_code,
      trip: {
        tripId: row.trip_id,
        tripDate: row.trip_date,
        departureTime: row.departure_time,
        arrivalTime: row.arrival_time,
        status: row.trip_status,
        operatorId: row.operator_id,
        busId: row.bus_id,
        driverId: row.driver_id,
        routeName: row.route_name,
        from: row.from_location,
        to: row.to_location,
      },
      seatLabel: row.seat_label,
      passenger: {
        id: row.passenger_id,
        name: row.passenger_name,
        email: row.passenger_email,
      },
    });
  } catch (e) {
    return res.status(500).json({ message: "Ticket validation failed", error: e.message });
  }
});

export default router;
