import jwt from "jsonwebtoken";

export function operatorAuth(req, res, next) {
  try {
    const header = req.headers.authorization || "";
    const token = header.startsWith("Bearer ") ? header.substring(7) : null;

    if (!token) {
      return res.status(401).json({ message: "Missing Authorization token" });
    }

    const decoded = jwt.verify(token, process.env.JWT_SECRET);

    // ✅ Must exist in token payload from /operator/login
    const operatorId = decoded.operator_id;

    if (!operatorId) {
      return res.status(401).json({ message: "Invalid token: operator_id missing" });
    }

    // ✅ Optional: ensure token is for operator role
    if (decoded.role && decoded.role !== "operator") {
      return res.status(403).json({ message: "Forbidden: not an operator" });
    }

    // ✅ This is what your routes need
    req.operatorId = operatorId;

    // Optional: keep decoded data if needed
    req.operator = decoded;

    next();
  } catch (e) {
    return res.status(401).json({ message: "Unauthorized", error: e.message });
  }
}
