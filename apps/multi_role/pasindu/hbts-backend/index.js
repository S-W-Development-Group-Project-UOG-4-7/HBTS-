import "./src/server.js";
import { startExpirePendingBookingsJob } from "./jobs/expirePendingBookings.job.js";
startExpirePendingBookingsJob();

