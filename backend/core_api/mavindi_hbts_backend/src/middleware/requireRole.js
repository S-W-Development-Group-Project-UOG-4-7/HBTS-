/**
 * Enforces a required role (or one of many roles).
 *
 * Usage:
 *   router.use(requireRole("conductor"));
 *   router.use(requireRole(["admin", "operator"]));
 */
export const requireRole = (allowed) => {
  const allowedRoles = Array.isArray(allowed) ? allowed : [allowed];

  return (req, res, next) => {
    const role = req.user?.role;

    if (!role) {
      return res.status(401).json({ message: "Missing role in token" });
    }

    if (!allowedRoles.includes(role)) {
      return res.status(403).json({
        message: "Forbidden",
        required: allowedRoles,
        got: role,
      });
    }

    next();
  };
};
