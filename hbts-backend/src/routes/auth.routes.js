import { Router } from "express";
import {
  passengerSignup,
  passengerVerifySignupOtp,
  passengerLogin,
  passengerVerifyLoginOtp,
  adminLogin,
  adminVerifyLoginOtp
} from "../controllers/auth.controller.js";
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
export default router;
