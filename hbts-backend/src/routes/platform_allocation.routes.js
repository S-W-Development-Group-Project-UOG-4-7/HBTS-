import express from "express";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";

const router = express.Router();

const PLATFORM_STATUSES = new Set(["available", "reserved", "occupied", "maintenance", "out_of_service"]);
const ALLOCATION_STATUSES = new Set(["reserved", "occupied", "released", "cancelled"]);

let ensured = false;

async function ensurePlatformTables() {
  if (ensured) return;

  await pool.query(`
    CREATE TABLE IF NOT EXISTS platforms (
      platform_id SERIAL PRIMARY KEY,
      operator_id INTEGER NOT NULL REFERENCES operators(operator_id) ON DELETE CASCADE,
      platform_number INTEGER NOT NULL,
      terminal_name TEXT,
      name TEXT,
      status TEXT NOT NULL DEFAULT 'available',
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS platforms_operator_terminal_number_idx
      ON platforms(operator_id, COALESCE(terminal_name, ''), platform_number)
  `);

  await pool.query(`
    CREATE TABLE IF NOT EXISTS platform_allocations (
      allocation_id SERIAL PRIMARY KEY,
      platform_id INTEGER NOT NULL REFERENCES platforms(platform_id) ON DELETE CASCADE,
      trip_id INTEGER NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
      operator_id INTEGER NOT NULL REFERENCES operators(operator_id) ON DELETE CASCADE,
      status TEXT NOT NULL DEFAULT 'reserved',
      start_time TIMESTAMP NOT NULL,
      end_time TIMESTAMP,
      notes TEXT,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE INDEX IF NOT EXISTS platform_allocations_active_idx
      ON platform_allocations (platform_id, start_time, COALESCE(end_time, start_time + INTERVAL '2 hour'))
      WHERE status IN ('reserved', 'occupied')
  `);

  ensured = true;
}

function asInt(val) {
  const num = Number(val);
  return Number.isInteger(num) ? num : null;
}

function normalizePlatformStatus(status, fallback = "available") {
  if (!status) return fallback;
  const normalized = String(status).toLowerCase();
  return PLATFORM_STATUSES.has(normalized) ? normalized : fallback;
}

function normalizeAllocationStatus(status, fallback = "reserved") {
  if (!status) return fallback;
  const normalized = String(status).toLowerCase();
  return ALLOCATION_STATUSES.has(normalized) ? normalized : fallback;
}

function parseTimestampInput(value) {
  if (value === undefined || value === null || value === "") return null;
  const parsed = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(parsed.getTime())) return null;
  return parsed.toISOString();
}

function normalizeDatePart(val) {
  if (!val) return null;
  if (val instanceof Date) return val.toISOString().slice(0, 10);
  const str = String(val).trim();
  if (!str) return null;
  const datePiece = str.split("T")[0].split(" ")[0];
  const parsed = new Date(datePiece);
  if (Number.isNaN(parsed.getTime())) return null;
  return datePiece;
}

function normalizeTimePart(val) {
  if (!val) return null;
  if (val instanceof Date) return val.toISOString().split("T")[1].replace("Z", "");
  const str = String(val).trim();
  if (!str) return null;
  if (str.includes("T")) {
    return str.split("T")[1];
  }
  const parts = str.split(" ");
  return parts.length > 1 ? parts[1] : parts[0];
}

function combineDateTime(dateValue, timeValue) {
  if (!dateValue && !timeValue) return null;
  const datePart = normalizeDatePart(dateValue);
  const timePart = normalizeTimePart(timeValue);
  if (datePart && timePart) {
    const combined = `${datePart}T${timePart}`;
    const parsed = new Date(combined);
    if (!Number.isNaN(parsed.getTime())) return parsed.toISOString();
  }
  return parseTimestampInput(timeValue) || parseTimestampInput(dateValue);
}

function deriveTripWindow(tripRow) {
  if (!tripRow) return { start: null, end: null };
  const start =
    combineDateTime(tripRow.trip_date, tripRow.departure_time) ||
    parseTimestampInput(tripRow.departure_time) ||
    parseTimestampInput(tripRow.trip_date);
  const end =
    combineDateTime(tripRow.trip_date, tripRow.arrival_time) ||
    parseTimestampInput(tripRow.arrival_time) ||
    start;
  return { start, end };
}

