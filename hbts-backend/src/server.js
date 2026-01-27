<<<<<<< HEAD
import express from "express";
import cors from "cors";
import { loadEnv } from "./utils/env.js";
import path from "path";
import { fileURLToPath } from "url";

=======
// src/server.js
import path from "path";
import { fileURLToPath } from "url";
import dotenv from "dotenv";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// ✅ Load .env from project root (hbts-backend/.env)
dotenv.config({ path: path.join(__dirname, "../.env") });

import http from "http";
import { WebSocketServer } from "ws";

import express from "express";
import cors from "cors";

>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e
import authRoutes from "./routes/auth.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import tripRoutes from "./routes/trip.routes.js";
import bookingRoutes from "./routes/booking.routes.js";
import operatorRoutes from "./routes/operator.routes.js";
import operatorBusesRoutes from "./routes/operator_buses.routes.js";
import operatorDriversRoutes from "./routes/operator_drivers.routes.js";
import operatorRoutesRoutes from "./routes/operator_routes.routes.js";
import operatorTripsRoutes from "./routes/operator_trips.routes.js";
import platformAllocationRoutes from "./routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./routes/ticket_validation.routes.js";
import seatSelectionRoutes from "./routes/seat_selection.routes.js";
import paymentRoutes from "./routes/payments.routes.js";
import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";
import notificationRoutes from "./routes/notification.routes.js";

<<<<<<< HEAD
loadEnv();

const app = express();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = path.join(__dirname, "..", "uploads");

app.use(cors());
=======
import { initNotificationWS } from "./ws/notification.ws.js";
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
>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e
app.use(express.json());
app.use("/uploads", express.static(uploadsDir));

<<<<<<< HEAD
// =======================
// API ROUTES
// =======================
=======
// ✅ Routes
>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e
app.use("/api/auth", authRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/trips", tripRoutes);
app.use("/api/bookings", bookingRoutes);
<<<<<<< HEAD
app.use("/api/payments", paymentRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);

// =======================
// OPERATOR ROUTES (✅ make consistent)
// =======================
app.use("/api/operator/buses", operatorBusesRoutes);
app.use("/api/operator/drivers", operatorDriversRoutes);
app.use("/api/operator/routes", operatorRoutesRoutes);
app.use("/api/operator/trips", operatorTripsRoutes);
app.use("/api/operator/platforms", platformAllocationRoutes);
app.use("/api/operator/tickets", ticketValidationRoutes);
app.use("/api/operator", operatorRoutes);

// =======================
// HEALTH CHECKS
// =======================
app.get("/health", (req, res) => res.json({ ok: true }));
app.get("/", (req, res) => res.send("HBTS Backend is running 🚀"));
=======
app.use("/api/notifications", notificationRoutes);

app.get("/health", (req, res) => res.json({ ok: true }));
app.get("/", (req, res) => res.send("HBTS Backend is running 🚀"));

const PORT = process.env.PORT || 4000;

// ✅ Create HTTP server
const server = http.createServer(app);

// ✅ WS servers (manual upgrade routing - reliable for multiple WS paths)
export const notificationWss = new WebSocketServer({ noServer: true });
export const trackingWss = new WebSocketServer({ noServer: true });

// ✅ Attach handlers
initNotificationWS(notificationWss);
initTrackingWS(trackingWss);

// ✅ Route WS upgrades by path
server.on("upgrade", (req, socket, head) => {
  try {
    const url = new URL(req.url, "http://localhost");
    const pathname = url.pathname;

    if (pathname === "/ws/notifications") {
      notificationWss.handleUpgrade(req, socket, head, (ws) => {
        notificationWss.emit("connection", ws, req);
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
>>>>>>> 07412e1203042fbfa2a74db4f898a950bbd6509e

server.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

console.log("BOOT: starting expirePendingBookings job");
startExpirePendingBookingsJob();
