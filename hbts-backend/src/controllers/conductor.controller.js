// src/controllers/conductor.controller.js
import { pool } from "../db.js";
import crypto from "crypto";

/* =========================================
   Helpers
========================================= */

async function getConductorContext(userId) {
  const { rows } = await pool.query(
    `
    SELECT conductor_id, user_id, bus_id, operator_id, is_active
    FROM conductors
    WHERE user_id = $1 AND is_active = true
    `,
    [userId]
  );
  return rows[0] || null;
}

async function logAction(client, { tripId = null, bookingId = null, userId, type, meta = {} }) {
  // NOTE: requires conductor_action_log.trip_id to allow NULL
  await client.query(
    `
    INSERT INTO conductor_action_log (trip_id, booking_id, conductor_user_id, type, meta)
    VALUES ($1, $2, $3, $4::conductor_log_type, $5::jsonb)
    `,
    [tripId, bookingId, userId, type, JSON.stringify(meta)]
  );
}

function parseQr(qrRaw) {
  if (!qrRaw || typeof qrRaw !== "string") return { ok: false, error: "QR is required" };
  const trimmed = qrRaw.trim();
  if (!trimmed) return { ok: false, error: "QR is empty" };

  // JSON QR: {"bookingId":123,"tripId":456}
  if (trimmed.startsWith("{") && trimmed.endsWith("}")) {
    try {
      const obj = JSON.parse(trimmed);
      const bookingId = Number(obj.bookingId ?? obj.booking_id);
      const tripId = obj.tripId != null ? Number(obj.tripId ?? obj.trip_id) : null;

      if (!Number.isFinite(bookingId)) return { ok: false, error: "Invalid bookingId in QR JSON" };
      if (tripId != null && !Number.isFinite(tripId)) return { ok: false, error: "Invalid tripId in QR JSON" };

      return { ok: true, bookingId, tripId, format: "json" };
    } catch {
      return { ok: false, error: "Invalid JSON QR" };
    }
  }

  // Plain text containing a number (e.g. "HBTS-123")
  const m = trimmed.match(/(\d+)/);
  if (m) {
    const bookingId = Number(m[1]);
    if (!Number.isFinite(bookingId)) return { ok: false, error: "Invalid bookingId in QR" };
    return { ok: true, bookingId, tripId: null, format: "text" };
  }

  return { ok: false, error: "Unsupported QR format" };
}

/**
 * Loads booking + trip, optionally locks row, and validates conductor ownership.
 * If tripIdHint provided, it must match booking.trip_id.
 */
async function mustGetBookingForConductor(client, { bookingId, userId, tripIdHint = null, lock = true }) {
  const ctx = await getConductorContext(userId);
  if (!ctx) {
    const err = new Error("Conductor profile not found or inactive");
    err.status = 403;
    throw err;
  }

  const lockSql = lock ? "FOR UPDATE" : "";
  const { rows } = await client.query(
    `
    SELECT
      b.booking_id,
      b.trip_id,
      b.user_id,
      u.name AS passenger_name,
      u.phone AS passenger_phone,
      b.seat_id,
      s.seat_label AS seat_number,

      b.boarding_stop_id,
      bs.stop_name AS boarding_stop_name,

      b.dropping_stop_id,
      ds.stop_name AS dropping_stop_name,

      b.price,
      b.status AS booking_status,

      b.paid_via,
      b.payment_status,
      b.payment_ref,
      b.paid_at,
      b.paid_by,

      b.boarded_at,
      b.boarded_by,

      b.qr_code,
      b.qr_scanned_at,
      b.last_scanned_by,
      b.verification_source,

      t.bus_id,
      t.operator_id,
      t.trip_date,
      t.departure_time,
      t.arrival_time,
      t.status AS trip_status,
      t.deleted_at
    FROM bookings b
    JOIN trips t ON t.trip_id = b.trip_id
    JOIN users u ON u.user_id = b.user_id
    JOIN seats s ON s.seat_id = b.seat_id
    JOIN stops bs ON bs.stop_id = b.boarding_stop_id
    JOIN stops ds ON ds.stop_id = b.dropping_stop_id
    WHERE b.booking_id = $1
      AND t.deleted_at IS NULL
    ${lockSql}
    `,
    [bookingId]
  );

  if (!rows.length) {
    const err = new Error("Booking not found");
    err.status = 404;
    throw err;
  }

  const b = rows[0];

  if (tripIdHint != null && tripIdHint !== b.trip_id) {
    const err = new Error("Booking does not belong to provided tripId");
    err.status = 400;
    throw err;
  }

  if (b.bus_id !== ctx.bus_id || b.operator_id !== ctx.operator_id) {
    const err = new Error("Trip not accessible for this conductor");
    err.status = 403;
    throw err;
  }

  return { ctx, b };
}

