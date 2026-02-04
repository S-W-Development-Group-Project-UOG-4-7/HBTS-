import { pool } from "../db.js";
import bcrypt from "bcrypt";

export const addAdminUser = async (req, res) => {
  try {
    const { name, email, phone, password } = req.body ?? {};

    if (!name || !email || !password) {
      return res
        .status(400)
        .json({ message: "Name, email, and password are required" });
    }

    const exists = await pool.query(
      "SELECT 1 FROM users WHERE email = $1 LIMIT 1",
      [email.trim()]
    );
    if (exists.rowCount > 0) {
      return res.status(409).json({ message: "Email already exists" });
    }

    const hash = await bcrypt.hash(password, 10);

    const result = await pool.query(
      `
      INSERT INTO users (name, email, phone, password_hash, role_id, is_verified)
      VALUES ($1, $2, $3, $4, $5, true)
      RETURNING user_id, name, email, phone, role_id
      `,
      [name.trim(), email.trim(), phone ?? null, hash, 2]
    );

    return res.status(201).json(result.rows[0]);
  } catch (err) {
    console.error("Add admin user error:", err);
    return res.status(500).json({ message: "Failed to add user" });
  }
};
