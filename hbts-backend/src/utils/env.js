import fs from "fs";
import path from "path";
import dotenv from "dotenv";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

function candidates() {
  const cwd = process.cwd();
  const parent = path.resolve(cwd, "..");
  return [
    process.env.DOTENV_PATH,
    path.join(cwd, ".env"),
    path.join(cwd, "hbts-backend", ".env"),
    path.join(cwd, "hbts-backend", "2.env"),
    path.join(cwd, "2.env"),
    path.join(parent, ".env"),
    path.join(parent, "2.env"),
    path.resolve(__dirname, "..", "..", "2.env"),
  ];
}

function loadEnv() {
  for (const candidate of candidates()) {
    if (!candidate) continue;
    if (fs.existsSync(candidate)) {
      dotenv.config({ path: candidate });
      return candidate;
    }
  }
  dotenv.config();
  return null;
}

export { loadEnv };
