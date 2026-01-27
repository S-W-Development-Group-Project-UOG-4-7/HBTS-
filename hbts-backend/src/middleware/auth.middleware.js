import jwt from "jsonwebtoken";

export const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  // 1️⃣ Check token exists
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      message: "Missing access token",
    });
  }

  const token = authHeader.split(" ")[1];

  try {
    // 2️⃣ Verify token
    const decoded = jwt.verify(
      token,
      process.env.JWT_ACCESS_SECRET
    );

    // Normalize ID fields so downstream controllers can rely on user_id or id
    const userId = decoded.userId ?? decoded.user_id ?? decoded.id;

    // 3️⃣ Attach user info to request
    // decoded MUST contain: userId, role
    req.user = {
      ...decoded,
<<<<<<< HEAD
      id: decoded.id ?? decoded.userId,
      userId: decoded.userId ?? decoded.id,
=======
      user_id: userId,
      id: userId,
>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e
    };

    next();
  } catch (err) {
    console.error("JWT verification failed:", err.name, err.message);
    return res.status(401).json({
      message: "Invalid or expired token",
      reason: err.name,
      detail: err.message,
    });
  }
};