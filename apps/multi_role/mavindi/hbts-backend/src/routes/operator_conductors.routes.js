import express from "express";
import fs from "fs";
import bcrypt from "bcrypt";
import { randomUUID } from "crypto";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";
import { makeUploader, toPublicPath } from "../utils/uploads.js";

const router = express.Router();
const conductorUpload = makeUploader("conductors");

const COLUMN_CACHE = {};

async function ensureConductorsTable() {
  await pool.query(
    `
    CREATE TABLE IF NOT EXISTS conductors (
      conductor_id SERIAL PRIMARY KEY,
      operator_id INTEGER,
      name TEXT,
      phone TEXT,
      email TEXT,
      id_number TEXT,
      profile_image_url TEXT,
      id_card_image_url TEXT,
      status TEXT DEFAULT 'active',
      created_at TIMESTAMP DEFAULT NOW()
    )
    `
  );
}

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

async function ensureConductorImageColumns() {
  const columns = await getColumns("conductors");
  const pending = [];

  if (!columns.has("profile_image_url")) {
    pending.push(
      "ALTER TABLE conductors ADD COLUMN IF NOT EXISTS profile_image_url TEXT"
    );
  }
  if (!columns.has("id_card_image_url")) {
    pending.push(
      "ALTER TABLE conductors ADD COLUMN IF NOT EXISTS id_card_image_url TEXT"
    );
  }

  for (const stmt of pending) {
    await pool.query(stmt);
  }

  if (pending.length) {
    delete COLUMN_CACHE.conductors;
  }
}

async function ensureConductorMetaColumns() {
  const columns = await getColumns("conductors");
  const pending = [];

  if (!columns.has("email")) {
    pending.push("ALTER TABLE conductors ADD COLUMN IF NOT EXISTS email TEXT");
  }
  if (!columns.has("id_number")) {
    pending.push(
      "ALTER TABLE conductors ADD COLUMN IF NOT EXISTS id_number TEXT"
    );
  }

  for (const stmt of pending) {
    await pool.query(stmt);
  }

  if (pending.length) {
    delete COLUMN_CACHE.conductors;
  }
}

function cleanupFiles(files) {
  if (!files) return;
  const list = Array.isArray(files) ? files : [files];
  list.forEach((file) => {
    if (file?.path) fs.unlink(file.path, () => {});
  });
}

