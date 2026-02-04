import express from "express";
import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { pool } from "../db.js";
import { operatorAuth } from "../middleware/operatorAuth.js";

const router = express.Router();

const DEMO_OPERATOR_EMAIL = "operator@gmail.com";
const DEMO_OPERATOR_PASSWORD = "HBTS@123";

const OWNERSHIP_META = {
  bus: { table: "buses", idColumn: "bus_id" },
  driver: { table: "drivers", idColumn: "driver_id" },
  trip: { table: "trips", idColumn: "trip_id" },
};

const columnCache = {};

async function getTableColumns(table) {
  if (columnCache[table]) {
    return columnCache[table];
  }

  const { rows } = await pool.query(
    `
    SELECT column_name
      FROM information_schema.columns
     WHERE table_name = $1
    `,
    [table]
  );

  const set = new Set(rows.map((r) => r.column_name));
  columnCache[table] = set;
  return set;
}

async function buildInsert(table, columnValueMap) {
  const columnsInDb = await getTableColumns(table);
  const columns = [];
  const values = [];

  Object.entries(columnValueMap).forEach(([column, value]) => {
    if (value !== undefined && columnsInDb.has(column)) {
      columns.push(column);
      values.push(value);
    }
  });

  return { columns, values };
}

async function buildUpdate(table, columnValueMap) {
  const columnsInDb = await getTableColumns(table);
  const sets = [];
  const values = [];

  Object.entries(columnValueMap).forEach(([column, value]) => {
    if (value !== undefined && columnsInDb.has(column)) {
      values.push(value);
      sets.push(`${column} = $${values.length}`);
    }
  });

  return { sets, values };
}

async function listOwned(kind, operatorId, columns = "*") {
  const meta = OWNERSHIP_META[kind];
  const { rows } = await pool.query(
    `SELECT ${columns}
       FROM ${meta.table}
      WHERE operator_id = $1
   ORDER BY ${meta.idColumn} DESC`,
    [operatorId]
  );
  return rows;
}

async function findOwned(kind, id, operatorId, columns = "*") {
  const meta = OWNERSHIP_META[kind];
  const { rows } = await pool.query(
    `SELECT ${columns}
       FROM ${meta.table}
      WHERE ${meta.idColumn} = $1
        AND operator_id = $2
      LIMIT 1`,
    [id, operatorId]
  );
  return rows[0] || null;
}

async function ensureOwned(kind, id, operatorId) {
  const found = await findOwned(kind, id, operatorId, `${OWNERSHIP_META[kind].idColumn}`);
  return Boolean(found);
}

async function ensureOperatorsTable() {
  await pool.query(
    `
    CREATE TABLE IF NOT EXISTS operators (
      operator_id SERIAL PRIMARY KEY,
      name TEXT,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      created_at TIMESTAMP DEFAULT NOW()
    )
    `
  );
}

async function seedOperatorIfConfigured() {
  const emailRaw = process.env.OPERATOR_SEED_EMAIL;
  const passwordRaw = process.env.OPERATOR_SEED_PASSWORD;
  const nameRaw = process.env.OPERATOR_SEED_NAME;

  if (!emailRaw || !passwordRaw) return;

  const email = emailRaw.trim().toLowerCase();
  const passwordHash = await bcrypt.hash(passwordRaw, 10);

  const { rows } = await pool.query(
    `SELECT operator_id FROM operators WHERE email = $1 LIMIT 1`,
    [email]
  );

  if (rows.length) return;

  await pool.query(
    `
    INSERT INTO operators (name, email, password_hash)
    VALUES ($1, $2, $3)
    `,
    [nameRaw || "Operator", email, passwordHash]
  );
}

async function findCompanyByEmail(email) {
  const { rows } = await pool.query(
    `SELECT operator_id, name, email
       FROM company
      WHERE LOWER(email) = LOWER($1)
      LIMIT 1`,
    [email]
  );
  return rows[0] || null;
}

async function findCompanyByOperatorId(operatorId) {
  const { rows } = await pool.query(
    `SELECT operator_id, name, email
       FROM company
      WHERE operator_id = $1
      LIMIT 1`,
    [operatorId]
  );
  return rows[0] || null;
}

