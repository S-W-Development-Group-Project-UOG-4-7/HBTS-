import bcrypt from "bcrypt";
import { pool } from "../db.js";
import jwt from "jsonwebtoken";
import { createOtp, verifyOtp } from "../services/otp.service.js";
import {
  signTempToken,
  signAccessToken,
  signRefreshToken,
} from "../services/token.service.js";

async function findUserByIdentifier(identifier) {
  const q = `
    SELECT 
      u.user_id,
      u.name,
      u.email,
      u.phone,
      u.password_hash,
      u.is_verified,
      r.role_name AS role
    FROM users u
    JOIN roles r ON r.role_id = u.role_id
    WHERE u.email = $1 OR u.phone = $1
    LIMIT 1
  `;
  const { rows } = await pool.query(q, [identifier.trim()]);
  return rows[0] ?? null;
}


async function getRoleId(roleName) {
  const r = await pool.query(
    "SELECT role_id FROM roles WHERE role_name = $1 LIMIT 1",
    [roleName]
  );
  if (r.rowCount === 0) {
    throw new Error(`Role '${roleName}' not found in roles table`);
  }
  return r.rows[0].role_id;
}

/* =========================
   PASSENGER SIGNUP
========================= */
export async function passengerSignup(req, res) {
  try {
    const { fullName, email, phone, password } = req.body;

    if (!fullName || !email || !password) {
      return res.status(400).json({
        message: "Missing fields (fullName, email, password)",
      });
    }

    const exists = await pool.query(
      "SELECT 1 FROM users WHERE email=$1 OR phone=$2",
      [email.trim(), phone ?? null]
    );

    if (exists.rowCount > 0) {
      return res.status(409).json({
        message: "Email or phone already exists",
      });
    }

    const passengerRoleId = await getRoleId("passenger");
    const passwordHash = await bcrypt.hash(password, 10);

    const { rows } = await pool.query(
      `
      INSERT INTO users (name, email, phone, password_hash, role_id, is_verified)
      VALUES ($1, $2, $3, $4, $5, false)
      RETURNING user_id, email, phone
      `,
      [fullName.trim(), email.trim(), phone ?? null, passwordHash, passengerRoleId]
    );

    const user = rows[0];

    const otpData = await createOtp({
      userId: user.user_id,
      email: user.email,
      phone: user.phone,
      purpose: "SIGNUP_VERIFY",
    });

    return res.status(201).json({
      message: "OTP sent",
      challengeId: otpData.challengeId,
      expiresAt: otpData.expiresAt,
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
}

/* =========================
   PASSENGER SIGNUP OTP VERIFY
========================= */
export async function passengerVerifySignupOtp(req, res) {
  try {
    const { challengeId, otp } = req.body;

    if (!challengeId || !otp) {
      return res.status(400).json({ message: "Missing challengeId or otp" });
    }

    // Verify the OTP and get the user ID
    const userId = await verifyOtp({ 
      challengeId, 
      otp, 
      purpose: "SIGNUP_VERIFY" 
    });

    // Update user as verified and get their data in a single query
    const result = await pool.query(
      `WITH updated_user AS (
        UPDATE users 
        SET is_verified = true,
            email_verified_at = NOW(),
            updated_at = NOW()
        WHERE user_id = $1
        RETURNING user_id, email, role_id, name, phone
      )
      SELECT 
        u.user_id, 
        u.email, 
        u.name,
        u.phone,
        r.role_name
      FROM updated_user u
      JOIN roles r ON u.role_id = r.role_id`,
      [userId]
    );

    if (result.rowCount === 0) {
      throw new Error("User not found or could not be verified");
    }

    const user = result.rows[0];

    // Generate tokens
    const accessToken = signAccessToken({
      user_id: user.user_id,
      role: user.role_name
    });
    
    const refreshToken = signRefreshToken(user.user_id);

    // Store refresh token in database
    const tokenHash = await bcrypt.hash(refreshToken, 10);
    await pool.query(
      `INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
       VALUES ($1, $2, NOW() + INTERVAL '30 days')`,
      [user.user_id, tokenHash]
    );

    return res.json({
      message: "Account verified successfully",
      accessToken,
      refreshToken,
      role: user.role_name,
      user: {
        id: user.user_id,
        name: user.name,
        email: user.email,
        phone: user.phone,
        role: user.role_name
      }
    });
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
}

/* =========================
   PASSENGER LOGIN (STEP 1)
========================= */
export async function passengerLogin(req, res) {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Missing email or password" });
    }

    const { rows } = await pool.query(
      `
      SELECT user_id, name, email, phone, password_hash, is_verified
      FROM users
      WHERE email = $1
      `,
      [email.trim()]
    );

    if (!rows.length) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const user = rows[0];

    if (!user.is_verified) {
      return res.status(403).json({ message: "Account not verified" });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const otpData = await createOtp({
      userId: user.user_id,
      email: user.email,
      phone: user.phone,
      purpose: "LOGIN_2FA",
    });

    const tempToken = signTempToken(user.user_id);

    return res.json({
      message: "OTP sent",
      challengeId: otpData.challengeId,
      tempToken,
      expiresAt: otpData.expiresAt,
      role: "passenger",
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
}

/* updating login function */
export async function login(req, res) {
  try {
    const { identifier, password } = req.body;

    if (!identifier || !password) {
      return res.status(400).json({ message: "Missing identifier or password" });
    }

    const user = await findUserByIdentifier(identifier);
    if (!user) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const ok = await bcrypt.compare(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    if (!user.is_verified) {
      if (user.role === "passenger") {
        return res.status(403).json({ message: "Account not verified" });
      }

      const autoVerifyRoles = ["admin", "operator", "conductor", "driver"];
      if (autoVerifyRoles.includes(user.role)) {
        await pool.query(
          `
          UPDATE users
          SET is_verified = true,
              email_verified_at = NOW(),
              updated_at = NOW()
          WHERE user_id = $1
          `,
          [user.user_id]
        );
      }
    }

    const otpData = await createOtp({
      userId: user.user_id,
      email: user.email,
      phone: user.phone,
      purpose: "LOGIN_2FA",
    });

    // temp token ONLY identifies user session
    const tempToken = signTempToken(user.user_id);

    return res.json({
      message: "OTP sent",
      challengeId: otpData.challengeId,
      expiresAt: otpData.expiresAt,
      tempToken,
      role: user.role, // helpful for UI
    });
  } catch (err) {
    console.error("login error:", err);
    return res.status(500).json({ message: err.message });
  }
}


/* =========================
   PASSENGER LOGIN OTP VERIFY (STEP 2)
========================= */
export async function passengerVerifyLoginOtp(req, res) {
  try {
    const { challengeId, otp } = req.body;
const userId = req.userId; // from requireTempToken middleware

if (!challengeId || !otp) {
  return res.status(400).json({ message: "Missing challengeId or otp" });
}

// 1️⃣ Load OTP challenge
const ch = await pool.query(
  "SELECT user_id FROM otp_challenges WHERE id = $1",
  [challengeId]
);

if (!ch.rowCount) {
  return res.status(400).json({ message: "Invalid challengeId" });
}

// 2️⃣ Ensure OTP belongs to the SAME user as temp token
if (ch.rows[0].user_id !== userId) {
  return res.status(403).json({
    message: "OTP does not belong to this session",
  });
}

// 3️⃣ Verify OTP
await verifyOtp({ challengeId, otp, purpose: "LOGIN_2FA" });

// 4️⃣ Load user
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
      return res.status(401).json({ message: "User not found" });
    }

    const user = rows[0];

    // ✅ IMPORTANT: user.user_id (not user.id)
    // ✅ use token service if possible
    const accessToken = signAccessToken(user);
    const refreshToken = signRefreshToken(user.user_id);

    const tokenHash = await bcrypt.hash(refreshToken, 10);
    await pool.query(
      `
      INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
      VALUES ($1, $2, now() + interval '30 days')
      `,
      [user.user_id, tokenHash]
    );

    return res.json({
      accessToken,
      refreshToken,
      role: user.role,
      user,
    });
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
}


/* new otp verifying */

export async function verifyLoginOtp(req, res) {
  try {
    const { challengeId, otp } = req.body;
    const userId = req.userId; // from requireTempToken

    if (!challengeId || !otp) {
      return res.status(400).json({ message: "Missing challengeId or otp" });
    }

    // Ensure OTP belongs to this user
    const ch = await pool.query(
      "SELECT user_id FROM otp_challenges WHERE id = $1",
      [challengeId]
    );

    if (!ch.rowCount || ch.rows[0].user_id !== userId) {
      return res.status(403).json({ message: "OTP session mismatch" });
    }

    await verifyOtp({ challengeId, otp, purpose: "LOGIN_2FA" });

    const { rows } = await pool.query(
      `
      SELECT 
        u.user_id,
        u.name,
        u.email,
        u.phone,
        r.role_name AS role
      FROM users u
      JOIN roles r ON r.role_id = u.role_id
      WHERE u.user_id = $1
      `,
      [userId]
    );

    if (!rows.length) {
      return res.status(404).json({ message: "User not found" });
    }

    const user = rows[0];

    const accessToken = signAccessToken(user);
    const refreshToken = signRefreshToken(user.user_id);

    const tokenHash = await bcrypt.hash(refreshToken, 10);
    await pool.query(
      `
      INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
      VALUES ($1, $2, now() + interval '30 days')
      `,
      [user.user_id, tokenHash]
    );

    return res.json({
      accessToken,
      refreshToken,
      role: user.role,
      user,
    });
  } catch (err) {
    console.error("verifyLoginOtp error:", err);
    return res.status(400).json({ message: err.message });
  }
}


/* =========
   ADMIN
============ */

// ADMIN LOGIN (STEP 1)
export const adminLogin = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({ message: "Missing email or password" });
    }

    const result = await pool.query(
      `
      SELECT u.user_id, u.password_hash, r.role_name
      FROM users u
      JOIN roles r ON u.role_id = r.role_id
      WHERE u.email = $1
      `,
      [email.trim()]
    );

    if (!result.rows.length) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const admin = result.rows[0];

    if (admin.role_name !== "admin") {
      return res.status(403).json({ message: "Admin access only" });
    }

    const match = await bcrypt.compare(password, admin.password_hash);
    if (!match) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const otpData = await createOtp({
      userId: admin.user_id,
      email: email.trim(),
      purpose: "LOGIN_2FA",
    });

    const tempToken = signTempToken(admin.user_id);

    return res.json({
      message: "OTP sent",
      challengeId: otpData.challengeId,
      tempToken,
      expiresAt: otpData.expiresAt,
      role: "admin",
    });
  } catch (err) {
    return res.status(500).json({ message: err.message });
  }
};

// ADMIN VERIFY LOGIN OTP (STEP 2)
export const adminVerifyLoginOtp = async (req, res) => {
  try {
    const { challengeId, otp } = req.body;
    const adminId = req.userId; // from requireTempToken middleware

    if (!challengeId || !otp) {
      return res.status(400).json({ message: "Missing challengeId or otp" });
    }

    await verifyOtp({ challengeId, otp, purpose: "LOGIN_2FA" });

    const result = await pool.query(
      `
      SELECT u.user_id, u.name, u.email, r.role_name AS role
      FROM users u
      JOIN roles r ON u.role_id = r.role_id
      WHERE u.user_id = $1
      `,
      [adminId]
    );

    if (!result.rows.length) {
      return res.status(404).json({ message: "Admin not found" });
    }

    const admin = result.rows[0];

    if (admin.role !== "admin") {
      return res.status(403).json({ message: "Access denied" });
    }

    // ✅ IMPORTANT: ensure JWT has { userId, role }
    // Best: use token service to keep consistent payload
    const accessToken = signAccessToken({
      user_id: admin.user_id,
      name: admin.name,
      email: admin.email,
      role: "admin",
    });

    const refreshToken = signRefreshToken(admin.user_id);

    const tokenHash = await bcrypt.hash(refreshToken, 10);
    await pool.query(
      `
      INSERT INTO refresh_tokens (user_id, token_hash, expires_at)
      VALUES ($1, $2, now() + interval '30 days')
      `,
      [admin.user_id, tokenHash]
    );

    return res.json({
      accessToken,
      refreshToken,
      role: "admin",
      user: {
        user_id: admin.user_id,
        name: admin.name,
        email: admin.email,
        role: "admin",
      },
    });
  } catch (err) {
    return res.status(400).json({ message: err.message });
  }
};