function normalizePaymentStatus(b) {
  // Back-compat: if payment_status null
  return b.payment_status ?? (String(b.paid_via) === "cash" ? "pending" : "paid");
}

/* =========================================
   Step 2 APIs (read)
========================================= */

/**
 * GET /api/conductor/me/bus
 */
export async function getMyBus(req, res) {
  try {
    const userId = req.user.user_id;

    const ctx = await getConductorContext(userId);
    if (!ctx) return res.status(403).json({ message: "Conductor profile not found or inactive" });

    const { rows } = await pool.query(
      `
      SELECT
        c.conductor_id,
        c.is_active,
        c.assigned_at,
        c.updated_at,

        b.bus_id,
        b.license_plate_no,
        b.route_no,
        b.capacity,
        b.model,
        b.service_type,

        co.operator_id,
        co.name AS company_name,
        co.email AS company_email,
        co.phone AS company_phone,
        co.verified AS company_verified
      FROM conductors c
      JOIN buses b ON b.bus_id = c.bus_id
      JOIN company co ON co.operator_id = c.operator_id
      WHERE c.user_id = $1
      `,
      [userId]
    );

    return res.json(rows[0] || null);
  } catch (e) {
    console.error("getMyBus error:", e);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /api/conductor/me/trips?date=YYYY-MM-DD
 */
export async function getMyTrips(req, res) {
  try {
    const userId = req.user.user_id;

    const ctx = await getConductorContext(userId);
    if (!ctx) return res.status(403).json({ message: "Conductor profile not found or inactive" });

    const date = (req.query.date || "").toString().trim();
    const dateOrNull = date.length ? date : null;

    const { rows } = await pool.query(
      `
      SELECT
        t.trip_id,
        t.route_id,
        t.operator_id,
        t.bus_id,
        t.driver_id,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status,

        r.route_name,
        r.from_location,
        r.to_location
      FROM trips t
      JOIN routes r ON r.route_id = t.route_id
      WHERE t.bus_id = $1
        AND t.operator_id = $2
        AND t.deleted_at IS NULL
        AND t.trip_date = COALESCE($3::date, CURRENT_DATE)
      ORDER BY t.departure_time ASC
      `,
      [ctx.bus_id, ctx.operator_id, dateOrNull]
    );

    return res.json(rows);
  } catch (e) {
    console.error("getMyTrips error:", e);
    return res.status(500).json({ message: "Server error" });
  }
}

/**
 * GET /api/conductor/trips/:tripId/bookings
 */
export async function getTripBookings(req, res) {
  try {
    const userId = req.user.user_id;

    const ctx = await getConductorContext(userId);
    if (!ctx) return res.status(403).json({ message: "Conductor profile not found or inactive" });

    const tripId = Number(req.params.tripId);
    if (!Number.isFinite(tripId)) return res.status(400).json({ message: "Invalid tripId" });

    // trip ownership check
    const tripCheck = await pool.query(
      `
      SELECT trip_id
      FROM trips
      WHERE trip_id = $1
        AND bus_id = $2
        AND operator_id = $3
        AND deleted_at IS NULL
      `,
      [tripId, ctx.bus_id, ctx.operator_id]
    );

    if (!tripCheck.rows.length) return res.status(403).json({ message: "Trip not accessible" });

    const status = (req.query.status || "").toString();
    const payment = (req.query.payment || "").toString();
    const q = (req.query.q || "").toString().trim();

    const page = Math.max(1, parseInt(req.query.page || "1", 10));
    const limit = Math.min(100, Math.max(1, parseInt(req.query.limit || "30", 10)));
    const offset = (page - 1) * limit;

    const where = [`b.trip_id = $1`, `t.deleted_at IS NULL`];
    const params = [tripId];
    let idx = 1;

    if (status === "boarded") where.push(`b.boarded_at IS NOT NULL`);
    if (status === "not_boarded") where.push(`b.boarded_at IS NULL`);

    if (payment === "cash_pending") {
      where.push(`b.paid_via = 'cash'::payment_method`);
      where.push(`b.payment_status = 'pending'::payment_status`);
    } else if (payment === "paid") {
      where.push(`b.payment_status = 'paid'::payment_status`);
    } else if (payment === "online_paid") {
      where.push(`b.paid_via <> 'cash'::payment_method`);
      where.push(`b.payment_status = 'paid'::payment_status`);
    }

    if (q) {
      idx++;
      params.push(q);
      where.push(`
        (
          b.booking_id::text = $${idx}
          OR s.seat_label::text = $${idx}
          OR EXISTS (
            SELECT 1 FROM users u
            WHERE u.user_id = b.user_id
              AND (u.phone::text = $${idx} OR u.phone ILIKE '%' || $${idx} || '%')
          )
        )
      `);
    }

    idx++;
    params.push(limit);
    const limitParam = `$${idx}`;

    idx++;
    params.push(offset);
    const offsetParam = `$${idx}`;

    const sql = `
      SELECT
        b.booking_id,
        b.trip_id,
        b.user_id,
        u.name AS passenger_name,
        u.phone AS passenger_phone,
        b.seat_id,
        s.seat_label AS seat_number,

        b.boarding_stop_id,
        bs.stop_name AS boarding_stop_name,

        b.dropping_stop_id,
        ds.stop_name AS dropping_stop_name,

        b.price,
        b.status,
        b.paid_via,
        b.payment_status,
        b.paid_at,
        b.paid_by,

      b.boarded_at,
      b.boarded_by,

      b.qr_code,
      b.qr_scanned_at,
      b.last_scanned_by,
      b.verification_source

      FROM bookings b
      JOIN trips t ON t.trip_id = b.trip_id
      JOIN users u ON u.user_id = b.user_id
      JOIN seats s ON s.seat_id = b.seat_id
      JOIN stops bs ON bs.stop_id = b.boarding_stop_id
      JOIN stops ds ON ds.stop_id = b.dropping_stop_id
      WHERE ${where.join(" AND ")}
      ORDER BY s.seat_label ASC, b.booking_id ASC
      LIMIT ${limitParam} OFFSET ${offsetParam}
    `;

    const { rows } = await pool.query(sql, params);

    return res.json({ page, limit, count: rows.length, items: rows });
  } catch (e) {
    console.error("getTripBookings error:", e);
    return res.status(500).json({ message: "Server error" });
  }
}

/* =========================================
   Step 3 APIs (actions)
========================================= */

/**
 * POST /api/conductor/scan/verify
 * Body: { qr: string, tripId?: number }
 */
export async function verifyScan(req, res) {
  const userId = req.user.user_id;

  const qrRaw = (req.body?.qr ?? "").toString();
  const tripIdFromBody = req.body?.tripId != null ? Number(req.body.tripId) : null;

  const parsed = parseQr(qrRaw);
  if (!parsed.ok) return res.status(400).json({ valid: false, reason: parsed.error });

  const bookingId = parsed.bookingId;
  const tripIdHint = parsed.tripId;
  const clientTripId = tripIdFromBody ?? tripIdHint ?? null;

  const qrHash = crypto.createHash("sha256").update(qrRaw).digest("hex");

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // We lock = false for verify (read-ish), but we still update scan markers later.
    const { b } = await mustGetBookingForConductor(client, {
      bookingId,
      userId,
      tripIdHint: clientTripId,
      lock: false,
    });

    const invalidStatuses = new Set(["cancelled", "expired"]);
    if (invalidStatuses.has(String(b.booking_status))) {
      await logAction(client, {
        tripId: b.trip_id,
        bookingId: b.booking_id,
        userId,
        type: "QR_VERIFY",
        meta: { ok: false, reason: "BOOKING_INVALID_STATUS", booking_status: b.booking_status, qrHash },
      });
      await client.query("COMMIT");
      return res.status(400).json({ valid: false, reason: `Booking is ${b.booking_status}` });
    }

    const paymentStatus = normalizePaymentStatus(b);
    const alreadyPaid = paymentStatus === "paid" || !!b.payment_ref;
    const cashPending = String(b.paid_via) === "cash" && paymentStatus === "pending";

    const alreadyBoarded = !!b.boarded_at;
    const alreadyScanned = !!b.qr_scanned_at;

    // mark scan (idempotent)
    await client.query(
      `
      UPDATE bookings
      SET
        qr_scanned_at = COALESCE(qr_scanned_at, CURRENT_TIMESTAMP),
        last_scanned_by = $2
      WHERE booking_id = $1
      `,
      [b.booking_id, userId]
    );

    await logAction(client, {
      tripId: b.trip_id,
      bookingId: b.booking_id,
      userId,
      type: alreadyBoarded ? "DUPLICATE_SCAN" : "QR_VERIFY",
      meta: {
        ok: true,
        qrHash,
        format: parsed.format,
        alreadyBoarded,
        alreadyScanned,
        payment: { paid_via: b.paid_via, paymentStatus, hasPaymentRef: !!b.payment_ref },
      },
    });

    await client.query("COMMIT");

    return res.json({
      valid: true,
      booking: {
        booking_id: b.booking_id,
        trip_id: b.trip_id,
        seat_id: b.seat_id,
        seat_number: b.seat_number,
        boarding_stop_id: b.boarding_stop_id,
        boarding_stop_name: b.boarding_stop_name,
        dropping_stop_id: b.dropping_stop_id,
        dropping_stop_name: b.dropping_stop_name,
        price: b.price,
        booking_status: b.booking_status,
        paid_via: b.paid_via,
        payment_status: paymentStatus,
        payment_ref: b.payment_ref ?? null,
        paid_at: b.paid_at ?? null,
        paid_by: b.paid_by ?? null,
        boarded_at: b.boarded_at ?? null,
        boarded_by: b.boarded_by ?? null,
        qr_code: b.qr_code ?? null,
        qr_scanned_at: b.qr_scanned_at ?? null,
      },
      flags: {
        alreadyBoarded,
        alreadyScanned,
        alreadyPaid,
        cashPending,
        canCollectCash: cashPending,
        canBoard: !alreadyBoarded,
      },
    });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("verifyScan error:", e);

    // Try to log unknown failures (optional, best-effort)
    try {
      const ctx = await getConductorContext(userId);
      if (ctx) {
        await logAction(client, {
          tripId: null,
          bookingId: null,
          userId,
          type: "QR_VERIFY",
          meta: { ok: false, reason: e.message, qrHash },
        });
      }
    } catch {}

    return res.status(e.status || 500).json({ valid: false, reason: e.message || "Server error" });
  } finally {
    client.release();
  }
}

/**
 * POST /api/conductor/bookings/:bookingId/board
 * Body: { tripId?: number, source?: "QR"|"MANUAL"|"OFFLINE_QR", override?: object }
 */
export async function boardBooking(req, res) {
  const userId = req.user.user_id;

  const bookingId = Number(req.params.bookingId);
  if (!Number.isFinite(bookingId)) return res.status(400).json({ message: "Invalid bookingId" });

  const tripIdHint = req.body?.tripId != null ? Number(req.body.tripId) : null;
  const source = (req.body?.source || "QR").toString();
  const override = req.body?.override ?? null;

  const allowedSources = new Set(["QR", "MANUAL", "OFFLINE_QR"]);
  if (!allowedSources.has(source)) return res.status(400).json({ message: "Invalid source" });

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    const { b } = await mustGetBookingForConductor(client, { bookingId, userId, tripIdHint, lock: true });

    const invalidStatuses = new Set(["cancelled", "expired"]);
    if (invalidStatuses.has(String(b.booking_status))) {
      const err = new Error(`Booking is ${b.booking_status}`);
      err.status = 400;
      throw err;
    }

    // Idempotent: already boarded
    if (b.boarded_at) {
      await logAction(client, {
        tripId: b.trip_id,
        bookingId: b.booking_id,
        userId,
        type: "DUPLICATE_SCAN",
        meta: { ok: true, idempotent: true, alreadyBoarded: true },
      });
      await client.query("COMMIT");
      return res.json({
        ok: true,
        idempotent: true,
        booking_id: b.booking_id,
        trip_id: b.trip_id,
        boarded_at: b.boarded_at,
        boarded_by: b.boarded_by,
      });
    }

    const upd = await client.query(
      `
      UPDATE bookings
      SET
        boarded_at = CURRENT_TIMESTAMP,
        boarded_by = $2,
        verification_source = $3::verification_source,
        qr_scanned_at = COALESCE(qr_scanned_at, CURRENT_TIMESTAMP),
        last_scanned_by = $2
      WHERE booking_id = $1
      RETURNING booking_id, trip_id, boarded_at, boarded_by, verification_source, qr_scanned_at, last_scanned_by
      `,
      [b.booking_id, userId, source]
    );

    await logAction(client, {
      tripId: b.trip_id,
      bookingId: b.booking_id,
      userId,
      type: "BOARD",
      meta: { ok: true, source },
    });

    if (override) {
      await logAction(client, {
        tripId: b.trip_id,
        bookingId: b.booking_id,
        userId,
        type: "STOP_OVERRIDE",
        meta: { ok: true, ...override },
      });
    }

    await client.query("COMMIT");
    return res.json({ ok: true, idempotent: false, booking: upd.rows[0] });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("boardBooking error:", e);
    return res.status(e.status || 500).json({ message: e.message || "Server error" });
  } finally {
    client.release();
  }
}