/**
 * POST /operator/login
 * Body: { email, password }
 */
router.post("/login", async (req, res) => {
  try {
    await ensureOperatorsTable();
    await seedOperatorIfConfigured();

    const { email, password } = req.body || {};
    if (!email || !password) {
      return res.status(400).json({ message: "Missing email/password" });
    }

    const normalizedEmail = email.trim().toLowerCase();
    const isDemo =
      normalizedEmail === DEMO_OPERATOR_EMAIL && password === DEMO_OPERATOR_PASSWORD;

    if (isDemo) {
      const passwordHash = await bcrypt.hash(DEMO_OPERATOR_PASSWORD, 10);
      const { rows } = await pool.query(
        `SELECT operator_id, name, email, password_hash
           FROM operators
          WHERE email = $1
          LIMIT 1`,
        [normalizedEmail]
      );

      let op = rows[0];
      if (!op) {
        const inserted = await pool.query(
          `
          INSERT INTO operators (name, email, password_hash)
          VALUES ($1, $2, $3)
          RETURNING operator_id, name, email, password_hash
          `,
          ["Demo Operator", normalizedEmail, passwordHash]
        );
        op = inserted.rows[0];
      }

      const jwtSecret = process.env.JWT_SECRET || process.env.JWT_ACCESS_SECRET;
      if (!jwtSecret) {
        return res.status(500).json({ message: "JWT secret not configured" });
      }

      const company = await findCompanyByEmail(op.email);
      const operatorId = company?.operator_id ?? op.operator_id;
      const operatorName = company?.name ?? op.name;
      const operatorEmail = company?.email ?? op.email;

      const token = jwt.sign(
        {
          operator_id: operatorId,
          email: operatorEmail,
          name: operatorName,
          role: "operator",
        },
        jwtSecret,
        { expiresIn: "7d" }
      );

      return res.json({
        token,
        operator: {
          id: operatorId,
          operator_id: operatorId,
          name: operatorName,
          email: operatorEmail,
        },
      });
    }

    const { rows } = await pool.query(
      `SELECT operator_id, name, email, password_hash
         FROM operators
        WHERE email = $1
        LIMIT 1`,
      [normalizedEmail]
    );

    if (!rows.length) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const op = rows[0];

    if (!op.password_hash) {
      return res.status(500).json({
        message: "Operator password not set. Missing password_hash in database.",
      });
    }

    const ok = await bcrypt.compare(password, op.password_hash);
    if (!ok) {
      return res.status(401).json({ message: "Invalid credentials" });
    }

    const jwtSecret = process.env.JWT_SECRET || process.env.JWT_ACCESS_SECRET;
    if (!jwtSecret) {
      return res.status(500).json({ message: "JWT secret not configured" });
    }

    const company = await findCompanyByEmail(op.email);
    const operatorId = company?.operator_id ?? op.operator_id;
    const operatorName = company?.name ?? op.name;
    const operatorEmail = company?.email ?? op.email;

    const token = jwt.sign(
      {
        operator_id: operatorId,
        email: operatorEmail,
        name: operatorName,
        role: "operator",
      },
      jwtSecret,
      { expiresIn: "7d" }
    );

    return res.json({
      token,
      operator: {
        id: operatorId,
        operator_id: operatorId,
        name: operatorName,
        email: operatorEmail,
      },
    });
  } catch (e) {
    return res.status(500).json({ message: "Login failed", error: e.message });
  }
});

// Protect all operator-owned routes below
router.use(operatorAuth);

/**
 * GET /operator/me
 */
router.get("/me", async (req, res) => {
  try {
    const operatorId = req.operatorId;

    const { rows } = await pool.query(
      `SELECT operator_id, name, email
         FROM operators
        WHERE operator_id = $1
        LIMIT 1`,
      [operatorId]
    );

    let record = rows[0] || null;

    if (!record) {
      record = await findCompanyByOperatorId(operatorId);
    }

    if (!record) {
      const fallback = req.operator || {};
      return res.json({
        id: operatorId,
        operator_id: operatorId,
        name: fallback.name || "Operator",
        email: fallback.email || null,
      });
    }

    return res.json({
      id: record.operator_id,
      operator_id: record.operator_id,
      name: record.name,
      email: record.email,
    });
  } catch (e) {
    return res.status(500).json({ message: "Failed to load operator", error: e.message });
  }
});

