// src/routes/trip.routes.js
import { Router } from "express";

import {
  searchTrips,
  getTripById,
  getTripSeats,
  startTrip,
  endTrip,
  cancelTrip, 
  pushTripLocation,
} from "../controllers/trip.controller.js";

import { requireAuth } from "../middleware/auth.middleware.js"; // ✅ correct file
import { requireRole } from "../middleware/requireRole.js";      // ✅ correct file

const router = Router();

// /api/trips?from=&to=&date=
router.get("/", searchTrips);

// /api/trips/:id
router.get("/:id", getTripById);

// /api/trips/:id/seats
router.get("/:id/seats", getTripSeats);


router.post("/:id/start", requireAuth, requireRole(["driver", "admin", "operator"]), startTrip);
router.post("/:id/end", requireAuth, requireRole(["driver", "admin", "operator"]), endTrip);
router.post("/:id/cancel", requireAuth, requireRole(["driver", "admin", "operator"]), cancelTrip);
router.post("/:id/location", requireAuth, pushTripLocation);


export default router;
