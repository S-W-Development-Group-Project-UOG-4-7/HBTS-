import jwt from "jsonwebtoken";
import { pool }from "../db.js";

// busKey = `${operator_id}:${bus_id}`
const busRooms = new Map(); 

function addToRoom(busKey, ws) {
  if (!busRooms.has(busKey)) busRooms.set(busKey, new Set());
  busRooms.get(busKey).add(ws);
}

function removeFromAllRooms(ws) {
  for (const set of busRooms.values()) set.delete(ws);
}

async function getConductorBusKey(userId) {
  const { rows } = await pool.query(
    `
    SELECT operator_id, bus_id
    FROM conductors
    WHERE user_id = $1 AND is_active = true
    LIMIT 1
    `,
    [userId]
  );
  if (!rows.length) return null;
  return `${rows[0].operator_id}:${rows[0].bus_id}`;
}

export function initRealtimeWS(wss) {
  wss.on("connection", async (ws, req) => {
    try {
      // token can be sent as ?token=... or Authorization header
      const url = new URL(req.url, "http://localhost");
      const tokenFromQuery = url.searchParams.get("token");

      const authHeader = req.headers["authorization"];
      const tokenFromHeader =
        authHeader && authHeader.startsWith("Bearer ") ? authHeader.split(" ")[1] : null;

      const token = tokenFromQuery || tokenFromHeader;
      if (!token) {
        ws.close(4001, "Missing token");
        return;
      }

      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
      const userId = decoded.userId ?? decoded.user_id ?? decoded.id;
      const role = decoded.role;

      ws.userId = userId;
      ws.role = role;

    
      if (role === "conductor") {
        const busKey = await getConductorBusKey(userId);
        if (!busKey) {
          ws.close(4003, "Conductor not assigned");
          return;
        }
        ws.busKey = busKey;
        addToRoom(busKey, ws);

        ws.send(JSON.stringify({ type: "CONNECTED", busKey }));
      } else {
        // other roles can connect but won't receive bus events (optional)
        ws.send(JSON.stringify({ type: "CONNECTED" }));
      }

      ws.on("close", () => {
        removeFromAllRooms(ws);
      });

      ws.on("error", () => {
        removeFromAllRooms(ws);
      });
    } catch (e) {
      ws.close(4002, "Invalid token");
    }
  });
}

// Broadcast helper
export function emitTripStarted({ operatorId, busId, tripId }) {
  const busKey = `${operatorId}:${busId}`;
  const set = busRooms.get(busKey);
  if (!set) return;

  const payload = JSON.stringify({
    type: "TRIP_STARTED",
    operatorId,
    busId,
    tripId,
  });

  for (const ws of set) {
    try {
      ws.send(payload);
    } catch {}
  }
}

export function emitTripEnded({ operatorId, busId, tripId }) {
  const busKey = `${operatorId}:${busId}`;
  const set = busRooms.get(busKey);
  if (!set) return;

  const payload = JSON.stringify({
    type: "TRIP_ENDED",
    operatorId,
    busId,
    tripId,
  });

  for (const ws of set) {
    try { ws.send(payload); } catch {}
  }
}

export function emitTripCancelled({ operatorId, busId, tripId }) {
  const busKey = `${operatorId}:${busId}`;
  const set = busRooms.get(busKey);
  if (!set) return;

  const payload = JSON.stringify({
    type: "TRIP_CANCELLED",
    operatorId,
    busId,
    tripId,
  });

  for (const ws of set) {
    try { ws.send(payload); } catch {}
  }
}

