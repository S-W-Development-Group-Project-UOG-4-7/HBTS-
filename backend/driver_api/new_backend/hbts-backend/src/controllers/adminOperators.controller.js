import { pool } from "../db.js";

export const listOperators = async (req, res) => {
  try {
    const { status, search = "" } = req.query;
    const statusFilter = status?.toLowerCase();

    if (statusFilter === "suspended") {
      return res.json([]);
    }

    const conditions = [];
    const params = [];

    if (statusFilter === "active") {
      conditions.push(`c.verified = true`);
    } else if (statusFilter === "inactive") {
      conditions.push(`c.verified = false`);
    }

    if (search) {
      conditions.push(
        `(LOWER(c.name) LIKE LOWER($${params.length + 1}) ` +
          `OR LOWER(c.email) LIKE LOWER($${params.length + 1}) ` +
          `OR LOWER(c.phone) LIKE LOWER($${params.length + 1}))`
      );
      params.push(`%${search}%`);
    }

    const whereSql = conditions.length
      ? `WHERE ${conditions.join(" AND ")}`
      : "";

    const result = await pool.query(
      `
      SELECT
        c.operator_id,
        c.name,
        c.email,
        c.phone,
        c.verified,
        c.created_at,
        c.updated_at,
        CASE WHEN c.verified THEN 'active' ELSE 'inactive' END AS status,
        (SELECT COUNT(*) FROM buses b WHERE b.operator_id = c.operator_id) AS fleet_size,
        (SELECT COUNT(*) FROM drivers d WHERE d.operator_id = c.operator_id) AS drivers
      FROM company c
      ${whereSql}
      ORDER BY c.created_at DESC
      `,
      params
    );

    res.json(result.rows);
  } catch (err) {
    console.error("List bus owners error:", err);
    res.status(500).json({ message: "Failed to load bus owners" });
  }
};
