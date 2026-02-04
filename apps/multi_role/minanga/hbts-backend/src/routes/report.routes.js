import express from "express";
import {
  driverStatusReport,
  reportSummary,
  reportSummaryPdf,
  reportSummaryExcel,
} from "../controllers/report.controller.js";
import { requireAuth } from "../middleware/auth.middleware.js";

const router = express.Router();

// inline admin-only check (no new file needed)
const requireAdmin = (req, res, next) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({ message: "Admins only" });
  }
  next();
};

router.get(
  "/drivers/status",
  requireAuth,
  requireAdmin,
  driverStatusReport
);

router.get(
  "/summary",
  requireAuth,
  requireAdmin,
  reportSummary
);

router.get(
  "/summary/pdf",
  requireAuth,
  requireAdmin,
  reportSummaryPdf
);

router.get(
  "/summary/excel",
  requireAuth,
  requireAdmin,
  reportSummaryExcel
);

export default router;