function addMinutesIso(iso, minutes) {
  const parsed = new Date(iso);
  if (Number.isNaN(parsed.getTime())) return null;
  parsed.setMinutes(parsed.getMinutes() + minutes);
  return parsed.toISOString();
}

async function fetchPlatform(client, platformId, operatorId, lock = false) {
  const sql = lock
    ? `SELECT * FROM platforms WHERE platform_id = $1 AND operator_id = $2 FOR UPDATE`
    : `SELECT * FROM platforms WHERE platform_id = $1 AND operator_id = $2`;
  const { rows } = await client.query(sql, [platformId, operatorId]);
  return rows[0] || null;
}

async function fetchTrip(client, tripId, operatorId) {
  const { rows } = await client.query(
    `
    SELECT *
    FROM trips
    WHERE trip_id = $1
      AND operator_id = $2
    LIMIT 1
    `,
    [tripId, operatorId]
  );
  return rows[0] || null;
}

async function refreshPlatformStatus(client, platformId) {
  const { rows } = await client.query(
    `
    SELECT status
    FROM platform_allocations
    WHERE platform_id = $1
      AND status IN ('reserved', 'occupied')
    ORDER BY (CASE WHEN status = 'occupied' THEN 1 ELSE 0 END) DESC,
             start_time DESC NULLS LAST,
             created_at DESC
    LIMIT 1
    `,
    [platformId]
  );

  const nextStatus = rows[0]?.status || "available";
  await client.query(
    `UPDATE platforms SET status = $1, updated_at = NOW() WHERE platform_id = $2`,
    [nextStatus, platformId]
  );
}

// Public: show platform info for a trip (for drivers/passengers)
router.get("/public/trips/:tripId/platform", async (req, res) => {
  try {
    await ensurePlatformTables();
    const tripId = asInt(req.params.tripId);
    if (tripId === null) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const { rows } = await pool.query(
      `
      SELECT
        pa.allocation_id,
        pa.status                AS allocation_status,
        pa.start_time,
        pa.end_time,
        p.platform_id,
        p.platform_number,
        p.terminal_name,
        p.name                   AS platform_name,
        p.status                 AS platform_status
      FROM platform_allocations pa
      JOIN platforms p ON p.platform_id = pa.platform_id
      WHERE pa.trip_id = $1
        AND pa.status IN ('reserved', 'occupied')
      ORDER BY pa.start_time DESC NULLS LAST, pa.created_at DESC
      LIMIT 1
      `,
      [tripId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "No platform assigned" });
    }

    const row = rows[0];
    return res.json({
      tripId,
      platform: {
        id: row.platform_id,
        number: row.platform_number,
        terminalName: row.terminal_name,
        name: row.platform_name,
        status: row.platform_status,
      },
      allocation: {
        id: row.allocation_id,
        status: row.allocation_status,
        startTime: row.start_time,
        endTime: row.end_time,
      },
    });
  } catch (e) {
    return res.status(500).json({ message: "Failed to load platform information", error: e.message });
  }
});

router.use(operatorAuth);

// List all platforms with their current assignment status
router.get("/", async (req, res) => {
  try {
    await ensurePlatformTables();

    const { rows } = await pool.query(
      `
      SELECT
        p.*,
        ca.allocation_id    AS current_allocation_id,
        ca.trip_id          AS current_trip_id,
        ca.status           AS current_allocation_status,
        ca.start_time       AS current_start_time,
        ca.end_time         AS current_end_time
      FROM platforms p
      LEFT JOIN LATERAL (
        SELECT allocation_id, trip_id, status, start_time, end_time
        FROM platform_allocations pa
        WHERE pa.platform_id = p.platform_id
          AND pa.status IN ('reserved', 'occupied')
        ORDER BY pa.start_time DESC NULLS LAST, pa.created_at DESC
        LIMIT 1
      ) ca ON TRUE
      WHERE p.operator_id = $1
      ORDER BY p.platform_number ASC, p.platform_id DESC
      `,
      [req.operatorId]
    );

    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load platforms", error: e.message });
  }
});

