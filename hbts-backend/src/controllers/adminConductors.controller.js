import { pool } from "../db.js";
import bcrypt from "bcrypt";
import fs from "fs";
import { toPublicPath } from "../utils/uploads.js";

let cachedConductorColumns = null;
const getConductorColumns = async () => {
  if (cachedConductorColumns) return cachedConductorColumns;
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'conductors'
    `
  );
  cachedConductorColumns = rows.map((r) => r.column_name);
  return cachedConductorColumns;
};

let cachedUserColumns = null;
const getUserColumns = async () => {
  if (cachedUserColumns) return cachedUserColumns;
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'users'
    `
  );
  cachedUserColumns = rows.map((r) => r.column_name);
  return cachedUserColumns;
};

const pickColumn = (columns, candidates) =>
  candidates.find((c) => columns.includes(c));

const getIdColumn = (columns) =>
  pickColumn(columns, ["conductor_id", "id", "conductorid"]);

const normalizeConductor = (row) => ({
  conductor_id: row.conductor_id ?? row.id ?? row.conductorid,
  user_id: row.user_id ?? row.userid,
  name: row.name ?? row.full_name ?? row.username,
  email: row.email ?? row.user_email,
  phone: row.phone ?? row.phone_number ?? row.mobile,
  operator_id: row.operator_id ?? row.operatorId ?? row.company_id,
  company: row.company ?? row.operator_name ?? row.company_name,
  bus_id: row.bus_id ?? row.busId,
  is_active: row.is_active ?? row.active,
  id_number: row.id_number ?? row.idNumber ?? row.id_no,
  id_card_image_url: row.id_card_image_url ?? row.idCardImageUrl ?? row.id_card_url,
  created_at: row.created_at ?? row.createdAt,
  updated_at: row.updated_at ?? row.updatedAt,
});

const cleanupFiles = (files) => {
  if (!files) return;
  const list = Array.isArray(files) ? files : [files];
  list.forEach((file) => {
    if (file?.path) fs.unlink(file.path, () => {});
  });
};

const ensureConductorExtraColumns = async (needsIdNumber, needsIdCard) => {
  if (!needsIdNumber && !needsIdCard) return;
  const columns = await getConductorColumns();
  const pending = [];
  if (needsIdNumber && !columns.includes("id_number")) {
    pending.push(
      "ALTER TABLE conductors ADD COLUMN IF NOT EXISTS id_number TEXT"
    );
  }
  if (needsIdCard && !columns.includes("id_card_image_url")) {
    pending.push(
      "ALTER TABLE conductors ADD COLUMN IF NOT EXISTS id_card_image_url TEXT"
    );
  }
  for (const stmt of pending) {
    await pool.query(stmt);
  }
  if (pending.length) {
    cachedConductorColumns = null;
  }
};