// =========================
// BUSES (operator scoped)
// =========================
router.get("/buses", async (req, res) => {
  try {
    const buses = await listOwned("bus", req.operatorId);
    return res.json(buses);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load buses", error: e.message });
  }
});

router.post("/buses", async (req, res) => {
  try {
    const { licensePlateNo, license_plate_no, model, capacity, serviceType, service_type, status = "active" } =
      req.body || {};

    if (!licensePlateNo && !license_plate_no) {
      return res.status(400).json({ message: "licensePlateNo is required" });
    }

    const capNum = capacity === undefined ? undefined : Number(capacity);
    if (capNum !== undefined && (!Number.isInteger(capNum) || capNum <= 0)) {
      return res.status(400).json({ message: "capacity must be a positive integer" });
    }

    const { columns, values } = await buildInsert("buses", {
      license_plate_no: (licensePlateNo || license_plate_no || "").trim(),
      model: model || null,
      capacity: capNum,
      service_type: serviceType || service_type || null,
      status: status || "active",
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      return res.status(500).json({ message: "operator_id column missing in buses table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO buses (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to create bus", error: e.message });
  }
});

router.put("/buses/:busId", async (req, res) => {
  try {
    const busId = Number(req.params.busId);
    if (!Number.isInteger(busId)) {
      return res.status(400).json({ message: "Invalid bus id" });
    }

    const owned = await ensureOwned("bus", busId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Bus not found" });
    }

    const capNum =
      req.body?.capacity === undefined || req.body.capacity === null ? req.body?.capacity : Number(req.body.capacity);
    if (capNum !== undefined && capNum !== null && (!Number.isInteger(capNum) || capNum <= 0)) {
      return res.status(400).json({ message: "capacity must be a positive integer" });
    }

    const { sets, values } = await buildUpdate("buses", {
      license_plate_no: req.body?.licensePlateNo || req.body?.license_plate_no,
      model: req.body?.model,
      capacity: capNum,
      service_type: req.body?.serviceType || req.body?.service_type,
      status: req.body?.status,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(busId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE buses
         SET ${sets.join(", ")}
       WHERE bus_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to update bus", error: e.message });
  }
});

// =========================
// DRIVERS (operator scoped)
// =========================
router.get("/drivers", async (req, res) => {
  try {
    const drivers = await listOwned("driver", req.operatorId);
    return res.json(drivers);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load drivers", error: e.message });
  }
});

router.post("/drivers", async (req, res) => {
  try {
    const { name, phone, licenseNo, license_no, status = "active" } = req.body || {};

    if (!name || !phone) {
      return res.status(400).json({ message: "name and phone are required" });
    }

    const { columns, values } = await buildInsert("drivers", {
      name: name.trim(),
      phone: phone.trim(),
      license_no: licenseNo || license_no || null,
      status: status || "active",
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      return res.status(500).json({ message: "operator_id column missing in drivers table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO drivers (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to create driver", error: e.message });
  }
});

router.put("/drivers/:driverId", async (req, res) => {
  try {
    const driverId = Number(req.params.driverId);
    if (!Number.isInteger(driverId)) {
      return res.status(400).json({ message: "Invalid driver id" });
    }

    const owned = await ensureOwned("driver", driverId, req.operatorId);
    if (!owned) {
      return res.status(404).json({ message: "Driver not found" });
    }

    const { sets, values } = await buildUpdate("drivers", {
      name: req.body?.name,
      phone: req.body?.phone,
      license_no: req.body?.licenseNo || req.body?.license_no,
      status: req.body?.status,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(driverId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE drivers
         SET ${sets.join(", ")}
       WHERE driver_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to update driver", error: e.message });
  }
});

// =========================
// TRIPS (operator scoped)
// =========================
router.get("/trips", async (req, res) => {
  try {
    const trips = await listOwned("trip", req.operatorId);
    return res.json(trips);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load trips", error: e.message });
  }
});

router.get("/trips/:tripId", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const trip = await findOwned("trip", tripId, req.operatorId);

    if (!trip) {
      return res.status(404).json({ message: "Trip not found" });
    }

    return res.json(trip);
  } catch (e) {
    return res.status(500).json({ message: "Failed to load trip", error: e.message });
  }
});

router.post("/trips", async (req, res) => {
  try {
    const { routeId, route_id, busId, bus_id, driverId, driver_id, tripDate, trip_date, departure_time, arrival_time, status = "scheduled" } =
      req.body || {};

    const resolvedRouteId = routeId || route_id;
    const resolvedBusId = busId || bus_id;
    const resolvedDriverId = driverId || driver_id;
    const resolvedTripDate = tripDate || trip_date;

    if (!resolvedRouteId || !resolvedBusId || !resolvedDriverId || !resolvedTripDate || !departure_time || !arrival_time) {
      return res.status(400).json({
        message: "routeId, busId, driverId, tripDate, departure_time, arrival_time are required",
      });
    }

    const busOwned = await ensureOwned("bus", Number(resolvedBusId), req.operatorId);
    if (!busOwned) {
      return res.status(403).json({ message: "Bus does not belong to this operator" });
    }

    const driverOwned = await ensureOwned("driver", Number(resolvedDriverId), req.operatorId);
    if (!driverOwned) {
      return res.status(403).json({ message: "Driver does not belong to this operator" });
    }

    const { columns, values } = await buildInsert("trips", {
      route_id: resolvedRouteId,
      bus_id: resolvedBusId,
      driver_id: resolvedDriverId,
      trip_date: resolvedTripDate,
      departure_time,
      arrival_time,
      status: status || "scheduled",
      operator_id: req.operatorId,
    });

    if (!columns.length) {
      return res.status(400).json({ message: "No valid fields to insert" });
    }

    if (!columns.includes("operator_id")) {
      return res.status(500).json({ message: "operator_id column missing in trips table" });
    }

    const placeholders = columns.map((_, idx) => `$${idx + 1}`).join(", ");
    const { rows } = await pool.query(
      `INSERT INTO trips (${columns.join(", ")}) VALUES (${placeholders}) RETURNING *`,
      values
    );

    return res.status(201).json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to create trip", error: e.message });
  }
});

router.put("/trips/:tripId", async (req, res) => {
  try {
    const tripId = Number(req.params.tripId);
    if (!Number.isInteger(tripId)) {
      return res.status(400).json({ message: "Invalid trip id" });
    }

    const ownedTrip = await ensureOwned("trip", tripId, req.operatorId);
    if (!ownedTrip) {
      return res.status(404).json({ message: "Trip not found" });
    }

    const resolvedBusId = req.body?.busId || req.body?.bus_id;
    const resolvedDriverId = req.body?.driverId || req.body?.driver_id;

    if (resolvedBusId !== undefined && resolvedBusId !== null) {
      const busOwned = await ensureOwned("bus", Number(resolvedBusId), req.operatorId);
      if (!busOwned) {
        return res.status(403).json({ message: "Bus does not belong to this operator" });
      }
    }

    if (resolvedDriverId !== undefined && resolvedDriverId !== null) {
      const driverOwned = await ensureOwned("driver", Number(resolvedDriverId), req.operatorId);
      if (!driverOwned) {
        return res.status(403).json({ message: "Driver does not belong to this operator" });
      }
    }

    const { sets, values } = await buildUpdate("trips", {
      route_id: req.body?.routeId || req.body?.route_id,
      bus_id: resolvedBusId,
      driver_id: resolvedDriverId,
      trip_date: req.body?.tripDate || req.body?.trip_date,
      departure_time: req.body?.departure_time,
      arrival_time: req.body?.arrival_time,
      status: req.body?.status,
    });

    if (!sets.length) {
      return res.status(400).json({ message: "No fields to update" });
    }

    values.push(tripId, req.operatorId);

    const { rows } = await pool.query(
      `
      UPDATE trips
         SET ${sets.join(", ")}
       WHERE trip_id = $${values.length - 1}
         AND operator_id = $${values.length}
      RETURNING *
      `,
      values
    );

    return res.json(rows[0]);
  } catch (e) {
    return res.status(500).json({ message: "Failed to update trip", error: e.message });
  }
});

export default router;
