import { Router } from "express";
import { requireAuth } from "../middleware/auth.middleware.js";
import { pushDriverLocation } from "../controllers/driverTracking.controller.js";

const router = Router();

// You may also require driver role middleware if you have it
router.post("/trips/:tripId/location", requireAuth, pushDriverLocation);

export default router;
