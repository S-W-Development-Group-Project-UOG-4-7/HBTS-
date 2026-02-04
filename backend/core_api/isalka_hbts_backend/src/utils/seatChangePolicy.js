// src/utils/seatChangePolicy.js

const CUTOFF_MINUTES = Number(process.env.BOOKING_CUTOFF_MINUTES || 10);
const GRACE_AFTER_MINUTES = Number(process.env.BOOKING_GRACE_AFTER_MINUTES || 5);

export function buildSeatChangePolicy({ departure_time, trip_status }) {
  const depMs = new Date(departure_time).getTime();
  const nowMs = Date.now();

  const cutoffMs = depMs - CUTOFF_MINUTES * 60 * 1000;
  const graceEndMs = depMs + GRACE_AFTER_MINUTES * 60 * 1000;

  const tripStatus = String(trip_status ?? "scheduled");

  let canChangeSeat = true;
  let code = null;
  let reason = null;

  if (["cancelled", "completed"].includes(tripStatus)) {
    canChangeSeat = false;
    code = "TRIP_NOT_EDITABLE";
    reason = "Trip is not editable";
  } else if (tripStatus !== "scheduled") {
    canChangeSeat = false;
    code = "TRIP_STARTED";
    reason = "Seat change closed (trip started)";
  } else if (nowMs > graceEndMs) {
    // after grace period, block
    canChangeSeat = false;
    code = "SEAT_CHANGE_WINDOW_CLOSED";
    reason = "Seat change window closed";
  }

  return {
    canChangeSeat,
    code,
    reason,
    cutoffMinutes: CUTOFF_MINUTES,
    graceAfterMinutes: GRACE_AFTER_MINUTES,
    serverNow: new Date(nowMs).toISOString(),
    departureTime: new Date(depMs).toISOString(),
    cutoffTime: new Date(cutoffMs).toISOString(),
    graceEndTime: new Date(graceEndMs).toISOString(),
  };
}
