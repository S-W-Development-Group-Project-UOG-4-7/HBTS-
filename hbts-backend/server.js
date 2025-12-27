import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import operatorRoutes from "./src/routes/operator.routes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.get("/", (req, res) => res.json({ ok: true, message: "HBTS backend running" }));

app.use("/operator", operatorRoutes);

const port = process.env.PORT || 8000;
app.listen(port, () => {
  console.log(`✅ Server running on http://localhost:${port}`);
});
