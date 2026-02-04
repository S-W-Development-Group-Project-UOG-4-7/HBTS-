import express from "express";
import { v4 as uuidv4 } from "uuid";
import { pool } from "../db.js";
import { requireAuth } from "../middleware/auth.middleware.js";

const router = express.Router();

const LOCK_MINUTES = Number(process.env.SEAT_LOCK_MINUTES || 5);
const PENDING_TTL_MINUTES = Number(process.env.PENDING_TTL_MINUTES || 10);

let ensured = false;

async function ensureSeatLocksTable() {
  if (ensured) return;
  await pool.query(`
    CREATE TABLE IF NOT EXISTS seat_locks (
      lock_id TEXT PRIMARY KEY,
      trip_id INTEGER NOT NULL REFERENCES trips(trip_id) ON DELETE CASCADE,
      seat_id INTEGER NOT NULL REFERENCES seats(seat_id) ON DELETE CASCADE,
      user_id INTEGER,
      locked_until TIMESTAMP NOT NULL,
      created_at TIMESTAMP NOT NULL DEFAULT NOW()
    )
  `);
  await pool.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS seat_locks_active_idx
      ON seat_locks (trip_id, seat_id)
     WHERE locked_until > NOW()
  `);
  ensured = true;
}

async function cleanupExpiredLocks() {
  await pool.query(`DELETE FROM seat_locks WHERE locked_until <= NOW()`);
}

async function getTripBusId(tripId) {
  const { rows } = await pool.query(
    `SELECT bus_id FROM trips WHERE trip_id = $1 LIMIT 1`,
    [tripId]
  );
  return rows[0]?.bus_id ?? null;
}

router.use(requireAuth);

// Seat map with availability state
router.get("/:tripId/seat-map", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    await ensureSeatLocksTable();
    await cleanupExpiredLocks();

    const busId = await getTripBusId(tripId);
    if (!busId) {
      return res.status(404).json({ message: "Trip not found" });
    }

    const { rows } = await pool.query(
      `
      WITH active_bookings AS (
        SELECT seat_id, status, booking_id, user_id
        FROM bookings
        WHERE trip_id = $1
          AND (
            status = 'confirmed'
            OR (status = 'pending' AND booking_time >= NOW() - ($2::text || ' minutes')::interval)
          )
      ),
      active_locks AS (
        SELECT seat_id, lock_id, user_id
        FROM seat_locks
        WHERE trip_id = $1
          AND locked_until > NOW()
      )
      SELECT
        s.seat_id,
        s.seat_label,
        s.row_number,
        s.column_number,
        ab.status        AS booking_status,
        ab.booking_id,
        ab.user_id       AS booking_user_id,
        al.lock_id,
        al.user_id       AS lock_user_id
      FROM seats s
      LEFT JOIN active_bookings ab ON ab.seat_id = s.seat_id
      LEFT JOIN active_locks al ON al.seat_id = s.seat_id
      WHERE s.bus_id = $3
      ORDER BY s.row_number NULLS LAST, s.seat_label
      `,
      [tripId, String(PENDING_TTL_MINUTES), busId]
    );

    const seats = rows.map((row) => {
      let status = "available";
      if (row.booking_status === "confirmed") status = "booked";
      else if (row.booking_status === "pending") status = "held";
      else if (row.lock_id) status = "locked";

      return {
        seatId: row.seat_id,
        seatLabel: row.seat_label,
        row: row.row_number,
        column: row.column_number,
        status,
        bookingId: row.booking_id || null,
        lockId: row.lock_id || null,
      };
    });

    return res.json({ tripId, busId, seats });
  } catch (e) {
    return res.status(500).json({ message: "Failed to load seat map", error: e.message });
  }
});

// Lock a seat temporarily to prevent double booking
router.post("/:tripId/lock", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    const seatId = Number(req.body?.seatId || req.body?.seat_id);
    const userId = req.user?.userId || req.user?.id || null;

    if (!Number.isInteger(tripId) || !Number.isInteger(seatId)) {
      return res.status(400).json({ message: "tripId and seatId must be integers" });
    }

    await ensureSeatLocksTable();
    await cleanupExpiredLocks();

    // Ensure seat belongs to trip's bus
    const seatCheck = await pool.query(
      `
      SELECT s.seat_id
      FROM trips t
      JOIN seats s ON s.bus_id = t.bus_id
      WHERE t.trip_id = $1
        AND s.seat_id = $2
      LIMIT 1
      `,
      [tripId, seatId]
    );

    if (!seatCheck.rowCount) {
      return res.status(400).json({ message: "Seat does not belong to this trip" });
    }

    // Prevent conflicts with existing bookings (pending/confirmed)
    const bookingConflict = await pool.query(
      `
      SELECT 1
      FROM bookings
      WHERE trip_id = $1
        AND seat_id = $2
        AND (
          status = 'confirmed'
          OR (status = 'pending' AND booking_time >= NOW() - ($3::text || ' minutes')::interval)
        )
      LIMIT 1
      `,
      [tripId, seatId, String(PENDING_TTL_MINUTES)]
    );

    if (bookingConflict.rowCount > 0) {
      return res.status(409).json({ message: "Seat already booked or held" });
    }

    // Check for active lock
    const activeLock = await pool.query(
      `
      SELECT lock_id, user_id
      FROM seat_locks
      WHERE trip_id = $1
        AND seat_id = $2
        AND locked_until > NOW()
      LIMIT 1
      `,
      [tripId, seatId]
    );

    if (activeLock.rowCount) {
      const lock = activeLock.rows[0];
      if (userId && lock.user_id && lock.user_id === userId) {
        // Extend own lock
        const { rows } = await pool.query(
          `
          UPDATE seat_locks
             SET locked_until = NOW() + ($3::text || ' minutes')::interval
           WHERE lock_id = $1
          RETURNING lock_id, locked_until
          `,
          [lock.lock_id, LOCK_MINUTES]
        );

        return res.json({
          lockId: rows[0].lock_id,
          tripId,
          seatId,
          expiresAt: rows[0].locked_until,
          extended: true,
        });
      }

      return res.status(409).json({ message: "Seat is locked by another user" });
    }

    const lockId = uuidv4();
    const { rows } = await pool.query(
      `
      INSERT INTO seat_locks (lock_id, trip_id, seat_id, user_id, locked_until)
      VALUES ($1, $2, $3, $4, NOW() + ($5::text || ' minutes')::interval)
      RETURNING lock_id, locked_until
      `,
      [lockId, tripId, seatId, userId, LOCK_MINUTES]
    );

    return res.status(201).json({
      lockId: rows[0].lock_id,
      tripId,
      seatId,
      expiresAt: rows[0].locked_until,
      extended: false,
    });
  } catch (e) {
    return res.status(500).json({ message: "Failed to lock seat", error: e.message });
  }
});

export default router;
