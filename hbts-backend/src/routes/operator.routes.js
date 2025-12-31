import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";

const router = express.Router();

/**
 * POST /operator/login
 * Body: { email, password }
 */
router.post("/login", async (req, res) => {
  try {
    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ message: "Missing email/password" });
    }

    // ✅ use operator_id consistently
    const { rows } = await pool.query(
      `SELECT operator_id, name, email, password_hash
       FROM operators
       WHERE email = $1
       LIMIT 1`,
      [email.trim().toLowerCase()]
    );

    if (!rows.length) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const op = rows[0];

    if (!op.password_hash) {
      return res.status(500).json({
        message: "Operator password not set. Missing password_hash in database.",
      });
    }

    const ok = await bcrypt.compare(password, op.password_hash);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    // ✅ token payload contains operator_id
    const token = jwt.sign(
      {
        operator_id: op.operator_id,
        email: op.email,
        name: op.name,
        role: "operator",
      },
      process.env.JWT_SECRET,
      { expiresIn: "7d" }
    );

    // ✅ response uses operator_id too
    return res.json({
      token,
      operator: {
        id: op.operator_id, // keep "id" for frontend compatibility
        operator_id: op.operator_id, // also include explicit name
        name: op.name,
        email: op.email,
      },
    });
  } catch (e) {
    return res.status(500).json({ message: "Login failed", error: e.message });
  }
});

/**
 * GET /operator/me
 * Requires operatorAuth (reads operator_id from JWT)
 */
router.get("/me", operatorAuth, async (req, res) => {
  try {
    // ✅ operatorAuth should set req.operatorId
    const operatorId = req.operatorId;

    const { rows } = await pool.query(
      `SELECT operator_id, name, email
       FROM operators
       WHERE operator_id = $1
       LIMIT 1`,
      [operatorId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "Operator not found" });
    }

    // ✅ return consistent shape
    return res.json({
      id: rows[0].operator_id,
      operator_id: rows[0].operator_id,
      name: rows[0].name,
      email: rows[0].email,
    });
  } catch (e) {
    return res.status(500).json({ message: "Failed to load operator", error: e.message });
  }
});

export default router;
