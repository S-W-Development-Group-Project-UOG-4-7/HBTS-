// src/routes/trip.routes.js
import express from "express";
import {
  searchTrips,
  getTripById,
  getTripSeats,
} from "../controllers/trip.controller.js";

const router = express.Router();

// /api/trips?from=&to=&date=
router.get("/", searchTrips);

// /api/trips/:id
router.get("/:id", getTripById);

// /api/trips/:id/seats
router.get("/:id/seats", getTripSeats);

export default router;
