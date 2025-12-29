import pg from "pg";
const { Pool } = pg;

if (!process.env.DATABASE_URL) {
  throw new Error("DATABASE_URL is missing. Check .env file.");
}

export const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  ssl: { rejectUnauthorized: false }, // required for Neon
});

// Test connection once
pool
  .query("SELECT 1")
  .then(() => console.log("✅ Postgres connected"))
  .catch((err) => console.error("❌ Postgres error:", err.message));
