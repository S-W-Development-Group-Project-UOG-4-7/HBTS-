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

function pickColumn(columns, candidates) {
  for (const candidate of candidates) {
    if (columns.has(candidate)) return candidate;
  }
  return null;
}

router.use(operatorAuth);

// List routes for this operator
router.get("/", async (req, res) => {
  try {
    const columns = await getColumns("routes");
    const idColumn = pickColumn(columns, ["route_id", "id"]);
    const operatorColumn = pickColumn(columns, ["operator_id"]);

    if (!idColumn || !operatorColumn) {
      return res.status(500).json({ message: "routes table missing required columns" });
    }

    const nameColumn = pickColumn(columns, ["route_name", "name"]);
    const fromColumn = pickColumn(columns, ["from_location", "origin", "from"]);
    const toColumn = pickColumn(columns, ["to_location", "destination", "to"]);
    const distanceColumn = pickColumn(columns, ["distance_km", "distance"]);

    const nameSelect = nameColumn ? `r.${nameColumn} AS route_name` : "NULL AS route_name";
    const fromSelect = fromColumn ? `r.${fromColumn} AS from_location` : "NULL AS from_location";
    const toSelect = toColumn ? `r.${toColumn} AS to_location` : "NULL AS to_location";
    const distanceSelect = distanceColumn ? `r.${distanceColumn} AS distance_km` : "NULL AS distance_km";

    const { rows } = await pool.query(
      `
      SELECT
        r.${idColumn} AS route_id,
        ${nameSelect},
        ${fromSelect},
        ${toSelect},
        ${distanceSelect}
      FROM routes r
      WHERE r.${operatorColumn} = $1
      ORDER BY r.${idColumn} DESC
      `,
      [req.operatorId]
    );

    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load routes", error: e.message });
  }
});

// Create a new route
router.post("/", async (req, res) => {
  try {
    const columns = await getColumns("routes");
    const operatorColumn = pickColumn(columns, ["operator_id"]);
    if (!operatorColumn) {
      return res.status(500).json({ message: "operator_id column missing in routes table" });
    }

    const nameColumn = pickColumn(columns, ["route_name", "name"]);
    const fromColumn = pickColumn(columns, ["from_location", "origin", "from"]);
    const toColumn = pickColumn(columns, ["to_location", "destination", "to"]);
    const distanceColumn = pickColumn(columns, ["distance_km", "distance"]);

    const nameValue = req.body?.routeName ?? req.body?.route_name ?? req.body?.name ?? null;
    const fromValue = req.body?.fromLocation ?? req.body?.from_location ?? req.body?.origin ?? req.body?.from ?? null;
    const toValue = req.body?.toLocation ?? req.body?.to_location ?? req.body?.destination ?? req.body?.to ?? null;
    const distanceValue = req.body?.distanceKm ?? req.body?.distance_km ?? req.body?.distance ?? null;

    if (!fromValue || !toValue) {
      return res.status(400).json({ message: "fromLocation and toLocation are required" });
    }

    const { columns: insertColumns, values } = await buildInsert("routes", {
      [operatorColumn]: req.operatorId,
      ...(nameColumn ? { [nameColumn]: nameValue } : {}),
      ...(fromColumn ? { [fromColumn]: fromValue } : {}),
      ...(toColumn ? { [toColumn]: toValue } : {}),
      ...(distanceColumn ? { [distanceColumn]: distanceValue } : {}),
    });

    if (!insertColumns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    const placeholders = insertColumns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO routes (${insertColumns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to create route", error: e.message });
  }
});

export default router;