// Create a new platform (admin-level for the operator)
router.post("/", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const platformNumber = asInt(req.body?.platformNumber ?? req.body?.platform_number);
    if (platformNumber === null) {
      return res.status(400).json({ message: "platformNumber must be an integer" });
    }

    const terminalName = req.body?.terminalName ?? req.body?.terminal_name ?? req.body?.terminal ?? null;
    const name = req.body?.name ?? req.body?.label ?? null;
    const status = normalizePlatformStatus(req.body?.status, "available");

    await client.query("BEGIN");
    begun = true;

    const existing = await client.query(
      `
      SELECT platform_id
      FROM platforms
      WHERE operator_id = $1
        AND platform_number = $2
        AND COALESCE(terminal_name, '') = COALESCE($3, '')
      LIMIT 1
      `,
      [req.operatorId, platformNumber, terminalName]
    );

    if (existing.rowCount) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "Platform already exists for this terminal" });
    }

    const { rows } = await client.query(
      `
      INSERT INTO platforms (operator_id, platform_number, terminal_name, name, status)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
      `,
      [req.operatorId, platformNumber, terminalName, name, status]
    );

    await client.query("COMMIT");
    return res.status(201).json(rows[0]);
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to create platform", error: e.message });
  } finally {
    client.release();
  }
});

// Update platform metadata or status
router.put("/:platformId", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const platformId = asInt(req.params.platformId);
    if (platformId === null) {
      return res.status(400).json({ message: "Invalid platform id" });
    }

    const platformNumber =
      req.body?.platformNumber !== undefined || req.body?.platform_number !== undefined
        ? asInt(req.body?.platformNumber ?? req.body?.platform_number)
        : undefined;

    if (platformNumber !== undefined && platformNumber === null) {
      return res.status(400).json({ message: "platformNumber must be an integer" });
    }

    const terminalName =
      req.body?.terminalName !== undefined || req.body?.terminal_name !== undefined || req.body?.terminal !== undefined
        ? req.body?.terminalName ?? req.body?.terminal_name ?? req.body?.terminal
        : undefined;

    const name = req.body?.name !== undefined || req.body?.label !== undefined ? req.body?.name ?? req.body?.label : undefined;
    const status = req.body?.status !== undefined ? normalizePlatformStatus(req.body.status) : undefined;

    await client.query("BEGIN");
    begun = true;

    const existing = await fetchPlatform(client, platformId, req.operatorId, true);
    if (!existing) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Platform not found" });
    }

    if (platformNumber !== undefined || terminalName !== undefined) {
      const targetNumber = platformNumber ?? existing.platform_number;
      const targetTerminal = terminalName ?? existing.terminal_name;

      const duplicate = await client.query(
        `
        SELECT platform_id
        FROM platforms
        WHERE operator_id = $1
          AND platform_id <> $2
          AND platform_number = $3
          AND COALESCE(terminal_name, '') = COALESCE($4, '')
        LIMIT 1
        `,
        [req.operatorId, platformId, targetNumber, targetTerminal]
      );

      if (duplicate.rowCount) {
        await client.query("ROLLBACK");
        return res.status(409).json({ message: "Another platform already uses this number/terminal" });
      }
    }

    const { rows } = await client.query(
      `
      UPDATE platforms
         SET platform_number = COALESCE($1, platform_number),
             terminal_name   = COALESCE($2, terminal_name),
             name            = COALESCE($3, name),
             status          = COALESCE($4, status),
             updated_at      = NOW()
       WHERE platform_id = $5
         AND operator_id = $6
      RETURNING *
      `,
      [platformNumber, terminalName, name, status, platformId, req.operatorId]
    );

    await client.query("COMMIT");
    return res.json(rows[0]);
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to update platform", error: e.message });
  } finally {
    client.release();
  }
});

// Delete a platform (blocked if active allocation exists)
router.delete("/:platformId", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const platformId = asInt(req.params.platformId);
    if (platformId === null) {
      return res.status(400).json({ message: "Invalid platform id" });
    }

    await client.query("BEGIN");
    begun = true;

    const platform = await fetchPlatform(client, platformId, req.operatorId, true);
    if (!platform) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Platform not found" });
    }

    const blocking = await client.query(
      `
      SELECT allocation_id
      FROM platform_allocations
      WHERE platform_id = $1
        AND status IN ('reserved', 'occupied')
      LIMIT 1
      `,
      [platformId]
    );

    if (blocking.rowCount) {
      await client.query("ROLLBACK");
      return res.status(409).json({ message: "Platform has active allocations" });
    }

    await client.query(`DELETE FROM platforms WHERE platform_id = $1 AND operator_id = $2`, [platformId, req.operatorId]);
    await client.query("COMMIT");
    return res.json({ success: true });
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to delete platform", error: e.message });
  } finally {
    client.release();
  }
});

