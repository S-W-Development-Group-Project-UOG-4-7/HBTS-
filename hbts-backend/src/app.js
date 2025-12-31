import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import operatorRoutes from "./routes/operator.routes.js";

dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

app.use("/operator", operatorRoutes);

app.get("/", (req, res) => res.send("HBTS backend running"));

app.listen(process.env.PORT || 8000, () => {
  console.log("Server running on port", process.env.PORT || 8000);
});
