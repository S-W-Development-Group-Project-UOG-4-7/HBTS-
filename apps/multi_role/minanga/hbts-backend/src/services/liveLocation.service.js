import { redis } from "../infra/redis.js";
import { pool } from "../db.js";

// ====== TUNING CONSTANTS (reliability knobs) ======
const MAX_JUMP_METERS = 400;       // teleport filter
const MAX_SPEED_KMH = 140;         // sanity filter
const BAD_ACCURACY_M = 80;         // degrade confidence
const HISTORY_WRITE_MIN_SECONDS = 45; // batch history
const MIN_MOVE_METERS_TO_BROADCAST = 20;

function toRad(d) { return (d * Math.PI) / 180; }
function haversineMeters(a, b) {
  const R = 6371000;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const s1 = Math.sin(dLat / 2);
  const s2 = Math.sin(dLng / 2);
  const q = s1 * s1 + Math.cos(toRad(a.lat)) * Math.cos(toRad(b.lat)) * s2 * s2;
  return 2 * R * Math.asin(Math.sqrt(q));
}

function nowIso() { return new Date().toISOString(); }

export async function ingestLocationPoint(input) {
  const tripId = String(input.tripId);
  const ts = input.timestamp ? new Date(input.timestamp) : new Date();
  const point = {
    tripId: Number(tripId),
    lat: input.lat,
    lng: input.lng,
    speed: input.speed ?? null,
    heading: input.heading ?? null,
    accuracy_m: input.accuracy_m ?? null,
    timestamp: ts.toISOString(),
    seq: input.seq ?? null,
    receivedAt: nowIso(),
  };

  // 1) read last known point
  const prevRaw = await redis.get(`trip:${tripId}:live`);
  const prev = prevRaw ? JSON.parse(prevRaw) : null;

  // 2) out-of-order protection
  if (prev?.seq != null && point.seq != null && point.seq <= prev.seq) {
    return { accepted: false, reason: "out_of_order_seq" };
  }
  if (prev?.timestamp && new Date(point.timestamp) <= new Date(prev.timestamp)) {
    // still allow if seq is newer (some devices send weird clocks)
    if (!(prev?.seq != null && point.seq != null && point.seq > prev.seq)) {
      return { accepted: false, reason: "out_of_order_time" };
    }
  }

  // 3) sanity checks
  if (point.speed != null && point.speed > MAX_SPEED_KMH) {
    return { accepted: false, reason: "speed_too_high" };
  }

  // 4) jump filter (if prev exists)
  let dist = null;
  if (prev) {
    dist = haversineMeters({ lat: prev.lat, lng: prev.lng }, { lat: point.lat, lng: point.lng });

    // assume nominal 5s interval; if timestamps present use that
    const dt = Math.max(1, (new Date(point.timestamp) - new Date(prev.timestamp)) / 1000);
    const impliedSpeed = (dist / dt) * 3.6;

    if (dist > MAX_JUMP_METERS && impliedSpeed > MAX_SPEED_KMH) {
      // reject teleport point
      await updateHealth(tripId, { lastRejectedAt: nowIso(), rejectReason: "teleport" });
      return { accepted: false, reason: "teleport" };
    }
  }

  // 5) smoothing (simple EMA to reduce jitter)
  const alpha = 0.35; // lower = smoother
  const smoothed = prev
    ? {
        ...point,
        lat: prev.lat + alpha * (point.lat - prev.lat),
        lng: prev.lng + alpha * (point.lng - prev.lng),
      }
    : point;

  // 6) write latest to redis
  await redis.set(`trip:${tripId}:live`, JSON.stringify(smoothed), { EX: 60 * 60 });

  // 7) update health
  const quality =
    smoothed.accuracy_m != null && smoothed.accuracy_m > BAD_ACCURACY_M ? "LOW" : "OK";

  await updateHealth(tripId, {
    lastSeenAt: nowIso(),
    quality,
    lastDistanceM: dist,
  });

  // 8) broadcast throttled
  const shouldBroadcast =
    !prev ||
    (dist != null && dist >= MIN_MOVE_METERS_TO_BROADCAST) ||
    quality === "LOW";

  if (shouldBroadcast) {
    await redis.publish(
      `trip:${tripId}`,
      JSON.stringify({
        type: "LOCATION_UPDATE",
        tripId: Number(tripId),
        lat: smoothed.lat,
        lng: smoothed.lng,
        speed: smoothed.speed,
        heading: smoothed.heading,
        accuracy_m: smoothed.accuracy_m,
        timestamp: smoothed.timestamp,
        quality,
      })
    );
  }

  // 9) batch insert history (every 45s)
  await maybeWriteHistory(tripId, smoothed);

  return { accepted: true, quality, broadcast: shouldBroadcast };
}

async function updateHealth(tripId, patch) {
  const key = `trip:${tripId}:health`;
  const prev = await redis.get(key);
  const merged = { ...(prev ? JSON.parse(prev) : {}), ...patch };
  await redis.set(key, JSON.stringify(merged), { EX: 60 * 60 });
}

async function maybeWriteHistory(tripId, point) {
  const key = `trip:${tripId}:history:lastWriteAt`;
  const lastWrite = await redis.get(key);
  const now = Date.now();
  if (lastWrite && now - Number(lastWrite) < HISTORY_WRITE_MIN_SECONDS * 1000) return;

  await pool.query(
    `INSERT INTO trip_location_history(trip_id, lat, lng, speed, heading, accuracy_m, recorded_at)
     VALUES ($1,$2,$3,$4,$5,$6, NOW())`,
    [Number(tripId), point.lat, point.lng, point.speed, point.heading, point.accuracy_m]
  );

  await redis.set(key, String(now), { EX: 60 * 60 });
}
