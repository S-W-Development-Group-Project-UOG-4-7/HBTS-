// src/utils/polylineProgress.js
// Decodes Google encoded polyline and gives a "progress index" for a point.

function decodePolyline(encoded) {
  let index = 0, lat = 0, lng = 0;
  const coordinates = [];

  if (!encoded || typeof encoded !== "string" || encoded.trim() === "") return coordinates;

  while (index < encoded.length) {
    let b, shift = 0, result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlat = (result & 1) ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.charCodeAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    const dlng = (result & 1) ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    coordinates.push([lat * 1e-5, lng * 1e-5]);
  }

  return coordinates;
}

function dist2(aLat, aLon, bLat, bLon) {
  const dx = aLat - bLat;
  const dy = aLon - bLon;
  return dx * dx + dy * dy;
}

function nearestIndex(points, lat, lon) {
  let bestI = 0;
  let bestD = Infinity;
  for (let i = 0; i < points.length; i++) {
    const [pLat, pLon] = points[i];
    const d = dist2(pLat, pLon, lat, lon);
    if (d < bestD) {
      bestD = d;
      bestI = i;
    }
  }
  return bestI;
}

export function buildProgressIndexForTrip(polylineStr) {
  const pts = decodePolyline(polylineStr);
  if (!pts.length) return null;

  return {
    points: pts,
    progressIndex(lat, lon) {
      return nearestIndex(pts, lat, lon);
    },
  };
}
