// src/ws/tracking.ws.js
import jwt from "jsonwebtoken";
import { pool } from "../db.js";

/**
 * tripId -> Set<ws>
 */
const tripClients = new Map();

/**
 * ws tracking metadata:
 * ws.userId
 * ws.subs: Map<tripId, { bookingId, boardingStop:{stop_id,lat,lon} }>
 */

function safeSend(ws, obj) {
  if (ws.readyState !== 1) return;
  ws.send(JSON.stringify(obj));
}

// ---------- ETA helpers ----------
function haversineKm(lat1, lon1, lat2, lon2) {
  const toRad = (v) => (v * Math.PI) / 180;
  const R = 6371;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);

  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) *
      Math.cos(toRad(lat2)) *
      Math.sin(dLon / 2) ** 2;

  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function computeEtaSeconds({ busLat, busLon, stopLat, stopLon, speedMps }) {
  const distM = haversineKm(busLat, busLon, stopLat, stopLon) * 1000;

  // fallback ≈ 30 km/h
  const v = Number(speedMps);
  const effectiveSpeed = Number.isFinite(v) && v >= 2 ? v : 8.33;

  return Math.max(0, Math.round(distM / effectiveSpeed));
}

// ---------- Speed smoothing (EMA) ----------
// tripId -> emaSpeed
const speedEma = new Map();

function smoothSpeed(tripId, speedMps) {
  const key = String(tripId);

  if (speedMps == null) return speedEma.get(key) ?? null;

  const v = Number(speedMps);
  if (!Number.isFinite(v) || v < 0) return speedEma.get(key) ?? null;

  const alpha = 0.25; // smoothing factor
  const prev = speedEma.get(key);
  const next = prev == null ? v : alpha * v + (1 - alpha) * prev;
  speedEma.set(key, next);
  return next;
}

// ---------- Boarding stop state (reached/passed) ----------
// bookingId -> { reached: boolean, passed: boolean }
const boardingState = new Map();

function distMeters(busLat, busLon, stopLat, stopLon) {
  return haversineKm(busLat, busLon, stopLat, stopLon) * 1000;
}

// ---------- Registry helpers ----------
function addTripClient(tripId, ws) {
  const key = String(tripId);
  if (!tripClients.has(key)) tripClients.set(key, new Set());
  tripClients.get(key).add(ws);
}

function removeTripClient(tripId, ws) {
  const key = String(tripId);
  const set = tripClients.get(key);
  if (!set) return;
  set.delete(ws);
  if (set.size === 0) tripClients.delete(key);
}

function removeAll(ws) {
  if (!ws.subs) return;
  // Remove client from all trips and clean per-booking boarding state
  for (const [tripId, sub] of ws.subs.entries()) {
    removeTripClient(tripId, ws);
    if (sub?.bookingId != null) {
      boardingState.delete(Number(sub.bookingId));
    }
  }
  ws.subs.clear();
}

/**
 * Broadcast live location update to all passengers subscribed to that trip,
 * with ETA calculated per passenger (their boarding stop).
 */
export async function broadcastTripLocation(tripId, location) {
  const key = String(tripId);
  const set = tripClients.get(key);
  if (!set) return;

  for (const ws of set) {
    if (ws.readyState !== 1) continue;

    const sub = ws.subs?.get(key);
    if (!sub?.boardingStop) {
      safeSend(ws, { type: "location_update", tripId: Number(tripId), location });
      continue;
    }

    // Smooth speed with EMA
    const smoothed = smoothSpeed(tripId, location.speed_mps);

    const etaSeconds = computeEtaSeconds({
      busLat: Number(location.lat),
      busLon: Number(location.lon),
      stopLat: Number(sub.boardingStop.lat),
      stopLon: Number(sub.boardingStop.lon),
      speedMps: smoothed ?? location.speed_mps,
    });

    safeSend(ws, {
      type: "tracking_update",
      tripId: Number(tripId),
      bookingId: sub.bookingId,
      location,
      eta: {
        boardingStopId: sub.boardingStop.stop_id,
        etaSeconds,
        etaMinutes: Math.ceil(etaSeconds / 60),
      },
    });

    // Boarding stop reached/passed detection (per booking)
    const d = distMeters(
      Number(location.lat),
      Number(location.lon),
      Number(sub.boardingStop.lat),
      Number(sub.boardingStop.lon)
    );
    const stateKey = Number(sub.bookingId);
    const st = boardingState.get(stateKey) ?? { reached: false, passed: false };

    // Reached threshold
    if (!st.reached && d < 60) {
      st.reached = true;
    }

    // Passed threshold after being reached
    if (st.reached && !st.passed && d > 250) {
      st.passed = true;
      safeSend(ws, {
        type: "boarding_passed",
        tripId: Number(tripId),
        bookingId: sub.bookingId,
      });
    }

    boardingState.set(stateKey, st);
  }
}

