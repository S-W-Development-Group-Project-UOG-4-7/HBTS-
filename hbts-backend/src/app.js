import express from "express";
import cors from "cors";
import { loadEnv } from "./utils/env.js";
import path from "path";
import { fileURLToPath } from "url";
import operatorRoutes from "./routes/operator.routes.js";
import operatorBusesRoutes from "./routes/operator_buses.routes.js";
import operatorDriversRoutes from "./routes/operator_drivers.routes.js";
import operatorConductorsRoutes from "./routes/operator_conductors.routes.js";
import operatorRoutesRoutes from "./routes/operator_routes.routes.js";
import operatorTripsRoutes from "./routes/operator_trips.routes.js";
import platformAllocationRoutes from "./routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./routes/ticket_validation.routes.js";
import seatSelectionRoutes from "./routes/seat_selection.routes.js";

loadEnv();

const app = express();
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsDir = path.join(__dirname, "..", "uploads");

app.use(cors());
app.use(express.json());
app.use("/uploads", express.static(uploadsDir));

app.use("/operator/buses", operatorBusesRoutes);
app.use("/operator/drivers", operatorDriversRoutes);
app.use("/operator/conductors", operatorConductorsRoutes);
app.use("/operator/routes", operatorRoutesRoutes);
app.use("/operator/trips", operatorTripsRoutes);
app.use("/operator/platforms", platformAllocationRoutes);
app.use("/operator", operatorRoutes);
app.use("/operator/tickets", ticketValidationRoutes);
// API aliases (keep /api prefix consistent with Flutter)
app.use("/api/operator/buses", operatorBusesRoutes);
app.use("/api/operator/drivers", operatorDriversRoutes);
app.use("/api/operator/conductors", operatorConductorsRoutes);
app.use("/api/operator/routes", operatorRoutesRoutes);
app.use("/api/operator/trips", operatorTripsRoutes);
app.use("/api/operator/platforms", platformAllocationRoutes);
app.use("/api/operator", operatorRoutes);
app.use("/api/operator/tickets", ticketValidationRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);

app.get("/", (req, res) => res.send("HBTS backend running"));

app.listen(process.env.PORT || 8000, () => {
  console.log("Server running on port", process.env.PORT || 8000);
});
