import jwt from "jsonwebtoken";

export function requireTempToken(req, res, next) {
  const auth = req.headers.authorization || "";
  const token = auth.startsWith("Bearer ") ? auth.slice(7) : null;

  if (!token) return res.status(401).json({ message: "Missing token" });

  try {
    const payload = jwt.verify(token, process.env.JWT_TEMP_SECRET);
    if (payload.type !== "TEMP_2FA") {
      return res.status(401).json({ message: "Invalid token type" });
    }
    req.userId = payload.userId;

    next();
  } catch {
    return res.status(401).json({ message: "Invalid or expired token" });
  }
}