// List allocations (active or historical)
router.get("/allocations", async (req, res) => {
  try {
    await ensurePlatformTables();

    const filters = ["pa.operator_id = $1"];
    const params = [req.operatorId];

    const statusParam = req.query?.status;
    const normalizedStatus =
      statusParam && ALLOCATION_STATUSES.has(String(statusParam).toLowerCase())
        ? String(statusParam).toLowerCase()
        : null;
    const activeOnly = String(req.query?.active || "").toLowerCase() === "true";

    if (normalizedStatus) {
      filters.push(`pa.status = $${params.length + 1}`);
      params.push(normalizedStatus);
    } else if (activeOnly) {
      filters.push(`pa.status IN ('reserved', 'occupied')`);
    }

    const { rows } = await pool.query(
      `
      SELECT
        pa.*,
        p.platform_number,
        p.terminal_name,
        p.name AS platform_name
      FROM platform_allocations pa
      JOIN platforms p ON p.platform_id = pa.platform_id
      WHERE ${filters.join(" AND ")}
      ORDER BY pa.start_time DESC NULLS LAST, pa.created_at DESC
      `,
      params
    );

    return res.json(rows);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load allocations", error: e.message });
  }
});

// Allocation details for a specific trip (operator-scoped)
router.get("/allocations/trip/:tripId", async (req, res) => {
  try {
    await ensurePlatformTables();

    const tripId = asInt(req.params.tripId);
    if (tripId === null) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const { rows } = await pool.query(
      `
      SELECT
        pa.*,
        p.platform_number,
        p.terminal_name,
        p.name AS platform_name
      FROM platform_allocations pa
      JOIN platforms p ON p.platform_id = pa.platform_id
      WHERE pa.trip_id = $1
        AND pa.operator_id = $2
      ORDER BY pa.start_time DESC NULLS LAST, pa.created_at DESC
      LIMIT 1
      `,
      [tripId, req.operatorId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "No platform allocation for this trip" });
    }

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load allocation", error: e.message });
  }
});

// Assign a platform to a trip (with conflict prevention)
router.post("/allocations", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const platformId = asInt(req.body?.platformId ?? req.body?.platform_id);
    const tripId = asInt(req.body?.tripId ?? req.body?.trip_id);
    const notes = req.body?.notes ?? null;
    const override = Boolean(req.body?.override);
    const autoOccupy = Boolean(req.body?.occupy || req.body?.startNow);

    if (platformId === null || tripId === null) {
      return res.status(400).json({ message: "platformId and tripId are required" });
    }

    const startInput = req.body?.startTime ?? req.body?.start_time;
    const endInput = req.body?.endTime ?? req.body?.end_time;

    const startFromBody = startInput ? parseTimestampInput(startInput) : null;
    const endFromBody = endInput ? parseTimestampInput(endInput) : null;

    if (startInput && !startFromBody) {
      return res.status(400).json({ message: "Invalid startTime" });
    }
    if (endInput && !endFromBody) {
      return res.status(400).json({ message: "Invalid endTime" });
    }

    await client.query("BEGIN");
    begun = true;

    const platform = await fetchPlatform(client, platformId, req.operatorId, true);
    if (!platform) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Platform not found" });
    }

    const trip = await fetchTrip(client, tripId, req.operatorId);
    if (!trip) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const derived = deriveTripWindow(trip);
    const startTime = startFromBody || derived.start;
    if (!startTime) {
      await client.query("ROLLBACK");
      return res
        .status(400)
        .json({ message: "startTime is required (provide startTime or ensure trip has departure/route time)" });
    }

    const endTime = endFromBody || derived.end || addMinutesIso(startTime, 120);
    if (!endTime) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Unable to determine endTime for this allocation" });
    }

    if (new Date(endTime) < new Date(startTime)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "endTime must be after startTime" });
    }

    const overlapEnd = endTime || addMinutesIso(startTime, 120);
    const conflict = await client.query(
      `
      SELECT allocation_id, trip_id, start_time, end_time, status
      FROM platform_allocations
      WHERE platform_id = $1
        AND status IN ('reserved', 'occupied')
        AND ($2::timestamptz, $3::timestamptz) OVERLAPS (start_time, COALESCE(end_time, start_time + INTERVAL '2 hour'))
      LIMIT 1
      `,
      [platformId, startTime, overlapEnd]
    );

    if (conflict.rowCount && !override) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: "Platform is already assigned during this time window",
        conflictWith: conflict.rows[0],
      });
    }

    const allocationStatus = normalizeAllocationStatus(req.body?.status, autoOccupy ? "occupied" : "reserved");

    const { rows } = await client.query(
      `
      INSERT INTO platform_allocations (platform_id, trip_id, operator_id, status, start_time, end_time, notes)
      VALUES ($1, $2, $3, $4, $5, $6, $7)
      RETURNING *
      `,
      [platformId, tripId, req.operatorId, allocationStatus, startTime, endTime, notes]
    );

    await refreshPlatformStatus(client, platformId);

    await client.query("COMMIT");

    return res.status(201).json({
      allocation: rows[0],
      conflict: conflict.rows[0] || null,
      overridden: Boolean(conflict.rowCount && override),
    });
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to assign platform", error: e.message });
  } finally {
    client.release();
  }
});

