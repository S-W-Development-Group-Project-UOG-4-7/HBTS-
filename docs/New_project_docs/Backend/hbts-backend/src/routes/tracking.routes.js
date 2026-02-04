import { Router } from "express";
import { requireAuth } from "../middleware/auth.middleware.js";
import { getTrackPayload, createWsToken } from "../controllers/tracking.controller.js";

const router = Router();

router.get("/bookings/:bookingId/track", requireAuth, getTrackPayload);

// optional: generate WS token for passenger app
router.get("/trips/:tripId/ws-token", requireAuth, createWsToken);

export default router;
