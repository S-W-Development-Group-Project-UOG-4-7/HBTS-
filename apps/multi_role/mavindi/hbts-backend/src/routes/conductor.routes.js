import express from "express";
import { requireAuth } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/requireRole.js";
import {
  getMyBus,
  getMyTrips,
  getTripBookings,
  verifyScan, 
  boardBooking,     // ✅ add
  payCashBooking, 
  scanCommit, 
  getMyActiveTrip,
} from "../controllers/conductor.controller.js";



const router = express.Router();

router.use(requireAuth);
router.use(requireRole("conductor"));

router.get("/me/bus", getMyBus);
router.get("/me/trips", getMyTrips);
router.get("/trips/:tripId/bookings", getTripBookings);
router.post("/scan/verify", verifyScan);
router.post("/bookings/:bookingId/board", boardBooking);
router.post("/bookings/:bookingId/pay-cash", payCashBooking);
router.post("/scan/commit", scanCommit);


router.get(
  "/me/active-trip",
  requireAuth,
  requireRole("conductor"),
  getMyActiveTrip
);




export default router;
