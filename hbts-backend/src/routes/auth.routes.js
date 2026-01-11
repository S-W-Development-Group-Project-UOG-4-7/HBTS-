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

<<<<<<< HEAD
=======

>>>>>>> d9023ac95f640deb59e67b3c22d1b147f5d89e1d
const router = Router();

// PASSENGER ROUTES
router.post("/passenger/signup", passengerSignup);
router.post("/passenger/signup/verify-otp", passengerVerifySignupOtp);
router.post("/passenger/login", passengerLogin);
router.post("/passenger/login/verify-otp", requireTempToken, passengerVerifyLoginOtp);

// ADMIN ROUTES
router.post("/admin/login", adminLogin);
<<<<<<< HEAD
router.post("/admin/login/verify-otp", requireTempToken, adminVerifyLoginOtp);

// CURRENT USER
=======
router.post(
  "/admin/login/verify-otp",
  requireTempToken,
  adminVerifyLoginOtp
);
>>>>>>> d9023ac95f640deb59e67b3c22d1b147f5d89e1d
router.get("/me", requireAuth, getMe);

export default router;
