// src/eta/eta.engine.js
import { haversineMeters } from "./distance.util.js";
import { getConfidence } from "./confidence.util.js";

export function calculateETA({
  driver, // { lat,lng,speedKmh,accuracyM,ts }
  stop,   // { stopId, lat,lng }
  nowTs,  // unix seconds
  tripStarted,
  fallbackSpeedKmh = 25, // route average fallback
}) {
  const distanceM = haversineMeters(
    { lat: driver.lat, lng: driver.lng },
    { lat: stop.lat, lng: stop.lng }
  );

  const gpsAgeSec = Math.max(0, nowTs - driver.ts);

  // speed rules
  const speedKmh =
    driver.speedKmh && driver.speedKmh >= 5 ? driver.speedKmh : fallbackSpeedKmh;

  const speedMs = (speedKmh * 1000) / 3600;
  const etaSeconds = speedMs > 0 ? Math.round(distanceM / speedMs) : null;

  const confidence = getConfidence({ gpsAgeSec, speedKmh: speedKmh, tripStarted });

  return {
    distanceMeters: Math.round(distanceM),
    etaSeconds,
    etaTimestamp: etaSeconds != null ? nowTs + etaSeconds : null,
    confidence,
    gpsAgeSec,
    speedKmh,
  };
}
