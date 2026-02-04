import express from "express";
import { requireAuth } from "../middleware/auth.middleware.js";

import {
  getPassengers,
  getPassengerById,
  addPassenger,
  updatePassenger,
  deletePassenger,
} from "../controllers/adminPassengers.controller.js";
import {
  listDrivers,
  getDriverById,
  updateDriver,
  updateDriverStatus,
} from "../controllers/adminDrivers.controller.js";
import {
  addOperator,
  deleteOperator,
  listOperators,
  updateOperator,
} from "../controllers/adminOperators.controller.js";
import {
  addCompany,
  deleteCompany,
  listCompanies,
  updateCompany,
} from "../controllers/adminCompanies.controller.js";
import {
  addConductor,
  deleteConductor,
  listConductors,
  updateConductor,
} from "../controllers/adminConductors.controller.js";
import {
  addBus,
  deleteBus,
  listBuses,
  listDeletedBuses,
  restoreBus,
  updateBus,
} from "../controllers/adminBuses.controller.js";
import {
  addRoute,
  deleteRoute,
  listDeletedRoutes,
  listRoutes,
  restoreRoute,
  updateRoute,
} from "../controllers/adminRoutes.controller.js";
import {
  addTripStop,
  addTrip,
  deleteTrip,
  listDeletedTrips,
  listAssignableDrivers,
  listTripLocationHistory,
  listTrips,
  listTripStops,
  restoreTrip,
  updateTrip,
} from "../controllers/adminTrips.controller.js";

const router = express.Router();

/* =========================
   AUTH & ROLE GUARD
========================= */
router.use(requireAuth);

// admin-only protection
router.use((req, res, next) => {
  if (req.user.role !== "admin") {
    return res.status(403).json({
      message: "Admin access only",
    });
  }
  next();
});

/* =========================
   PASSENGERS CRUD
========================= */

// GET passengers (search)
router.get("/passengers", getPassengers);

// GET single passenger
router.get("/passengers/:id", getPassengerById);

// ADD passenger
router.post("/passengers", addPassenger);

// UPDATE passenger  ✅ FIXED (no email update)
router.put("/passengers/:id", updatePassenger);

// DELETE passenger
router.delete("/passengers/:id", deletePassenger);

/* =========================
   DRIVERS CRUD
========================= */

// GET drivers (status/search)
router.get("/drivers", listDrivers);

// GET single driver
router.get("/drivers/:id", getDriverById);

// UPDATE driver profile
router.put("/drivers/:id", updateDriver);

// UPDATE driver status
router.put("/drivers/:id/status", updateDriverStatus);

/* =========================
   OPERATORS
========================= */

// GET operators
router.get("/operators", listOperators);
// ADD operator
router.post("/operators", addOperator);
// UPDATE operator
router.put("/operators/:id", updateOperator);
// DELETE operator
router.delete("/operators/:id", deleteOperator);

/* =========================
   COMPANIES
========================= */

// GET companies
router.get("/companies", listCompanies);
// ADD company
router.post("/companies", addCompany);
// UPDATE company
router.put("/companies/:id", updateCompany);
// DELETE company
router.delete("/companies/:id", deleteCompany);

/* =========================
   CONDUCTORS
========================= */

// GET conductors
router.get("/conductors", listConductors);
// ADD conductor
router.post("/conductors", addConductor);
// UPDATE conductor
router.put("/conductors/:id", updateConductor);
// DELETE conductor
router.delete("/conductors/:id", deleteConductor);

/* =========================
   BUSES CRUD
========================= */

// GET buses (active)
router.get("/buses", listBuses);

// GET deleted buses
router.get("/buses/deleted", listDeletedBuses);
// GET bus history (deleted)
router.get("/buses/history", listDeletedBuses);

// ADD bus
router.post("/buses", addBus);

// UPDATE bus
router.put("/buses/:id", updateBus);

// DELETE bus
router.delete("/buses/:id", deleteBus);
// RESTORE bus
router.put("/buses/:id/restore", restoreBus);

/* =========================
   ROUTES CRUD
========================= */

// GET routes (active)
router.get("/routes", listRoutes);

// GET deleted routes
router.get("/routes/deleted", listDeletedRoutes);
// GET route history (deleted)
router.get("/routes/history", listDeletedRoutes);

// ADD route
router.post("/routes", addRoute);

// UPDATE route
router.put("/routes/:id", updateRoute);

// DELETE route
router.delete("/routes/:id", deleteRoute);
// RESTORE route
router.put("/routes/:id/restore", restoreRoute);

/* =========================
   TRIPS CRUD
========================= */

// GET trips (active)
router.get("/trips", listTrips);

// GET deleted trips
router.get("/trips/deleted", listDeletedTrips);
// GET trip history (deleted)
router.get("/trips/history", listDeletedTrips);

// GET assignable drivers (for trip form)
router.get("/trips/assignable-drivers", listAssignableDrivers);

// GET trip stops
router.get("/trips/:id/stops", listTripStops);
// ADD trip stop
router.post("/trips/:id/stops", addTripStop);

// GET trip location history
router.get("/trips/:id/location-history", listTripLocationHistory);

// ADD trip
router.post("/trips", addTrip);

// UPDATE trip
router.put("/trips/:id", updateTrip);

// DELETE trip
router.delete("/trips/:id", deleteTrip);
// RESTORE trip
router.put("/trips/:id/restore", restoreTrip);

export default router;
