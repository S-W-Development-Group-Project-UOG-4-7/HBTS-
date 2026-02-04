// src/server.js
import path from "path";
import { fileURLToPath } from "url";
<<<<<<< HEAD
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const uploadsDir = path.join(__dirname, "..", "uploads");

// âœ… Load .env from project root (hbts-backend/.env)
dotenv.config({ path: path.join(__dirname, "../.env") });

=======
>>>>>>> origin/develop
import http from "http";

import cors from "cors";
import express from "express";
import { WebSocketServer } from "ws";

import { loadEnv } from "./utils/env.js";

<<<<<<< HEAD
import authRoutes from "./routes/auth.routes.js";
=======
>>>>>>> origin/develop
import adminRoutes from "./routes/admin.routes.js";
import authRoutes from "./routes/auth.routes.js";
import bookingRoutes from "./routes/booking.routes.js";
<<<<<<< HEAD
=======
import conductorRoutes from "./routes/conductor.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import paymentRoutes from "./routes/payments.routes.js";
import reportRoutes from "./routes/report.routes.js";
import routeRoutes from "./routes/route.routes.js";
import seatSelectionRoutes from "./routes/seat_selection.routes.js";
import tripRoutes from "./routes/trip.routes.js";

>>>>>>> origin/develop
import operatorRoutes from "./routes/operator.routes.js";
import operatorBusesRoutes from "./routes/operator_buses.routes.js";
import operatorDriversRoutes from "./routes/operator_drivers.routes.js";
import operatorConductorsRoutes from "./routes/operator_conductors.routes.js";
import operatorRoutesRoutes from "./routes/operator_routes.routes.js";
import operatorTripsRoutes from "./routes/operator_trips.routes.js";
import platformAllocationRoutes from "./routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./routes/ticket_validation.routes.js";
<<<<<<< HEAD
import seatSelectionRoutes from "./routes/seat_selection.routes.js";
import paymentRoutes from "./routes/payments.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import conductorRoutes from "./routes/conductor.routes.js";
import routeRoutes from "./routes/route.routes.js";

import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";
import { initNotificationWS } from "./ws/notification.ws.js";
import { initRealtimeWS } from "./ws/realtime.ws.js";
import { initTrackingWS } from "./ws/tracking.ws.js";
import { initDatabase } from "./db/init.js";

const app = express();
=======

import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";

import { initNotificationWS } from "./ws/notification.ws.js";
import { initRealtimeWS } from "./ws/realtime.ws.js";
import { initTrackingWS } from "./ws/tracking.ws.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

loadEnv();

const app = express();
const uploadsDir = path.join(__dirname, "..", "uploads");
>>>>>>> origin/develop

app.use(
  cors({
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

app.options("*", cors());
app.use(express.json());
app.use("/uploads", express.static(uploadsDir));

<<<<<<< HEAD
// âœ… Routes
=======
// Routes
>>>>>>> origin/develop
app.use("/api/auth", authRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/admin/reports", reportRoutes);
app.use("/api/trips", tripRoutes);
app.use("/api/bookings", bookingRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/conductor", conductorRoutes);
app.use("/api/routes", routeRoutes);

<<<<<<< HEAD
// =======================
// OPERATOR ROUTES
// =======================
=======
// Operator routes (consistent /api prefix)
>>>>>>> origin/develop
app.use("/api/operator/buses", operatorBusesRoutes);
app.use("/api/operator/drivers", operatorDriversRoutes);
app.use("/api/operator/conductors", operatorConductorsRoutes);
app.use("/api/operator/routes", operatorRoutesRoutes);
app.use("/api/operator/trips", operatorTripsRoutes);
app.use("/api/operator/platforms", platformAllocationRoutes);
app.use("/api/operator/tickets", ticketValidationRoutes);
app.use("/api/operator", operatorRoutes);

<<<<<<< HEAD
app.use("/api/notifications", notificationRoutes);
app.use("/api/conductor", conductorRoutes);
app.use("/api/routes", routeRoutes);

// =======================
// HEALTH CHECKS
// =======================
app.get("/health", (req, res) => res.json({ ok: true }));
app.get("/", (req, res) => res.send("HBTS Backend is running ðŸš€"));

const PORT = process.env.PORT || 4000;

try {
  await initDatabase();
} catch (e) {
  console.error("DB init failed:", e);
  process.exit(1);
}

// âœ… Create HTTP server
const server = http.createServer(app);

// âœ… WS servers (manual upgrade routing - reliable for multiple WS paths)
=======
// Health checks
app.get("/health", (req, res) => res.json({ ok: true }));
app.get("/", (req, res) => res.send("HBTS Backend is running"));

const PORT = process.env.PORT || 4000;

// Create HTTP server
const server = http.createServer(app);

// WS servers (manual upgrade routing for multiple paths)
>>>>>>> origin/develop
export const notificationsWss = new WebSocketServer({ noServer: true });
export const realtimeWss = new WebSocketServer({ noServer: true });
export const trackingWss = new WebSocketServer({ noServer: true });

<<<<<<< HEAD
// âœ… Attach handlers
=======
// Attach handlers
>>>>>>> origin/develop
initNotificationWS(notificationsWss);
initRealtimeWS(realtimeWss);
initTrackingWS(trackingWss);

<<<<<<< HEAD
// âœ… Route WS upgrades by path
=======
// Route WS upgrades by path
>>>>>>> origin/develop
server.on("upgrade", (req, socket, head) => {
  try {
    const { pathname } = new URL(req.url, `http://${req.headers.host}`);

    if (pathname === "/ws/notifications") {
      notificationsWss.handleUpgrade(req, socket, head, (ws) => {
        notificationsWss.emit("connection", ws, req);
      });
      return;
    }

    if (pathname === "/ws/realtime") {
      realtimeWss.handleUpgrade(req, socket, head, (ws) => {
        realtimeWss.emit("connection", ws, req);
      });
      return;
    }

    if (pathname === "/ws/tracking") {
      trackingWss.handleUpgrade(req, socket, head, (ws) => {
        trackingWss.emit("connection", ws, req);
      });
      return;
    }

    // Unknown WS path
    socket.destroy();
  } catch {
    socket.destroy();
  }
});

server.listen(PORT, () => {
<<<<<<< HEAD
  console.log(`ðŸš€ Server running on port ${PORT}`);
=======
  console.log(`Server running on port ${PORT}`);
>>>>>>> origin/develop
});

console.log("BOOT: starting expirePendingBookings job");
startExpirePendingBookingsJob();
