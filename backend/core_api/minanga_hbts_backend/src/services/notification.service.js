import { pool } from "../db.js";

const TYPE_DEFINITIONS = {
  BOOKING_CONFIRMED: {
    audience: "passenger",
    category: "booking",
    titleTemplate: "Booking confirmed",
    messageTemplate: "Your booking from {from} -> {to} is confirmed.",
  },
  SEAT_BOOKED: {
    audience: "passenger",
    category: "booking",
    titleTemplate: "Seat booked",
    messageTemplate: "Seat {seatLabel} booked successfully for {from} -> {to}.",
  },
  TRIP_DELAYED: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Trip delayed",
    messageTemplate: "Your bus is delayed by {delayMinutes} minutes.",
  },
  TRIP_CANCELLED: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Trip cancelled",
    messageTemplate: "Your trip from {from} -> {to} has been cancelled.",
  },
  BOOKING_CANCELLED: {
    audience: "passenger",
    category: "booking",
    titleTemplate: "Booking cancelled",
    messageTemplate: "Your booking from {from} -> {to} has been cancelled.",
  },
  PASSENGER_ONBOARD: {
    audience: "passenger",
    category: "booking",
    titleTemplate: "Onboard confirmed",
    messageTemplate: "You are marked onboard for {from} -> {to}.",
  },
  ROUTE_CHANGED: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Route changed",
    messageTemplate: "Your route has changed: {from} -> {to}.",
  },
  SCHEDULE_CHANGED: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Schedule changed",
    messageTemplate: "Schedule updated. New departure: {departureTime}.",
  },
  PAYMENT_SUCCESS: {
    audience: "passenger",
    category: "payment",
    titleTemplate: "Payment success",
    messageTemplate: "Your payment of LKR {amount} was successful.",
  },
  PAYMENT_FAILED: {
    audience: "passenger",
    category: "payment",
    titleTemplate: "Payment failed",
    messageTemplate: "Your payment of LKR {amount} failed. Please try again.",
  },
  PAYMENT_PENDING_REMINDER: {
    audience: "passenger",
    category: "payment",
    titleTemplate: "Payment pending",
    messageTemplate:
      "Payment pending for booking {bookingId}. Please complete within {minutes} minutes.",
  },
  REFUND_PROCESSED: {
    audience: "passenger",
    category: "payment",
    titleTemplate: "Refund processed",
    messageTemplate: "Refund of LKR {amount} has been processed to your card.",
  },
  INVOICE_GENERATED: {
    audience: "passenger",
    category: "payment",
    titleTemplate: "Invoice ready",
    messageTemplate: "Your invoice for booking {bookingId} is ready.",
  },
  VEHICLE_BREAKDOWN: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Vehicle breakdown",
    messageTemplate: "Alert: Vehicle breakdown reported on your route.",
  },
  ACCIDENT_ALERT: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Accident alert",
    messageTemplate: "Alert: Accident reported on your route.",
  },
  OVER_SPEED_WARNING: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Over-speed warning",
    messageTemplate: "Warning: Bus is over speed limit.",
  },
  WEATHER_WARNING: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Weather warning",
    messageTemplate: "Warning: {weather} detected on your route.",
  },
  ROAD_CLOSURE: {
    audience: "passenger",
    category: "system",
    titleTemplate: "Road closure",
    messageTemplate: "Alert: Road closure on your route. Expect changes.",
  },
  DAILY_REVENUE_SUMMARY: {
    audience: "admin",
    category: "admin",
    titleTemplate: "Daily revenue summary",
    messageTemplate: "Daily revenue: LKR {amount}. Trips: {tripCount}.",
  },
  FAILED_TRANSACTIONS: {
    audience: "admin",
    category: "admin",
    titleTemplate: "Failed transactions",
    messageTemplate: "{count} payment failures detected today.",
  },
  VEHICLE_MAINTENANCE_ALERT: {
    audience: "admin",
    category: "admin",
    titleTemplate: "Vehicle maintenance alert",
    messageTemplate: "Vehicle {vehicleId} requires maintenance.",
  },
};

function fillTemplate(template, data) {
  return template.replace(/\{(\w+)\}/g, (match, key) => {
    if (data && data[key] !== undefined && data[key] !== null) {
      return String(data[key]);
    }
    return "";
  });
}

export function getNotificationDefinition(type) {
  return TYPE_DEFINITIONS[type];
}

export function resolveNotification({ type, data = {}, title, message }) {
  const def = TYPE_DEFINITIONS[type];
  if (!def) {
    throw new Error("Unsupported notification type");
  }

  const resolvedTitle = title ?? fillTemplate(def.titleTemplate, data);
  const resolvedMessage = message ?? fillTemplate(def.messageTemplate, data);

  return {
    audience: def.audience,
    category: def.category,
    type,
    title: resolvedTitle,
    message: resolvedMessage,
    data,
  };
}

export async function createNotification({ userId, type, data, title, message }) {
  const resolved = resolveNotification({ type, data, title, message });

  if (resolved.audience === "passenger" && !userId) {
    throw new Error("userId is required for passenger notifications");
  }

  const result = await pool.query(
    `
    INSERT INTO notifications (
      user_id,
      audience,
      category,
      type,
      title,
      message,
      data,
      is_read,
      created_at
    )
    VALUES ($1, $2, $3, $4, $5, $6, $7, false, NOW())
    RETURNING
      notification_id,
      user_id,
      audience,
      category,
      type,
      title,
      message,
      data,
      is_read,
      created_at
    `,
    [
      userId ?? null,
      resolved.audience,
      resolved.category,
      resolved.type,
      resolved.title,
      resolved.message,
      resolved.data,
    ]
  );

  const created = result.rows[0];

  // Realtime push is handled in the controller after creation.
  // Service returns the created row only.
  return created;
}

export async function listPassengerNotifications({
  userId,
  limit = 50,
  offset = 0,
  unreadOnly = false,
}) {
  const result = await pool.query(
    `
    SELECT
      notification_id,
      user_id,
      audience,
      category,
      type,
      title,
      message,
      data,
      is_read,
      created_at
    FROM notifications
    WHERE audience = 'passenger'
      AND user_id = $1
      AND ($2::boolean = false OR is_read = false)
    ORDER BY created_at DESC
    LIMIT $3 OFFSET $4
    `,
    [userId, unreadOnly, limit, offset]
  );

  return result.rows;
}

export async function listAdminNotifications({ limit = 50, offset = 0 }) {
  const result = await pool.query(
    `
    SELECT
      notification_id,
      user_id,
      audience,
      category,
      type,
      title,
      message,
      data,
      is_read,
      created_at
    FROM notifications
    WHERE audience = 'admin'
    ORDER BY created_at DESC
    LIMIT $1 OFFSET $2
    `,
    [limit, offset]
  );

  return result.rows;
}

export async function markNotificationRead({ notificationId, userId, audience }) {
  const result = await pool.query(
    `
    UPDATE notifications
    SET is_read = true
    WHERE notification_id = $1
      AND audience = $2
      AND ($3::int IS NULL OR user_id = $3)
    RETURNING
      notification_id,
      user_id,
      audience,
      category,
      type,
      title,
      message,
      data,
      is_read,
      created_at
    `,
    [notificationId, audience, userId ?? null]
  );

  return result.rows[0];
}
