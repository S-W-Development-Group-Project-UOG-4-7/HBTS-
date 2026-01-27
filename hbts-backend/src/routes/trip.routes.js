// src/routes/trip.routes.js
import { Router } from "express";
import {
  searchTrips,
  getTripById,
  getTripSeats,
  pushTripLocation,
} from "../controllers/trip.controller.js";

import { requireAuth } from "../middleware/auth.middleware.js";

const router = Router();

// /api/trips?from=&to=&date=
router.get("/", searchTrips);

// /api/trips/:id
router.get("/:id", getTripById);

// /api/trips/:id/seats
router.get("/:id/seats", getTripSeats);
router.post("/:id/location", requireAuth, pushTripLocation);


export default router;
