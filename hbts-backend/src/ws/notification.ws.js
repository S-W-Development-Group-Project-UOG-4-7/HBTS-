import jwt from "jsonwebtoken";

const clients = new Map(); // userId -> ws

export function initNotificationWS(wss) {
  wss.on("connection", (ws, req) => {
    try {
      const url = new URL(req.url, "http://localhost");
      const token = url.searchParams.get("token");

      if (!token) {
        ws.close();
        return;
      }

      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      const userId = decoded.userId;

      clients.set(userId, ws);
      ws.userId = userId;

      console.log(`🔔 WS connected: user ${userId}`);

      ws.on("close", () => {
        clients.delete(userId);
        console.log(`❌ WS disconnected: user ${userId}`);
      });
    } catch (e) {
      ws.close();
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
