import { pool } from "../db.js";
import bcrypt from "bcrypt";

// GET passengers
export const getPassengers = async (req, res) => {
  const search = req.query.search ?? "";
  const result = await pool.query(
    `
    SELECT user_id, name, email, phone, created_at
    FROM users u
    JOIN roles r ON u.role_id = r.role_id
    WHERE r.role_name='passenger'
      AND u.deleted_at IS NULL
      AND (LOWER(name) LIKE LOWER($1) OR LOWER(email) LIKE LOWER($1))
    ORDER BY created_at DESC
    `,
    [`%${search}%`]
  );
  res.json(result.rows);
};

// GET single passenger
export const getPassengerById = async (req, res) => {
  const { id } = req.params;
  const result = await pool.query(
    `
    SELECT u.user_id, u.name, u.email, u.phone, u.created_at, u.updated_at,
           u.is_verified, r.role_name
    FROM users u
    JOIN roles r ON u.role_id = r.role_id
    WHERE u.user_id = $1
      AND u.deleted_at IS NULL
    `,
    [id]
  );
  if (!result.rows.length) {
    return res.status(404).json({ message: "Passenger not found" });
  }
  res.json(result.rows[0]);
};

// ADD passenger
export const addPassenger = async (req, res) => {
  const { name, email, phone, password } = req.body;
  const role = await pool.query(
    "SELECT role_id FROM roles WHERE role_name='passenger'"
  );

  const hash = await bcrypt.hash(password, 10);

  const result = await pool.query(
    `
    INSERT INTO users (name, email, phone, password_hash, role_id, is_verified)
    VALUES ($1,$2,$3,$4,$5,true)
    RETURNING user_id,name,email
    `,
    [name, email, phone, hash, role.rows[0].role_id]
  );

  res.status(201).json(result.rows[0]);
};

// UPDATE passenger
export const updatePassenger = async (req, res) => {
  try {
    const { id } = req.params;
    const { name, phone } = req.body;

    if (!name) {
      return res.status(400).json({ message: "Name is required" });
    }

    const result = await pool.query(
      `
      UPDATE users
      SET name = $1,
          phone = $2,
          updated_at = now()
      WHERE user_id = $3
        AND deleted_at IS NULL
      RETURNING user_id, name, email, phone
      `,
      [name, phone ?? null, id]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Passenger not found" });
    }

    res.json(result.rows[0]);
  } catch (err) {
    console.error("Update passenger error:", err);
    res.status(500).json({ message: "Failed to update passenger" });
  }
};

// DELETE passenger
export const deletePassenger = async (req, res) => {
  const { id } = req.params;
  const result = await pool.query(
    `
    UPDATE users
    SET deleted_at = now(),
        updated_at = now()
    WHERE user_id = $1
      AND deleted_at IS NULL
    RETURNING user_id
    `,
    [id]
  );

  if (!result.rows.length) {
    return res.status(404).json({ message: "Passenger not found" });
  }

  res.json({ message: "Passenger deleted" });
};
