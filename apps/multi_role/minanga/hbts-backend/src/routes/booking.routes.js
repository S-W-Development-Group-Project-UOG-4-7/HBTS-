// src/routes/booking.routes.js
import { Router } from "express";
import {
  createBooking,
  getMyBookings,
  changeBookingSeat,
  cancelBooking,
  getBookingTracking,
} from "../controllers/booking.controller.js";
import { requireAuth } from "../middleware/auth.middleware.js";

const router = Router();

// Passenger must be logged in
router.post("/", requireAuth, createBooking);
router.get("/me", requireAuth, getMyBookings);
router.patch("/:bookingId/seat", requireAuth, changeBookingSeat);
router.patch("/:bookingId/cancel", requireAuth, cancelBooking);

// ✅ Booking tracking snapshot
router.get("/:bookingId/tracking", requireAuth, getBookingTracking);

export default router;