// Update allocation timing/status or move to another platform (admin override supported)
router.put("/allocations/:allocationId", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const allocationId = asInt(req.params.allocationId);
    if (allocationId === null) {
      return res.status(400).json({ message: "Invalid allocation id" });
    }

    const targetPlatformId =
      req.body?.platformId !== undefined || req.body?.platform_id !== undefined
        ? asInt(req.body?.platformId ?? req.body?.platform_id)
        : undefined;

    if (targetPlatformId !== undefined && targetPlatformId === null) {
      return res.status(400).json({ message: "platformId must be an integer" });
    }

    const startInput = req.body?.startTime ?? req.body?.start_time;
    const endInput = req.body?.endTime ?? req.body?.end_time;
    const notes = req.body?.notes ?? undefined;
    const override = Boolean(req.body?.override);
    const status = req.body?.status ? normalizeAllocationStatus(req.body.status) : undefined;

    const startFromBody = startInput ? parseTimestampInput(startInput) : undefined;
    const endFromBody = endInput ? parseTimestampInput(endInput) : undefined;

    if (startInput && startFromBody === null) {
      return res.status(400).json({ message: "Invalid startTime" });
    }
    if (endInput && endFromBody === null) {
      return res.status(400).json({ message: "Invalid endTime" });
    }

    await client.query("BEGIN");
    begun = true;

    const allocationRes = await client.query(
      `
      SELECT *
      FROM platform_allocations
      WHERE allocation_id = $1
        AND operator_id = $2
      FOR UPDATE
      `,
      [allocationId, req.operatorId]
    );

    if (!allocationRes.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Allocation not found" });
    }

    const allocation = allocationRes.rows[0];
    const platformId = targetPlatformId ?? allocation.platform_id;

    const platform = await fetchPlatform(client, platformId, req.operatorId, true);
    if (!platform) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Target platform not found" });
    }

    const trip = await fetchTrip(client, allocation.trip_id, req.operatorId);
    if (!trip) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Trip not found" });
    }

    const derived = deriveTripWindow(trip);
    const startTime =
      startFromBody === undefined ? allocation.start_time : startFromBody || derived.start || allocation.start_time;
    const endTime = endFromBody === undefined ? allocation.end_time : endFromBody || derived.end || allocation.end_time;

    if (!startTime) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "startTime is required" });
    }

    const resolvedEnd = endTime || addMinutesIso(startTime, 120);
    if (!resolvedEnd) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "Unable to determine endTime" });
    }

    if (new Date(resolvedEnd) < new Date(startTime)) {
      await client.query("ROLLBACK");
      return res.status(400).json({ message: "endTime must be after startTime" });
    }

    const overlapEnd = resolvedEnd || addMinutesIso(startTime, 120);
    const conflict = await client.query(
      `
      SELECT allocation_id, trip_id, start_time, end_time, status
      FROM platform_allocations
      WHERE platform_id = $1
        AND allocation_id <> $2
        AND status IN ('reserved', 'occupied')
        AND ($3::timestamptz, $4::timestamptz) OVERLAPS (start_time, COALESCE(end_time, start_time + INTERVAL '2 hour'))
      LIMIT 1
      `,
      [platformId, allocationId, startTime, overlapEnd]
    );

    if (conflict.rowCount && !override) {
      await client.query("ROLLBACK");
      return res.status(409).json({
        message: "Platform is already assigned during this time window",
        conflictWith: conflict.rows[0],
      });
    }

    const allocationStatus = status ?? allocation.status;

    const { rows } = await client.query(
      `
      UPDATE platform_allocations
         SET platform_id = $1,
             start_time = $2,
             end_time   = $3,
             status     = $4,
             notes      = COALESCE($5, notes),
             updated_at = NOW()
       WHERE allocation_id = $6
         AND operator_id = $7
      RETURNING *
      `,
      [platformId, startTime, resolvedEnd, allocationStatus, notes, allocationId, req.operatorId]
    );

    // Refresh statuses for both old and new platforms if moved
    await refreshPlatformStatus(client, platformId);

    if (platformId !== allocation.platform_id) {
      await refreshPlatformStatus(client, allocation.platform_id);
    }

    await client.query("COMMIT");

    return res.json({
      allocation: rows[0],
      conflict: conflict.rows[0] || null,
      overridden: Boolean(conflict.rowCount && override),
    });
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to update allocation", error: e.message });
  } finally {
    client.release();
  }
});

