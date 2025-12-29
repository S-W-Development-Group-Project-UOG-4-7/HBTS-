import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Load .env from hbts-backend/.env
dotenv.config({ path: path.resolve(__dirname, "../.env") });

import pg from "pg";
const { Pool } = pg;

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is missing. Check hbts-backend/.env");
}

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // Neon requires SSL
});

// Optional test
pool
  .query("SELECT 1")
  .then(() => console.log("✅ Postgres connected"))
  .catch((err) => console.error("❌ Postgres error:", err.message));
