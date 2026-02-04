// src/ws/trip.socket.js
import WebSocket, { WebSocketServer } from "ws";
import jwt from "jsonwebtoken";
import { redis } from "../infra/redis.js";

// Constants
const ETA_THROTTLE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const MIN_ETA_UPDATE_INTERVAL_MS = 3000; // 3 seconds
const ETA_REDIS_TTL_SECONDS = 60; // 1 minute

function parseUrl(reqUrl) {
  const u = new URL(reqUrl, "http://localhost"); // base required
  return u;
}

// throttle map for ETA emits with automatic cleanup
const _etaThrottle = new Map(); // key -> { etaTs, confidence, sentAtMs }

// Clean up old throttle entries to prevent memory leaks
function cleanupOldThrottleEntries() {
  const now = Date.now();
  for (const [key, entry] of _etaThrottle.entries()) {
    if (now - entry.sentAtMs > ETA_THROTTLE_TTL_MS) {
      _etaThrottle.delete(key);
    }
  }
}

// Schedule cleanup to run periodically
setInterval(cleanupOldThrottleEntries, ETA_THROTTLE_TTL_MS).unref();

/**
 * Emit ETA update to all listeners of this trip via Redis pubsub.
 * Your WS server already subscribes to "trip:*" and broadcasts to connected clients.
 * @param {Object} params - The parameters object
 * @param {string|number} params.tripId - The trip ID
 * @param {string|number} params.passengerStopId - The passenger stop ID
 * @param {Object} params.driver - The driver's location
 * @param {number} params.driver.lat - Driver's latitude
 * @param {number} params.driver.lng - Driver's longitude
 * @param {Object} [params.eta] - ETA information
 * @param {number} [params.eta.etaTimestamp] - ETA timestamp in seconds
 * @param {number} [params.eta.etaSeconds] - ETA in seconds
 * @param {string} [params.eta.confidence] - Confidence level (e.g., 'HIGH', 'MEDIUM', 'LOW')
 * @param {number} [params.eta.distanceMeters] - Distance in meters
 * @returns {Promise<void>}
 * @throws {Error} If required parameters are missing or invalid
 */
export async function emitEtaUpdate({ tripId, passengerStopId, driver, eta = {} }) {
  // Input validation
  if (tripId === undefined || tripId === null) throw new Error('tripId is required');
  if (passengerStopId === undefined || passengerStopId === null) throw new Error('passengerStopId is required');
  if (!driver || typeof driver.lat !== 'number' || typeof driver.lng !== 'number') {
    throw new Error('Valid driver location with lat/lng is required');
  }

  const key = `${tripId}:${passengerStopId}`;
  const nowMs = Date.now();

  // Check rate limiting
  const prev = _etaThrottle.get(key);
  if (prev && nowMs - prev.sentAtMs < MIN_ETA_UPDATE_INTERVAL_MS) {
    return; // Too soon to send another update
  }

  // Check if ETA or confidence has changed significantly
  const etaChanged = !prev ||
    (eta?.etaTimestamp != null &&
      prev?.etaTs != null &&
      Math.abs(eta.etaTimestamp - prev.etaTs) >= 30) ||
    (!prev?.etaTs && eta?.etaTimestamp != null);

  const confidenceChanged = !prev || prev.confidence !== eta?.confidence;

  // Skip if no significant changes
  if (!etaChanged && !confidenceChanged) return;

  // Update throttle tracking
  _etaThrottle.set(key, {
    etaTs: eta?.etaTimestamp ?? null,
    confidence: eta?.confidence ?? null,
    sentAtMs: nowMs,
  });

  // Prepare payload
  const payload = {
    type: "ETA_UPDATE",
    tripId: Number(tripId),
    passengerStopId: Number(passengerStopId),
    eta: eta?.etaTimestamp != null
      ? new Date(eta.etaTimestamp * 1000).toISOString()
      : null,
    etaSeconds: eta?.etaSeconds ?? null,
    confidence: eta?.confidence ?? "LOW",
    distanceMeters: eta?.distanceMeters ?? null,
    driver: { lat: driver.lat, lng: driver.lng },
    ts: new Date().toISOString(),
  };

  try {
    // Publish to Redis pub/sub
    await redis.publish(`trip:${tripId}`, JSON.stringify(payload));

    // Store latest ETA snapshot for new joiners
    await redis.set(
      `trip:${tripId}:eta`,
      JSON.stringify(payload),
      { EX: ETA_REDIS_TTL_SECONDS }
    );
  } catch (error) {
    console.error('Error publishing ETA update:', error);
    throw new Error(`Failed to publish ETA update: ${error.message}`);
  }
}

export function attachTripSocket(httpServer) {
  const wss = new WebSocketServer({ server: httpServer, path: "/ws" });

  // Trip rooms: tripId -> Set<ws>
  const rooms = new Map();

  function joinRoom(tripId, ws) {
    if (!rooms.has(tripId)) rooms.set(tripId, new Set());
    rooms.get(tripId).add(ws);
  }

  function leaveAll(ws) {
    for (const set of rooms.values()) set.delete(ws);
  }

  async function broadcastToTrip(tripId, payload) {
    const set = rooms.get(String(tripId));
    if (!set) return;

    const msg = JSON.stringify(payload);
    for (const client of set) {
      if (client.readyState === WebSocket.OPEN) client.send(msg);
    }
  }

  // Redis pubsub -> websocket fanout
  const sub = redis.duplicate();
  sub.connect().then(async () => {
    try {
      await sub.pSubscribe("trip:*", async (message, channel) => {
        // channel: trip:{tripId}
        const tripId = channel.split(":")[1];
        if (!tripId) {
          console.warn('Received message on invalid channel:', channel);
          return;
        }
        
        try {
          const payload = JSON.parse(message);
          await broadcastToTrip(tripId, payload);
        } catch (parseError) {
          console.error('Error parsing message:', parseError, 'Message:', message);
        }
      });
      console.log("✅ WS Redis pubsub subscribed");
    } catch (error) {
      console.error('Failed to subscribe to Redis pubsub:', error);
      // Attempt to reconnect after a delay
      setTimeout(() => {
        console.log('Attempting to reconnect to Redis pubsub...');
        sub.connect().catch(console.error);
      }, 5000);
    }
  }).catch(error => {
    console.error('Failed to connect to Redis for pubsub:', error);
  });

  wss.on("connection", async (ws, req) => {
    try {
      const url = parseUrl(req.url);
      const token = url.searchParams.get("token");
      const tripId = url.searchParams.get("tripId");

      if (!token || !tripId) {
        ws.close(1008, "Missing token/tripId");
        return;
      }

      jwt.verify(token, process.env.WS_SECRET);

      joinRoom(String(tripId), ws);

      // send initial snapshot (latest data from Redis)
      const live = await redis.get(`trip:${tripId}:live`);
      const eta = await redis.get(`trip:${tripId}:eta`);
      const health = await redis.get(`trip:${tripId}:health`);

      ws.send(
        JSON.stringify({
          type: "SNAPSHOT",
          live: live ? JSON.parse(live) : null,
          eta: eta ? JSON.parse(eta) : null,
          health: health ? JSON.parse(health) : null,
        })
      );

      ws.on("close", () => leaveAll(ws));
    } catch (e) {
      ws.close(1008, "Unauthorized");
    }
  });

  return { wss };
}
