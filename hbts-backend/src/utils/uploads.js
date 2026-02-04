import multer from "multer";
import path from "path";
import fs from "fs";
import crypto from "crypto";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const uploadsRoot = path.resolve(__dirname, "..", "..", "uploads");

function ensureDir(dir) {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

function randomName() {
  if (typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }
  return `${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function makeUploader(subdir) {
  const storage = multer.diskStorage({
    destination: (req, file, cb) => {
      const dest = path.join(uploadsRoot, subdir);
      ensureDir(dest);
      cb(null, dest);
    },
    filename: (req, file, cb) => {
      const rawExt = path.extname(file.originalname || "");
      const ext = rawExt && rawExt.length <= 10 ? rawExt.toLowerCase() : "";
      cb(null, `${Date.now()}-${randomName()}${ext}`);
    },
  });

  return multer({
    storage,
    limits: { fileSize: 10 * 1024 * 1024 },
    fileFilter: (req, file, cb) => {
      if (file.mimetype && file.mimetype.startsWith("image/")) {
        cb(null, true);
        return;
      }
      cb(new Error("Only image uploads are allowed"));
    },
  });
}

function toPublicPath(subdir, filename) {
  const clean = filename.replace(/\\/g, "/");
  return `/uploads/${subdir}/${clean}`;
}

function getUploadsRoot() {
  return uploadsRoot;
}

export { makeUploader, toPublicPath, getUploadsRoot };
