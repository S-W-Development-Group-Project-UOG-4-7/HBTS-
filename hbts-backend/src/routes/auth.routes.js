import { Router } from "express";
import {
  passengerSignup,
  passengerVerifySignupOtp,
  passengerLogin,
  passengerVerifyLoginOtp,
  adminLogin,
  adminVerifyLoginOtp
} from "../controllers/auth.controller.js";
import { requireTempToken } from "../middleware/tempAuth.js";
import { requireAuth } from "../middleware/auth.middleware.js";
import { getMe } from "../controllers/me.controller.js";

import { requireTempToken } from "../middleware/tempAuth.middleware.js";

const router = Router();

// PASSENGER ROUTES
router.post("/passenger/signup", passengerSignup);
router.post("/passenger/signup/verify-otp", passengerVerifySignupOtp);
router.post("/passenger/login", passengerLogin);
router.post(
  "/passenger/login/verify-otp",
  requireTempToken,
  passengerVerifyLoginOtp
);

// ADMIN ROUTES
router.post("/admin/login", adminLogin);
router.post("/admin/login/verify-otp", 

  requireTempToken,
  adminVerifyLoginOtp
);
router.get("/me", requireAuth, getMe);

);  
export default router;
