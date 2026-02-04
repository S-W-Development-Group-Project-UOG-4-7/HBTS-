import { Router } from "express";
import {
  passengerSignup,
  passengerVerifySignupOtp,
  passengerLogin,
  passengerVerifyLoginOtp,
  adminLogin,
  adminVerifyLoginOtp,
  login,
  verifyLoginOtp,
} from "../controllers/auth.controller.js";
import { requireTempToken } from "../middleware/tempAuth.middleware.js";
import { requireAuth } from "../middleware/auth.middleware.js";
import { getMe } from "../controllers/me.controller.js";

<<<<<<< HEAD
import {
  login,
  verifyLoginOtp,
} from "../controllers/auth.controller.js";


=======
>>>>>>> origin/develop
const router = Router();

// Unified login
router.post("/login", login);
router.post("/login/verify-otp", requireTempToken, verifyLoginOtp);

// Passenger routes
router.post("/passenger/signup", passengerSignup);
router.post("/passenger/signup/verify-otp", passengerVerifySignupOtp);
router.post("/passenger/login", passengerLogin);
router.post("/passenger/login/verify-otp", requireTempToken, passengerVerifyLoginOtp);

// Admin routes
router.post("/admin/login", adminLogin);
router.post("/admin/login/verify-otp", requireTempToken, adminVerifyLoginOtp);

// Current user
router.get("/me", requireAuth, getMe);

export default router;