/**
 * POST /api/conductor/bookings/:bookingId/pay-cash
 * Body: { tripId?: number, amount?: number, clientActionId?: string(uuid) }
 */
export async function payCashBooking(req, res) {
  const userId = req.user.user_id;

  const bookingId = Number(req.params.bookingId);
  if (!Number.isFinite(bookingId)) return res.status(400).json({ message: "Invalid bookingId" });

  const tripIdHint = req.body?.tripId != null ? Number(req.body.tripId) : null;
  const amount = req.body?.amount != null ? Number(req.body.amount) : null;
  const clientActionId = req.body?.clientActionId ? String(req.body.clientActionId) : null;

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Optional idempotency via conductor_sync_action (for retries/offline)
    if (clientActionId) {
      const seen = await client.query(
        `SELECT client_action_id, status, result FROM conductor_sync_action WHERE client_action_id = $1`,
        [clientActionId]
      );
      if (seen.rows.length) {
        await client.query("COMMIT");
        return res.json({ ok: true, idempotent: true, clientActionId, previous: seen.rows[0] });
      }
    }

    const { b } = await mustGetBookingForConductor(client, { bookingId, userId, tripIdHint, lock: true });

    if (String(b.paid_via) !== "cash") {
      const err = new Error("This booking is not a cash payment");
      err.status = 400;
      throw err;
    }

    const currentPaymentStatus = b.payment_status ?? (b.payment_ref ? "paid" : "pending");

    // Idempotent: already paid
    if (currentPaymentStatus === "paid") {
      await logAction(client, {
        tripId: b.trip_id,
        bookingId: b.booking_id,
        userId,
        type: "PAY_CASH",
        meta: { ok: true, idempotent: true, alreadyPaid: true, amount },
      });

      if (clientActionId) {
        await client.query(
          `
          INSERT INTO conductor_sync_action (client_action_id, trip_id, booking_id, conductor_user_id, action_type, status, result)
          VALUES ($1, $2, $3, $4, 'PAY_CASH'::conductor_log_type, 'applied', $5::jsonb)
          `,
          [clientActionId, b.trip_id, b.booking_id, userId, JSON.stringify({ ok: true, idempotent: true })]
        );
      }

      await client.query("COMMIT");
      return res.json({
        ok: true,
        idempotent: true,
        booking_id: b.booking_id,
        trip_id: b.trip_id,
        payment_status: currentPaymentStatus,
        paid_at: b.paid_at ?? null,
        paid_by: b.paid_by ?? null,
      });
    }

    const upd = await client.query(
      `
      UPDATE bookings
      SET
        payment_status = 'paid'::payment_status,
        paid_at = CURRENT_TIMESTAMP,
        paid_by = $2
      WHERE booking_id = $1
      RETURNING booking_id, trip_id, paid_via, payment_status, paid_at, paid_by
      `,
      [b.booking_id, userId]
    );

    await logAction(client, {
      tripId: b.trip_id,
      bookingId: b.booking_id,
      userId,
      type: "PAY_CASH",
      meta: { ok: true, idempotent: false, amount },
    });

    if (clientActionId) {
      await client.query(
        `
        INSERT INTO conductor_sync_action (client_action_id, trip_id, booking_id, conductor_user_id, action_type, status, result)
        VALUES ($1, $2, $3, $4, 'PAY_CASH'::conductor_log_type, 'applied', $5::jsonb)
        `,
        [clientActionId, b.trip_id, b.booking_id, userId, JSON.stringify({ ok: true, idempotent: false })]
      );
    }

    await client.query("COMMIT");
    return res.json({ ok: true, idempotent: false, booking: upd.rows[0] });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("payCashBooking error:", e);
    return res.status(e.status || 500).json({ message: e.message || "Server error" });
  } finally {
    client.release();
  }
}

