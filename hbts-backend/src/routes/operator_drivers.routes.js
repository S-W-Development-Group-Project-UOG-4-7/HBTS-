import express from "express";
import fs from "fs";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";
import { makeUploader, toPublicPath } from "../utils/uploads.js";

const router = express.Router();
const driverUpload = makeUploader("drivers");

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

async function ensureDriverImageColumns() {
  const columns = await getColumns("drivers");
  const pending = [];

  if (!columns.has("profile_image_url")) {
    pending.push("ALTER TABLE drivers ADD COLUMN IF NOT EXISTS profile_image_url TEXT");
  }
  if (!columns.has("license_image_url")) {
    pending.push("ALTER TABLE drivers ADD COLUMN IF NOT EXISTS license_image_url TEXT");
  }
  if (!columns.has("id_card_image_url")) {
    pending.push("ALTER TABLE drivers ADD COLUMN IF NOT EXISTS id_card_image_url TEXT");
  }

  for (const stmt of pending) {
    await pool.query(stmt);
  }

  if (pending.length) {
    delete COLUMN_CACHE.drivers;
  }
}

function cleanupFiles(files) {
  if (!files) return;
  const list = Array.isArray(files) ? files : [files];
  list.forEach((file) => {
    if (file?.path) fs.unlink(file.path, () => {});
  });
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

router.post(
  "/",
  driverUpload.fields([
    { name: "profile", maxCount: 1 },
    { name: "license", maxCount: 1 },
    { name: "idCard", maxCount: 1 },
    { name: "id_card", maxCount: 1 },
  ]),
  async (req, res) => {
  try {
    const { name, phone, licenseNo, license_no, status = "active" } = req.body || {};

    if (!name || !phone) {
      return res.status(400).json({ message: "name and phone are required" });
    }

    const files = req.files || {};
    const profileFile = files.profile?.[0];
    const licenseFile = files.license?.[0];
    const idFile = (files.idCard && files.idCard[0]) || (files.id_card && files.id_card[0]);

    if (profileFile || licenseFile || idFile) {
      await ensureDriverImageColumns();
    }

    const { columns, values } = await buildInsert("drivers", {
      name: name.trim(),
      phone: phone.trim(),
      license_no: licenseNo || license_no || null,
      profile_image_url: profileFile ? toPublicPath("drivers", profileFile.filename) : undefined,
      license_image_url: licenseFile ? toPublicPath("drivers", licenseFile.filename) : undefined,
      id_card_image_url: idFile ? toPublicPath("drivers", idFile.filename) : undefined,
      status: status || "active",
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      cleanupFiles([profileFile, licenseFile, idFile]);
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      cleanupFiles([profileFile, licenseFile, idFile]);
      return res.status(500).json({ message: "operator_id column missing in drivers table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO drivers (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    cleanupFiles(Object.values(req.files || {}).flat());
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

router.post(
  "/:driverId/photos",
  driverUpload.fields([
    { name: "profile", maxCount: 1 },
    { name: "license", maxCount: 1 },
    { name: "idCard", maxCount: 1 },
    { name: "id_card", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      const driverId = Number(req.params.driverId);
      if (!Number.isInteger(driverId)) {
        cleanupFiles(Object.values(req.files || {}).flat());
        return res.status(400).json({ message: "Invalid driver id" });
      }

      const owned = await ensureOwnedDriver(driverId, req.operatorId);
      if (!owned) {
        cleanupFiles(Object.values(req.files || {}).flat());
        return res.status(404).json({ message: "Driver not found" });
      }

      const files = req.files || {};
      const profileFile = files.profile?.[0];
      const licenseFile = files.license?.[0];
      const idFile = (files.idCard && files.idCard[0]) || (files.id_card && files.id_card[0]);

      if (!profileFile && !licenseFile && !idFile) {
        return res.status(400).json({ message: "At least one photo is required" });
      }

      await ensureDriverImageColumns();

      const { sets, values } = await buildUpdate("drivers", {
        profile_image_url: profileFile ? toPublicPath("drivers", profileFile.filename) : undefined,
        license_image_url: licenseFile ? toPublicPath("drivers", licenseFile.filename) : undefined,
        id_card_image_url: idFile ? toPublicPath("drivers", idFile.filename) : undefined,
      });

      if (!sets.length) {
        cleanupFiles([profileFile, licenseFile, idFile]);
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
      cleanupFiles(Object.values(req.files || {}).flat());
      return res.status(500).json({ message: "Failed to upload driver photos", error: e.message });
    }
  }
);

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
