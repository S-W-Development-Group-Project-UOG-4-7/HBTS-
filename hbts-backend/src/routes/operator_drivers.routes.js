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

async function ensureOwnedDriver(driverId, operatorId) {
  const { rows } = await pool.query(
    `
    SELECT 1
    FROM drivers
    WHERE driver_id = $1 AND operator_id = $2
    LIMIT 1
    `,
    [driverId, operatorId]
  );
  return Boolean(rows.length);
}

async function ensureOwnedBus(busId, operatorId) {
  const { rows } = await pool.query(
    `
    SELECT 1
    FROM buses
    WHERE bus_id = $1 AND operator_id = $2
    LIMIT 1
    `,
    [busId, operatorId]
  );
  return Boolean(rows.length);
}

router.use(operatorAuth);

router.get("/", async (req, res) => {
  try {
    const { rows } = await pool.query(
      `
      SELECT *
      FROM drivers
      WHERE operator_id = $1
      ORDER BY driver_id DESC
      `,
      [req.operatorId]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load drivers", error: e.message });
  }
});

router.post("/", async (req, res) => {
  try {
    const { name, phone, licenseNo, license_no, status = "active" } = req.body || {};

    if (!name || !phone) {
      return res.status(400).json({ message: "name and phone are required" });
    }

    const { columns, values } = await buildInsert("drivers", {
      name: name.trim(),
      phone: phone.trim(),
      license_no: licenseNo || license_no || null,
      status: status || "active",
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      return res.status(500).json({ message: "operator_id column missing in drivers table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO drivers (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to create driver", error: e.message });
  }
});

router.put("/:driverId", async (req, res) => {
  try {
    const driverId = Number(req.params.driverId);
    if (!Number.isInteger(driverId)) {
      return res.status(400).json({ message: "Invalid driver id" });
    }

    const owned = await ensureOwnedDriver(driverId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Driver not found" });
    }

    const { sets, values } = await buildUpdate("drivers", {
      name: req.body?.name,
      phone: req.body?.phone,
      license_no: req.body?.licenseNo || req.body?.license_no,
      status: req.body?.status,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(driverId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE drivers
         SET ${sets.join(", ")}
       WHERE driver_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to update driver", error: e.message });
  }
});

router.delete("/:driverId", async (req, res) => {
  try {
    const driverId = Number(req.params.driverId);
    if (!Number.isInteger(driverId)) {
      return res.status(400).json({ message: "Invalid driver id" });
    }

    const owned = await ensureOwnedDriver(driverId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Driver not found" });
    }

    await pool.query(
      `
      DELETE FROM drivers
      WHERE driver_id = $1 AND operator_id = $2
      `,
      [driverId, req.operatorId]
    );

    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ message: "Failed to delete driver", error: e.message });
  }
});

router.put("/:driverId/assign", async (req, res) => {
  try {
    const driverId = Number(req.params.driverId);
    const busIdRaw = req.body?.busId ?? req.body?.bus_id;

    if (!Number.isInteger(driverId)) {
      return res.status(400).json({ message: "Invalid driver id" });
    }

    if (busIdRaw === undefined || busIdRaw === null) {
      return res.status(400).json({ message: "busId is required" });
    }

    const busId = Number(busIdRaw);
    if (!Number.isInteger(busId)) {
      return res.status(400).json({ message: "busId must be an integer" });
    }

    const [driverOwned, busOwned] = await Promise.all([
      ensureOwnedDriver(driverId, req.operatorId),
      ensureOwnedBus(busId, req.operatorId),
    ]);

    if (!driverOwned) {
      return res.status(404).json({ message: "Driver not found" });
    }

    if (!busOwned) {
      return res.status(404).json({ message: "Bus not found" });
    }

    const columns = await getColumns("drivers");
    if (!columns.has("bus_id")) {
      return res.status(400).json({ message: "drivers.bus_id column not found; add it to support assignments" });
    }

    const { rows } = await pool.query(
      `
      UPDATE drivers
         SET bus_id = $1
       WHERE driver_id = $2
         AND operator_id = $3
      RETURNING *
      `,
      [busId, driverId, req.operatorId]
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to assign driver to bus", error: e.message });
  }
});

export default router;
