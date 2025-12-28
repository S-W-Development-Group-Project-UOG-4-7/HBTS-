import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import { pool } from "./db.js";

import passengerRoutes from "./routes/passenger.routes.js";
import adminRoutes from "./routes/admin.routes.js";
import reportRoutes from "./routes/report.routes.js";

dotenv.config();

// ✅ CREATE APP FIRST
const app = express();

// =======================
// MIDDLEWARE
// =======================
app.use(cors());
app.use(express.json());

// =======================
// ROUTES
// =======================
app.use("/auth/passenger", passengerRoutes);
app.use("/admin", adminRoutes);
app.use("/admin/reports", reportRoutes);

// =======================
// HEALTH CHECK
// =======================
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
