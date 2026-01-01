import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import operatorRoutes from "./src/routes/operator.routes.js";
import operatorBusesRoutes from "./src/routes/operator_buses.routes.js";
import operatorDriversRoutes from "./src/routes/operator_drivers.routes.js";
import operatorTripsRoutes from "./src/routes/operator_trips.routes.js";
import paymentRoutes from "./src/routes/payments.routes.js";
import seatSelectionRoutes from "./src/routes/seat_selection.routes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (req, res) => res.json({ ok: true, message: "HBTS backend running" }));

app.use("/operator/buses", operatorBusesRoutes);
app.use("/operator/drivers", operatorDriversRoutes);
app.use("/operator/trips", operatorTripsRoutes);
app.use("/operator", operatorRoutes);
app.use("/api/payments", paymentRoutes);
app.use("/api/seat-selection", seatSelectionRoutes);

const port = process.env.PORT || 8000;
app.listen(port, () => {
  console.log(`✅ Server running on http://localhost:${port}`);
});
