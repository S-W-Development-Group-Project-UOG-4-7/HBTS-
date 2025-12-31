import { pool } from "../db.js";

export async function getMe(req, res) {
  try {
    const userId = req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthenticated" });

    const { rows } = await pool.query(
      `
      SELECT u.user_id, u.name, u.email, u.phone, r.role_name AS role
      FROM users u
      JOIN roles r ON u.role_id = r.role_id
      WHERE u.user_id = $1
      `,
      [userId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = rows[0];

    return res.json({
      user,
      role: user.role,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
}