export const listConductors = async (req, res) => {
  try {
    const { search = "" } = req.query;
    const conductorCols = await getConductorColumns();
    const userCols = await getUserColumns();

    if (!conductorCols.length || !userCols.length) {
      return res
        .status(500)
        .json({ message: "Conductors or users table not configured" });
    }

    const cIdCol = getIdColumn(conductorCols) ?? "conductor_id";
    const cUserIdCol = pickColumn(conductorCols, ["user_id", "userId"]);
    const cOperatorIdCol = pickColumn(conductorCols, [
      "operator_id",
      "operatorId",
      "company_id",
    ]);
    const cBusIdCol = pickColumn(conductorCols, ["bus_id", "busId"]);
    const cActiveCol = pickColumn(conductorCols, ["is_active", "active"]);
    const cDeletedAtCol = pickColumn(conductorCols, ["deleted_at"]);

    const uIdCol = pickColumn(userCols, ["user_id", "id"]);
    const uNameCol = pickColumn(userCols, ["name", "full_name", "username"]);
    const uEmailCol = pickColumn(userCols, ["email"]);
    const uPhoneCol = pickColumn(userCols, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const uRoleCol = pickColumn(userCols, ["role_id", "roleid"]);
    const uCompanyCol = pickColumn(userCols, ["company", "operator_name"]);
    const uDeletedAtCol = pickColumn(userCols, ["deleted_at"]);

    if (!cUserIdCol || !uIdCol) {
      return res
        .status(500)
        .json({ message: "Conductor user_id column not found" });
    }

    const conditions = [];
    const params = [];

    if (cDeletedAtCol) {
      conditions.push(`c."${cDeletedAtCol}" IS NULL`);
    }
    if (uDeletedAtCol) {
      conditions.push(`u."${uDeletedAtCol}" IS NULL`);
    }
    if (uRoleCol) {
      conditions.push(`u."${uRoleCol}" = 6`);
    }

    if (search) {
      const offset = params.length + 1;
      const parts = [];
      if (uNameCol) parts.push(`LOWER(u."${uNameCol}") LIKE LOWER($${offset})`);
      if (uEmailCol) parts.push(`LOWER(u."${uEmailCol}") LIKE LOWER($${offset})`);
      if (uPhoneCol) parts.push(`LOWER(u."${uPhoneCol}") LIKE LOWER($${offset})`);
      if (uCompanyCol) parts.push(`LOWER(u."${uCompanyCol}") LIKE LOWER($${offset})`);
      if (parts.length) {
        conditions.push(`(${parts.join(" OR ")})`);
        params.push(`%${search}%`);
      }
    }

    const companyExpr = cOperatorIdCol
      ? `COALESCE(${uCompanyCol ? `u."${uCompanyCol}"` : "NULL"}, co.name)`
      : uCompanyCol
        ? `u."${uCompanyCol}"`
        : "NULL";

    const selectParts = [
      `c."${cIdCol}" AS conductor_id`,
      cUserIdCol ? `c."${cUserIdCol}" AS user_id` : "NULL AS user_id",
      cOperatorIdCol ? `c."${cOperatorIdCol}" AS operator_id` : "NULL AS operator_id",
      cBusIdCol ? `c."${cBusIdCol}" AS bus_id` : "NULL AS bus_id",
      cActiveCol ? `c."${cActiveCol}" AS is_active` : "NULL AS is_active",
      conductorCols.includes("id_number") ? `c."id_number"` : "NULL AS id_number",
      conductorCols.includes("id_card_image_url")
        ? `c."id_card_image_url"`
        : "NULL AS id_card_image_url",
      uNameCol ? `u."${uNameCol}" AS name` : "NULL AS name",
      uEmailCol ? `u."${uEmailCol}" AS email` : "NULL AS email",
      uPhoneCol ? `u."${uPhoneCol}" AS phone` : "NULL AS phone",
      `${companyExpr} AS company`,
      conductorCols.includes("created_at") ? `c."created_at"` : "NULL AS created_at",
      conductorCols.includes("updated_at") ? `c."updated_at"` : "NULL AS updated_at",
    ];

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";
    const orderCol = conductorCols.includes("created_at") ? "created_at" : cIdCol;

    const result = await pool.query(
      `
      SELECT ${selectParts.join(", ")}
      FROM conductors c
      LEFT JOIN users u ON u."${uIdCol}" = c."${cUserIdCol}"
      ${cOperatorIdCol ? `LEFT JOIN company co ON co.operator_id = c."${cOperatorIdCol}"` : ""}
      ${whereSql}
      ORDER BY c."${orderCol}" DESC
      `,
      params
    );

    res.json(result.rows.map((r) => normalizeConductor(r)));
  } catch (err) {
    console.error("List conductors error:", err);
    res.status(500).json({ message: "Failed to load conductors" });
  }
};

export const addConductor = async (req, res) => {
  const client = await pool.connect();
  try {
    const files = req.files || {};
    const idFile =
      (files.idCard && files.idCard[0]) ||
      (files.id_card && files.id_card[0]);

    const idNumberRaw = req.body?.idNumber ?? req.body?.id_number ?? "";
    const idNumber = idNumberRaw.toString().trim();

    await ensureConductorExtraColumns(!!idNumber, !!idFile);

    const conductorCols = await getConductorColumns();
    const userCols = await getUserColumns();
    if (!conductorCols.length || !userCols.length) {
      cleanupFiles([idFile]);
      return res
        .status(500)
        .json({ message: "Conductors or users table not configured" });
    }

    const name = req.body?.name?.toString().trim() ?? "";
    const email = req.body?.email?.toString().trim() ?? "";
    const phone = req.body?.phone?.toString().trim() ?? "";
    const password = req.body?.password?.toString() ?? "";
    let operatorId = req.body?.operatorId ?? req.body?.operator_id ?? null;
    const company = req.body?.company?.toString().trim() ?? null;
    const busId = req.body?.busId ?? req.body?.bus_id ?? null;
    const isActive = req.body?.isActive ?? req.body?.is_active ?? true;

    if (!name || !email || !password) {
      cleanupFiles([idFile]);
      return res
        .status(400)
        .json({ message: "Name, email, and password are required" });
    }

    if (busId == null) {
      cleanupFiles([idFile]);
      return res.status(400).json({ message: "Bus is required" });
    }

    if (!idNumber) {
      cleanupFiles([idFile]);
      return res.status(400).json({ message: "ID number is required" });
    }

    await client.query("BEGIN");

    if (busId != null) {
      const busCheck = await client.query(
        `SELECT operator_id FROM buses WHERE bus_id = $1 LIMIT 1`,
        [busId]
      );
      if (!busCheck.rows.length) {
        await client.query("ROLLBACK");
        cleanupFiles([idFile]);
        return res.status(400).json({ message: "Invalid bus_id" });
      }
      const busOperatorId = busCheck.rows[0].operator_id;
      // Always align operator_id to the selected bus operator_id.
      operatorId = busOperatorId;
    }

    if (userCols.includes("email")) {
      const exists = await client.query(
        `SELECT 1 FROM users WHERE email = $1 LIMIT 1`,
        [email]
      );
      if (exists.rowCount > 0) {
        await client.query("ROLLBACK");
        cleanupFiles([idFile]);
        return res.status(409).json({ message: "Email already exists" });
      }
    }

    const uNameCol = pickColumn(userCols, ["name", "full_name", "username"]);
    const uEmailCol = pickColumn(userCols, ["email"]);
    const uPhoneCol = pickColumn(userCols, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const uOperatorIdCol = pickColumn(userCols, [
      "operator_id",
      "operatorId",
      "company_id",
    ]);
    const uCompanyCol = pickColumn(userCols, ["company", "operator_name"]);
    const uRoleCol = pickColumn(userCols, ["role_id", "roleid"]);
    const uPasswordHashCol = pickColumn(userCols, ["password_hash"]);
    const uPasswordCol = pickColumn(userCols, ["password"]);

    if (!uRoleCol) {
      await client.query("ROLLBACK");
      return res.status(500).json({ message: "role_id column not found" });
    }

    const userColsOut = [];
    const userPlaceholders = [];
    const userParams = [];
    const addUserParam = (col, value) => {
      if (!col) return;
      userColsOut.push(`"${col}"`);
      userParams.push(value ?? null);
      userPlaceholders.push(`$${userParams.length}`);
    };

    addUserParam(uNameCol, name);
    addUserParam(uEmailCol, email);
    addUserParam(uPhoneCol, phone || null);
    addUserParam(uOperatorIdCol, operatorId);
    addUserParam(uCompanyCol, company);
    addUserParam(uRoleCol, 6);

    const passwordHash = await bcrypt.hash(password, 10);
    if (uPasswordHashCol) {
      addUserParam(uPasswordHashCol, passwordHash);
    } else if (uPasswordCol) {
      addUserParam(uPasswordCol, passwordHash);
    }

    if (userCols.includes("is_verified")) {
      addUserParam("is_verified", true);
    }
    if (userCols.includes("created_at")) {
      userColsOut.push(`"created_at"`);
      userPlaceholders.push("now()");
    }
    if (userCols.includes("updated_at")) {
      userColsOut.push(`"updated_at"`);
      userPlaceholders.push("now()");
    }

    const userResult = await client.query(
      `
      INSERT INTO users (${userColsOut.join(", ")})
      VALUES (${userPlaceholders.join(", ")})
      RETURNING *
      `,
      userParams
    );

    const userRow = userResult.rows[0];
    const userId = userRow?.user_id ?? userRow?.id;

    const cUserIdCol = pickColumn(conductorCols, ["user_id", "userId"]);
    const cOperatorIdCol = pickColumn(conductorCols, [
      "operator_id",
      "operatorId",
      "company_id",
    ]);
    const cBusIdCol = pickColumn(conductorCols, ["bus_id", "busId"]);
    const cActiveCol = pickColumn(conductorCols, ["is_active", "active"]);

    const cColsOut = [];
    const cPlaceholders = [];
    const cParams = [];
    const addConductorParam = (col, value) => {
      if (!col) return;
      cColsOut.push(`"${col}"`);
      cParams.push(value ?? null);
      cPlaceholders.push(`$${cParams.length}`);
    };

    addConductorParam(cUserIdCol, userId);
    addConductorParam(cOperatorIdCol, operatorId);
    addConductorParam(cBusIdCol, busId);
    if (conductorCols.includes("id_number")) {
      addConductorParam("id_number", idNumber);
    }
    if (conductorCols.includes("id_card_image_url")) {
      addConductorParam(
        "id_card_image_url",
        idFile ? toPublicPath("conductors", idFile.filename) : null
      );
    }
    if (cActiveCol) addConductorParam(cActiveCol, !!isActive);

    if (conductorCols.includes("created_at")) {
      cColsOut.push(`"created_at"`);
      cPlaceholders.push("now()");
    }
    if (conductorCols.includes("updated_at")) {
      cColsOut.push(`"updated_at"`);
      cPlaceholders.push("now()");
    }

    const conductorResult = await client.query(
      `
      INSERT INTO conductors (${cColsOut.join(", ")})
      VALUES (${cPlaceholders.join(", ")})
      RETURNING *
      `,
      cParams
    );

    await client.query("COMMIT");
    return res.status(201).json({
      ...normalizeConductor(conductorResult.rows[0] ?? {}),
      name,
      email,
      phone,
      company,
      operator_id: operatorId,
    });
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch {}
    cleanupFiles(Object.values(req.files || {}).flat());
    console.error("Add conductor error:", err);
    res.status(500).json({ message: "Failed to add conductor" });
  } finally {
    client.release();
  }
};

export const updateConductor = async (req, res) => {
  const client = await pool.connect();
  try {
    const { id } = req.params;
    const files = req.files || {};
    const idFile =
      (files.idCard && files.idCard[0]) ||
      (files.id_card && files.id_card[0]);

    const idNumberRaw = req.body?.idNumber ?? req.body?.id_number ?? null;
    const idNumber =
      idNumberRaw == null ? null : idNumberRaw.toString().trim();

    await ensureConductorExtraColumns(!!idNumber, !!idFile);

    const conductorCols = await getConductorColumns();
    const userCols = await getUserColumns();
    if (!conductorCols.length || !userCols.length) {
      cleanupFiles([idFile]);
      return res
        .status(500)
        .json({ message: "Conductors or users table not configured" });
    }

    const cIdCol = getIdColumn(conductorCols);
    const cUserIdCol = pickColumn(conductorCols, ["user_id", "userId"]);
    if (!cIdCol || !cUserIdCol) {
      return res.status(500).json({ message: "Conductor id column not found" });
    }

    const name = req.body?.name?.toString().trim() ?? "";
    const email = req.body?.email?.toString().trim() ?? "";
    const phone = req.body?.phone?.toString().trim() ?? "";
    const password = req.body?.password?.toString() ?? "";
    let operatorId = req.body?.operatorId ?? req.body?.operator_id ?? null;
    const company = req.body?.company?.toString().trim() ?? null;
    const busId = req.body?.busId ?? req.body?.bus_id ?? null;
    const isActive = req.body?.isActive ?? req.body?.is_active ?? null;

    if (busId == null) {
      cleanupFiles([idFile]);
      return res.status(400).json({ message: "Bus is required" });
    }

    await client.query("BEGIN");

    const existing = await client.query(
      `SELECT * FROM conductors WHERE "${cIdCol}" = $1 LIMIT 1`,
      [id]
    );
    if (!existing.rows.length) {
      await client.query("ROLLBACK");
      cleanupFiles([idFile]);
      return res.status(404).json({ message: "Conductor not found" });
    }

    const conductorRow = existing.rows[0];
    const userId = conductorRow[cUserIdCol];

    if (busId != null) {
      const busCheck = await client.query(
        `SELECT operator_id FROM buses WHERE bus_id = $1 LIMIT 1`,
        [busId]
      );
      if (!busCheck.rows.length) {
        await client.query("ROLLBACK");
        cleanupFiles([idFile]);
        return res.status(400).json({ message: "Invalid bus_id" });
      }
      const busOperatorId = busCheck.rows[0].operator_id;
      // Always align operator_id to the selected bus operator_id.
      operatorId = busOperatorId;
    }

    const uIdCol = pickColumn(userCols, ["user_id", "id"]);
    const uNameCol = pickColumn(userCols, ["name", "full_name", "username"]);
    const uEmailCol = pickColumn(userCols, ["email"]);
    const uPhoneCol = pickColumn(userCols, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const uOperatorIdCol = pickColumn(userCols, [
      "operator_id",
      "operatorId",
      "company_id",
    ]);
    const uCompanyCol = pickColumn(userCols, ["company", "operator_name"]);
    const uPasswordHashCol = pickColumn(userCols, ["password_hash"]);
    const uPasswordCol = pickColumn(userCols, ["password"]);

    const userUpdates = [];
    const userParams = [];
    const addUserUpdate = (col, value) => {
      if (!col) return;
      userUpdates.push(`"${col}" = $${userUpdates.length + 1}`);
      userParams.push(value ?? null);
    };

    if (name) addUserUpdate(uNameCol, name);
    if (email) addUserUpdate(uEmailCol, email);
    if (phone) addUserUpdate(uPhoneCol, phone);
    if (operatorId != null) addUserUpdate(uOperatorIdCol, operatorId);
    if (company != null) addUserUpdate(uCompanyCol, company);

    if (password) {
      const passwordHash = await bcrypt.hash(password, 10);
      if (uPasswordHashCol) addUserUpdate(uPasswordHashCol, passwordHash);
      if (!uPasswordHashCol && uPasswordCol)
        addUserUpdate(uPasswordCol, passwordHash);
    }

    if (userCols.includes("updated_at")) {
      userUpdates.push(`"updated_at" = now()`);
    }

    if (userUpdates.length) {
      const idCol = uIdCol ?? "user_id";
      userParams.push(userId);
      await client.query(
        `
        UPDATE users
        SET ${userUpdates.join(", ")}
        WHERE "${idCol}" = $${userParams.length}
        `,
        userParams
      );
    }

    const cOperatorIdCol = pickColumn(conductorCols, [
      "operator_id",
      "operatorId",
      "company_id",
    ]);
    const cBusIdCol = pickColumn(conductorCols, ["bus_id", "busId"]);
    const cActiveCol = pickColumn(conductorCols, ["is_active", "active"]);

    const cUpdates = [];
    const cParams = [];
    const addConductorUpdate = (col, value) => {
      if (!col) return;
      cUpdates.push(`"${col}" = $${cUpdates.length + 1}`);
      cParams.push(value ?? null);
    };

    if (operatorId != null) addConductorUpdate(cOperatorIdCol, operatorId);
    if (busId != null) addConductorUpdate(cBusIdCol, busId);
    if (isActive != null) addConductorUpdate(cActiveCol, !!isActive);
    if (idNumber != null && conductorCols.includes("id_number")) {
      addConductorUpdate("id_number", idNumber);
    }
    if (idFile && conductorCols.includes("id_card_image_url")) {
      addConductorUpdate(
        "id_card_image_url",
        toPublicPath("conductors", idFile.filename)
      );
    }

    if (conductorCols.includes("updated_at")) {
      cUpdates.push(`"updated_at" = now()`);
    }

    if (cUpdates.length) {
      cParams.push(id);
      await client.query(
        `
        UPDATE conductors
        SET ${cUpdates.join(", ")}
        WHERE "${cIdCol}" = $${cParams.length}
        `,
        cParams
      );
    }

    await client.query("COMMIT");
    return res.json({
      conductor_id: id,
      user_id: userId,
      name,
      email,
      phone,
      operator_id: operatorId,
      company,
      bus_id: busId,
      is_active: isActive,
      id_number: idNumber,
      id_card_image_url: idFile
        ? toPublicPath("conductors", idFile.filename)
        : undefined,
    });
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch {}
    cleanupFiles(Object.values(req.files || {}).flat());
    console.error("Update conductor error:", err);
    res.status(500).json({ message: "Failed to update conductor" });
  } finally {
    client.release();
  }
};

export const deleteConductor = async (req, res) => {
  const client = await pool.connect();
  try {
    const { id } = req.params;
    const conductorCols = await getConductorColumns();
    const userCols = await getUserColumns();
    if (!conductorCols.length || !userCols.length) {
      return res
        .status(500)
        .json({ message: "Conductors or users table not configured" });
    }

    const cIdCol = getIdColumn(conductorCols);
    const cUserIdCol = pickColumn(conductorCols, ["user_id", "userId"]);
    if (!cIdCol || !cUserIdCol) {
      return res.status(500).json({ message: "Conductor id column not found" });
    }

    await client.query("BEGIN");

    const existing = await client.query(
      `SELECT * FROM conductors WHERE "${cIdCol}" = $1 LIMIT 1`,
      [id]
    );
    if (!existing.rows.length) {
      await client.query("ROLLBACK");
      return res.status(404).json({ message: "Conductor not found" });
    }

    const conductorRow = existing.rows[0];
    const userId = conductorRow[cUserIdCol];

    const cDeletedAtCol = pickColumn(conductorCols, ["deleted_at"]);
    const cUpdatedAtCol = pickColumn(conductorCols, ["updated_at"]);
    if (cDeletedAtCol) {
      const updates = [`"${cDeletedAtCol}" = now()`];
      if (cUpdatedAtCol) updates.push(`"${cUpdatedAtCol}" = now()`);
      await client.query(
        `
        UPDATE conductors
        SET ${updates.join(", ")}
        WHERE "${cIdCol}" = $1
        `,
        [id]
      );
    } else {
      await client.query(
        `DELETE FROM conductors WHERE "${cIdCol}" = $1`,
        [id]
      );
    }

    const uIdCol = pickColumn(userCols, ["user_id", "id"]);
    const uDeletedAtCol = pickColumn(userCols, ["deleted_at"]);
    const uUpdatedAtCol = pickColumn(userCols, ["updated_at"]);
    const userIdCol = uIdCol ?? "user_id";
    if (uDeletedAtCol) {
      const updates = [`"${uDeletedAtCol}" = now()`];
      if (uUpdatedAtCol) updates.push(`"${uUpdatedAtCol}" = now()`);
      await client.query(
        `
        UPDATE users
        SET ${updates.join(", ")}
        WHERE "${userIdCol}" = $1
        `,
        [userId]
      );
    } else {
      await client.query(`DELETE FROM users WHERE "${userIdCol}" = $1`, [userId]);
    }

    await client.query("COMMIT");
    res.json({ message: "Conductor deleted" });
  } catch (err) {
    try {
      await client.query("ROLLBACK");
    } catch {}
    console.error("Delete conductor error:", err);
    res.status(500).json({ message: "Failed to delete conductor" });
  } finally {
    client.release();
  }
};
