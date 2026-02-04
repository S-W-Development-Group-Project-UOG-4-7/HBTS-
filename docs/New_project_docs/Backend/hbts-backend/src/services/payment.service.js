import { pool } from "../db.js";
import { v4 as uuidv4 } from "uuid";

const ACTIVE_STATUSES = ["initiated", "processing"];
const FINAL_STATUSES = ["succeeded", "failed", "cancelled"];

const ensurePaymentsTablePromise = ensurePaymentsTable();

function createError(status, message, details) {
  const err = new Error(message);
  err.status = status;
  if (details) err.details = details;
  return err;
}

function isPrivilegedRole(role) {
  return role === "admin" || role === "operator";
}

function mapPayment(row) {
  return {
    paymentId: row.payment_id,
    bookingId: row.booking_id,
    userId: row.user_id,
    amount: row.amount === null ? null : Number(row.amount),
    currency: row.currency,
    provider: row.provider,
    status: row.status,
    gatewayReference: row.gateway_reference,
    failureReason: row.failure_reason,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

async function ensurePaymentsTable() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS payments (
      payment_id TEXT PRIMARY KEY,
      booking_id INTEGER NOT NULL REFERENCES bookings(booking_id) ON DELETE CASCADE,
      user_id INTEGER,
      amount NUMERIC NOT NULL,
      currency TEXT NOT NULL DEFAULT 'USD',
      provider TEXT NOT NULL DEFAULT 'mock',
      status TEXT NOT NULL DEFAULT 'initiated',
      gateway_reference TEXT,
      failure_reason TEXT,
      raw_payload JSONB,
      created_at TIMESTAMP NOT NULL DEFAULT NOW(),
      updated_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);

  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS payments_one_active_per_booking
      ON payments (booking_id)
     WHERE status IN ('initiated','processing')
  `);
}

async function getBookingForUpdate(client, bookingId) {
  return client.query(
    `
    SELECT booking_id, user_id, status, paid_via, price
    FROM bookings
    WHERE booking_id = $1
    FOR UPDATE
    `,
    [bookingId]
  );
}

async function getPaymentWithBooking(client, paymentId) {
  return client.query(
    `
    SELECT
      p.*,
      b.user_id AS booking_user_id,
      b.status AS booking_status
    FROM payments p
    JOIN bookings b ON b.booking_id = p.booking_id
    WHERE p.payment_id = $1
    FOR UPDATE
    `,
    [paymentId]
  );
}

export async function createPaymentIntent({
  bookingId,
  userId,
  role,
  provider = "mock",
  currency = "USD",
  amountOverride,
  metadata,
}) {
  await ensurePaymentsTablePromise;

  const parsedBookingId = Number(bookingId);
  if (!Number.isInteger(parsedBookingId)) {
    throw createError(400, "bookingId must be an integer");
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const bookingRes = await getBookingForUpdate(client, parsedBookingId);
    if (!bookingRes.rowCount) {
      throw createError(404, "Booking not found");
    }

    const booking = bookingRes.rows[0];
    const privileged = isPrivilegedRole(role);

    if (!privileged && userId && booking.user_id !== userId) {
      throw createError(403, "Not allowed to pay for this booking");
    }

    if (booking.status === "cancelled") {
      throw createError(400, "Booking is already cancelled");
    }

    if (booking.status === "confirmed") {
      throw createError(400, "Booking already confirmed");
    }

    const existing = await client.query(
      `
      SELECT *
      FROM payments
      WHERE booking_id = $1
        AND status = ANY($2)
      ORDER BY created_at DESC
      LIMIT 1
      `,
      [booking.booking_id, ACTIVE_STATUSES]
    );

    if (existing.rowCount) {
      await client.query("COMMIT");
      return { payment: mapPayment(existing.rows[0]), created: false };
    }

    const amount =
      booking.price !== undefined && booking.price !== null
        ? Number(booking.price)
        : amountOverride !== undefined
        ? Number(amountOverride)
        : null;

    if (!amount || Number.isNaN(amount) || amount <= 0) {
      throw createError(400, "A positive amount is required for payment");
    }

    if (booking.paid_via && booking.paid_via !== "online") {
      throw createError(400, "Booking was not created for online payment");
    }

    const paymentId = uuidv4();

    const insert = await client.query(
      `
      INSERT INTO payments (
        payment_id,
        booking_id,
        user_id,
        amount,
        currency,
        provider,
        status,
        raw_payload
      )
      VALUES ($1,$2,$3,$4,$5,$6,'initiated',$7)
      RETURNING *
      `,
      [paymentId, booking.booking_id, booking.user_id, amount, currency, provider, metadata ?? null]
    );

    await client.query(
      `UPDATE bookings SET paid_via = 'online' WHERE booking_id = $1`,
      [booking.booking_id]
    );

    await client.query("COMMIT");
    return { payment: mapPayment(insert.rows[0]), created: true };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

export async function confirmPayment({
  paymentId,
  userId,
  role,
  gatewayReference,
  payload,
}) {
  await ensurePaymentsTablePromise;

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const paymentRes = await getPaymentWithBooking(client, paymentId);
    if (!paymentRes.rowCount) {
      throw createError(404, "Payment not found");
    }

    const payment = paymentRes.rows[0];
    const privileged = isPrivilegedRole(role);

    if (!privileged && userId && payment.booking_user_id !== userId) {
      throw createError(403, "Not allowed to update this payment");
    }

    if (payment.booking_status === "cancelled") {
      throw createError(400, "Booking is cancelled; cannot confirm payment");
    }

    if (payment.status === "succeeded") {
      await client.query("COMMIT");
      return { payment: mapPayment(payment) };
    }

    if (payment.status === "cancelled" || payment.status === "failed") {
      throw createError(400, `Payment already ${payment.status}`);
    }

    const { rows } = await client.query(
      `
      UPDATE payments
      SET status = 'succeeded',
          gateway_reference = COALESCE($2, gateway_reference),
          raw_payload = COALESCE($3, raw_payload),
          updated_at = NOW()
      WHERE payment_id = $1
      RETURNING *
      `,
      [paymentId, gatewayReference || null, payload ?? null]
    );

    await client.query(
      `UPDATE bookings SET status = 'confirmed' WHERE booking_id = $1`,
      [payment.booking_id]
    );

    await client.query("COMMIT");
    return { payment: mapPayment(rows[0]) };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

async function finalizePayment({ paymentId, userId, role, status, reason, payload }) {
  await ensurePaymentsTablePromise;

  if (!["failed", "cancelled"].includes(status)) {
    throw createError(400, "Invalid payment final status");
  }

  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const paymentRes = await getPaymentWithBooking(client, paymentId);
    if (!paymentRes.rowCount) {
      throw createError(404, "Payment not found");
    }

    const payment = paymentRes.rows[0];
    const privileged = isPrivilegedRole(role);

    if (!privileged && userId && payment.booking_user_id !== userId) {
      throw createError(403, "Not allowed to update this payment");
    }

    if (payment.status === "succeeded") {
      throw createError(400, "Payment already succeeded");
    }

    if (FINAL_STATUSES.includes(payment.status)) {
      await client.query("COMMIT");
      return { payment: mapPayment(payment) };
    }

    const { rows } = await client.query(
      `
      UPDATE payments
      SET status = $2,
          failure_reason = COALESCE($3, failure_reason),
          raw_payload = COALESCE($4, raw_payload),
          updated_at = NOW()
      WHERE payment_id = $1
      RETURNING *
      `,
      [paymentId, status, reason || null, payload ?? null]
    );

    await client.query(
      `UPDATE bookings SET status = 'cancelled' WHERE booking_id = $1`,
      [payment.booking_id]
    );

    await client.query("COMMIT");
    return { payment: mapPayment(rows[0]) };
  } catch (err) {
    await client.query("ROLLBACK");
    throw err;
  } finally {
    client.release();
  }
}

export function markPaymentFailed(args) {
  return finalizePayment({ ...args, status: "failed" });
}

export function cancelPayment(args) {
  return finalizePayment({ ...args, status: "cancelled" });
}

export async function getPaymentStatus({ paymentId, userId, role }) {
  await ensurePaymentsTablePromise;

  const client = await pool.connect();

  try {
    const paymentRes = await client.query(
      `
      SELECT
        p.*,
        b.user_id AS booking_user_id
      FROM payments p
      JOIN bookings b ON b.booking_id = p.booking_id
      WHERE p.payment_id = $1
      `,
      [paymentId]
    );

    if (!paymentRes.rowCount) {
      throw createError(404, "Payment not found");
    }

    const payment = paymentRes.rows[0];
    const privileged = isPrivilegedRole(role);

    if (!privileged && userId && payment.booking_user_id !== userId) {
      throw createError(403, "Not allowed to view this payment");
    }

    return { payment: mapPayment(payment) };
  } finally {
    client.release();
  }
}
