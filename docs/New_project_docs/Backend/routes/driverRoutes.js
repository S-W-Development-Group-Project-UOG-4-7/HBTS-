const express = require('express');
const router = express.Router();
const driverController = require('../controllers/driverController');

// Driver routes
router.get('/driver/:driverId/trips', driverController.getDriverTrips);
router.put('/driver/trip/:tripId/start', driverController.startTrip);
router.put('/driver/trip/:tripId/end', driverController.endTrip);
router.get('/driver/trip/:tripId/route', driverController.getRouteStops);
router.get('/driver/trip/:tripId/bookings', driverController.getTripBookings);
router.post('/driver/trip/:tripId/telemetry', driverController.sendTelemetry);

module.exports = router;
