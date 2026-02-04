import bcrypt from "bcrypt";
import { pool } from "../db.js";

function generateOtp() {
  return String(Math.floor(100000 + Math.random() * 900000));
}

export async function createOtp({ userId, email, phone, purpose }) {
  const otp = generateOtp();
  const otpHash = await bcrypt.hash(otp, 10);

  const expiresMinutes = Number(process.env.OTP_EXPIRES_MINUTES || 5);

  const { rows } = await pool.query(
    `INSERT INTO otp_challenges
     (user_id, purpose, channel, otp_hash, expires_at)
     VALUES ($1,$2,'BOTH',$3, now() + ($4 || ' minutes')::interval)
     RETURNING id, expires_at`,
    [userId, purpose, otpHash, expiresMinutes]
  );

  // TEMP FOR TESTING (REMOVE LATER)
  console.log("OTP (TEST ONLY):", otp);

  return { challengeId: rows[0].id, expiresAt: rows[0].expires_at };
}

export async function verifyOtp({ challengeId, otp, purpose }) {
  const { rows } = await pool.query(
    "SELECT * FROM otp_challenges WHERE id=$1",
    [challengeId]
  );
  if (rows.length === 0) throw new Error("Invalid OTP challenge");

  const ch = rows[0];
  if (ch.purpose !== purpose) throw new Error("Wrong OTP purpose");
  if (ch.consumed_at) throw new Error("OTP already used");
  if (new Date(ch.expires_at) < new Date()) throw new Error("OTP expired");

  const valid = await bcrypt.compare(otp, ch.otp_hash);
  if (!valid) {
    await pool.query(
      "UPDATE otp_challenges SET attempts=attempts+1 WHERE id=$1",
      [challengeId]
    );
    throw new Error("Invalid OTP");
  }

  await pool.query(
    "UPDATE otp_challenges SET consumed_at=now() WHERE id=$1",
    [challengeId]
  );
}
