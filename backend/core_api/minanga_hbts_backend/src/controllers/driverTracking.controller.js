// src/controllers/driverTracking.controller.js

import { z } from "zod";
import { pool } from "../db.js";
import { ingestLocationPoint } from "../services/liveLocation.service.js";
import { setLastDriverLocation } from "../driverTracking/location.store.js";
import { calculateETA } from "../eta/eta.engine.js";
import { emitEtaUpdate } from "../ws/trip.socket.js";

const BodySchema = z.object({
  lat: z.number(),
  lng: z.number(),
  speed: z.number().optional(), // km/h (as you’re sending)
  heading: z.number().optional(),
  accuracy_m: z.number().optional(),
  timestamp: z.string().optional(), // ISO from device
  seq: z.number().int().optional(),
});

/**
 * Fetches all unique boarding stops for a trip
 * @param {number} tripId - The trip ID to get boarding stops for
 * @returns {Promise<Array<{stopId: number, lat: number, lng: number}>>} Array of stop objects
 */
async function getBoardingStopsForTrip(tripId) {
  const q = await pool.query(
    `
    SELECT DISTINCT
      s.stop_id,
      s.lat,
      s.lon
    FROM bookings b
    JOIN stops s ON s.stop_id = b.boarding_stop_id
    WHERE b.trip_id = $1
    `,
    [tripId]
  );

  return q.rows.map((r) => ({
    stopId: Number(r.stop_id),
    lat: Number(r.lat),
    lng: Number(r.lon),
  }));
}

export async function pushDriverLocation(req, res) {
  try {
    const tripId = Number(req.params.tripId);
    const body = BodySchema.parse(req.body);

    // 1) Ingest + validate + persist (your existing flow)
    const result = await ingestLocationPoint({
      tripId,
      driverUserId: req.user.userId ?? req.user.id, // depends on your token payload
      ...body,
    });

    // 2) Store last driver location (MVP memory store)
    const nowTs = Math.floor(Date.now() / 1000);

    const driverLocation = {
      lat: body.lat,
      lng: body.lng,
      speedKmh: body.speed ?? 0,
      accuracyM: body.accuracy_m ?? null,
      ts: nowTs,
    };

    setLastDriverLocation(tripId, driverLocation);

    // 3) Compute + emit ETA (DON'T fail the request if ETA logic fails)
    try {
      const stops = await getBoardingStopsForTrip(tripId);
      if (stops.length === 0) return res.json({ ok: true, result });

      await Promise.all(
        stops.map(async (stop) => {
          const eta = calculateETA({
            driver: driverLocation,
            stop,
            nowTs,
            tripStarted: true,
            fallbackSpeedKmh: 25,
          });

          await emitEtaUpdate({
            tripId,
            passengerStopId: stop.stopId,
            driver: driverLocation,
            eta,
          });
        })
      );
    } catch (etaErr) {
      // keep endpoint stable even if ETA fails
      console.warn("[ETA] compute/emit failed:", etaErr?.message ?? etaErr);
    }

    return res.json({ ok: true, result });
  } catch (e) {
    return res.status(400).json({ ok: false, message: e.message });
  }
}