export async function scanCommit(req, res) {
  const userId = req.user.user_id;

  const qrRaw = (req.body?.qr ?? "").toString();
  const source = (req.body?.source || "QR").toString(); // QR | MANUAL | OFFLINE_QR
  const collectCash = !!req.body?.collectCash;
  const amount = req.body?.amount != null ? Number(req.body.amount) : null;

  const tripIdFromBody = req.body?.tripId != null ? Number(req.body.tripId) : null;
  const clientActionId = req.body?.clientActionId ? String(req.body.clientActionId) : null;

  const allowedSources = new Set(["QR", "MANUAL", "OFFLINE_QR"]);
  if (!allowedSources.has(source)) return res.status(400).json({ ok: false, message: "Invalid source" });

  const parsed = parseQr(qrRaw);
  if (!parsed.ok) return res.status(400).json({ ok: false, message: parsed.error });

  const bookingId = parsed.bookingId;
  const tripIdHint = parsed.tripId;
  const tripIdFinalHint = tripIdFromBody ?? tripIdHint ?? null;

  const qrHash = crypto.createHash("sha256").update(qrRaw).digest("hex");

  const client = await pool.connect();
  try {
    await client.query("BEGIN");

    // Optional idempotency (offline retries)
    if (clientActionId) {
      const seen = await client.query(
        `SELECT client_action_id, status, result FROM conductor_sync_action WHERE client_action_id = $1`,
        [clientActionId]
      );
      if (seen.rows.length) {
        await client.query("COMMIT");
        return res.json({ ok: true, idempotent: true, clientActionId, previous: seen.rows[0] });
      }
    }

    // Lock booking row (single source of truth)
    const { b } = await mustGetBookingForConductor(client, {
      bookingId,
      userId,
      tripIdHint: tripIdFinalHint,
      lock: true,
    });

    // Block invalid booking statuses
    const invalidStatuses = new Set(["cancelled", "expired"]);
    if (invalidStatuses.has(String(b.booking_status))) {
      await logAction(client, {
        tripId: b.trip_id,
        bookingId: b.booking_id,
        userId,
        type: "QR_VERIFY",
        meta: { ok: false, reason: "BOOKING_INVALID_STATUS", booking_status: b.booking_status, qrHash },
      });
      await client.query("COMMIT");
      return res.status(400).json({ ok: false, message: `Booking is ${b.booking_status}` });
    }

    // ----------------------------
    // Decide payment state
    // ----------------------------
    const paymentStatus =
      b.payment_status ?? (String(b.paid_via) === "cash" ? "pending" : "paid");

    const alreadyPaid = paymentStatus === "paid" || !!b.payment_ref;
    const cashPending = String(b.paid_via) === "cash" && paymentStatus === "pending";

    // ----------------------------
    // Decide boarding state
    // ----------------------------
    const alreadyBoarded = !!b.boarded_at;

    // Mark scan markers (idempotent)
    await client.query(
      `
      UPDATE bookings
      SET
        qr_scanned_at = COALESCE(qr_scanned_at, CURRENT_TIMESTAMP),
        last_scanned_by = $2
      WHERE booking_id = $1
      `,
      [b.booking_id, userId]
    );

    // Always log the scan
    await logAction(client, {
      tripId: b.trip_id,
      bookingId: b.booking_id,
      userId,
      type: alreadyBoarded ? "DUPLICATE_SCAN" : "QR_VERIFY",
      meta: { ok: true, qrHash, format: parsed.format, alreadyBoarded },
    });

    // ----------------------------
    // If cash pending and caller wants to collect cash → mark paid
    // ----------------------------
    let cashPaid = false;

    if (cashPending) {
      if (!collectCash) {
        // Caller didn't request payment, so keep pending and return
        await client.query("COMMIT");
        return res.status(409).json({
          ok: false,
          message: "Cash payment pending",
          booking_id: b.booking_id,
          trip_id: b.trip_id,
          flags: { cashPending: true, alreadyPaid: false, alreadyBoarded },
        });
      }

      // apply payment (only if not already paid)
      const payUpd = await client.query(
        `
        UPDATE bookings
        SET
          payment_status = 'paid'::payment_status,
          paid_at = CURRENT_TIMESTAMP,
          paid_by = $2
        WHERE booking_id = $1
          AND paid_via = 'cash'::payment_method
          AND COALESCE(payment_status, 'pending'::payment_status) = 'pending'::payment_status
        RETURNING booking_id, payment_status, paid_at, paid_by
        `,
        [b.booking_id, userId]
      );

      if (payUpd.rows.length) {
        cashPaid = true;
        await logAction(client, {
          tripId: b.trip_id,
          bookingId: b.booking_id,
          userId,
          type: "PAY_CASH",
          meta: { ok: true, amount, idempotent: false },
        });
      } else {
        // someone else might have paid concurrently
        cashPaid = true;
        await logAction(client, {
          tripId: b.trip_id,
          bookingId: b.booking_id,
          userId,
          type: "PAY_CASH",
          meta: { ok: true, amount, idempotent: true, note: "Already paid by another action" },
        });
      }
    }

    // ----------------------------
    // Board passenger (idempotent)
    // ----------------------------
    let boarded = false;

    if (!alreadyBoarded) {
      const boardUpd = await client.query(
        `
        UPDATE bookings
        SET
          boarded_at = CURRENT_TIMESTAMP,
          boarded_by = $2,
          verification_source = $3::verification_source,
          qr_scanned_at = COALESCE(qr_scanned_at, CURRENT_TIMESTAMP),
          last_scanned_by = $2
        WHERE booking_id = $1
          AND boarded_at IS NULL
        RETURNING booking_id, trip_id, boarded_at, boarded_by, verification_source
        `,
        [b.booking_id, userId, source]
      );

      if (boardUpd.rows.length) {
        boarded = true;
        await logAction(client, {
          tripId: b.trip_id,
          bookingId: b.booking_id,
          userId,
          type: "BOARD",
          meta: { ok: true, source, idempotent: false },
        });
      } else {
        // concurrent board
        boarded = true;
        await logAction(client, {
          tripId: b.trip_id,
          bookingId: b.booking_id,
          userId,
          type: "BOARD",
          meta: { ok: true, source, idempotent: true, note: "Already boarded by another action" },
        });
      }
    }

    // Prepare final booking state (fresh read)
    const finalQ = await client.query(
      `
      SELECT
        b.booking_id,
        b.trip_id,
        b.seat_id,
        s.seat_label AS seat_number,

        b.boarding_stop_id,
        bs.stop_name AS boarding_stop_name,

        b.dropping_stop_id,
        ds.stop_name AS dropping_stop_name,

        b.price,
        b.status AS booking_status,

        b.paid_via,
        b.payment_status,
        b.payment_ref,
        b.paid_at,
        b.paid_by,

        b.boarded_at,
        b.boarded_by,

        b.qr_scanned_at,
        b.last_scanned_by,
        b.verification_source
      FROM bookings b
      JOIN seats s ON s.seat_id = b.seat_id
      JOIN stops bs ON bs.stop_id = b.boarding_stop_id
      JOIN stops ds ON ds.stop_id = b.dropping_stop_id
      WHERE b.booking_id = $1
      `,
      [b.booking_id]
    );

    const finalBooking = finalQ.rows[0];

    // Record idempotency result if clientActionId provided
    if (clientActionId) {
      await client.query(
        `
        INSERT INTO conductor_sync_action (client_action_id, trip_id, booking_id, conductor_user_id, action_type, status, result)
        VALUES ($1, $2, $3, $4, 'SCAN_COMMIT'::conductor_log_type, 'applied', $5::jsonb)
        `,
        [
          clientActionId,
          b.trip_id,
          b.booking_id,
          userId,
          JSON.stringify({
            ok: true,
            actions: { verified: true, cashPaid: cashPaid || false, boarded: boarded || alreadyBoarded },
            booking_id: b.booking_id,
            trip_id: b.trip_id,
          }),
        ]
      );
    }

    await client.query("COMMIT");

    return res.json({
      ok: true,
      booking: finalBooking,
      actions: {
        verified: true,
        cashPaid: cashPaid,
        boarded: boarded || alreadyBoarded,
      },
      flags: {
        alreadyPaid: alreadyPaid || cashPaid,
        cashPending: false,
      },
    });
  } catch (e) {
    await client.query("ROLLBACK");
    console.error("scanCommit error:", e);
    return res.status(e.status || 500).json({ ok: false, message: e.message || "Server error" });
  } finally {
    client.release();
  }
}


