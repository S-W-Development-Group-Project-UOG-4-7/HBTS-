import express from "express";
import {
  passengerSignup,
  passengerVerifySignupOtp,
  passengerLogin,
  passengerVerifyLoginOtp,
} from "../controllers/auth.controller.js";

import { requireTempToken } from "../middleware/tempAuth.middleware.js";

const router = express.Router();

/* =========================
   PASSENGER AUTH ROUTES
========================= */

// SIGNUP
router.post("/signup", passengerSignup);
router.post("/signup/verify-otp", passengerVerifySignupOtp);

// LOGIN
router.post("/login", passengerLogin);
router.post("/login/verify-otp", requireTempToken, passengerVerifyLoginOtp);

export default router;
