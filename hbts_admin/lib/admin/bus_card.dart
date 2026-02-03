import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BusCard extends StatelessWidget {
  const BusCard({super.key, required this.bus, this.onTap, this.onRestore});

  final Map<String, dynamic> bus;
  final VoidCallback? onTap;
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    final plate = bus["license_plate_no"]?.toString() ?? "-";
    final route = bus["route_no"]?.toString() ?? "-";
    final model = bus["model"]?.toString() ?? "-";
    final serviceType = bus["service_type"]?.toString() ?? "-";
    final capacity = bus["capacity"]?.toString() ?? "-";
    final operatorId = bus["operator_id"]?.toString() ?? "-";
    final operatorName = bus["operator_name"]?.toString();
    final createdAt = _formatDate(bus["created_at"]);
    final updatedAt = _formatDate(bus["updated_at"]);

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
                      Icons.directions_bus_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plate,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Route: $route | Model: $model",
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  _Badge(
                    text: serviceType,
                    color: _serviceTypeColor(serviceType),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Tag(text: "Capacity: $capacity"),
                  _Tag(text: "Bus ID: ${bus["bus_id"] ?? "-"}"),
                  _Tag(text: "Operator ID: $operatorId"),
                ],
              ),
              const SizedBox(height: 12),
              _InfoRow(
                label: "Operator",
                value: operatorName ?? operatorId,
              ),
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

Color _serviceTypeColor(String value) {
  final normalized = value.toLowerCase().trim();
  if (normalized.contains("semi")) return AppColors.danger;
  if (normalized.contains("luxery")) return AppColors.success;
  if (normalized.contains("luxury")) return AppColors.success;
  if (normalized.contains("normal")) return AppColors.warning;
  return AppColors.primary;
}



