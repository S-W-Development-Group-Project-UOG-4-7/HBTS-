// src/driverTracking/location.store.js

const lastDriverLocationByTrip = new Map();
// tripId -> { lat, lng, speedKmh, accuracyM, ts }

export function setLastDriverLocation(tripId, location) {
  lastDriverLocationByTrip.set(String(tripId), location);
}

export function getLastDriverLocation(tripId) {
  return lastDriverLocationByTrip.get(String(tripId)) || null;
}
