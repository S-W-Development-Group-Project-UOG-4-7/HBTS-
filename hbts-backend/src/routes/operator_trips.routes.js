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

async function buildInsert(table, columnValueMap) {
  const columnsInDb = await getColumns(table);
  const columns = [];
  const values = [];

  Object.entries(columnValueMap).forEach(([column, value]) => {
    if (value !== undefined && columnsInDb.has(column)) {
      columns.push(column);
      values.push(value);
    }
  });

  return { columns, values };
}

async function buildUpdate(table, columnValueMap) {
  const columnsInDb = await getColumns(table);
  const sets = [];
  const values = [];

  Object.entries(columnValueMap).forEach(([column, value]) => {
    if (value !== undefined && columnsInDb.has(column)) {
      values.push(value);
      sets.push(`${column} = $${values.length}`);
    }
  });

  return { sets, values };
}

function _parseDate(value) {
  if (!value) return null;
  const text = String(value).trim();
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return null;
  return text;
}

function _resolveRange(query) {
  const fromRaw = query.from ?? query.start ?? query.startDate;
  const toRaw = query.to ?? query.end ?? query.endDate;

  if (!fromRaw && !toRaw) {
    return { hasRange: false };
  }

  const from = _parseDate(fromRaw);
  const to = _parseDate(toRaw);

  if (!from && !to) {
    return { error: "from/to must be YYYY-MM-DD" };
  }

  const start = from || to;
  const end = to || from;

  if (start > end) {
    return { error: "from must be before or equal to to" };
  }

  return { hasRange: true, start, end };
}

async function ensureOwned(table, idColumn, id, operatorId) {
  const { rows } = await pool.query(
    `
    SELECT 1
    FROM ${table}
    WHERE ${idColumn} = $1 AND operator_id = $2
    LIMIT 1
    `,
    [id, operatorId]
  );
  return Boolean(rows.length);
}

async function ensureRouteOwned(routeId, operatorId) {
  const columns = await getColumns("routes");
  if (!columns.has("route_id") || !columns.has("operator_id")) {
    // Fallback: allow if table metadata missing
    return true;
  }

  const owned = await ensureOwned("routes", "route_id", routeId, operatorId);
  return owned;
}

router.use(operatorAuth);

