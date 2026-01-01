import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import authRoutes from "./routes/auth.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import tripRoutes from "./routes/trip.routes.js";
import bookingRoutes from "./routes/booking.routes.js";
import operatorRoutes from "./routes/operator.routes.js";
import operatorBusesRoutes from "./routes/operator_buses.routes.js";
import operatorDriversRoutes from "./routes/operator_drivers.routes.js";
import operatorTripsRoutes from "./routes/operator_trips.routes.js";
import platformAllocationRoutes from "./routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./routes/ticket_validation.routes.js";
import seatSelectionRoutes from "./routes/seat_selection.routes.js";
import paymentRoutes from "./routes/payments.routes.js";
import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";

dotenv.config();

const app = express();

app.use(cors());
app.use(express.json());

// =======================
// API ROUTES
// =======================
app.use("/api/auth", authRoutes);
app.use("/api/admin", adminRoutes);
app.use("/api/trips", tripRoutes);
app.use("/api/bookings", bookingRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);

// =======================
// OPERATOR ROUTES
// =======================
app.use("/operator/buses", operatorBusesRoutes);
app.use("/operator/drivers", operatorDriversRoutes);
app.use("/operator/trips", operatorTripsRoutes);
app.use("/operator/platforms", platformAllocationRoutes);
app.use("/operator/tickets", ticketValidationRoutes);
app.use("/operator", operatorRoutes);

// =======================
// HEALTH CHECKS
// =======================
app.get("/health", (req, res) => {
  res.json({ ok: true });
});

app.get("/", (req, res) => {
  res.send("HBTS Backend is running 🚀");
});

// =======================
// START SERVER
// =======================
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
});

console.log("BOOT: starting expirePendingBookings job");
startExpirePendingBookingsJob();
