import express from "express";
import cors from "cors";
import { loadEnv } from "./src/utils/env.js";
import path from "path";
import { fileURLToPath } from "url";

import operatorRoutes from "./src/routes/operator.routes.js";
import operatorBusesRoutes from "./src/routes/operator_buses.routes.js";
import operatorDriversRoutes from "./src/routes/operator_drivers.routes.js";
import operatorRoutesRoutes from "./src/routes/operator_routes.routes.js";
import operatorTripsRoutes from "./src/routes/operator_trips.routes.js";
import platformAllocationRoutes from "./src/routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./src/routes/ticket_validation.routes.js";
import paymentRoutes from "./src/routes/payments.routes.js";
import seatSelectionRoutes from "./src/routes/seat_selection.routes.js";

loadEnv();

const app = express();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = path.join(__dirname, "uploads");

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(uploadsDir));

app.get("/", (req, res) => res.json({ ok: true, message: "HBTS backend running" }));

app.use("/operator/buses", operatorBusesRoutes);
app.use("/operator/drivers", operatorDriversRoutes);
app.use("/operator/routes", operatorRoutesRoutes);
app.use("/operator/trips", operatorTripsRoutes);
app.use("/operator", operatorRoutes);
app.use("/operator/platforms", platformAllocationRoutes);
app.use("/operator/tickets", ticketValidationRoutes);
app.use("/api/operator/buses", operatorBusesRoutes);
app.use("/api/operator/drivers", operatorDriversRoutes);
app.use("/api/operator/routes", operatorRoutesRoutes);
app.use("/api/operator/trips", operatorTripsRoutes);
app.use("/api/operator", operatorRoutes);
app.use("/api/operator/platforms", platformAllocationRoutes);
app.use("/api/operator/tickets", ticketValidationRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);

const port = process.env.PORT || 4000;
app.listen(port, () => {
  console.log(`✅ Server running on http://localhost:${port}`);
});
