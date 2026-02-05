import { Router } from "express";
import {
  passengerSignup,
  passengerVerifySignupOtp,
  passengerLogin,
  passengerVerifyLoginOtp,
  adminLogin,
  adminVerifyLoginOtp,
} from "../controllers/auth.controller.js";
import { requireTempToken } from "../middleware/tempAuth.middleware.js";
import { requireAuth } from "../middleware/auth.middleware.js";
import { getMe } from "../controllers/me.controller.js";

import {
  login,
  verifyLoginOtp,
} from "../controllers/auth.controller.js";


const router = Router();

// NEW unified login
router.post("/login", login);
router.post(
  "/login/verify-otp",
  requireTempToken,
  verifyLoginOtp
);


// PASSENGER ROUTES
router.post("/passenger/signup", passengerSignup);
router.post("/passenger/signup/verify-otp", passengerVerifySignupOtp);
router.post("/passenger/login", passengerLogin);
router.post("/passenger/login/verify-otp", requireTempToken, passengerVerifyLoginOtp);

// ADMIN ROUTES
router.post("/admin/login", adminLogin);
router.post("/admin/login/verify-otp", requireTempToken, adminVerifyLoginOtp);

// CURRENT USER
router.get("/me", requireAuth, getMe);
 

export default router;




