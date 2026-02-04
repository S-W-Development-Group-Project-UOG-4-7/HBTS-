import {
  createNotification,
  listPassengerNotifications,
  listAdminNotifications,
  markNotificationRead,
  getNotificationDefinition,
} from "../services/notification.service.js";

import { pushNotificationToUser } from "../ws/notification.ws.js";


function parsePaging(query) {
  const limit = Math.min(Number(query.limit ?? 50), 200);
  const offset = Math.max(Number(query.offset ?? 0), 0);
  const unreadOnly = String(query.unreadOnly ?? "false") === "true";
  return { limit, offset, unreadOnly };
}

export async function createNotificationHandler(req, res) {
  try {
    const { userId, type, data, title, message } = req.body ?? {};

    if (!type) {
      return res.status(400).json({ message: "type is required" });
    }

    const def = getNotificationDefinition(type);
    if (!def) {
      return res.status(400).json({ message: "Unsupported notification type" });
    }

    if (def.audience === "passenger" && !userId) {
      return res
        .status(400)
        .json({ message: "userId is required for passenger notifications" });
    }

    const created = await createNotification({ userId, type, data, title, message });

    // ✅ PUSH REALTIME if passenger notification
    if (created?.audience === "passenger" && created?.user_id) {
      pushNotificationToUser(created.user_id, created);
    }

    return res.status(201).json(created);
  } catch (err) {
    console.error("createNotificationHandler error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}


export async function getMyNotifications(req, res) {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const { limit, offset, unreadOnly } = parsePaging(req.query);
    const rows = await listPassengerNotifications({
      userId,
      limit,
      offset,
      unreadOnly,
    });

    return res.json(rows);
  } catch (err) {
    console.error("getMyNotifications error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function getAdminNotifications(req, res) {
  try {
    const { limit, offset } = parsePaging(req.query);
    const rows = await listAdminNotifications({ limit, offset });
    return res.json(rows);
  } catch (err) {
    console.error("getAdminNotifications error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}

export async function markMyNotificationRead(req, res) {
  try {
    const userId = req.user?.userId ?? req.user?.id;
    if (!userId) return res.status(401).json({ message: "Unauthorized" });

    const { id } = req.params;
    if (!id) return res.status(400).json({ message: "notification id is required" });

    const updated = await markNotificationRead({
      notificationId: Number(id),
      userId,
      audience: "passenger",
    });

    if (!updated) {
      return res.status(404).json({ message: "Notification not found" });
    }

    return res.json(updated);
  } catch (err) {
    console.error("markMyNotificationRead error:", err);
    return res.status(500).json({ message: "Server error" });
  }
}
