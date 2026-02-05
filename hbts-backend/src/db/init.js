import fs from "fs/promises";
import path from "path";
import { fileURLToPath } from "url";
import { pool } from "../db.js";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const schemaPath = path.join(__dirname, "..", "..", "sql", "schema.sql");

export async function initDatabase() {
  let sql = "";
  try {
    sql = await fs.readFile(schemaPath, "utf8");
  } catch (e) {
    if (e?.code === "ENOENT") {
      console.warn("DB init skipped: schema.sql not found at", schemaPath);
      return;
    }
    throw e;
  }
  if (!sql.trim()) return;

  const statements = sql
    .split(";")
    .map((stmt) => stmt.trim())
    .filter(Boolean);

  for (const stmt of statements) {
    try {
      await pool.query(stmt);
    } catch (e) {
      if (["42703", "42P01", "42710", "42P07"].includes(e?.code)) {
        console.warn("DB init skipped statement:", e.message);
        continue;
      }
      throw e;
    }
  }
}
