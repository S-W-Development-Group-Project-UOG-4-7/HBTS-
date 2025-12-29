import dotenv from "dotenv";
dotenv.config({ path: "./.env" }); // if you run from backend/ folder
// If you run from project root, use: dotenv.config({ path: "./backend/.env" });

import express from "express";
import cors from "cors";

import authRoutes from "./routes/auth.routes.js";
import adminRoutes from "./routes/admin.routes.js";

const app = express();

// ✅ CORS — MUST be before routes
app.use(
  cors({
    origin: true,
    credentials: true,
    methods: ["GET", "POST", "PUT", "DELETE", "OPTIONS"],
    allowedHeaders: ["Content-Type", "Authorization"],
  })
);

// ✅ THIS LINE IS REQUIRED FOR FLUTTER WEB preflight
app.options("*", cors());

app.use(express.json());

// ✅ Health check
app.get("/health", (req, res) => {
  res.json({ ok: true });
});

// ✅ Routes
app.use("/api/auth", authRoutes);
app.use("/api/admin", adminRoutes);

// ✅ Start server (only once)
const PORT = process.env.PORT || 4000;
app.listen(PORT, () => {
  console.log(`✅ API running on http://localhost:${PORT}`);
  console.log("✅ DATABASE_URL type:", typeof process.env.DATABASE_URL);
});