/**
 * GET /api/conductor/me/active-trip
 * Returns the currently running trip for this conductor's bus (if any)
 */
export async function getMyActiveTrip(req, res) {
  try {
    const userId = req.user.user_id;

    // 1️⃣ Get conductor context
    const ctxQ = await pool.query(
      `
      SELECT bus_id, operator_id
      FROM conductors
      WHERE user_id = $1 AND is_active = true
      `,
      [userId]
    );

    if (!ctxQ.rows.length) {
      return res.status(403).json({ message: "Conductor profile not found or inactive" });
    }

    const { bus_id, operator_id } = ctxQ.rows[0];

    // 2️⃣ Find running trip
    const tripQ = await pool.query(
      `
      SELECT
        t.trip_id,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status,

        r.route_name,
        r.from_location,
        r.to_location,

        b.bus_id,
        b.license_plate_no,
        b.model
      FROM trips t
      JOIN routes r ON r.route_id = t.route_id
      JOIN buses b ON b.bus_id = t.bus_id
      WHERE t.bus_id = $1
        AND t.operator_id = $2
        AND t.status = 'running'::trip_status
        AND t.deleted_at IS NULL
      LIMIT 1
      `,
      [bus_id, operator_id]
    );

    // 3️⃣ No active trip → return null
    if (!tripQ.rows.length) {
      return res.json(null);
    }

    // 4️⃣ Active trip found
    return res.json(tripQ.rows[0]);
  } catch (e) {
    console.error("getMyActiveTrip error:", e);
    return res.status(500).json({ message: "Server error" });
  }
}