async function ensureOwnedConductor(conductorId, operatorId) {
  const { rows } = await pool.query(
    `
    SELECT 1
    FROM conductors
    WHERE conductor_id = $1 AND operator_id = $2
    LIMIT 1
    `,
    [conductorId, operatorId]
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

async function createConductorUser(client, { name, email, phone, operatorId }) {
  const passwordHash = await bcrypt.hash(randomUUID(), 10);
  const { rows } = await client.query(
    `
    INSERT INTO users (name, email, phone, password_hash, role_id, operator_id)
    VALUES ($1, $2, $3, $4, 6, $5)
    RETURNING user_id, name, email, phone
    `,
    [name, email, phone, passwordHash, operatorId]
  );
  return rows[0];
}

router.use(operatorAuth);

router.get("/", async (req, res) => {
  try {
    await ensureConductorsTable();
    const columns = await getColumns("conductors");
    if (columns.has("user_id")) {
      const { rows } = await pool.query(
        `
        SELECT
          c.*,
          u.name AS user_name,
          u.phone AS user_phone,
          u.email AS user_email
        FROM conductors c
        JOIN users u ON u.user_id = c.user_id
        WHERE c.operator_id = $1
        ORDER BY c.conductor_id DESC
        `,
        [req.operatorId]
      );

      const mapped = rows.map((row) => ({
        ...row,
        name: row.user_name ?? row.name ?? null,
        phone: row.user_phone ?? row.phone ?? null,
        email: row.email ?? row.user_email ?? null,
        status: row.is_active === false ? "inactive" : "active",
      }));

      return res.json(mapped);
    }

    const { rows } = await pool.query(
      `
      SELECT *
      FROM conductors
      WHERE operator_id = $1
      ORDER BY conductor_id DESC
      `,
      [req.operatorId]
    );
    return res.json(rows);
  } catch (e) {
    return res
      .status(500)
      .json({ message: "Failed to load conductors", error: e.message });
  }
});

router.post(
  "/",
  conductorUpload.fields([
    { name: "profile", maxCount: 1 },
    { name: "idCard", maxCount: 1 },
    { name: "id_card", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      await ensureConductorsTable();

      const {
        name,
        phone,
        email,
        idNumber,
        id_number,
        status = "active",
        busId,
        bus_id,
      } = req.body || {};

      if (!name || !phone || !email || !(idNumber || id_number)) {
        return res.status(400).json({
          message: "name, phone, email and id_number are required",
        });
      }

      const columns = await getColumns("conductors");
      const usesLegacySchema =
        columns.has("user_id") && columns.has("bus_id") && columns.has("operator_id");

      const files = req.files || {};
      const profileFile = files.profile?.[0];
      const idFile =
        (files.idCard && files.idCard[0]) ||
        (files.id_card && files.id_card[0]);

      if (profileFile || idFile) {
        await ensureConductorImageColumns();
      }
      await ensureConductorMetaColumns();

      if (usesLegacySchema) {
        const resolvedBusId = busId ?? bus_id;
        if (resolvedBusId === undefined || resolvedBusId === null || resolvedBusId === "") {
          cleanupFiles([profileFile, idFile]);
          return res.status(400).json({ message: "busId is required for conductor registration" });
        }

        const numericBusId = Number(resolvedBusId);
        if (!Number.isInteger(numericBusId)) {
          cleanupFiles([profileFile, idFile]);
          return res.status(400).json({ message: "busId must be an integer" });
        }

        const ownedBus = await ensureOwnedBus(numericBusId, req.operatorId);
        if (!ownedBus) {
          cleanupFiles([profileFile, idFile]);
          return res.status(404).json({ message: "Bus not found for this operator" });
        }

        const client = await pool.connect();
        let created;
        try {
          await client.query("BEGIN");
          const user = await createConductorUser(client, {
            name: name.trim(),
            email: email.trim(),
            phone: phone.trim(),
            operatorId: req.operatorId,
          });

          const isActive = String(status || "active").toLowerCase() !== "inactive";

          const { columns: insertCols, values } = await buildInsert("conductors", {
            user_id: user.user_id,
            bus_id: numericBusId,
            operator_id: req.operatorId,
            is_active: isActive,
            assigned_at: new Date(),
            updated_at: new Date(),
            email: email.trim(),
            id_number: (idNumber || id_number || "").trim(),
            profile_image_url: profileFile
              ? toPublicPath("conductors", profileFile.filename)
              : undefined,
            id_card_image_url: idFile
              ? toPublicPath("conductors", idFile.filename)
              : undefined,
          });

          if (!insertCols.length) {
            throw new Error("No valid fields to insert");
          }

          const placeholders = insertCols.map((_, idx) => `$${idx + 1}`).join(", ");
          const { rows } = await client.query(
            `INSERT INTO conductors (${insertCols.join(
              ", "
            )}) VALUES (${placeholders}) RETURNING *`,
            values
          );
          created = rows[0];
          await client.query("COMMIT");
        } catch (err) {
          await client.query("ROLLBACK");
          if (err?.code === "23505") {
            cleanupFiles([profileFile, idFile]);
            return res.status(409).json({ message: "Email already exists" });
          }
          throw err;
        } finally {
          client.release();
        }

        return res.status(201).json(created);
      }

      const { columns: insertColumns, values } = await buildInsert("conductors", {
        name: name.trim(),
        phone: phone.trim(),
        email: email.trim(),
        id_number: (idNumber || id_number || "").trim(),
        profile_image_url: profileFile
          ? toPublicPath("conductors", profileFile.filename)
          : undefined,
        id_card_image_url: idFile
          ? toPublicPath("conductors", idFile.filename)
          : undefined,
        status: status || "active",
        operator_id: req.operatorId,
      });

      if (!insertColumns.length) {
        cleanupFiles([profileFile, idFile]);
        return res.status(400).json({ message: "No valid fields to insert" });
      }

      if (!insertColumns.includes("operator_id")) {
        cleanupFiles([profileFile, idFile]);
        return res.status(500).json({
          message: "operator_id column missing in conductors table",
        });
      }

      const placeholders = insertColumns.map((_, idx) => `$${idx + 1}`).join(", ");
      const { rows } = await pool.query(
        `INSERT INTO conductors (${insertColumns.join(
          ", "
        )}) VALUES (${placeholders}) RETURNING *`,
        values
      );

      return res.status(201).json(rows[0]);
    } catch (e) {
      cleanupFiles(Object.values(req.files || {}).flat());
      return res.status(500).json({
        message: "Failed to create conductor",
        error: e.message,
      });
    }
  }
);

router.put("/:conductorId", async (req, res) => {
  try {
    await ensureConductorsTable();
    const conductorId = Number(req.params.conductorId);
    if (!Number.isInteger(conductorId)) {
      return res.status(400).json({ message: "Invalid conductor id" });
    }

    const owned = await ensureOwnedConductor(conductorId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Conductor not found" });
    }

    const columns = await getColumns("conductors");
    if (columns.has("user_id")) {
      const { rows: lookup } = await pool.query(
        `
        SELECT user_id
        FROM conductors
        WHERE conductor_id = $1 AND operator_id = $2
        LIMIT 1
        `,
        [conductorId, req.operatorId]
      );

      if (!lookup.length) {
        return res.status(404).json({ message: "Conductor not found" });
      }

      const userId = lookup[0].user_id;
      const client = await pool.connect();
      try {
        await client.query("BEGIN");

        const userSets = [];
        const userValues = [];
        if (req.body?.name) {
          userValues.push(req.body.name);
          userSets.push(`name = $${userValues.length}`);
        }
        if (req.body?.phone) {
          userValues.push(req.body.phone);
          userSets.push(`phone = $${userValues.length}`);
        }
        if (req.body?.email) {
          userValues.push(req.body.email);
          userSets.push(`email = $${userValues.length}`);
        }

        if (userSets.length) {
          userValues.push(userId);
          await client.query(
            `
            UPDATE users
               SET ${userSets.join(", ")}
             WHERE user_id = $${userValues.length}
            `,
            userValues
          );
        }

        const statusRaw = req.body?.status;
        const isActive =
          statusRaw === undefined || statusRaw === null
            ? undefined
            : String(statusRaw).toLowerCase() !== "inactive";

        const { sets, values } = await buildUpdate("conductors", {
          id_number: req.body?.idNumber || req.body?.id_number,
          is_active: isActive,
        });

        if (sets.length) {
          values.push(conductorId, req.operatorId);
          await client.query(
            `
            UPDATE conductors
               SET ${sets.join(", ")}
             WHERE conductor_id = $${values.length - 1}
               AND operator_id = $${values.length}
            `,
            values
          );
        }

        await client.query("COMMIT");
      } catch (e) {
        await client.query("ROLLBACK");
        if (e?.code === "23505") {
          return res.status(409).json({ message: "Email already exists" });
        }
        throw e;
      } finally {
        client.release();
      }

      const { rows } = await pool.query(
        `
        SELECT
          c.*,
          u.name AS user_name,
          u.phone AS user_phone,
          u.email AS user_email
        FROM conductors c
        JOIN users u ON u.user_id = c.user_id
        WHERE c.conductor_id = $1
          AND c.operator_id = $2
        LIMIT 1
        `,
        [conductorId, req.operatorId]
      );

      const row = rows[0];
      return res.json({
        ...row,
        name: row?.user_name ?? row?.name ?? null,
        phone: row?.user_phone ?? row?.phone ?? null,
        email: row?.email ?? row?.user_email ?? null,
        status: row?.is_active === false ? "inactive" : "active",
      });
    }

    if (req.body?.email || req.body?.idNumber || req.body?.id_number) {
      await ensureConductorMetaColumns();
    }

    const { sets, values } = await buildUpdate("conductors", {
      name: req.body?.name,
      phone: req.body?.phone,
      email: req.body?.email,
      id_number: req.body?.idNumber || req.body?.id_number,
      status: req.body?.status,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(conductorId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE conductors
         SET ${sets.join(", ")}
       WHERE conductor_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({
      message: "Failed to update conductor",
      error: e.message,
    });
  }
});

router.delete("/:conductorId", async (req, res) => {
  try {
    await ensureConductorsTable();
    const conductorId = Number(req.params.conductorId);
    if (!Number.isInteger(conductorId)) {
      return res.status(400).json({ message: "Invalid conductor id" });
    }

    const owned = await ensureOwnedConductor(conductorId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Conductor not found" });
    }

    await pool.query(
      `
      DELETE FROM conductors
      WHERE conductor_id = $1 AND operator_id = $2
      `,
      [conductorId, req.operatorId]
    );

    return res.json({ success: true });
  } catch (e) {
    return res.status(500).json({
      message: "Failed to delete conductor",
      error: e.message,
    });
  }
});

router.post(
  "/:conductorId/photos",
  conductorUpload.fields([
    { name: "profile", maxCount: 1 },
    { name: "idCard", maxCount: 1 },
    { name: "id_card", maxCount: 1 },
  ]),
  async (req, res) => {
    try {
      await ensureConductorsTable();
      const conductorId = Number(req.params.conductorId);
      if (!Number.isInteger(conductorId)) {
        cleanupFiles(Object.values(req.files || {}).flat());
        return res.status(400).json({ message: "Invalid conductor id" });
      }

      const owned = await ensureOwnedConductor(conductorId, req.operatorId);
      if (!owned) {
        cleanupFiles(Object.values(req.files || {}).flat());
        return res.status(404).json({ message: "Conductor not found" });
      }

      const files = req.files || {};
      const profileFile = files.profile?.[0];
      const idFile =
        (files.idCard && files.idCard[0]) ||
        (files.id_card && files.id_card[0]);

      if (!profileFile && !idFile) {
        return res.status(400).json({ message: "At least one photo is required" });
      }

      await ensureConductorImageColumns();

      const { sets, values } = await buildUpdate("conductors", {
        profile_image_url: profileFile
          ? toPublicPath("conductors", profileFile.filename)
          : undefined,
        id_card_image_url: idFile
          ? toPublicPath("conductors", idFile.filename)
          : undefined,
      });

      if (!sets.length) {
        cleanupFiles([profileFile, idFile]);
        return res.status(400).json({ message: "No fields to update" });
      }

      values.push(conductorId, req.operatorId);

      const { rows } = await pool.query(
        `
        UPDATE conductors
           SET ${sets.join(", ")}
         WHERE conductor_id = $${values.length - 1}
           AND operator_id = $${values.length}
        RETURNING *
        `,
        values
      );

      return res.json(rows[0]);
    } catch (e) {
      cleanupFiles(Object.values(req.files || {}).flat());
      return res.status(500).json({
        message: "Failed to upload conductor photos",
        error: e.message,
      });
    }
  }
);

export default router;
