import { pool } from "../db.js";

let cachedCompanyColumns = null;
const getCompanyColumns = async () => {
  if (cachedCompanyColumns) return cachedCompanyColumns;
  const { rows } = await pool.query(
    `
      SELECT column_name
      FROM information_schema.columns
      WHERE table_name = 'company'
    `
  );
  cachedCompanyColumns = rows.map((r) => r.column_name);
  return cachedCompanyColumns;
};

const ensureCompanyAddressColumn = async (needsAddress) => {
  if (!needsAddress) return;
  const columns = await getCompanyColumns();
  if (!columns.includes("address")) {
    await pool.query(
      "ALTER TABLE company ADD COLUMN IF NOT EXISTS address TEXT"
    );
    cachedCompanyColumns = null;
  }
};

const pickColumn = (columns, candidates) =>
  candidates.find((c) => columns.includes(c));

const getIdColumn = (columns) =>
  pickColumn(columns, ["operator_id", "company_id", "id"]);

export const listCompanies = async (req, res) => {
  try {
    const { search = "" } = req.query;
    const columns = await getCompanyColumns();
    if (!columns.length) {
      return res.status(500).json({ message: "Company table not configured" });
    }

    const idCol = getIdColumn(columns) ?? "operator_id";
    const nameCol = pickColumn(columns, ["name", "company_name"]);
    const emailCol = pickColumn(columns, ["email", "company_email"]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const addressCol = pickColumn(columns, ["address", "company_address"]);
    const deletedAtCol = pickColumn(columns, ["deleted_at"]);

    const conditions = [];
    const params = [];

    if (deletedAtCol) {
      conditions.push(`c."${deletedAtCol}" IS NULL`);
    }

    if (search) {
      const parts = [];
      if (nameCol) parts.push(`LOWER(c."${nameCol}") LIKE LOWER($1)`);
      if (emailCol) parts.push(`LOWER(c."${emailCol}") LIKE LOWER($1)`);
      if (phoneCol) parts.push(`LOWER(c."${phoneCol}") LIKE LOWER($1)`);
      if (addressCol) parts.push(`LOWER(c."${addressCol}") LIKE LOWER($1)`);
      if (parts.length) {
        conditions.push(`(${parts.join(" OR ")})`);
        params.push(`%${search}%`);
      }
    }

    const selectParts = [
      `c."${idCol}" AS operator_id`,
      nameCol ? `c."${nameCol}" AS name` : "NULL AS name",
      emailCol ? `c."${emailCol}" AS email` : "NULL AS email",
      phoneCol ? `c."${phoneCol}" AS phone` : "NULL AS phone",
      addressCol ? `c."${addressCol}" AS address` : "NULL AS address",
      columns.includes("created_at") ? `c."created_at"` : "NULL AS created_at",
      columns.includes("updated_at") ? `c."updated_at"` : "NULL AS updated_at",
    ];

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const orderCol = columns.includes("created_at") ? "created_at" : idCol;

    const result = await pool.query(
      `
      SELECT ${selectParts.join(", ")}
      FROM company c
      ${whereSql}
      ORDER BY c."${orderCol}" DESC
      `,
      params
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List companies error:", err);
    res.status(500).json({ message: "Failed to load companies" });
  }
};

export const addCompany = async (req, res) => {
  try {
    const address = req.body?.address?.toString().trim() ?? "";
    await ensureCompanyAddressColumn(!!address);
    const columns = await getCompanyColumns();
    if (!columns.length) {
      return res.status(500).json({ message: "Company table not configured" });
    }

    const name = req.body?.name?.toString().trim() ?? "";
    const email = req.body?.email?.toString().trim() ?? "";
    const phone = req.body?.phone?.toString().trim() ?? "";

    if (!name || !email || !phone) {
      return res
        .status(400)
        .json({ message: "Name, email, and phone are required" });
    }

    const nameCol = pickColumn(columns, ["name", "company_name"]);
    const emailCol = pickColumn(columns, ["email", "company_email"]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const addressCol = pickColumn(columns, ["address", "company_address"]);

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
    addParam(phoneCol, phone);
    addParam(addressCol, address || null);

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
      INSERT INTO company (${cols.join(", ")})
      VALUES (${placeholders.join(", ")})
      RETURNING *
      `,
      params
    );

    res.status(201).json(result.rows[0] ?? {});
  } catch (err) {
    console.error("Add company error:", err);
    res.status(500).json({ message: "Failed to add company" });
  }
};

export const updateCompany = async (req, res) => {
  try {
    const { id } = req.params;
    const address = req.body?.address?.toString().trim() ?? "";
    await ensureCompanyAddressColumn(!!address);
    const columns = await getCompanyColumns();
    if (!columns.length) {
      return res.status(500).json({ message: "Company table not configured" });
    }

    const idCol = getIdColumn(columns);
    if (!idCol) {
      return res.status(500).json({ message: "Company id column not found" });
    }

    const name = req.body?.name?.toString().trim() ?? "";
    const email = req.body?.email?.toString().trim() ?? "";
    const phone = req.body?.phone?.toString().trim() ?? "";

    const nameCol = pickColumn(columns, ["name", "company_name"]);
    const emailCol = pickColumn(columns, ["email", "company_email"]);
    const phoneCol = pickColumn(columns, [
      "phone",
      "phone_number",
      "mobile",
      "mobile_number",
    ]);
    const addressCol = pickColumn(columns, ["address", "company_address"]);

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
    if (address) addUpdate(addressCol, address);

    if (columns.includes("updated_at")) {
      updates.push(`"updated_at" = now()`);
    }

    if (!updates.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    params.push(id);
    const result = await pool.query(
      `
      UPDATE company
      SET ${updates.join(", ")}
      WHERE "${idCol}" = $${params.length}
      RETURNING *
      `,
      params
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Company not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Update company error:", err);
    res.status(500).json({ message: "Failed to update company" });
  }
};

export const deleteCompany = async (req, res) => {
  try {
    const { id } = req.params;
    const columns = await getCompanyColumns();
    const idCol = getIdColumn(columns);
    if (!idCol) {
      return res.status(500).json({ message: "Company id column not found" });
    }

    const deletedAtCol = pickColumn(columns, ["deleted_at"]);
    const updatedAtCol = pickColumn(columns, ["updated_at"]);

    let result;
    if (deletedAtCol) {
      const updates = [`"${deletedAtCol}" = now()`];
      if (updatedAtCol) updates.push(`"${updatedAtCol}" = now()`);
      result = await pool.query(
        `
        UPDATE company
        SET ${updates.join(", ")}
        WHERE "${idCol}" = $1
        RETURNING *
        `,
        [id]
      );
    } else {
      result = await pool.query(
        `DELETE FROM company WHERE "${idCol}" = $1 RETURNING *`,
        [id]
      );
    }

    if (!result.rows.length) {
      return res.status(404).json({ message: "Company not found" });
    }

    res.json({ message: "Company deleted" });
  } catch (err) {
    console.error("Delete company error:", err);
    res.status(500).json({ message: "Failed to delete company" });
  }
};
