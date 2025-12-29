import { pool } from "../db.js";


export const driverStatusReport = async (req, res) => {
  try {
    const result = await db.query(`
      SELECT status, COUNT(*) AS total
      FROM drivers
      GROUP BY status
    `);

    res.json(result.rows);
  } catch (error) {
    console.error("Driver status report error:", error);
    res.status(500).json({ message: "Failed to generate report" });
  }
};
