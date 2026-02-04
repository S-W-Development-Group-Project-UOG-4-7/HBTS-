import { Router } from "express";
import {
  createNotificationHandler,
  getMyNotifications,
  getAdminNotifications,
  markMyNotificationRead,
} from "../controllers/notification.controller.js";
import { requireAuth } from "../middleware/auth.middleware.js";

const router = Router();

// Passenger notifications
router.get("/me", requireAuth, getMyNotifications);
router.patch("/me/:id/read", requireAuth, markMyNotificationRead);

// Admin notifications (storage only for now)
router.get("/admin", requireAuth, getAdminNotifications);

// Internal create hook (can be restricted later)
router.post("/", requireAuth, createNotificationHandler);

export default router;
