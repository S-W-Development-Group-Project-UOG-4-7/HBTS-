import express from "express";
import { requireAuth } from "../middleware/auth.middleware.js";
import {
  cancelPayment,
  confirmPayment,
  createPaymentIntent,
  getPaymentStatus,
  markPaymentFailed,
} from "../services/payment.service.js";

const router = express.Router();

router.post("/intent", requireAuth, async (req, res) => {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    const role = req.user?.role;
    const { bookingId, provider, currency, amount, metadata } = req.body || {};

    const result = await createPaymentIntent({
      bookingId,
      userId,
      role,
      provider,
      currency,
      amountOverride: amount,
      metadata,
    });

    return res.status(result.created ? 201 : 200).json(result);
  } catch (err) {
    return sendError(res, err);
  }
});

router.post("/:paymentId/confirm", requireAuth, async (req, res) => {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    const role = req.user?.role;
    const { gatewayReference, payload } = req.body || {};

    const result = await confirmPayment({
      paymentId: req.params.paymentId,
      userId,
      role,
      gatewayReference,
      payload,
    });

    return res.json(result);
  } catch (err) {
    return sendError(res, err);
  }
});

router.post("/:paymentId/fail", requireAuth, async (req, res) => {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    const role = req.user?.role;
    const { reason, payload } = req.body || {};

    const result = await markPaymentFailed({
      paymentId: req.params.paymentId,
      userId,
      role,
      reason,
      payload,
    });

    return res.json(result);
  } catch (err) {
    return sendError(res, err);
  }
});

router.post("/:paymentId/cancel", requireAuth, async (req, res) => {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    const role = req.user?.role;
    const { reason, payload } = req.body || {};

    const result = await cancelPayment({
      paymentId: req.params.paymentId,
      userId,
      role,
      reason,
      payload,
    });

    return res.json(result);
  } catch (err) {
    return sendError(res, err);
  }
});

router.get("/:paymentId/status", requireAuth, async (req, res) => {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    const role = req.user?.role;

    const result = await getPaymentStatus({
      paymentId: req.params.paymentId,
      userId,
      role,
    });

    return res.json(result);
  } catch (err) {
    return sendError(res, err);
  }
});

function sendError(res, err) {
  const status = err?.status || 500;
  const payload = { message: err?.message || "Payment error" };
  if (err?.details) {
    payload.details = err.details;
  }
  return res.status(status).json(payload);
}

export default router;
