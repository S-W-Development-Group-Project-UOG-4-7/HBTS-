import jwt from "jsonwebtoken";

export const requireAuth = (req, res, next) => {
  const authHeader = req.headers.authorization;

  // Check token exists
  if (!authHeader || !authHeader.startsWith("Bearer ")) {
    return res.status(401).json({
      message: "Missing access token",
    });
  }

  const token = authHeader.split(" ")[1];

  try {
    // Verify token
    const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);

    // Normalize ID fields so downstream controllers can rely on user_id or id
    const userId = decoded.userId ?? decoded.user_id ?? decoded.id;

    // Attach user info to request
    req.user = {
      ...decoded,
      user_id: userId,
      userId,
      id: userId,
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
