// src/server.js
import path from "path";
import { fileURLToPath } from "url";
import http from "http";

import cors from "cors";
import express from "express";
import { WebSocketServer } from "ws";

import { loadEnv } from "./utils/env.js";

import adminRoutes from "./routes/admin.routes.js";
import authRoutes from "./routes/auth.routes.js";
import bookingRoutes from "./routes/booking.routes.js";
import conductorRoutes from "./routes/conductor.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import paymentRoutes from "./routes/payments.routes.js";
import reportRoutes from "./routes/report.routes.js";
import routeRoutes from "./routes/route.routes.js";
import seatSelectionRoutes from "./routes/seat_selection.routes.js";
import tripRoutes from "./routes/trip.routes.js";

import operatorRoutes from "./routes/operator.routes.js";
import operatorBusesRoutes from "./routes/operator_buses.routes.js";
import operatorDriversRoutes from "./routes/operator_drivers.routes.js";
import operatorRoutesRoutes from "./routes/operator_routes.routes.js";
import operatorTripsRoutes from "./routes/operator_trips.routes.js";
import platformAllocationRoutes from "./routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./routes/ticket_validation.routes.js";

import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";

import { initNotificationWS } from "./ws/notification.ws.js";
import { initRealtimeWS } from "./ws/realtime.ws.js";
import { initTrackingWS } from "./ws/tracking.ws.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

loadEnv();

const app = express();
const uploadsDir = path.join(__dirname, "..", "uploads");

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

// Routes
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

// Operator routes (consistent /api prefix)
app.use("/api/operator/buses", operatorBusesRoutes);
app.use("/api/operator/drivers", operatorDriversRoutes);
app.use("/api/operator/routes", operatorRoutesRoutes);
app.use("/api/operator/trips", operatorTripsRoutes);
app.use("/api/operator/platforms", platformAllocationRoutes);
app.use("/api/operator/tickets", ticketValidationRoutes);
app.use("/api/operator", operatorRoutes);

// Health checks
app.get("/health", (req, res) => res.json({ ok: true }));
app.get("/", (req, res) => res.send("HBTS Backend is running"));

const PORT = process.env.PORT || 4000;

// Create HTTP server
const server = http.createServer(app);

// WS servers (manual upgrade routing for multiple paths)
export const notificationsWss = new WebSocketServer({ noServer: true });
export const realtimeWss = new WebSocketServer({ noServer: true });
export const trackingWss = new WebSocketServer({ noServer: true });

// Attach handlers
initNotificationWS(notificationsWss);
initRealtimeWS(realtimeWss);
initTrackingWS(trackingWss);

// Route WS upgrades by path
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
  console.log(`Server running on port ${PORT}`);
});

console.log("BOOT: starting expirePendingBookings job");
startExpirePendingBookingsJob();
