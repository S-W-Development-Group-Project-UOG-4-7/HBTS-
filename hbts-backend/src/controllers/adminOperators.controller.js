import { pool } from "../db.js";
import bcrypt from "bcrypt";

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
  pickColumn(columns, ["user_id", "id", "userid"]);

const normalizeOperator = (row) => ({
  user_id: row.user_id ?? row.id ?? row.userid,
  name: row.name ?? row.full_name ?? row.username,
  email: row.email ?? row.user_email,
  phone: row.phone ?? row.phone_number ?? row.mobile,
  operator_id: row.operator_id ?? row.operatorId,
  company: row.company ?? row.operator_name ?? row.company_name,
  role_id: row.role_id ?? row.roleId,
  is_verified: row.is_verified ?? row.verified,
  created_at: row.created_at ?? row.createdAt,
  updated_at: row.updated_at ?? row.updatedAt,
});

export const listOperators = async (req, res) => {
  try {
    const { search = "", companyId } = req.query;
    const columns = await getUserColumns();
    if (!columns.length) {
      return res.status(500).json({ message: "Users table not configured" });
    }

    const idCol = getIdColumn(columns) ?? "user_id";
    const nameCol = pickColumn(columns, ["name", "full_name", "username"]);
    const emailCol = pickColumn(columns, ["email"]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const operatorIdCol = pickColumn(columns, [
      "operator_id",
      "operatorid",
      "operatorId",
      "company_id",
    ]);
    const companyCol = pickColumn(columns, ["company", "operator_name"]);
    const roleCol = pickColumn(columns, ["role_id", "roleid"]);
    const deletedAtCol = pickColumn(columns, ["deleted_at"]);

    if (!roleCol) {
      return res.status(500).json({ message: "role_id column not found" });
    }

    const conditions = [`u."${roleCol}" = 5`];
    const params = [];

    if (deletedAtCol) {
      conditions.push(`u."${deletedAtCol}" IS NULL`);
    }

    if (companyId && operatorIdCol) {
      const parsed = Number(companyId);
      if (!Number.isFinite(parsed)) {
        return res.status(400).json({ message: "Invalid companyId" });
      }
      conditions.push(`u."${operatorIdCol}" = $${params.length + 1}`);
      params.push(parsed);
    }

    if (search) {
      const parts = [];
      const offset = params.length + 1;
      if (nameCol) parts.push(`LOWER(u."${nameCol}") LIKE LOWER($${offset})`);
      if (emailCol) parts.push(`LOWER(u."${emailCol}") LIKE LOWER($${offset})`);
      if (phoneCol) parts.push(`LOWER(u."${phoneCol}") LIKE LOWER($${offset})`);
      if (companyCol) parts.push(`LOWER(u."${companyCol}") LIKE LOWER($${offset})`);
      if (parts.length) {
        conditions.push(`(${parts.join(" OR ")})`);
        params.push(`%${search}%`);
      }
    }

    const selectParts = [
      `u."${idCol}" AS user_id`,
      nameCol ? `u."${nameCol}" AS name` : "NULL AS name",
      emailCol ? `u."${emailCol}" AS email` : "NULL AS email",
      phoneCol ? `u."${phoneCol}" AS phone` : "NULL AS phone",
      operatorIdCol ? `u."${operatorIdCol}" AS operator_id` : "NULL AS operator_id",
      companyCol ? `u."${companyCol}" AS company` : "NULL AS company",
      `u."${roleCol}" AS role_id`,
      columns.includes("is_verified") ? `u."is_verified"` : "NULL AS is_verified",
      columns.includes("created_at") ? `u."created_at"` : "NULL AS created_at",
      columns.includes("updated_at") ? `u."updated_at"` : "NULL AS updated_at",
    ];

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const orderCol = columns.includes("created_at") ? "created_at" : idCol;

    const result = await pool.query(
      `
      SELECT ${selectParts.join(", ")}
      FROM users u
      ${whereSql}
      ORDER BY u."${orderCol}" DESC
      `,
      params
    );

    res.json(result.rows.map((r) => normalizeOperator(r)));
  } catch (err) {
    console.error("List operators error:", err);
    res.status(500).json({ message: "Failed to load operators" });
  }
};

export const addOperator = async (req, res) => {
  try {
    const columns = await getUserColumns();
    if (!columns.length) {
      return res.status(500).json({ message: "Users table not configured" });
    }

    const name = req.body?.name?.toString().trim() ?? "";
    const email = req.body?.email?.toString().trim() ?? "";
    const phone = req.body?.phone?.toString().trim() ?? "";
    const password = req.body?.password?.toString() ?? "";
    const operatorId = req.body?.operatorId ?? req.body?.operator_id ?? null;
    const company = req.body?.company?.toString().trim() ?? null;

    if (!name || !email || !password) {
      return res
        .status(400)
        .json({ message: "Name, email, and password are required" });
    }

    if (columns.includes("email")) {
      const exists = await pool.query(
        `SELECT 1 FROM users WHERE email = $1 LIMIT 1`,
        [email]
      );
      if (exists.rowCount > 0) {
        return res.status(409).json({ message: "Email already exists" });
      }
    }

    const nameCol = pickColumn(columns, ["name", "full_name", "username"]);
    const emailCol = pickColumn(columns, ["email"]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const operatorIdCol = pickColumn(columns, [
      "operator_id",
      "operatorid",
      "operatorId",
      "company_id",
    ]);
    const companyCol = pickColumn(columns, ["company", "operator_name"]);
    const roleCol = pickColumn(columns, ["role_id", "roleid"]);
    const passwordHashCol = pickColumn(columns, ["password_hash"]);
    const passwordCol = pickColumn(columns, ["password"]);

    if (!roleCol) {
      return res.status(500).json({ message: "role_id column not found" });
    }

    const cols = [];
    const placeholders = [];
    const params = [];

    const addParam = (col, value) => {
      if (!col) return;
      cols.push(`"${col}"`);
      params.push(value ?? null);
      placeholders.push(`$${params.length}`);
    };

    addParam(nameCol, name);
    addParam(emailCol, email);
    addParam(phoneCol, phone || null);
    addParam(operatorIdCol, operatorId);
    addParam(companyCol, company);
    addParam(roleCol, 5);

    const passwordHash = await bcrypt.hash(password, 10);
    if (passwordHashCol) {
      addParam(passwordHashCol, passwordHash);
    } else if (passwordCol) {
      addParam(passwordCol, passwordHash);
    }

    if (columns.includes("is_verified")) {
      addParam("is_verified", true);
    }
    if (columns.includes("created_at")) {
      cols.push(`"created_at"`);
      placeholders.push("now()");
    }
    if (columns.includes("updated_at")) {
      cols.push(`"updated_at"`);
      placeholders.push("now()");
    }

    const result = await pool.query(
      `
      INSERT INTO users (${cols.join(", ")})
      VALUES (${placeholders.join(", ")})
      RETURNING *
      `,
      params
    );

    return res.status(201).json(normalizeOperator(result.rows[0] ?? {}));
  } catch (err) {
    console.error("Add operator error:", err);
    res.status(500).json({ message: "Failed to add operator" });
  }
};

export const updateOperator = async (req, res) => {
  try {
    const { id } = req.params;
    const columns = await getUserColumns();
    if (!columns.length) {
      return res.status(500).json({ message: "Users table not configured" });
    }

    const idCol = getIdColumn(columns);
    if (!idCol) {
      return res.status(500).json({ message: "User id column not found" });
    }
    const roleCol = pickColumn(columns, ["role_id", "roleid"]);

    const name = req.body?.name?.toString().trim() ?? "";
    const email = req.body?.email?.toString().trim() ?? "";
    const phone = req.body?.phone?.toString().trim() ?? "";
    const password = req.body?.password?.toString() ?? "";
    const operatorId = req.body?.operatorId ?? req.body?.operator_id ?? null;
    const company = req.body?.company?.toString().trim() ?? null;

    const nameCol = pickColumn(columns, ["name", "full_name", "username"]);
    const emailCol = pickColumn(columns, ["email"]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const operatorIdCol = pickColumn(columns, [
      "operator_id",
      "operatorid",
      "operatorId",
      "company_id",
    ]);
    const companyCol = pickColumn(columns, ["company", "operator_name"]);
    const passwordHashCol = pickColumn(columns, ["password_hash"]);
    const passwordCol = pickColumn(columns, ["password"]);

    const updates = [];
    const params = [];

    const addUpdate = (col, value) => {
      if (!col) return;
      updates.push(`"${col}" = $${updates.length + 1}`);
      params.push(value ?? null);
    };

    if (name) addUpdate(nameCol, name);
    if (email) addUpdate(emailCol, email);
    if (phone) addUpdate(phoneCol, phone);
    if (operatorId != null) addUpdate(operatorIdCol, operatorId);
    if (company != null) addUpdate(companyCol, company);

    if (password) {
      const passwordHash = await bcrypt.hash(password, 10);
      if (passwordHashCol) addUpdate(passwordHashCol, passwordHash);
      if (!passwordHashCol && passwordCol) addUpdate(passwordCol, passwordHash);
    }

    if (columns.includes("updated_at")) {
      updates.push(`"updated_at" = now()`);
    }

    if (!updates.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    params.push(id);
    const roleClause = roleCol ? ` AND "${roleCol}" = 5` : "";
    const result = await pool.query(
      `
      UPDATE users
      SET ${updates.join(", ")}
      WHERE "${idCol}" = $${params.length}${roleClause}
      RETURNING *
      `,
      params
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Operator not found" });
    }

    res.json(normalizeOperator(result.rows[0]));
  } catch (err) {
    console.error("Update operator error:", err);
    res.status(500).json({ message: "Failed to update operator" });
  }
};

export const deleteOperator = async (req, res) => {
  try {
    const { id } = req.params;
    const columns = await getUserColumns();
    const idCol = getIdColumn(columns);
    if (!idCol) {
      return res.status(500).json({ message: "User id column not found" });
    }
    const roleCol = pickColumn(columns, ["role_id", "roleid"]);

    const deletedAtCol = pickColumn(columns, ["deleted_at"]);
    const updatedAtCol = pickColumn(columns, ["updated_at"]);
    const roleClause = roleCol ? ` AND "${roleCol}" = 5` : "";

    let result;
    if (deletedAtCol) {
      const updates = [`"${deletedAtCol}" = now()`];
      if (updatedAtCol) updates.push(`"${updatedAtCol}" = now()`);
      result = await pool.query(
        `
        UPDATE users
        SET ${updates.join(", ")}
        WHERE "${idCol}" = $1${roleClause}
        RETURNING *
        `,
        [id]
      );
    } else {
      result = await pool.query(
        `DELETE FROM users WHERE "${idCol}" = $1${roleClause} RETURNING *`,
        [id]
      );
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Operator not found" });
    }

    res.json({ message: "Operator deleted" });
  } catch (err) {
    console.error("Delete operator error:", err);
    res.status(500).json({ message: "Failed to delete operator" });
  }
};
