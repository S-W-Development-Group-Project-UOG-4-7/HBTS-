// src/eta/confidence.util.js
export function getConfidence({ gpsAgeSec, speedKmh, tripStarted }) {
  if (!tripStarted) return "LOW";
  if (gpsAgeSec < 5 && speedKmh > 10) return "HIGH";
  if (gpsAgeSec < 15) return "MEDIUM";
  return "LOW";
}
