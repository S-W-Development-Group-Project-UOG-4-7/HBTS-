import jwt from "jsonwebtoken";

const clients = new Map(); // userId -> ws

export function initNotificationWS(wss) {
  wss.on("connection", (ws, req) => {
    try {
      const url = new URL(req.url, `http://${req.headers.host}`);
      const token = url.searchParams.get("token");

      if (!token) {
        ws.close(4001, "Missing token");
        return;
      }

      const decoded = jwt.verify(token, process.env.JWT_ACCESS_SECRET);
      const userId = decoded.userId ?? decoded.user_id ?? decoded.id;

      if (!userId) {
        ws.close(4002, "Missing userId in token");
        return;
      }

      clients.set(userId, ws);
      ws.userId = userId;

      console.log(`🔔 Notifications WS connected: user ${userId}`);

      ws.on("close", () => {
        clients.delete(userId);
        console.log(`❌ Notifications WS disconnected: user ${userId}`);
      });

      ws.on("error", () => {
        clients.delete(userId);
      });

      ws.send(JSON.stringify({ type: "CONNECTED" }));
    } catch (e) {
      const msg = e?.name === "TokenExpiredError" ? "Token expired" : "Invalid token";
      ws.close(4003, msg);
    }
  });
}

export function pushNotificationToUser(userId, notification) {
  const ws = clients.get(userId);
  if (!ws) return;
  if (ws.readyState !== ws.OPEN) return;

  ws.send(
    JSON.stringify({
      event: "notification",
      payload: notification,
    })
  );
}
