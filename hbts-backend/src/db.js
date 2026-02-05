import pg from "pg";
import { URL } from "url";
import { loadEnv } from "./utils/env.js";

loadEnv();

const rawUrl = process.env.DATABASE_URL;
if (!rawUrl) {
  throw new Error("DATABASE_URL is not set");
}

let connectionString = rawUrl;
let useSsl = false;

try {
  const url = new URL(rawUrl);
  // Neon URLs include channel_binding, which node-postgres doesn't need.
  url.searchParams.delete("channel_binding");
  connectionString = url.toString();
  useSsl = url.searchParams.get("sslmode") === "require";
} catch {
  // Fall back to the raw URL if parsing fails.
  connectionString = rawUrl;
}

console.log("DATABASE_URL (backend):", connectionString);

export const pool = new pg.Pool({
  connectionString,
  ssl: useSsl ? { rejectUnauthorized: false } : undefined,
  connectionTimeoutMillis: 20000,
  keepAlive: true,
  keepAliveInitialDelayMillis: 10000,
});

pool.on("connect", () => {
  console.log("PostgreSQL connected");
});
