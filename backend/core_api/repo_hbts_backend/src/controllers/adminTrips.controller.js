import { pool } from "../db.js";

const tableCache = new Map();

const getColumns = async (tableName) => {
  if (tableCache.has(tableName)) return tableCache.get(tableName);
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = $1
    `,
    [tableName]
  );
  const columns = rows.map((r) => r.column_name);
  tableCache.set(tableName, columns);
  return columns;
};

const pickColumn = (columns, candidates) =>
  candidates.find((c) => columns.includes(c));

const normalizeTripInput = (body) => ({
  routeId: body.routeId ?? body.route_id ?? null,
  operatorId: body.operatorId ?? body.operator_id ?? null,
  busId: body.busId ?? body.bus_id ?? null,
  driverId: body.driverId ?? body.driver_id ?? null,
  tripDate: body.tripDate ?? body.trip_date ?? null,
  departureTime: body.departureTime ?? body.departure_time ?? null,
  arrivalTime: body.arrivalTime ?? body.arrival_time ?? null,
  status: body.status ?? null,
});

const getOrderColumn = (columns) =>
  columns.includes("trip_date")
    ? "trip_date"
    : columns.includes("trip_id")
      ? "trip_id"
      : columns[0];

export const listTrips = async (req, res) => {
  try {
    const columns = await getColumns("trips");
    const driverColumns = await getColumns("drivers");
    const routeColumns = await getColumns("routes");
    const busColumns = await getColumns("buses");

    const {
      tripId,
      routeId,
      operatorId,
      busId,
      driverId,
      status,
      tripDate,
      includeDeleted,
    } = req.query;

    const includeAll = ["1", "true", "yes"].includes(
      (includeDeleted ?? "").toString().toLowerCase()
    );

    const conditions = [];
    const params = [];

    const pushNumber = (value, column) => {
      if (!value || !columns.includes(column)) return;
      const parsed = Number.parseInt(value, 10);
      if (Number.isNaN(parsed)) {
        return res.status(400).json({ message: `Invalid ${column}` });
      }
      conditions.push(`t.${column} = $${params.length + 1}`);
      params.push(parsed);
    };

    pushNumber(tripId, "trip_id");
    pushNumber(routeId, "route_id");
    pushNumber(operatorId, "operator_id");
    pushNumber(busId, "bus_id");
    pushNumber(driverId, "driver_id");

    if (status && columns.includes("status")) {
      conditions.push(`LOWER(t.status::text) = LOWER($${params.length + 1})`);
      params.push(status);
    }

    if (tripDate && columns.includes("trip_date")) {
      conditions.push(`t.trip_date = $${params.length + 1}`);
      params.push(tripDate);
    }

    if (!includeAll) {
      if (columns.includes("deleted_at")) {
        conditions.push("t.deleted_at IS NULL");
      } else if (columns.includes("is_deleted")) {
        conditions.push("(t.is_deleted IS NULL OR t.is_deleted = false)");
      }
    }

    const driverNameCol = pickColumn(driverColumns, [
      "name",
      "full_name",
      "driver_name",
      "fullName",
      "driverName",
    ]);
    const routeNameCol = pickColumn(routeColumns, [
      "route_name",
      "name",
      "routeName",
    ]);
    const routeCodeCol = pickColumn(routeColumns, [
      "route_no",
      "route_code",
      "route_number",
      "code",
    ]);
    const busPlateCol = pickColumn(busColumns, [
      "license_plate_no",
      "license_plate",
    ]);

    const selectExtras = [
      driverNameCol
        ? `d."${driverNameCol}" AS driver_name`
        : "NULL AS driver_name",
      routeNameCol
        ? `r."${routeNameCol}" AS route_name`
        : "NULL AS route_name",
      routeCodeCol
        ? `r."${routeCodeCol}" AS route_code`
        : "NULL AS route_code",
      busPlateCol
        ? `b."${busPlateCol}" AS license_plate_no`
        : "NULL AS license_plate_no",
      "c.name AS operator_name",
    ];

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const result = await pool.query(
      `
      SELECT t.*, ${selectExtras.join(", ")}
      FROM trips t
      LEFT JOIN routes r ON r.route_id = t.route_id
      LEFT JOIN buses b ON b.bus_id = t.bus_id
      LEFT JOIN drivers d ON d.driver_id = t.driver_id
      LEFT JOIN company c ON c.operator_id = t.operator_id
      ${whereSql}
      ORDER BY t.${getOrderColumn(columns)} DESC
      `,
      params
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List trips error:", err);
    res.status(500).json({ message: "Failed to load trips" });
  }
};

export const listDeletedTrips = async (req, res) => {
  try {
    const columns = await getColumns("trips");
    const driverColumns = await getColumns("drivers");
    const routeColumns = await getColumns("routes");
    const busColumns = await getColumns("buses");
    if (!columns.includes("deleted_at") && !columns.includes("is_deleted")) {
      return res.json([]);
    }

    const where = [];
    if (columns.includes("deleted_at")) {
      where.push("t.deleted_at IS NOT NULL");
    } else if (columns.includes("is_deleted")) {
      where.push("t.is_deleted = true");
    }

    const driverNameCol = pickColumn(driverColumns, [
      "name",
      "full_name",
      "driver_name",
      "fullName",
      "driverName",
    ]);
    const routeNameCol = pickColumn(routeColumns, [
      "route_name",
      "name",
      "routeName",
    ]);
    const routeCodeCol = pickColumn(routeColumns, [
      "route_no",
      "route_code",
      "route_number",
      "code",
    ]);
    const busPlateCol = pickColumn(busColumns, [
      "license_plate_no",
      "license_plate",
    ]);

    const selectExtras = [
      driverNameCol
        ? `d."${driverNameCol}" AS driver_name`
        : "NULL AS driver_name",
      routeNameCol
        ? `r."${routeNameCol}" AS route_name`
        : "NULL AS route_name",
      routeCodeCol
        ? `r."${routeCodeCol}" AS route_code`
        : "NULL AS route_code",
      busPlateCol
        ? `b."${busPlateCol}" AS license_plate_no`
        : "NULL AS license_plate_no",
      "c.name AS operator_name",
    ];

    const result = await pool.query(
      `
      SELECT t.*, ${selectExtras.join(", ")}
      FROM trips t
      LEFT JOIN routes r ON r.route_id = t.route_id
      LEFT JOIN buses b ON b.bus_id = t.bus_id
      LEFT JOIN drivers d ON d.driver_id = t.driver_id
      LEFT JOIN company c ON c.operator_id = t.operator_id
      WHERE ${where.join(" AND ")}
      ORDER BY t.${getOrderColumn(columns)} DESC
      `
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List deleted trips error:", err);
    res.status(500).json({ message: "Failed to load trip history" });
  }
};

export const addTrip = async (req, res) => {
  try {
    const data = normalizeTripInput(req.body ?? {});
    const required = [
      ["routeId", data.routeId],
      ["operatorId", data.operatorId],
      ["busId", data.busId],
      ["driverId", data.driverId],
      ["tripDate", data.tripDate],
      ["departureTime", data.departureTime],
      ["arrivalTime", data.arrivalTime],
    ];
    const missing = required.filter(([, value]) => value == null || value === "");
    if (missing.length) {
      return res
        .status(400)
        .json({ message: `Missing fields: ${missing.map((m) => m[0]).join(", ")}` });
    }

    const result = await pool.query(
      `
      INSERT INTO trips (
        route_id,
        operator_id,
        bus_id,
        driver_id,
        trip_date,
        departure_time,
        arrival_time,
        status
      )
      VALUES ($1,$2,$3,$4,$5,$6,$7,COALESCE($8,'scheduled')::trip_status)
      RETURNING *
      `,
      [
        data.routeId,
        data.operatorId,
        data.busId,
        data.driverId,
        data.tripDate,
        data.departureTime,
        data.arrivalTime,
        data.status,
      ]
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("Add trip error:", err);
    res.status(500).json({ message: "Failed to add trip" });
  }
};

export const updateTrip = async (req, res) => {
  try {
    const data = normalizeTripInput(req.body ?? {});
    const updates = [];
    const params = [];

    const addUpdate = (column, value) => {
      if (value === undefined || value === null || value === "") return;
      updates.push(`${column} = $${params.length + 1}`);
      params.push(value);
    };

    addUpdate("route_id", data.routeId);
    addUpdate("operator_id", data.operatorId);
    addUpdate("bus_id", data.busId);
    addUpdate("driver_id", data.driverId);
    addUpdate("trip_date", data.tripDate);
    addUpdate("departure_time", data.departureTime);
    addUpdate("arrival_time", data.arrivalTime);
    if (data.status) {
      updates.push(`status = $${params.length + 1}::trip_status`);
      params.push(data.status);
    }

    if (!updates.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    const columns = await getColumns("trips");
    if (columns.includes("updated_at")) {
      updates.push("updated_at = now()");
    }

    params.push(req.params.id);

    const where = [`trip_id = $${params.length}`];
    if (columns.includes("deleted_at")) {
      where.push("deleted_at IS NULL");
    } else if (columns.includes("is_deleted")) {
      where.push("(is_deleted IS NULL OR is_deleted = false)");
    }

    const result = await pool.query(
      `
      UPDATE trips
      SET ${updates.join(", ")}
      WHERE ${where.join(" AND ")}
      RETURNING *
      `,
      params
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Trip not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Update trip error:", err);
    res.status(500).json({ message: "Failed to update trip" });
  }
};

export const deleteTrip = async (req, res) => {
  try {
    const columns = await getColumns("trips");
    let result = null;

    if (columns.includes("deleted_at")) {
      const updates = ["deleted_at = now()"];
      if (columns.includes("updated_at")) {
        updates.push("updated_at = now()");
      }
      result = await pool.query(
        `
        UPDATE trips
        SET ${updates.join(", ")}
        WHERE trip_id = $1
          AND deleted_at IS NULL
        RETURNING trip_id
        `,
        [req.params.id]
      );
    } else if (columns.includes("is_deleted")) {
      const updates = ["is_deleted = true"];
      if (columns.includes("updated_at")) {
        updates.push("updated_at = now()");
      }
      result = await pool.query(
        `
        UPDATE trips
        SET ${updates.join(", ")}
        WHERE trip_id = $1
          AND (is_deleted IS NULL OR is_deleted = false)
        RETURNING trip_id
        `,
        [req.params.id]
      );
    } else {
      return res
        .status(400)
        .json({ message: "Soft delete not supported for trips" });
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Trip not found" });
    }

    res.json({ message: "Trip deleted" });
  } catch (err) {
    console.error("Delete trip error:", err);
    res.status(500).json({ message: "Failed to delete trip" });
  }
};

export const restoreTrip = async (req, res) => {
  try {
    const columns = await getColumns("trips");
    let result = null;

    if (columns.includes("deleted_at")) {
      result = await pool.query(
        `
        UPDATE trips
        SET deleted_at = NULL,
            updated_at = now()
        WHERE trip_id = $1
          AND deleted_at IS NOT NULL
        RETURNING *
        `,
        [req.params.id]
      );
    } else if (columns.includes("is_deleted")) {
      result = await pool.query(
        `
        UPDATE trips
        SET is_deleted = false,
            updated_at = now()
        WHERE trip_id = $1
          AND is_deleted = true
        RETURNING *
        `,
        [req.params.id]
      );
    } else {
      return res
        .status(400)
        .json({ message: "Restore not supported for trips" });
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Trip not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Restore trip error:", err);
    res.status(500).json({ message: "Failed to restore trip" });
  }
};

export const addTripStop = async (req, res) => {
  try {
    const tripId = Number.parseInt(req.params.id, 10);
    if (Number.isNaN(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const columns = await getColumns("trip_stops");
    if (!columns.length) {
      return res.status(500).json({ message: "Trip stops table not found" });
    }

    const tripIdCol = pickColumn(columns, ["trip_id", "tripId"]);
    const stopIdCol = pickColumn(columns, ["stop_id", "stopId"]);
    const orderCol = pickColumn(columns, ["stop_order", "stopOrder", "order"]);
    const timeCol = pickColumn(columns, ["scheduled_time", "time"]);
    const boardingCol = pickColumn(columns, [
      "is_boarding_allowed",
      "boarding_allowed",
      "isBoardingAllowed",
    ]);

    if (!tripIdCol || !stopIdCol) {
      return res
        .status(500)
        .json({ message: "Trip stop columns are not configured" });
    }

    const body = req.body ?? {};
    const stopId =
      body.stopId ??
      body.stop_id ??
      body.stop ??
      body.id ??
      null;
    const stopOrder =
      body.stopOrder ?? body.stop_order ?? body.order ?? null;
    const scheduledTime =
      body.scheduledTime ?? body.scheduled_time ?? body.time ?? null;
    const isBoardingAllowed =
      body.isBoardingAllowed ??
      body.is_boarding_allowed ??
      body.boarding_allowed ??
      null;
    const parseBool = (value) => {
      if (typeof value === "boolean") return value;
      const str = value?.toString?.().toLowerCase();
      return ["true", "1", "yes"].includes(str);
    };

    if (stopId == null || stopId == "") {
      return res.status(400).json({ message: "Stop id is required" });
    }

    const cols = [];
    const params = [];
    const placeholders = [];

    const addParam = (column, value) => {
      if (!column) return;
      cols.push(`"${column}"`);
      params.push(value ?? null);
      placeholders.push(`$${params.length}`);
    };

    addParam(tripIdCol, tripId);
    addParam(stopIdCol, stopId);
    if (orderCol && stopOrder != null && stopOrder != "") {
      addParam(orderCol, stopOrder);
    }
    if (timeCol && scheduledTime) {
      addParam(timeCol, scheduledTime);
    }
    if (boardingCol && isBoardingAllowed != null && isBoardingAllowed != "") {
      addParam(boardingCol, parseBool(isBoardingAllowed));
    }

    if (cols.length < 2) {
      return res.status(400).json({ message: "Missing stop data" });
    }

    const result = await pool.query(
      `
      INSERT INTO trip_stops (${cols.join(", ")})
      VALUES (${placeholders.join(", ")})
      RETURNING *
      `,
      params
    );

    res.status(201).json(result.rows[0] ?? {});
  } catch (err) {
    console.error("Add trip stop error:", err);
    res.status(500).json({ message: "Failed to add trip stop" });
  }
};

export const listTripStops = async (req, res) => {
  try {
    const stopsColumns = await getColumns("stops");
    const stopNameCol = pickColumn(stopsColumns, [
      "stop_name",
      "name",
      "title",
    ]);
    const stopCodeCol = pickColumn(stopsColumns, [
      "stop_code",
      "code",
    ]);

    const selectExtras = [
      stopNameCol ? `s."${stopNameCol}" AS stop_name` : "NULL AS stop_name",
      stopCodeCol ? `s."${stopCodeCol}" AS stop_code` : "NULL AS stop_code",
    ];

    const result = await pool.query(
      `
      SELECT ts.*, ${selectExtras.join(", ")}
      FROM trip_stops ts
      LEFT JOIN stops s ON s.stop_id = ts.stop_id
      WHERE ts.trip_id = $1
      ORDER BY ts.stop_order ASC
      `,
      [req.params.id]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List trip stops error:", err);
    res.status(500).json({ message: "Failed to load trip stops" });
  }
};

export const listTripLocationHistory = async (req, res) => {
  try {
    const result = await pool.query(
      `
      SELECT *
      FROM trip_location_history
      WHERE trip_id = $1
      ORDER BY recorded_at DESC
      LIMIT 500
      `,
      [req.params.id]
    );

    res.json(result.rows);
  } catch (err) {
    console.error("Trip location history error:", err);
    res.status(500).json({ message: "Failed to load trip location history" });
  }
};

export const listAssignableDrivers = async (req, res) => {
  try {
    const columns = await getColumns("drivers");
    const idCol = pickColumn(columns, ["driver_id", "id", "driverId", "driverid"]);
    if (!idCol) {
      return res.status(500).json({ message: "Driver id column not found" });
    }

    const nameCol = pickColumn(columns, [
      "name",
      "full_name",
      "driver_name",
      "fullName",
      "driverName",
    ]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const operatorCol = pickColumn(columns, [
      "operator_id",
      "operatorId",
      "operatorid",
      "company_id",
    ]);
    const statusCol = pickColumn(columns, ["status"]);

    const where = [];
    if (statusCol) {
      where.push(`LOWER(d."${statusCol}") = 'active'`);
    }

    const whereSql = where.length ? `WHERE ${where.join(" AND ")}` : "";

    const result = await pool.query(
      `
      SELECT
        d."${idCol}" AS driver_id,
        ${nameCol ? `d."${nameCol}"` : "NULL"} AS name,
        ${phoneCol ? `d."${phoneCol}"` : "NULL"} AS phone,
        ${operatorCol ? `d."${operatorCol}"` : "NULL"} AS operator_id,
        ${statusCol ? `d."${statusCol}"` : "NULL"} AS status
      FROM drivers d
      ${whereSql}
      ORDER BY d."${idCol}" DESC
      `
    );

    res.json(result.rows);
  } catch (err) {
    console.error("Assignable drivers error:", err);
    res.status(500).json({ message: "Failed to load drivers" });
  }
};
