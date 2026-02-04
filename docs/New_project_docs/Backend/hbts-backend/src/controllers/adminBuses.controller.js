import { pool } from "../db.js";

let cachedBusColumns = null;
const getBusColumns = async () => {
  if (cachedBusColumns) return cachedBusColumns;
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'buses'
    `
  );
  cachedBusColumns = rows.map((r) => r.column_name);
  return cachedBusColumns;
};

const pickColumn = (columns, candidates) =>
  candidates.find((c) => columns.includes(c));

const getIdColumn = (columns) =>
  pickColumn(columns, [
    "bus_id",
    "id",
    "busId",
    "busid",
  ]);

const normalizeBusInput = (body) => {
  const rawServiceType = body.serviceType ?? body.service_type ?? null;
  const normalizedServiceType =
    typeof rawServiceType === "string"
      ? rawServiceType.trim().toLowerCase()
      : rawServiceType;

  return {
    operatorId: body.operatorId ?? body.operator_id ?? body.operator ?? null,
    licensePlateNo:
      body.licensePlateNo ?? body.license_plate_no ?? body.license_plate ?? null,
    routeNo: body.routeNo ?? body.route_no ?? body.route ?? null,
    capacity: body.capacity ?? null,
    model: body.model ?? null,
    serviceType: normalizedServiceType,
  };
};

const fetchBusById = async (id, idCol = "bus_id") => {
  const result = await pool.query(
    `
    SELECT
      b.bus_id,
      b.operator_id,
      b.license_plate_no,
      b.route_no,
      b.capacity,
      b.model,
      b.service_type,
      b.created_at,
      b.updated_at,
      c.name AS operator_name
    FROM buses b
    LEFT JOIN company c ON c.operator_id = b.operator_id
    WHERE b."${idCol}" = $1
    LIMIT 1
    `,
    [id]
  );

  return result.rows[0] ?? null;
};

export const listBuses = async (req, res) => {
  try {
    const {
      busId,
      operatorId,
      licensePlateNo,
      routeNo,
      capacity,
      serviceType,
      status,
      includeDeleted,
    } = req.query;

    const columns = await getBusColumns();
    const hasDeletedAt = columns.includes("deleted_at");
    const hasIsDeleted = columns.includes("is_deleted");
    const statusFilter = (status ?? "").toString().toLowerCase();
    const includeAll = ["1", "true", "yes"].includes(
      (includeDeleted ?? "").toString().toLowerCase()
    );

    if (statusFilter === "deleted" && !hasDeletedAt && !hasIsDeleted) {
      return res.json([]);
    }

    const conditions = [];
    const params = [];

    const pushNumberFilter = (value, column) => {
      if (value == null || value === "") return;
      if (!columns.includes(column)) return;
      const parsed = Number.parseInt(value, 10);
      if (Number.isNaN(parsed)) {
        throw new Error(`Invalid ${column} value`);
      }
      conditions.push(`b.${column} = $${params.length + 1}`);
      params.push(parsed);
    };

    pushNumberFilter(busId, "bus_id");
    pushNumberFilter(operatorId, "operator_id");
    pushNumberFilter(capacity, "capacity");

    if (licensePlateNo && columns.includes("license_plate_no")) {
      conditions.push(
        `LOWER(b.license_plate_no) = LOWER($${params.length + 1})`
      );
      params.push(licensePlateNo);
    }

    if (routeNo && columns.includes("route_no")) {
      conditions.push(`LOWER(b.route_no) = LOWER($${params.length + 1})`);
      params.push(routeNo);
    }

    if (serviceType && columns.includes("service_type")) {
      conditions.push(
        `LOWER(CAST(b.service_type AS TEXT)) = LOWER($${params.length + 1})`
      );
      params.push(serviceType);
    }

    if (!includeAll && (hasDeletedAt || hasIsDeleted)) {
      if (statusFilter === "deleted") {
        conditions.push(
          hasDeletedAt ? "b.deleted_at IS NOT NULL" : "b.is_deleted = true"
        );
      } else {
        conditions.push(
          hasDeletedAt
            ? "b.deleted_at IS NULL"
            : "(b.is_deleted IS NULL OR b.is_deleted = false)"
        );
      }
    }

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const result = await pool.query(
      `
      SELECT
        b.bus_id,
        b.operator_id,
        b.license_plate_no,
        b.route_no,
        b.capacity,
        b.model,
        b.service_type,
        b.created_at,
        b.updated_at,
        c.name AS operator_name
      FROM buses b
      LEFT JOIN company c ON c.operator_id = b.operator_id
      ${whereSql}
      ORDER BY b.created_at DESC
      `,
      params
    );

    res.json(result.rows);
  } catch (err) {
    const message =
      err?.message?.includes("Invalid") ? err.message : "Failed to load buses";
    if (message.startsWith("Invalid")) {
      return res.status(400).json({ message });
    }
    console.error("List buses error:", err);
    res.status(500).json({ message });
  }
};

export const listDeletedBuses = async (req, res) => {
  req.query = { ...req.query, status: "deleted" };
  return listBuses(req, res);
};

export const addBus = async (req, res) => {
  try {
    const columns = await getBusColumns();
    const data = normalizeBusInput(req.body ?? {});

    const cols = [];
    const params = [];
    const placeholders = [];

    const addParam = (column, value) => {
      if (!column) return;
      cols.push(`"${column}"`);
      params.push(value ?? null);
      placeholders.push(`$${params.length}`);
    };

    addParam(pickColumn(columns, ["operator_id", "operatorid", "operatorId"]), data.operatorId);
    addParam(
      pickColumn(columns, ["license_plate_no", "license_plate", "licensePlateNo"]),
      data.licensePlateNo
    );
    addParam(pickColumn(columns, ["route_no", "route", "routeNo"]), data.routeNo);
    addParam(pickColumn(columns, ["capacity", "seats"]), data.capacity);
    addParam(pickColumn(columns, ["model"]), data.model);
    addParam(
      pickColumn(columns, ["service_type", "serviceType"]),
      data.serviceType
    );

    if (columns.includes("created_at")) {
      cols.push('"created_at"');
      placeholders.push("now()");
    }
    if (columns.includes("updated_at")) {
      cols.push('"updated_at"');
      placeholders.push("now()");
    }

    if (!cols.length) {
      return res.status(400).json({ message: "Bus fields are not configured" });
    }

    const result = await pool.query(
      `
      INSERT INTO buses (${cols.join(", ")})
      VALUES (${placeholders.join(", ")})
      RETURNING *
      `,
      params
    );

    const row = result.rows[0];
    if (!row) {
      return res.status(500).json({ message: "Failed to add bus" });
    }

    const idCol = getIdColumn(columns) ?? "bus_id";
    const full = await fetchBusById(row[idCol] ?? row.bus_id, idCol);

    return res.status(201).json(full ?? row);
  } catch (err) {
    console.error("Add bus error:", err);
    res.status(500).json({ message: "Failed to add bus" });
  }
};

export const updateBus = async (req, res) => {
  try {
    const { id } = req.params;
    const columns = await getBusColumns();
    const data = normalizeBusInput(req.body ?? {});

    const updates = [];
    const params = [];

    const addUpdate = (column, value) => {
      if (!column || value === undefined) return;
      updates.push(`"${column}" = $${params.length + 1}`);
      params.push(value ?? null);
    };

    addUpdate(pickColumn(columns, ["operator_id", "operatorid", "operatorId"]), data.operatorId);
    addUpdate(
      pickColumn(columns, ["license_plate_no", "license_plate", "licensePlateNo"]),
      data.licensePlateNo
    );
    addUpdate(pickColumn(columns, ["route_no", "route", "routeNo"]), data.routeNo);
    addUpdate(pickColumn(columns, ["capacity", "seats"]), data.capacity);
    addUpdate(pickColumn(columns, ["model"]), data.model);
    addUpdate(
      pickColumn(columns, ["service_type", "serviceType"]),
      data.serviceType
    );

    if (updates.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    if (columns.includes("updated_at")) {
      updates.push("updated_at = now()");
    }

    const where = [];
    const idCol = getIdColumn(columns) ?? "bus_id";
    where.push(`"${idCol}" = $${params.length + 1}`);
    params.push(id);

    if (columns.includes("deleted_at")) {
      where.push("deleted_at IS NULL");
    } else if (columns.includes("is_deleted")) {
      where.push("(is_deleted IS NULL OR is_deleted = false)");
    }

    const result = await pool.query(
      `
      UPDATE buses
      SET ${updates.join(", ")}
      WHERE ${where.join(" AND ")}
      RETURNING *
      `,
      params
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Bus not found" });
    }

    const full = await fetchBusById(id, idCol);
    return res.json(full ?? result.rows[0]);
  } catch (err) {
    console.error("Update bus error:", err);
    res.status(500).json({ message: "Failed to update bus" });
  }
};

export const deleteBus = async (req, res) => {
  try {
    const { id } = req.params;
    const columns = await getBusColumns();
    const idCol = getIdColumn(columns) ?? "bus_id";

    let result = null;
    if (columns.includes("deleted_at")) {
      result = await pool.query(
        `
        UPDATE buses
        SET deleted_at = now(),
            updated_at = now()
        WHERE "${idCol}" = $1
          AND deleted_at IS NULL
        RETURNING ${idCol}
        `,
        [id]
      );
    } else if (columns.includes("is_deleted")) {
      result = await pool.query(
        `
        UPDATE buses
        SET is_deleted = true,
            updated_at = now()
        WHERE "${idCol}" = $1
          AND (is_deleted IS NULL OR is_deleted = false)
        RETURNING ${idCol}
        `,
        [id]
      );
    } else {
      return res
        .status(400)
        .json({ message: "Soft delete not supported for buses" });
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Bus not found" });
    }

    res.json({ message: "Bus deleted" });
  } catch (err) {
    console.error("Delete bus error:", err);
    res.status(500).json({ message: "Failed to delete bus" });
  }
};

export const restoreBus = async (req, res) => {
  try {
    const { id } = req.params;
    const columns = await getBusColumns();
    const idCol = getIdColumn(columns) ?? "bus_id";

    let result = null;
    if (columns.includes("deleted_at")) {
      result = await pool.query(
        `
        UPDATE buses
        SET deleted_at = NULL,
            updated_at = now()
        WHERE "${idCol}" = $1
          AND deleted_at IS NOT NULL
        RETURNING *
        `,
        [id]
      );
    } else if (columns.includes("is_deleted")) {
      result = await pool.query(
        `
        UPDATE buses
        SET is_deleted = false,
            updated_at = now()
        WHERE "${idCol}" = $1
          AND is_deleted = true
        RETURNING *
        `,
        [id]
      );
    } else {
      return res
        .status(400)
        .json({ message: "Restore not supported for buses" });
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Bus not found" });
    }

    const full = await fetchBusById(id, idCol);
    return res.json(full ?? result.rows[0]);
  } catch (err) {
    console.error("Restore bus error:", err);
    res.status(500).json({ message: "Failed to restore bus" });
  }
};
