const pool = require('../config/db');

// Get driver's assigned trips
exports.getDriverTrips = async (req, res) => {
  try {
    const { driverId } = req.params;

    const query = `
      SELECT
        t.trip_id,
        t.route_id,
        t.driver_id,
        t.bus_id,
        t.trip_date,
        t.departure_time,
        t.arrival_time,
        t.status,
        r.route_name,
        r.from_location,
        r.to_location,
        r.distance_km
      FROM trips t
      JOIN routes r ON t.route_id = r.route_id
      WHERE t.driver_id = $1
      ORDER BY t.trip_date DESC, t.departure_time DESC
    `;

    const result = await pool.query(query, [driverId]);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching driver trips:', error);
    res.status(500).json({ error: 'Failed to fetch trips' });
  }
};

// Start a trip
exports.startTrip = async (req, res) => {
  try {
    const { tripId } = req.params;

    const query = `
      UPDATE trips
      SET status = 'running', updated_at = CURRENT_TIMESTAMP
      WHERE trip_id = $1 AND status = 'scheduled'
      RETURNING *
    `;

    const result = await pool.query(query, [tripId]);

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Trip not found or already started' });
    }

    res.json({
      message: 'Trip started successfully',
      trip: result.rows[0]
    });
  } catch (error) {
    console.error('Error starting trip:', error);
    res.status(500).json({ error: 'Failed to start trip' });
  }
};

// End a trip
exports.endTrip = async (req, res) => {
  try {
    const { tripId } = req.params;

    const query = `
      UPDATE trips
      SET status = 'completed', updated_at = CURRENT_TIMESTAMP
      WHERE trip_id = $1 AND status = 'running'
      RETURNING *
    `;

    const result = await pool.query(query, [tripId]);

    if (result.rows.length === 0) {
      return res.status(400).json({ error: 'Trip not found or not running' });
    }

    res.json({
      message: 'Trip completed successfully',
      trip: result.rows[0]
    });
  } catch (error) {
    console.error('Error ending trip:', error);
    res.status(500).json({ error: 'Failed to end trip' });
  }
};

// Get route stops for a trip
exports.getRouteStops = async (req, res) => {
  try {
    const { tripId } = req.params;

    const query = `
      SELECT
        s.stop_id,
        s.stop_name,
        s.lat,
        s.lon,
        ts.stop_order as sequence,
        ts.scheduled_time as arrival_time,
        ts.scheduled_time as departure_time
      FROM trip_stops ts
      JOIN stops s ON ts.stop_id = s.stop_id
      WHERE ts.trip_id = $1
      ORDER BY ts.stop_order ASC
    `;

    const result = await pool.query(query, [tripId]);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching route stops:', error);
    res.status(500).json({ error: 'Failed to fetch route stops' });
  }
};

// Get trip bookings
exports.getTripBookings = async (req, res) => {
  try {
    const { tripId } = req.params;

    const query = `
      SELECT
        b.booking_id,
        b.user_id,
        b.trip_id,
        b.seat_id,
        b.price,
        b.status,
        u.name as passenger_name,
        u.phone as passenger_phone,
        s.seat_label as seat_number,
        boarding.stop_name as boarding_stop,
        dropping.stop_name as dropping_stop
      FROM bookings b
      JOIN users u ON b.user_id = u.user_id
      JOIN seats s ON b.seat_id = s.seat_id
      JOIN stops boarding ON b.boarding_stop_id = boarding.stop_id
      JOIN stops dropping ON b.dropping_stop_id = dropping.stop_id
      WHERE b.trip_id = $1 AND b.status IN ('pending', 'confirmed')
      ORDER BY s.seat_label ASC
    `;

    const result = await pool.query(query, [tripId]);
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching bookings:', error);
    res.status(500).json({ error: 'Failed to fetch bookings' });
  }
};

// Send telemetry data
exports.sendTelemetry = async (req, res) => {
  try {
    const { tripId } = req.params;
    const { bus_id, lat, lon, speed, heading } = req.body;

    const query = `
      INSERT INTO telemetry (bus_id, trip_id, lat, lon, speed, heading, recorded_at)
      VALUES ($1, $2, $3, $4, $5, $6, CURRENT_TIMESTAMP)
      RETURNING *
    `;

    const result = await pool.query(query, [
      bus_id,
      tripId,
      lat,
      lon,
      speed || null,
      heading || null
    ]);

    res.status(201).json({
      message: 'Telemetry sent successfully',
      telemetry: result.rows[0]
    });
  } catch (error) {
    console.error('Error sending telemetry:', error);
    res.status(500).json({ error: 'Failed to send telemetry' });
  }
};