// Mark allocation as occupied (trip started)
router.post("/allocations/:allocationId/occupy", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const allocationId = asInt(req.params.allocationId);
    if (allocationId === null) {
      return res.status(400).json({ message: "Invalid allocation id" });
    }

    await client.query("BEGIN");
    begun = true;

    const allocationRes = await client.query(
      `
      SELECT *
      FROM platform_allocations
      WHERE allocation_id = $1
        AND operator_id = $2
      FOR UPDATE
      `,
      [allocationId, req.operatorId]
    );

    if (!allocationRes.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Allocation not found" });
    }

    const allocation = allocationRes.rows[0];

    const { rows } = await client.query(
      `
      UPDATE platform_allocations
         SET status = 'occupied',
             updated_at = NOW()
       WHERE allocation_id = $1
         AND operator_id = $2
      RETURNING *
      `,
      [allocationId, req.operatorId]
    );

    await client.query(
      `UPDATE platforms SET status = 'occupied', updated_at = NOW() WHERE platform_id = $1`,
      [allocation.platform_id]
    );

    await client.query("COMMIT");
    return res.json(rows[0]);
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to update allocation", error: e.message });
  } finally {
    client.release();
  }
});

// Release a platform after trip completion
router.post("/allocations/:allocationId/release", async (req, res) => {
  const client = await pool.connect();
  let begun = false;
  try {
    await ensurePlatformTables();

    const allocationId = asInt(req.params.allocationId);
    if (allocationId === null) {
      return res.status(400).json({ message: "Invalid allocation id" });
    }

    const releaseTimeInput = req.body?.releasedAt ?? req.body?.release_time;
    const releaseTime =
      releaseTimeInput !== undefined && releaseTimeInput !== null ? parseTimestampInput(releaseTimeInput) : null;

    if (releaseTimeInput && !releaseTime) {
      return res.status(400).json({ message: "Invalid releasedAt time" });
    }

    await client.query("BEGIN");
    begun = true;

    const allocationRes = await client.query(
      `
      SELECT *
      FROM platform_allocations
      WHERE allocation_id = $1
        AND operator_id = $2
      FOR UPDATE
      `,
      [allocationId, req.operatorId]
    );

    if (!allocationRes.rowCount) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Allocation not found" });
    }

    const allocation = allocationRes.rows[0];
    if (allocation.status === "released") {
      await client.query("COMMIT");
      return res.json(allocation);
    }

    const endTime = releaseTime || allocation.end_time || new Date().toISOString();

    const { rows } = await client.query(
      `
      UPDATE platform_allocations
         SET status = 'released',
             end_time = COALESCE(end_time, $1),
             updated_at = NOW()
       WHERE allocation_id = $2
         AND operator_id = $3
      RETURNING *
      `,
      [endTime, allocationId, req.operatorId]
    );

    await refreshPlatformStatus(client, allocation.platform_id);
    await client.query("COMMIT");
    return res.json(rows[0]);
  } catch (e) {
    if (begun) await client.query("ROLLBACK");
    return res.status(500).json({ message: "Failed to release platform", error: e.message });
  } finally {
    client.release();
  }
});

export default router;
