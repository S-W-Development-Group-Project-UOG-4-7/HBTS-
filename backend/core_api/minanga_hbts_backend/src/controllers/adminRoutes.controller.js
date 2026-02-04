import { pool } from "../db.js";

let cachedRoutesTable = null;
let cachedRouteColumns = null;

const getRoutesTable = async () => {
  if (cachedRoutesTable) return cachedRoutesTable;
  const { rows } = await pool.query(
    `
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
        AND table_name IN ('routes', 'route')
      ORDER BY CASE WHEN table_name = 'routes' THEN 0 ELSE 1 END
      LIMIT 1
    `
  );
  cachedRoutesTable = rows[0]?.table_name ?? null;
  return cachedRoutesTable;
};

const getRouteColumns = async (tableName) => {
  if (cachedRouteColumns && cachedRouteColumns.table === tableName) {
    return cachedRouteColumns.columns;
  }
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = $1
    `,
    [tableName]
  );
  const columns = rows.map((r) => r.column_name);
  cachedRouteColumns = { table: tableName, columns };
  return columns;
};

const pickColumn = (columns, candidates) =>
  candidates.find((c) => columns.includes(c));

const getIdColumn = (columns) =>
  pickColumn(columns, ["route_id", "id", "routeId", "routeid"]);

const getOrderColumn = (columns) =>
  getIdColumn(columns) ?? (columns.includes("created_at") ? "created_at" : columns[0]);

const normalizeRouteInput = (body) => {
  const rawStatus = body.status ?? body.route_status ?? null;
  const normalizedStatus =
    typeof rawStatus === "string" ? rawStatus.trim().toLowerCase() : rawStatus;

  return {
    name:
      body.name ??
      body.routeName ??
      body.route_name ??
      body.route ??
      null,
    code:
      body.code ??
      body.routeNo ??
      body.route_no ??
      body.route_number ??
      body.route_code ??
      null,
    origin:
      body.origin ??
      body.start ??
      body.startPoint ??
      body.start_point ??
      body.from_location ??
      body.from ??
      null,
    destination:
      body.destination ??
      body.end ??
      body.endPoint ??
      body.end_point ??
      body.to_location ??
      body.to ??
      null,
    distance:
      body.distance ??
      body.distanceKm ??
      body.distance_km ??
      null,
    fare: body.fare ?? body.price ?? null,
    status: normalizedStatus,
    description: body.description ?? body.notes ?? null,
  };
};

const applySoftDeleteFilter = ({ columns, conditions }) => {
  if (columns.includes("deleted_at")) {
    conditions.push("r.deleted_at IS NULL");
    return true;
  }
  if (columns.includes("is_deleted")) {
    conditions.push("(r.is_deleted IS NULL OR r.is_deleted = false)");
    return true;
  }
  return false;
};

export const listRoutes = async (req, res) => {
  try {
    const tableName = await getRoutesTable();
    if (!tableName) {
      return res.status(500).json({ message: "Routes table not found" });
    }

    const columns = await getRouteColumns(tableName);
    const {
      routeId,
      name,
      code,
      origin,
      destination,
      status,
      includeDeleted,
    } = req.query;

    const includeAll = ["1", "true", "yes"].includes(
      (includeDeleted ?? "").toString().toLowerCase()
    );

    const conditions = [];
    const params = [];

    const pushExact = (value, column) => {
      if (!value || !column) return;
      conditions.push(`LOWER(r."${column}") = LOWER($${params.length + 1})`);
      params.push(value);
    };

    const pushLike = (value, column) => {
      if (!value || !column) return;
      conditions.push(`LOWER(r."${column}") LIKE LOWER($${params.length + 1})`);
      params.push(`%${value}%`);
    };

    if (routeId) {
      const idCol = getIdColumn(columns);
      if (idCol) {
        const parsed = Number.parseInt(routeId, 10);
        if (Number.isNaN(parsed)) {
          return res.status(400).json({ message: "Invalid routeId" });
        }
        conditions.push(`r."${idCol}" = $${params.length + 1}`);
        params.push(parsed);
      }
    }

    pushLike(name, pickColumn(columns, ["route_name", "name", "routeName"]));
    pushLike(
      code,
      pickColumn(columns, ["route_no", "route_number", "route_code", "code"])
    );
    pushLike(
      origin,
      pickColumn(columns, [
        "origin",
        "start_point",
        "start",
        "from_location",
        "from",
      ])
    );
    pushLike(
      destination,
      pickColumn(columns, [
        "destination",
        "end_point",
        "end",
        "to_location",
        "to",
      ])
    );
    pushExact(status, pickColumn(columns, ["status", "route_status"]));

    if (!includeAll) {
      applySoftDeleteFilter({ columns, conditions });
    }

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const result = await pool.query(
      `
      SELECT *
      FROM ${tableName} r
      ${whereSql}
      ORDER BY r.${getOrderColumn(columns)} DESC
      `,
      params
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List routes error:", err);
    res.status(500).json({ message: "Failed to load routes" });
  }
};

export const listDeletedRoutes = async (req, res) => {
  req.query = { ...req.query, includeDeleted: "true" };
  try {
    const tableName = await getRoutesTable();
    if (!tableName) {
      return res.status(500).json({ message: "Routes table not found" });
    }
    const columns = await getRouteColumns(tableName);
    if (!columns.includes("deleted_at") && !columns.includes("is_deleted")) {
      return res.json([]);
    }

    const conditions = [];
    if (columns.includes("deleted_at")) {
      conditions.push("r.deleted_at IS NOT NULL");
    } else if (columns.includes("is_deleted")) {
      conditions.push("r.is_deleted = true");
    }

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const result = await pool.query(
      `
      SELECT *
      FROM ${tableName} r
      ${whereSql}
      ORDER BY r.${getOrderColumn(columns)} DESC
      `
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List deleted routes error:", err);
    res.status(500).json({ message: "Failed to load route history" });
  }
};

export const addRoute = async (req, res) => {
  try {
    const tableName = await getRoutesTable();
    if (!tableName) {
      return res.status(500).json({ message: "Routes table not found" });
    }
    const columns = await getRouteColumns(tableName);
    const data = normalizeRouteInput(req.body ?? {});

    const cols = [];
    const params = [];
    const placeholders = [];

    const addParam = (column, value) => {
      if (!column) return;
      cols.push(`"${column}"`);
      params.push(value ?? null);
      placeholders.push(`$${params.length}`);
    };

    addParam(pickColumn(columns, ["route_name", "name", "routeName"]), data.name);
    addParam(
      pickColumn(columns, ["route_no", "route_number", "route_code", "code"]),
      data.code
    );
    addParam(
      pickColumn(columns, [
        "origin",
        "start_point",
        "start",
        "from_location",
        "from",
      ]),
      data.origin
    );
    addParam(
      pickColumn(columns, [
        "destination",
        "end_point",
        "end",
        "to_location",
        "to",
      ]),
      data.destination
    );
    addParam(pickColumn(columns, ["distance", "distance_km"]), data.distance);
    addParam(pickColumn(columns, ["fare", "price"]), data.fare);
    addParam(pickColumn(columns, ["status", "route_status"]), data.status);
    addParam(pickColumn(columns, ["description", "notes"]), data.description);

    if (columns.includes("created_at")) {
      cols.push('"created_at"');
      placeholders.push("now()");
    }
    if (columns.includes("updated_at")) {
      cols.push('"updated_at"');
      placeholders.push("now()");
    }

    if (!cols.length) {
      return res.status(400).json({ message: "Route fields not configured" });
    }

    const result = await pool.query(
      `
      INSERT INTO ${tableName} (${cols.join(", ")})
      VALUES (${placeholders.join(", ")})
      RETURNING *
      `,
      params
    );

    res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("Add route error:", err);
    res.status(500).json({ message: "Failed to add route" });
  }
};

export const updateRoute = async (req, res) => {
  try {
    const tableName = await getRoutesTable();
    if (!tableName) {
      return res.status(500).json({ message: "Routes table not found" });
    }
    const columns = await getRouteColumns(tableName);
    const data = normalizeRouteInput(req.body ?? {});
    const updates = [];
    const params = [];

    const addUpdate = (column, value) => {
      if (!column || value === undefined) return;
      updates.push(`"${column}" = $${params.length + 1}`);
      params.push(value ?? null);
    };

    addUpdate(pickColumn(columns, ["route_name", "name", "routeName"]), data.name);
    addUpdate(
      pickColumn(columns, ["route_no", "route_number", "route_code", "code"]),
      data.code
    );
    addUpdate(
      pickColumn(columns, [
        "origin",
        "start_point",
        "start",
        "from_location",
        "from",
      ]),
      data.origin
    );
    addUpdate(
      pickColumn(columns, [
        "destination",
        "end_point",
        "end",
        "to_location",
        "to",
      ]),
      data.destination
    );
    addUpdate(pickColumn(columns, ["distance", "distance_km"]), data.distance);
    addUpdate(pickColumn(columns, ["fare", "price"]), data.fare);
    addUpdate(pickColumn(columns, ["status", "route_status"]), data.status);
    addUpdate(pickColumn(columns, ["description", "notes"]), data.description);

    if (updates.length === 0) {
      return res.status(400).json({ message: "No fields to update" });
    }

    if (columns.includes("updated_at")) {
      updates.push("updated_at = now()");
    }

    const idCol = getIdColumn(columns) ?? "route_id";
    params.push(req.params.id);

    const where = [`"${idCol}" = $${params.length}`];
    if (columns.includes("deleted_at")) {
      where.push("deleted_at IS NULL");
    } else if (columns.includes("is_deleted")) {
      where.push("(is_deleted IS NULL OR is_deleted = false)");
    }

    const result = await pool.query(
      `
      UPDATE ${tableName}
      SET ${updates.join(", ")}
      WHERE ${where.join(" AND ")}
      RETURNING *
      `,
      params
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Route not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Update route error:", err);
    res.status(500).json({ message: "Failed to update route" });
  }
};

export const deleteRoute = async (req, res) => {
  try {
    const tableName = await getRoutesTable();
    if (!tableName) {
      return res.status(500).json({ message: "Routes table not found" });
    }
    const columns = await getRouteColumns(tableName);
    const idCol = getIdColumn(columns) ?? "route_id";

    let result = null;
    if (columns.includes("deleted_at")) {
      const updates = ["deleted_at = now()"];
      if (columns.includes("updated_at")) {
        updates.push("updated_at = now()");
      }
      result = await pool.query(
        `
        UPDATE ${tableName}
        SET ${updates.join(", ")}
        WHERE "${idCol}" = $1
          AND deleted_at IS NULL
        RETURNING ${idCol}
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
        UPDATE ${tableName}
        SET ${updates.join(", ")}
        WHERE "${idCol}" = $1
          AND (is_deleted IS NULL OR is_deleted = false)
        RETURNING ${idCol}
        `,
        [req.params.id]
      );
    } else {
      return res
        .status(400)
        .json({ message: "Soft delete not supported for routes" });
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Route not found" });
    }

    res.json({ message: "Route deleted" });
  } catch (err) {
    console.error("Delete route error:", err);
    res.status(500).json({ message: "Failed to delete route" });
  }
};

export const restoreRoute = async (req, res) => {
  try {
    const tableName = await getRoutesTable();
    if (!tableName) {
      return res.status(500).json({ message: "Routes table not found" });
    }
    const columns = await getRouteColumns(tableName);
    const idCol = getIdColumn(columns) ?? "route_id";

    let result = null;
    if (columns.includes("deleted_at")) {
      result = await pool.query(
        `
        UPDATE ${tableName}
        SET deleted_at = NULL,
            updated_at = now()
        WHERE "${idCol}" = $1
          AND deleted_at IS NOT NULL
        RETURNING *
        `,
        [req.params.id]
      );
    } else if (columns.includes("is_deleted")) {
      result = await pool.query(
        `
        UPDATE ${tableName}
        SET is_deleted = false,
            updated_at = now()
        WHERE "${idCol}" = $1
          AND is_deleted = true
        RETURNING *
        `,
        [req.params.id]
      );
    } else {
      return res
        .status(400)
        .json({ message: "Restore not supported for routes" });
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Route not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Restore route error:", err);
    res.status(500).json({ message: "Failed to restore route" });
  }
};
