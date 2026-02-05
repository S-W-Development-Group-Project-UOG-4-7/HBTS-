// src/jobs/expirePendingBookings.job.js
import cron from "node-cron";
import { pool } from "../db.js";

const TTL_MINUTES = Number(process.env.PENDING_TTL_MINUTES || 10);

let running = false;

export async function expirePendingBookingsOnce() {
  const result = await pool.query(
    `
    UPDATE bookings
    SET status = 'cancelled'
    WHERE status = 'pending'
      AND booking_time < NOW() - ($1::text || ' minutes')::interval
    RETURNING booking_id
    `,
    [String(TTL_MINUTES)]
  );

  if (result.rowCount > 0) {
    console.log(
      `[expirePendingBookings] Cancelled ${result.rowCount} pending booking(s): ${result.rows
        .slice(0, 10)
        .map((r) => r.booking_id)
        .join(", ")}${result.rowCount > 10 ? " ..." : ""}`
    );
  }

  return result.rowCount;
}

export function startExpirePendingBookingsJob() {
  // Every minute
  cron.schedule("* * * * *", async () => {
     console.log("[expirePendingBookings] tick", new Date().toISOString());
    if (running) return; // prevent overlap
    running = true;
    try {
      await expirePendingBookingsOnce();
    } catch (e) {
      console.error("expirePendingBookingsJob error:", e);
    } finally {
      running = false;
    }
  });
}
