import { Router } from "express";
import { requireAuth } from "../middleware/auth.middleware.js";
import { generateRoutePolyline } from "../controllers/route.controller.js";

const router = Router();

// Admin/operator only (you can add role checks inside controller later)
router.post("/:routeId/generate-polyline", requireAuth, generateRoutePolyline);

export default router;
