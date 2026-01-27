import jwt from "jsonwebtoken";

/* =========================
   TEMP TOKEN (OTP STEP 1)
========================= */
export function signTempToken(userId) {
  return jwt.sign(
    {
      userId: userId,// 🔑 REQUIRED
      type: "TEMP_2FA"
    },
    process.env.JWT_TEMP_SECRET,
    { expiresIn: "10m" }
  );
}

/* =========================
   ACCESS TOKEN (OTP STEP 2)
========================= */
export function signAccessToken(user) {
  return jwt.sign(
    {
      userId: user.user_id, // 🔑 REQUIRED
      role: user.role, 
      type: "ACCESS"     // 🔑 REQUIRED
    },
    process.env.JWT_ACCESS_SECRET,
    { expiresIn: process.env.ACCESS_TOKEN_EXPIRES_IN || "1h" }
  );
}

/* =========================
   REFRESH TOKEN
========================= */
export function signRefreshToken(userId) {
  return jwt.sign(
    {
      userId: userId,
    },
    process.env.JWT_REFRESH_SECRET,
    { expiresIn: "30d" }
  );
}