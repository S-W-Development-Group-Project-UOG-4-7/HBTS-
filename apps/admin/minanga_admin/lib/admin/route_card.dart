import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RouteCard extends StatelessWidget {
  const RouteCard({super.key, required this.route, this.onTap, this.onRestore});

  final Map<String, dynamic> route;
  final VoidCallback? onTap;
  final VoidCallback? onRestore;

  String _pickString(List<String> keys, {String fallback = "-"}) {
    for (final key in keys) {
      final value = route[key];
      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }
    return fallback;
  }

  @override
  Widget build(BuildContext context) {
    final id = _pickString(["route_id", "id"], fallback: "-");
    final name = _pickString(["route_name", "name"], fallback: "Route $id");
    final code = _pickString(
      ["route_no", "route_number", "route_code", "code"],
      fallback: "-",
    );
    final origin = _pickString(
      ["origin", "start_point", "start", "from_location", "from"],
      fallback: "-",
    );
    final destination = _pickString(
      ["destination", "end_point", "end", "to_location", "to"],
      fallback: "-",
    );
    final distance = _pickString(["distance_km", "distance"], fallback: "-");
    final fare = _pickString(["fare", "price"], fallback: "-");
    final status = _pickString(["status", "route_status"], fallback: "unknown");
    final createdAt = _formatDate(route["created_at"]);
    final updatedAt = _formatDate(route["updated_at"]);

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
                      Icons.alt_route_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "$origin -> $destination",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _Badge(
                    text: status,
                    color: _statusColor(status),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(text: "Code: $code"),
                  _Tag(text: "Distance: $distance"),
                  _Tag(text: "Fare: $fare"),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(label: "Route ID", value: id),
              const SizedBox(height: 6),
              _InfoRow(label: "Created", value: createdAt),
              const SizedBox(height: 6),
              _InfoRow(label: "Updated", value: updatedAt),
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

Color _statusColor(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains("active")) return AppColors.success;
  if (normalized.contains("pause")) return AppColors.warning;
  if (normalized.contains("inactive")) return AppColors.warning;
  if (normalized.contains("suspend")) return AppColors.danger;
  return AppColors.primary;
}

