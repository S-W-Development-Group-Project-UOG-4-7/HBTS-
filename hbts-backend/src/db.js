import pg from "pg";
import { loadEnv } from "./utils/env.js";

loadEnv();

console.log("DATABASE_URL (backend):", process.env.DATABASE_URL);
export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL,
});

pool.on("connect", () => {
  console.log("PostgreSQL connected");
});
