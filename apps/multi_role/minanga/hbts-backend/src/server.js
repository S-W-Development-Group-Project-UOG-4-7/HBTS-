// src/server.js
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";
import { pool } from "./db.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ✅ Load .env from project root (hbts-backend/.env)
dotenv.config({ path: path.join(__dirname, "../.env") });

import http from "http";
import { WebSocketServer } from "ws";

import express from "express";
import cors from "cors";

import authRoutes from "./routes/auth.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import tripRoutes from "./routes/trip.routes.js";
import bookingRoutes from "./routes/booking.routes.js";
import notificationRoutes from "./routes/notification.routes.js";
import conductorRoutes from "./routes/conductor.routes.js";
import routeRoutes from "./routes/route.routes.js";

import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";
import reportRoutes from "./routes/report.routes.js";

// ✅ WS handlers
import { initNotificationWS } from "./ws/notification.ws.js";
import { initRealtimeWS } from "./ws/realtime.ws.js";
// OPTIONAL: only if you actually use /ws/tracking
import { initTrackingWS } from "./ws/tracking.ws.js";

const app = express();

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

// ✅ Routes
app.use("/api/auth", authRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/admin/reports", reportRoutes);
app.use("/api/trips", tripRoutes);
app.use("/api/bookings", bookingRoutes);
app.use("/api/notifications", notificationRoutes);
app.use("/api/conductor", conductorRoutes);
app.use("/api/routes", routeRoutes);

app.get("/health", (req, res) => res.json({ ok: true }));
app.get("/", (req, res) => res.send("HBTS Backend is running 🚀"));

const PORT = process.env.PORT || 4000;

// ✅ Create HTTP server
const server = http.createServer(app);

// ✅ WS servers (manual upgrade routing - reliable for multiple WS paths)
export const notificationsWss = new WebSocketServer({ noServer: true });
export const realtimeWss = new WebSocketServer({ noServer: true });
export const trackingWss = new WebSocketServer({ noServer: true }); // optional but safe to keep

// ✅ Attach handlers
initNotificationWS(notificationsWss);
initRealtimeWS(realtimeWss);
initTrackingWS(trackingWss); // if tracking.ws.js exists; otherwise remove this line + import

// ✅ Route WS upgrades by path
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
  } catch (e) {
    socket.destroy();
  }
});

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

console.log("BOOT: starting expirePendingBookings job");
startExpirePendingBookingsJob();
