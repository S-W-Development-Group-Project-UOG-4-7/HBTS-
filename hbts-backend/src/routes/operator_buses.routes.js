import express from "express";
import fs from "fs";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";
import { makeUploader, toPublicPath } from "../utils/uploads.js";

const router = express.Router();
const busUpload = makeUploader("buses");

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

async function ensureBusImageColumns() {
  const columns = await getColumns("buses");
  const pending = [];

  if (!columns.has("photo_url")) {
    pending.push("ALTER TABLE buses ADD COLUMN IF NOT EXISTS photo_url TEXT");
  }

  for (const stmt of pending) {
    await pool.query(stmt);
  }

  if (pending.length) {
    delete COLUMN_CACHE.buses;
  }
}

function cleanupFile(file) {
  if (!file?.path) return;
  fs.unlink(file.path, () => {});
}

function _todayIso() {
  const now = new Date();
  const yyyy = String(now.getFullYear());
  const mm = String(now.getMonth() + 1).padStart(2, "0");
  const dd = String(now.getDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
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

  const from = _parseDate(fromRaw);
  const to = _parseDate(toRaw);

  const start = from || to || _todayIso();
  const end = to || from || _todayIso();

  if (!start || !end) {
    return { error: "from/to must be YYYY-MM-DD" };
  }

  if (start > end) {
    return { error: "from must be before or equal to to" };
  }

  return { start, end };
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
      FROM buses
      WHERE operator_id = $1
      ORDER BY bus_id DESC
      `,
      [req.operatorId]
    );
    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load buses", error: e.message });
  }
});

router.get("/booking-counts", async (req, res) => {
  try {
    const range = _resolveRange(req.query || {});
    if (range.error) {
      return res.status(400).json({ message: range.error });
    }

    const { start, end } = range;

    const { rows } = await pool.query(
      `
      SELECT
        b.bus_id,
        b.license_plate_no,
        b.model,
        b.capacity,
        b.service_type,
        COUNT(DISTINCT t.trip_id) AS trip_count,
        COALESCE(SUM(CASE WHEN bk.status <> 'cancelled' AND bk.paid_via = 'online' THEN 1 ELSE 0 END), 0) AS online_booked,
        COALESCE(SUM(CASE WHEN bk.status <> 'cancelled' AND bk.paid_via = 'cash' THEN 1 ELSE 0 END), 0) AS cash_booked,
        COALESCE(SUM(CASE WHEN bk.status <> 'cancelled' THEN 1 ELSE 0 END), 0) AS total_booked,
        COALESCE(SUM(CASE WHEN bk.status = 'cancelled' THEN 1 ELSE 0 END), 0) AS cancelled_booked
      FROM buses b
      LEFT JOIN trips t
        ON t.bus_id = b.bus_id
       AND t.trip_date >= $1::date
       AND t.trip_date <= $2::date
      LEFT JOIN bookings bk
        ON bk.trip_id = t.trip_id
      WHERE b.operator_id = $3
      GROUP BY b.bus_id
      ORDER BY b.bus_id DESC
      `,
      [start, end, req.operatorId]
    );

    return res.json({ from: start, to: end, buses: rows });
  } catch (e) {
    return res.status(500).json({ message: "Failed to load booking counts", error: e.message });
  }
});

router.post("/", busUpload.single("photo"), async (req, res) => {
  try {
    const { licensePlateNo, license_plate_no, model, capacity, serviceType, service_type, status = "active" } =
      req.body || {};

    if (!licensePlateNo && !license_plate_no) {
      return res.status(400).json({ message: "licensePlateNo is required" });
    }

    const capNum = capacity === undefined ? undefined : Number(capacity);
    if (capNum !== undefined && (!Number.isInteger(capNum) || capNum <= 0)) {
      return res.status(400).json({ message: "capacity must be a positive integer" });
    }

    let photoUrl;
    if (req.file) {
      await ensureBusImageColumns();
      photoUrl = toPublicPath("buses", req.file.filename);
    }

    const { columns, values } = await buildInsert("buses", {
      license_plate_no: (licensePlateNo || license_plate_no || "").trim(),
      model: model || null,
      capacity: capNum,
      service_type: serviceType || service_type || null,
      photo_url: photoUrl,
      status: status || "active",
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      return res.status(500).json({ message: "operator_id column missing in buses table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO buses (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    cleanupFile(req.file);
    return res.status(500).json({ message: "Failed to create bus", error: e.message });
  }
});

router.post("/:busId/photo", busUpload.single("photo"), async (req, res) => {
  try {
    const busId = Number(req.params.busId);
    if (!Number.isInteger(busId)) {
      cleanupFile(req.file);
      return res.status(400).json({ message: "Invalid bus id" });
    }

    if (!req.file) {
      return res.status(400).json({ message: "photo file is required" });
    }

    const owned = await ensureOwnedBus(busId, req.operatorId);
    if (!owned) {
      cleanupFile(req.file);
      return res.status(404).json({ message: "Bus not found" });
    }

    await ensureBusImageColumns();

    const photoUrl = toPublicPath("buses", req.file.filename);

    const { rows } = await pool.query(
      `
      UPDATE buses
         SET photo_url = $1
       WHERE bus_id = $2
         AND operator_id = $3
      RETURNING *
      `,
      [photoUrl, busId, req.operatorId]
    );

    return res.json(rows[0]);
  } catch (e) {
    cleanupFile(req.file);
    return res.status(500).json({ message: "Failed to upload bus photo", error: e.message });
  }
});

router.put("/:busId", async (req, res) => {
  try {
    const busId = Number(req.params.busId);
    if (!Number.isInteger(busId)) {
      return res.status(400).json({ message: "Invalid bus id" });
    }

    const owned = await ensureOwnedBus(busId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Bus not found" });
    }

    const capNum =
      req.body?.capacity === undefined || req.body.capacity === null ? req.body?.capacity : Number(req.body.capacity);
    if (capNum !== undefined && capNum !== null && (!Number.isInteger(capNum) || capNum <= 0)) {
      return res.status(400).json({ message: "capacity must be a positive integer" });
    }

    const { sets, values } = await buildUpdate("buses", {
      license_plate_no: req.body?.licensePlateNo || req.body?.license_plate_no,
      model: req.body?.model,
      capacity: capNum,
      service_type: req.body?.serviceType || req.body?.service_type,
      status: req.body?.status,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(busId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE buses
         SET ${sets.join(", ")}
       WHERE bus_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to update bus", error: e.message });
  }
});

router.delete("/:busId", async (req, res) => {
  try {
    const busId = Number(req.params.busId);
    if (!Number.isInteger(busId)) {
      return res.status(400).json({ message: "Invalid bus id" });
    }

    const owned = await ensureOwnedBus(busId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Bus not found" });
    }

    await pool.query(
      `
      DELETE FROM buses
      WHERE bus_id = $1 AND operator_id = $2
      `,
      [busId, req.operatorId]
    );

    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({ message: "Failed to delete bus", error: e.message });
  }
});

export default router;
