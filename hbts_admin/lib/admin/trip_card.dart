import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TripCard extends StatelessWidget {
  const TripCard({super.key, required this.trip, this.onTap, this.onRestore});

  final Map<String, dynamic> trip;
  final VoidCallback? onTap;
  final VoidCallback? onRestore;

  String _value(String key, {String fallback = "-"}) {
    final v = trip[key];
    if (v == null || v.toString().trim().isEmpty) return fallback;
    return v.toString();
  }

  String _valueAny(List<String> keys, {String fallback = "-"}) {
    for (final key in keys) {
      final value = _value(key, fallback: "");
      if (value.trim().isNotEmpty) return value;
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final tripId = _valueAny(["trip_id", "tripId", "id"]);
    final routeName =
        _valueAny(["route_name", "routeName", "name"], fallback: _valueAny([
      "route_code",
      "route_no",
      "routeCode",
    ]));
    final routeCode = _valueAny(["route_code", "route_no", "routeCode"]);
    final plate =
        _valueAny(["license_plate_no", "license_plate", "plate_no"]);
    final driverName =
        _valueAny(["driver_name", "driverName", "full_name", "name"]);
    final tripDate = _formatDate(trip["trip_date"] ?? trip["tripDate"]);
    final departure =
        _formatTime(trip["departure_time"] ?? trip["departureTime"]);
    final arrival =
        _formatTime(trip["arrival_time"] ?? trip["arrivalTime"]);
    final status = _valueAny(["status"], fallback: "scheduled");
    final statusLabel = _statusLabel(status);

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha((0.12 * 255).round()),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routeName.isEmpty ? "Trip $tripId" : routeName,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Route: $routeCode | Bus: $plate",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _Badge(text: statusLabel, color: _statusColor(status)),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(text: "Trip ID: $tripId"),
                  _Tag(text: "Driver: $driverName"),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(label: "Date", value: tripDate),
              const SizedBox(height: 6),
              _InfoRow(label: "Depart", value: departure),
              const SizedBox(height: 6),
              _InfoRow(label: "Arrive", value: arrival),
              if (onRestore != null) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onRestore,
                    icon: const Icon(Icons.restore),
                    label: const Text("Restore"),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textMuted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null) return "-";
  final raw = value.toString();
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return raw;
  final y = parsed.year.toString().padLeft(4, "0");
  final m = parsed.month.toString().padLeft(2, "0");
  final d = parsed.day.toString().padLeft(2, "0");
  return "$y-$m-$d";
}

String _formatTime(dynamic value) {
  if (value == null) return "-";
  final raw = value.toString().trim();
  if (raw.isEmpty) return "-";
  final parsed = DateTime.tryParse(raw);
  if (parsed != null) {
    final h = parsed.hour.toString().padLeft(2, "0");
    final min = parsed.minute.toString().padLeft(2, "0");
    return "$h:$min";
  }
  if (raw.contains(" ")) {
    final parts = raw.split(" ");
    return _formatTime(parts.last);
  }
  if (raw.contains(":")) {
    final bits = raw.split(":");
    if (bits.length >= 2) {
      return "${bits[0].padLeft(2, "0")}:${bits[1].padLeft(2, "0")}";
    }
  }
  return raw;
}

String _statusLabel(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains("progress") || normalized.contains("running")) {
    return "running";
  }
  return normalized.isEmpty ? "scheduled" : value;
}

Color _statusColor(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains("cancel")) return AppColors.danger;
  if (normalized.contains("progress") || normalized.contains("running")) {
    return AppColors.primary;
  }
  if (normalized.contains("complete")) return AppColors.success;
  return AppColors.warning;
}

