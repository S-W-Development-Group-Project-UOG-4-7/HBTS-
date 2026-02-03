// src/routes/trip.routes.js
import { Router } from "express";
import {
  searchTrips,
  getTripById,
  getTripSeats,
  pushTripLocation,
  startTrip,
  endTrip,
  cancelTrip,
} from "../controllers/trip.controller.js";

import { requireAuth } from "../middleware/auth.middleware.js";
import { requireRole } from "../middleware/requireRole.js";

const router = Router();

// /api/trips?from=&to=&date=
router.get("/", searchTrips);

// /api/trips/:id
router.get("/:id", getTripById);

// /api/trips/:id/seats
router.get("/:id/seats", getTripSeats);

// Location updates (driver/operator/admin)
router.post("/:id/location", requireAuth, pushTripLocation);

// Trip state transitions
router.post("/:id/start", requireAuth, requireRole(["driver", "admin", "operator"]), startTrip);
router.post("/:id/end", requireAuth, requireRole(["driver", "admin", "operator"]), endTrip);
router.post("/:id/cancel", requireAuth, requireRole(["driver", "admin", "operator"]), cancelTrip);

export default router;
