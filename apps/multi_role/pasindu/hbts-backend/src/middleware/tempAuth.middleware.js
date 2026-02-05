import jwt from "jsonwebtoken";

/*
  This middleware verifies TEMP TOKENS
  Used ONLY for OTP verification (login step 2)
*/

export const requireTempToken = (req, res, next) => {
  const authHeader = req.headers.authorization;

  // 1️⃣ Check header exists
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      message: "Missing temp token",
    });
  }

  const token = authHeader.split(" ")[1];

  try {
    // 2️⃣ Verify temp token
    const decoded = jwt.verify(
      token,
      process.env.JWT_TEMP_SECRET
      
    );
console.log("TEMP TOKEN PAYLOAD:", decoded);

    // 3️⃣ Attach userId to request
    req.userId = decoded.userId;

    next();
  } catch (err) {
    console.error("Temp token verification failed:", err.message);
    return res.status(401).json({
      message: "Invalid or expired temp token",
    });
  }
};