export function initTrackingWS(wss) {
  wss.on("connection", (ws, req) => {
    try {
      // ✅ SAME STYLE AS YOUR notification.ws.js
      const url = new URL(req.url, "http://localhost");
      const token = url.searchParams.get("token");
      if (!token) {
        ws.close();
        return;
      }

      // ✅ Use same secret as REST auth middleware
      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);

      const userId = decoded.userId ?? decoded.user_id ?? decoded.id;
      if (!userId) {
        ws.close();
        return;
      }

      ws.userId = userId;
      ws.subs = new Map();

      console.log(`🛰️ Tracking WS connected: user ${userId}`);

      safeSend(ws, { type: "connected", userId });

      ws.on("message", async (raw) => {
        let msg;
        try {
          msg = JSON.parse(raw.toString());
        } catch {
          safeSend(ws, { type: "error", message: "Invalid JSON" });
          return;
        }

        // { type:"subscribe", tripId, bookingId }
        if (msg.type === "subscribe") {
          const tripId = Number(msg.tripId);
          const bookingId = Number(msg.bookingId);

          if (!tripId || !bookingId) {
            safeSend(ws, { type: "error", message: "tripId and bookingId are required" });
            return;
          }

          // ✅ Verify booking belongs to this passenger + trip matches,
          // and load boarding stop coordinates for ETA.
          const r = await pool.query(
            `
            SELECT
              b.booking_id,
              b.trip_id,
              b.status,
              s.stop_id,
              s.lat,
              s.lon
            FROM bookings b
            JOIN stops s ON s.stop_id = b.boarding_stop_id
            WHERE b.booking_id = $1
              AND b.user_id = $2
              AND b.trip_id = $3
              AND b.status IN ('confirmed')
            LIMIT 1
            `,
            [bookingId, ws.userId, tripId]
          );

          if (r.rowCount === 0) {
            safeSend(ws, { type: "error", message: "Forbidden (booking not found for user/trip)" });
            return;
          }

          const row = r.rows[0];
          const key = String(tripId);

          // Hygiene: reset boarding reached/passed state on (re)subscribe
          boardingState.delete(bookingId);

          ws.subs.set(key, {
            bookingId,
            boardingStop: {
              stop_id: Number(row.stop_id),
              lat: Number(row.lat),
              lon: Number(row.lon),
            },
          });

          addTripClient(tripId, ws);

          safeSend(ws, { type: "subscribed", tripId, bookingId });

          // Send last known location immediately (if exists)
          const live = await pool.query(
            `
            SELECT trip_id, lat, lon, speed_mps, heading, gps_at, updated_at
            FROM trip_live
            WHERE trip_id = $1
            `,
            [tripId]
          );

          if (live.rowCount > 0) {
            const loc = live.rows[0];
            await broadcastTripLocation(tripId, {
              trip_id: Number(loc.trip_id),
              lat: Number(loc.lat),
              lon: Number(loc.lon),
              speed_mps: loc.speed_mps != null ? Number(loc.speed_mps) : null,
              heading: loc.heading != null ? Number(loc.heading) : null,
              gps_at: loc.gps_at,
              updated_at: loc.updated_at,
            });
          }

          return;
        }

        // { type:"unsubscribe", tripId }
        if (msg.type === "unsubscribe") {
          const tripId = String(msg.tripId ?? "");
          if (!tripId) return;

          // Clean boarding state for this subscription (if present)
          const sub = ws.subs?.get(tripId);
          if (sub?.bookingId != null) {
            boardingState.delete(Number(sub.bookingId));
          }

          removeTripClient(tripId, ws);
          ws.subs?.delete(tripId);

          safeSend(ws, { type: "unsubscribed", tripId: Number(tripId) });
          return;
        }

        safeSend(ws, { type: "error", message: "Unknown message type" });
      });

      ws.on("close", () => {
        removeAll(ws);
        console.log(`❌ Tracking WS disconnected: user ${ws.userId}`);
      });
    } catch (e) {
      ws.close();
    }
  });
}
