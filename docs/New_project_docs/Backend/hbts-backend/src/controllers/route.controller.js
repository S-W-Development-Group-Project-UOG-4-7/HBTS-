import { pool } from "../db.js";

export async function generateRoutePolyline(req, res) {
  try {
    const routeId = Number(req.params.routeId);
    if (!routeId) return res.status(400).json({ message: "Invalid routeId" });

    // Load route data (needs from/to)
    const r = await pool.query(
      `SELECT route_id, from_location, to_location FROM routes WHERE route_id = $1`,
      [routeId]
    );
    if (r.rowCount === 0) return res.status(404).json({ message: "Route not found" });

    const { from_location, to_location } = r.rows[0];
    const key = process.env.GOOGLE_MAPS_API_KEY;
    if (!key) return res.status(500).json({ message: "Missing GOOGLE_MAPS_API_KEY in .env" });

    // Call Directions API (no extra library needed; Node 18+ has fetch)
    const url = new URL("https://maps.googleapis.com/maps/api/directions/json");
    url.searchParams.set("origin", String(from_location));
    url.searchParams.set("destination", String(to_location));
    url.searchParams.set("key", key);

    const resp = await fetch(url.toString());
    const data = await resp.json();

    if (data.status !== "OK" || !data.routes?.length) {
      return res.status(400).json({
        message: "Directions API failed",
        status: data.status,
        error_message: data.error_message,
      });
    }

    const encoded = data.routes[0]?.overview_polyline?.points;
    if (!encoded) return res.status(400).json({ message: "No polyline returned" });

    await pool.query(`UPDATE routes SET polyline = $1 WHERE route_id = $2`, [encoded, routeId]);

    return res.json({ ok: true, routeId, polylineLength: encoded.length });
  } catch (err) {
    console.error("generateRoutePolyline error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}