// List trips for this operator
router.get("/", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      SELECT *
      FROM trips
      WHERE operator_id = $1
      ORDER BY trip_id DESC
      `,
      [req.operatorId]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load trips", error: e.message });
  }
});

// Get one trip
router.get("/:tripId", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const { rows } = await pool.query(
      `
      SELECT *
      FROM trips
      WHERE trip_id = $1
        AND operator_id = $2
      LIMIT 1
      `,
      [tripId, req.operatorId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Trip not found" });
    }

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load trip", error: e.message });
  }
});

// View bookings for a specific trip (operator scoped)
router.get("/:tripId/bookings", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const ownedTrip = await ensureOwned("trips", "trip_id", tripId, req.operatorId);
    if (!ownedTrip) {
      return res.status(404).json({ message: "Trip not found" });
    }

    const { rows } = await pool.query(
      `
      SELECT
        b.booking_id,
        b.trip_id,
        COUNT(b.seat_id) AS seats_booked
      FROM bookings b
      JOIN trips t ON t.trip_id = b.trip_id
      WHERE b.trip_id = $1
        AND t.operator_id = $2
        AND t.deleted_at IS NULL
      GROUP BY b.booking_id, b.trip_id
      ORDER BY b.booking_id DESC
      `,
      [tripId, req.operatorId]
    );

    return res.json({ tripId, count: rows.length, items: rows });
  } catch (e) {
    return res.status(500).json({ message: "Failed to load trip bookings", error: e.message });
  }
});

// View assigned trips (filter by driverId or busId)
router.get("/assigned/all", async (req, res) => {
  try {
    const driverColumns = await getColumns("drivers");
    const busColumns = await getColumns("buses");
    const routeColumns = await getColumns("routes");
    const tripColumns = await getColumns("trips");

    const driverNameCol = driverColumns.has("name")
      ? "name"
      : driverColumns.has("driver_name")
        ? "driver_name"
        : driverColumns.has("full_name")
          ? "full_name"
          : null;

    const busPlateCol = busColumns.has("license_plate_no")
      ? "license_plate_no"
      : busColumns.has("plate_no")
        ? "plate_no"
        : busColumns.has("license_no")
          ? "license_no"
          : null;

    const routeNameCol = routeColumns.has("route_name")
      ? "route_name"
      : routeColumns.has("name")
        ? "name"
        : null;

    const routeFromCol = routeColumns.has("from_location")
      ? "from_location"
      : routeColumns.has("origin")
        ? "origin"
        : null;

    const routeToCol = routeColumns.has("to_location")
      ? "to_location"
      : routeColumns.has("destination")
        ? "destination"
        : null;

    const busPlateSelect = busPlateCol
      ? `b.${busPlateCol} AS license_plate_no`
      : "NULL AS license_plate_no";
    const driverNameSelect = driverNameCol
      ? `d.${driverNameCol} AS driver_name`
      : "NULL AS driver_name";
    const routeNameSelect = routeNameCol
      ? `r.${routeNameCol} AS route_name`
      : "NULL AS route_name";
    const routeFromSelect = routeFromCol
      ? `r.${routeFromCol} AS from_location`
      : "NULL AS from_location";
    const routeToSelect = routeToCol
      ? `r.${routeToCol} AS to_location`
      : "NULL AS to_location";

    const filters = ["t.operator_id = $1"];
    const params = [req.operatorId];

    const statusRaw = req.query.status;
    if (statusRaw !== undefined && statusRaw !== null && String(statusRaw).trim() !== "") {
      params.push(String(statusRaw));
      filters.push(`LOWER(t.status) = LOWER($${params.length})`);
    }

    const range = _resolveRange(req.query || {});
    if (range.error) {
      return res.status(400).json({ message: range.error });
    }

    if (range.hasRange && tripColumns.has("trip_date")) {
      params.push(range.start, range.end);
      filters.push(`t.trip_date >= $${params.length - 1}::date AND t.trip_date <= $${params.length}::date`);
    }

    const driverIdRaw = req.query.driverId || req.query.driver_id;
    const busIdRaw = req.query.busId || req.query.bus_id;

    if (driverIdRaw !== undefined) {
      const driverId = Number(driverIdRaw);
      if (!Number.isInteger(driverId)) {
        return res.status(400).json({ message: "driverId must be an integer" });
      }
      params.push(driverId);
      filters.push(`t.driver_id = $${params.length}`);
    }

    if (busIdRaw !== undefined) {
      const busId = Number(busIdRaw);
      if (!Number.isInteger(busId)) {
        return res.status(400).json({ message: "busId must be an integer" });
      }
      params.push(busId);
      filters.push(`t.bus_id = $${params.length}`);
    }

    const { rows } = await pool.query(
      `
      SELECT
        t.*,
        ${busPlateSelect},
        ${driverNameSelect},
        ${routeNameSelect},
        ${routeFromSelect},
        ${routeToSelect}
      FROM trips t
      LEFT JOIN buses b   ON b.bus_id = t.bus_id
      LEFT JOIN drivers d ON d.driver_id = t.driver_id
      LEFT JOIN routes r  ON r.route_id = t.route_id
      WHERE ${filters.join(" AND ")}
      ORDER BY t.trip_date DESC NULLS LAST, t.departure_time DESC NULLS LAST, t.trip_id DESC
      `,
      params
    );

    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load assigned trips", error: e.message });
  }
});

// Create trip
router.post("/", async (req, res) => {
  try {
    const {
      routeId,
      route_id,
      busId,
      bus_id,
      driverId,
      driver_id,
      tripDate,
      trip_date,
      departure_time,
      arrival_time,
      fare,
      status = "scheduled",
      seatsAvailable,
      seats_available,
      seatCapacity,
      seat_capacity,
    } = req.body || {};

    const resolvedRouteId = routeId || route_id;
    const resolvedBusId = busId || bus_id;
    const resolvedDriverId = driverId || driver_id;
    const resolvedTripDate = tripDate || trip_date;

    if (!resolvedRouteId || !resolvedBusId || !resolvedDriverId || !resolvedTripDate || !departure_time || !arrival_time) {
      return res.status(400).json({
        message: "routeId, busId, driverId, tripDate, departure_time, arrival_time are required",
      });
    }

    const busOwned = await ensureOwned("buses", "bus_id", Number(resolvedBusId), req.operatorId);
    if (!busOwned) {
      return res.status(403).json({ message: "Bus does not belong to this operator" });
    }

    const driverOwned = await ensureOwned("drivers", "driver_id", Number(resolvedDriverId), req.operatorId);
    if (!driverOwned) {
      return res.status(403).json({ message: "Driver does not belong to this operator" });
    }

    const routeOwned = await ensureRouteOwned(Number(resolvedRouteId), req.operatorId);
    if (!routeOwned) {
      return res.status(403).json({ message: "Route does not belong to this operator" });
    }

    const fareNum = fare === undefined || fare === null ? null : Number(fare);
    if (fareNum !== null && (Number.isNaN(fareNum) || fareNum < 0)) {
      return res.status(400).json({ message: "fare must be a positive number" });
    }

    const seatAvailNum =
      seatsAvailable !== undefined ? Number(seatsAvailable) : seats_available !== undefined ? Number(seats_available) : undefined;
    if (seatAvailNum !== undefined && (Number.isNaN(seatAvailNum) || seatAvailNum < 0)) {
      return res.status(400).json({ message: "seatsAvailable must be a non-negative number" });
    }

    const seatCapacityNum =
      seatCapacity !== undefined ? Number(seatCapacity) : seat_capacity !== undefined ? Number(seat_capacity) : undefined;
    if (seatCapacityNum !== undefined && (Number.isNaN(seatCapacityNum) || seatCapacityNum <= 0)) {
      return res.status(400).json({ message: "seatCapacity must be a positive number" });
    }

    const { columns, values } = await buildInsert("trips", {
      route_id: resolvedRouteId,
      bus_id: resolvedBusId,
      driver_id: resolvedDriverId,
      trip_date: resolvedTripDate,
      departure_time,
      arrival_time,
      status: status || "scheduled",
      fare: fareNum,
      seats_available: seatAvailNum,
      seat_capacity: seatCapacityNum,
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      return res.status(500).json({ message: "operator_id column missing in trips table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO trips (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to create trip", error: e.message });
  }
});

// Update trip (schedule, fare, seat availability, bus/driver assignment)
router.put("/:tripId", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const ownedTrip = await ensureOwned("trips", "trip_id", tripId, req.operatorId);
    if (!ownedTrip) {
      return res.status(404).json({ message: "Trip not found" });
    }

    const resolvedBusId = req.body?.busId || req.body?.bus_id;
    const resolvedDriverId = req.body?.driverId || req.body?.driver_id;
    const resolvedRouteId = req.body?.routeId || req.body?.route_id;

    if (resolvedBusId !== undefined && resolvedBusId !== null) {
      const busOwned = await ensureOwned("buses", "bus_id", Number(resolvedBusId), req.operatorId);
      if (!busOwned) {
        return res.status(403).json({ message: "Bus does not belong to this operator" });
      }
    }

    if (resolvedDriverId !== undefined && resolvedDriverId !== null) {
      const driverOwned = await ensureOwned("drivers", "driver_id", Number(resolvedDriverId), req.operatorId);
      if (!driverOwned) {
        return res.status(403).json({ message: "Driver does not belong to this operator" });
      }
    }

    if (resolvedRouteId !== undefined && resolvedRouteId !== null) {
      const routeOwned = await ensureRouteOwned(Number(resolvedRouteId), req.operatorId);
      if (!routeOwned) {
        return res.status(403).json({ message: "Route does not belong to this operator" });
      }
    }

    const fareNum =
      req.body?.fare === undefined || req.body?.fare === null ? req.body?.fare : Number(req.body?.fare);
    if (fareNum !== undefined && fareNum !== null && (Number.isNaN(fareNum) || fareNum < 0)) {
      return res.status(400).json({ message: "fare must be a positive number" });
    }

    const seatAvailNum =
      req.body?.seatsAvailable !== undefined
        ? Number(req.body.seatsAvailable)
        : req.body?.seats_available !== undefined
        ? Number(req.body.seats_available)
        : undefined;
    if (seatAvailNum !== undefined && (Number.isNaN(seatAvailNum) || seatAvailNum < 0)) {
      return res.status(400).json({ message: "seatsAvailable must be a non-negative number" });
    }

    const seatCapacityNum =
      req.body?.seatCapacity !== undefined
        ? Number(req.body.seatCapacity)
        : req.body?.seat_capacity !== undefined
        ? Number(req.body.seat_capacity)
        : undefined;
    if (seatCapacityNum !== undefined && (Number.isNaN(seatCapacityNum) || seatCapacityNum <= 0)) {
      return res.status(400).json({ message: "seatCapacity must be a positive number" });
    }

    const { sets, values } = await buildUpdate("trips", {
      route_id: resolvedRouteId,
      bus_id: resolvedBusId,
      driver_id: resolvedDriverId,
      trip_date: req.body?.tripDate || req.body?.trip_date,
      departure_time: req.body?.departure_time,
      arrival_time: req.body?.arrival_time,
      status: req.body?.status,
      fare: fareNum,
      seats_available: seatAvailNum,
      seat_capacity: seatCapacityNum,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(tripId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE trips
         SET ${sets.join(", ")}
       WHERE trip_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to update trip", error: e.message });
  }
});

// Optional: cancel/delete trip
router.delete("/:tripId", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const ownedTrip = await ensureOwned("trips", "trip_id", tripId, req.operatorId);
    if (!ownedTrip) {
      return res.status(404).json({ message: "Trip not found" });
    }

    await pool.query(
      `
      DELETE FROM trips
      WHERE trip_id = $1
        AND operator_id = $2
      `,
      [tripId, req.operatorId]
    );

    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ message: "Failed to delete trip", error: e.message });
  }
});

// Start trip (status -> running)
router.post("/:tripId/start", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    await client.query("BEGIN");
    begun = true;

    const tripRes = await client.query(
      `SELECT * FROM trips WHERE trip_id = $1 AND operator_id = $2 FOR UPDATE`,
      [tripId, req.operatorId]
    );

    if (!tripRes.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const trip = tripRes.rows[0];
    const currentStatus = String(trip.status || "").toLowerCase();

    if (currentStatus === "cancelled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Trip is cancelled" });
    }

    if (currentStatus === "completed") {
      await client.query("COMMIT");
      return res.json(trip);
    }

    if (currentStatus === "running") {
      await client.query("COMMIT");
      return res.json(trip);
    }

    const columns = await getColumns("trips");
    const sets = [`status = 'running'`];
    if (columns.has("started_at")) {
      sets.push(`started_at = COALESCE(started_at, NOW())`);
    }
    if (columns.has("updated_at")) {
      sets.push(`updated_at = NOW()`);
    }

    const { rows } = await client.query(
      `
      UPDATE trips
         SET ${sets.join(", ")}
       WHERE trip_id = $1
         AND operator_id = $2
      RETURNING *
      `,
      [tripId, req.operatorId]
    );

    await client.query("COMMIT");
    return res.json(rows[0]);
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to start trip", error: e.message });
  } finally {
    client.release();
  }
});

// End trip (status -> completed)
router.post("/:tripId/end", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    await client.query("BEGIN");
    begun = true;

    const tripRes = await client.query(
      `SELECT * FROM trips WHERE trip_id = $1 AND operator_id = $2 FOR UPDATE`,
      [tripId, req.operatorId]
    );

    if (!tripRes.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const trip = tripRes.rows[0];
    const currentStatus = String(trip.status || "").toLowerCase();

    if (currentStatus === "cancelled") {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Trip is cancelled" });
    }

    if (currentStatus === "completed") {
      await client.query("COMMIT");
      return res.json(trip);
    }

    const columns = await getColumns("trips");
    const sets = [`status = 'completed'`];
    if (columns.has("ended_at")) {
      sets.push(`ended_at = NOW()`);
    }
    if (columns.has("updated_at")) {
      sets.push(`updated_at = NOW()`);
    }

    const { rows } = await client.query(
      `
      UPDATE trips
         SET ${sets.join(", ")}
       WHERE trip_id = $1
         AND operator_id = $2
      RETURNING *
      `,
      [tripId, req.operatorId]
    );

    await client.query("COMMIT");
    return res.json(rows[0]);
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to end trip", error: e.message });
  } finally {
    client.release();
  }
});

export default router;
