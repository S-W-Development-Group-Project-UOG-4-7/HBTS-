import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import operatorRoutes from "./routes/operator.routes.js";
import operatorBusesRoutes from "./routes/operator_buses.routes.js";
import operatorDriversRoutes from "./routes/operator_drivers.routes.js";
import operatorTripsRoutes from "./routes/operator_trips.routes.js";
import platformAllocationRoutes from "./routes/platform_allocation.routes.js";
import ticketValidationRoutes from "./routes/ticket_validation.routes.js";
import seatSelectionRoutes from "./routes/seat_selection.routes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use("/operator/buses", operatorBusesRoutes);
app.use("/operator/drivers", operatorDriversRoutes);
app.use("/operator/trips", operatorTripsRoutes);
app.use("/operator/platforms", platformAllocationRoutes);
app.use("/operator", operatorRoutes);
app.use("/operator/tickets", ticketValidationRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);

app.get("/", (req, res) => res.send("HBTS backend running"));

app.listen(process.env.PORT || 8000, () => {
  console.log("Server running on port", process.env.PORT || 8000);
});
