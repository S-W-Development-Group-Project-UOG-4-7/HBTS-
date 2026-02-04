import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'operator_assignments_page.dart';
import 'operator_bus_register_page.dart';
import 'operator_bus_stats_page.dart';
import 'operator_login_page.dart';
import 'operator_platforms_page.dart';
import 'operator_staff_register_page.dart';
import 'operator_trips_page.dart';
import 'services/operator_api.dart';
import 'services/utils/operator_session.dart';

const Color _primaryColor = Color(0xFF3E5BFA);
const Color _primaryDark = Color(0xFF2F46DB);
const Color _dashboardBg = Color(0xFFF4F6FF);
const Color _sidebarBg = Color(0xFFFFFFFF);

TextStyle _appFont({
  double size = 14,
  FontWeight weight = FontWeight.w500,
  Color color = Colors.black,
  double? height,
}) {
  return GoogleFonts.manrope(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );
}

class _OperatorSummary {
  final List<Map<String, dynamic>> drivers;
  final List<Map<String, dynamic>> conductors;
  final List<Map<String, dynamic>> buses;
  final List<Map<String, dynamic>> trips;

  const _OperatorSummary({
    required this.drivers,
    required this.conductors,
    required this.buses,
    required this.trips,
  });
}

class _NavItem {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool selected;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.onTap,
    this.selected = false,
  });
}

class _Sidebar extends StatelessWidget {
  final List<_NavItem> items;
  final VoidCallback onAddStaff;
  final VoidCallback onAddBus;

  const _Sidebar({
    required this.items,
    required this.onAddStaff,
    required this.onAddBus,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _sidebarBg,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: _primaryColor,
                    child: Icon(Icons.directions_bus, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "HBTS",
                        style: _appFont(
                          size: 16,
                          weight: FontWeight.w700,
                          color: _primaryDark,
                        ),
                      ),
                      Text(
                        "Operator Panel",
                        style: _appFont(size: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddStaff,
                  icon: const Icon(Icons.person_add_alt),
                  label: Text(
                    "Register Staff",
                    style: _appFont(size: 12, weight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddBus,
                  icon: const Icon(Icons.add_road),
                  label: Text(
                    "Register Bus",
                    style: _appFont(size: 12, weight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _primaryColor,
                    side: BorderSide(color: _primaryColor.withValues(alpha: 0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items.map((item) {
                  final highlight = item.selected;
                  final color = highlight ? _primaryColor : Colors.grey.shade700;
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color:
                          highlight ? const Color(0xFFE9EDFF) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      dense: true,
                      leading: Icon(item.icon, color: color),
                      title: Text(
                        item.label,
                        style: _appFont(
                          size: 13,
                          weight: highlight ? FontWeight.w700 : FontWeight.w600,
                          color: color,
                        ),
                      ),
                      onTap: item.onTap,
                      horizontalTitleGap: 8,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCardData {
  final String label;
  final String value;
  final String footer;
  final Color accent;
  final IconData icon;

  const _MetricCardData({
    required this.label,
    required this.value,
    required this.footer,
    required this.accent,
    required this.icon,
  });
}

class _MetricGrid extends StatelessWidget {
  final List<_MetricCardData> cards;

  const _MetricGrid({required this.cards});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final perRow = width > 1200
            ? 4
            : width > 900
                ? 3
                : width > 600
                    ? 2
                    : 1;
        final spacing = 16.0;
        final cardWidth = (width - spacing * (perRow - 1)) / perRow;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: cards
              .map(
                (card) => SizedBox(
                  width: cardWidth,
                  child: _MetricCard(data: card),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final _MetricCardData data;

  const _MetricCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 132,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.value,
                        style: _appFont(
                          size: 20,
                          weight: FontWeight.w700,
                          color: data.accent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data.label,
                        style: _appFont(size: 13, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: data.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(data.icon, color: data.accent, size: 18),
                ),
              ],
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: data.accent,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Text(
              data.footer,
              style: _appFont(size: 11, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.child,
    this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: _primaryColor, size: 18),
                ),
              if (icon != null) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: _appFont(size: 14, weight: FontWeight.w700, color: _primaryDark),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _AnalyticsSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 980;
        final placeholder = Container(
          height: 230,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        );

        if (stacked) {
          return Column(
            children: [
              placeholder,
              const SizedBox(height: 16),
              placeholder,
              const SizedBox(height: 16),
              placeholder,
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: placeholder),
            const SizedBox(width: 16),
            Expanded(child: placeholder),
            const SizedBox(width: 16),
            Expanded(child: placeholder),
          ],
        );
      },
    );
  }
}

class _MetricMini extends StatelessWidget {
  final String label;
  final String value;

  const _MetricMini({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: _appFont(size: 16, weight: FontWeight.w700, color: _primaryDark),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: _appFont(size: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _TripDay {
  final String label;
  final int count;

  const _TripDay({required this.label, required this.count});
}

class _TripBarChart extends StatelessWidget {
  final List<_TripDay> days;

  const _TripBarChart({required this.days});

  @override
  Widget build(BuildContext context) {
    final maxCount = days.fold<int>(
      1,
      (maxValue, day) => day.count > maxValue ? day.count : maxValue,
    );

    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: days.map((day) {
          final barHeight = 24 + (day.count / maxCount) * 90;
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  height: barHeight,
                  width: 16,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_primaryColor, _primaryDark],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  day.label,
                  style: _appFont(size: 10, color: Colors.grey.shade700),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _BusTypeBreakdown extends StatelessWidget {
  final Map<String, int> typeCounts;
  final String Function(String) formatLabel;

  const _BusTypeBreakdown({
    required this.typeCounts,
    required this.formatLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (typeCounts.isEmpty) {
      return Text(
        "No buses registered yet.",
        style: _appFont(size: 12, color: Colors.grey.shade700),
      );
    }

    final entries = typeCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topEntries = entries.length > 3 ? entries.take(3).toList() : entries;
    if (entries.length > 3) {
      final otherCount = entries.skip(3).fold<int>(0, (sum, e) => sum + e.value);
      topEntries.add(MapEntry("other", otherCount));
    }

    final colors = [
      const Color(0xFF2BB673),
      const Color(0xFFF9A826),
      const Color(0xFFEF4B76),
      const Color(0xFF3E5BFA),
    ];

    final values = topEntries.map((e) => e.value.toDouble()).toList();

    return Row(
      children: [
        SizedBox(
          width: 120,
          height: 120,
          child: _RingChart(values: values, colors: colors),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(topEntries.length, (index) {
              final entry = topEntries[index];
              final color = colors[index % colors.length];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        formatLabel(entry.key),
                        style: _appFont(size: 12, weight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      entry.value.toString(),
                      style: _appFont(size: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _RingChart extends StatelessWidget {
  final List<double> values;
  final List<Color> colors;

  const _RingChart({
    required this.values,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    const strokeWidth = 16.0;
    return CustomPaint(
      painter: _RingChartPainter(
        values: values,
        colors: colors,
        strokeWidth: strokeWidth,
      ),
    );
  }
}

class _RingChartPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  final double strokeWidth;

  _RingChartPainter({
    required this.values,
    required this.colors,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (sum, value) => sum + value);
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final backgroundPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, backgroundPaint);

    if (total <= 0) return;

    var startAngle = -1.5708;
    for (var i = 0; i < values.length; i++) {
      final sweep = (values[i] / total) * 6.28318;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweep,
        false,
        paint,
      );
      startAngle += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _RingChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.colors != colors;
  }
}

class _StatusBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _StatusBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final percent = total == 0 ? 0.0 : count / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: _appFont(size: 12, weight: FontWeight.w600),
              ),
            ),
            Text(
              "${(percent * 100).toStringAsFixed(0)}%",
              style: _appFont(size: 12, color: Colors.grey.shade700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

class _InlineNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _InlineNotice({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade50),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _primaryColor.withValues(alpha: 0.1),
            child: Icon(icon, color: _primaryColor, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: _appFont(size: 13, weight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: _appFont(size: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onAction,
            child: Text(
              actionLabel,
              style: _appFont(size: 12, weight: FontWeight.w600, color: _primaryColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperatorHeaderCard extends StatelessWidget {
  final Future<Map<String, dynamic>> operatorFuture;
  final String? fallbackName;
  final String? fallbackEmail;
  final VoidCallback onRetry;

  const _OperatorHeaderCard({
    required this.operatorFuture,
    required this.fallbackName,
    required this.fallbackEmail,
    required this.onRetry,
  });

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  Widget _infoCard({required String name, required String email}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: _primaryColor.withValues(alpha: 0.12),
            child: const Icon(Icons.badge, color: _primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: _appFont(size: 14, weight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  email == "-" ? "No email provided" : email,
                  style: _appFont(size: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: operatorFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          final fallback = fallbackName?.trim();
          if (fallback != null && fallback.isNotEmpty) {
            final emailFallback = fallbackEmail?.trim();
            return _infoCard(
              name: fallback,
              email: (emailFallback != null && emailFallback.isNotEmpty)
                  ? emailFallback
                  : "-",
            );
          }
          return _InlineNotice(
            icon: Icons.info_outline,
            title: "Operator Info",
            message: "Failed to load operator details.",
            actionLabel: "Retry",
            onAction: onRetry,
          );
        }
        if (!snapshot.hasData) {
          return _InlineNotice(
            icon: Icons.info_outline,
            title: "Operator Info",
            message: "No operator data available.",
            actionLabel: "Retry",
            onAction: onRetry,
          );
        }

        final op = snapshot.data!;
        final name = _safeStr(op["name"] ?? fallbackName);
        final email = _safeStr(op["email"] ?? fallbackEmail);

        return _infoCard(name: name, email: email);
      },
    );
  }
}

class _AssignedTripsSection extends StatelessWidget {
  final Future<List<Map<String, dynamic>>> tripsFuture;
  final VoidCallback onRetry;
  final Future<void> Function(int, String) onStatusChange;
  final Color Function(String) statusColor;

  const _AssignedTripsSection({
    required this.tripsFuture,
    required this.onRetry,
    required this.onStatusChange,
    required this.statusColor,
  });

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: tripsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LinearProgressIndicator();
        }
        if (snapshot.hasError) {
          return _InlineNotice(
            icon: Icons.warning_amber_outlined,
            title: "Assigned Trips",
            message: "Failed to load assigned trips.",
            actionLabel: "Retry",
            onAction: onRetry,
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _InlineNotice(
            icon: Icons.info_outline,
            title: "Assigned Trips",
            message: "No assigned trips yet.",
            actionLabel: "Refresh",
            onAction: onRetry,
          );
        }

        final trips = snapshot.data!;
        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 720;
            return Column(
              children: trips.map((trip) {
                final tripId = int.tryParse(_safeStr(trip["trip_id"])) ?? 0;
                final routeName = _safeStr(trip["route_name"]);
                final from = _safeStr(trip["from_location"]);
                final to = _safeStr(trip["to_location"]);
                final status = _safeStr(trip["status"]);
                final bus = _safeStr(trip["license_plate_no"]);
                final driver = _safeStr(trip["driver_name"]);
                final date = _safeStr(trip["trip_date"]);
                final depart = _safeStr(trip["departure_time"]);

                final title = routeName != "-"
                    ? routeName
                    : ((from != "-" || to != "-")
                        ? "$from -> $to"
                        : "Trip #$tripId");

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.blue.shade50),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.directions_bus, color: _primaryColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              title,
                              style: _appFont(size: 13, weight: FontWeight.w700),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor(status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: _appFont(
                                size: 10,
                                weight: FontWeight.w700,
                                color: statusColor(status),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          PopupMenuButton<String>(
                            onSelected: (s) => onStatusChange(tripId, s),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: "scheduled",
                                child: Text("Set Scheduled"),
                              ),
                              PopupMenuItem(
                                value: "parked",
                                child: Text("Set Parked"),
                              ),
                              PopupMenuItem(
                                value: "ongoing",
                                child: Text("Set Ongoing"),
                              ),
                              PopupMenuItem(
                                value: "delayed",
                                child: Text("Set Delayed"),
                              ),
                              PopupMenuItem(
                                value: "completed",
                                child: Text("Complete"),
                              ),
                              PopupMenuItem(
                                value: "cancelled",
                                child: Text("Cancel"),
                              ),
                            ],
                            child: const Icon(Icons.more_vert, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isCompact) ...[
                        Text(
                          "Date: $date | Depart: $depart",
                          style: _appFont(size: 11, color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Bus: $bus | Driver: $driver",
                          style: _appFont(size: 11, color: Colors.grey.shade700),
                        ),
                      ] else
                        Row(
                          children: [
                            _TripMeta(label: "Date", value: date),
                            _TripMeta(label: "Depart", value: depart),
                            _TripMeta(label: "Bus", value: bus),
                            _TripMeta(label: "Driver", value: driver),
                          ],
                        ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _TripMeta extends StatelessWidget {
  final String label;
  final String value;

  const _TripMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: _appFont(size: 10, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: _appFont(size: 11, weight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class OperatorDashboardPage extends StatefulWidget {
  final int operatorId;

  const OperatorDashboardPage({super.key, required this.operatorId});

  @override
  State<OperatorDashboardPage> createState() => _OperatorDashboardPageState();
}

class _OperatorDashboardPageState extends State<OperatorDashboardPage> {
  late Future<Map<String, dynamic>> _operatorFuture;
  late Future<List<Map<String, dynamic>>> _assignedFuture;
  late Future<_OperatorSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _operatorFuture = OperatorApi.fetchOperatorDetails();
    _assignedFuture = OperatorApi.fetchAssignedTrips();
    _summaryFuture = _buildSummary();
  }

  Future<_OperatorSummary> _buildSummary() async {
    final results = await Future.wait<List<Map<String, dynamic>>>([
      OperatorApi.fetchDrivers(),
      OperatorApi.fetchConductors(),
      OperatorApi.fetchBuses(),
      _assignedFuture,
    ]);

    return _OperatorSummary(
      drivers: results[0],
      conductors: results[1],
      buses: results[2],
      trips: results[3],
    );
  }

  void _reload() {
    setState(() {
      _loadData();
    });
  }

  String _safeStr(dynamic v) => (v == null) ? "-" : v.toString();

  DateTime? _tryParseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int _countTrips(List<Map<String, dynamic>> trips, Set<String> statuses) {
    return trips.where((trip) {
      final status = _safeStr(trip["status"]).toLowerCase();
      return statuses.contains(status);
    }).length;
  }

  List<_TripDay> _buildTripDays(List<Map<String, dynamic>> trips, int days) {
    final now = DateTime.now();
    final start =
        DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final end = DateTime(now.year, now.month, now.day);
    final counts = <DateTime, int>{};

    for (final trip in trips) {
      final date = _tryParseDate(trip["trip_date"] ?? trip["date"]);
      if (date == null) continue;
      final day = DateTime(date.year, date.month, date.day);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      counts[day] = (counts[day] ?? 0) + 1;
    }

    final results = <_TripDay>[];
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      results.add(_TripDay(label: _weekdayLabel(day), count: counts[day] ?? 0));
    }
    return results;
  }

  String _weekdayLabel(DateTime date) {
    const names = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    return names[date.weekday - 1];
  }

  Map<String, int> _busTypeCounts(List<Map<String, dynamic>> buses) {
    final counts = <String, int>{};
    for (final bus in buses) {
      final raw = bus["service_type"] ??
          bus["serviceType"] ??
          bus["type"] ??
          bus["model"];
      final value = raw == null ? "standard" : raw.toString().trim();
      final key = value.isEmpty ? "standard" : value.toLowerCase();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    return counts;
  }

  String _titleCase(String value) {
    if (value.isEmpty) return value;
    final parts = value.split(RegExp(r"[_\s-]+"));
    return parts
        .map((part) {
          if (part.isEmpty) return part;
          return part[0].toUpperCase() + part.substring(1);
        })
        .where((part) => part.isNotEmpty)
        .join(" ");
  }

  Future<void> _changeTripStatus(int tripId, String status) async {
    try {
      await OperatorApi.updateTripStatus(tripId: tripId, status: status);
      setState(() {
        _assignedFuture = OperatorApi.fetchAssignedTrips();
        _summaryFuture = _buildSummary();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  }

  void _logout() {
    OperatorSession.clear();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const OperatorLoginPage()),
    );
  }

  void _openPage(Widget page, {required bool inDrawer}) {
    if (inDrawer) {
      Navigator.pop(context);
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _openStaffRegister({required bool inDrawer}) {
    if (inDrawer) {
      Navigator.pop(context);
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const OperatorStaffRegisterPage(
          initialRole: "driver",
          allowRoleSelection: true,
        ),
      ),
    );
  }

  void _openBusRegister({required bool inDrawer}) {
    if (inDrawer) {
      Navigator.pop(context);
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const OperatorBusRegisterPage()),
    );
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case "scheduled":
        return Colors.blue.shade600;
      case "delayed":
        return Colors.orange.shade700;
      case "parked":
        return Colors.blueGrey.shade700;
      case "ongoing":
      case "running":
      case "in_progress":
        return _primaryColor;
      case "completed":
        return Colors.green.shade700;
      case "cancelled":
        return Colors.red.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  List<_NavItem> _navItems({required bool inDrawer}) {
    return [
      _NavItem(
        label: "Dashboard",
        icon: Icons.dashboard,
        selected: true,
        onTap: () {
          if (inDrawer) Navigator.pop(context);
        },
      ),
      _NavItem(
        label: "Drivers",
        icon: Icons.badge,
        onTap: () => _openPage(
          const OperatorAssignmentsPage(view: OperatorAssignmentsView.drivers),
          inDrawer: inDrawer,
        ),
      ),
      _NavItem(
        label: "Conductors",
        icon: Icons.groups,
        onTap: () => _openPage(
          const OperatorAssignmentsPage(view: OperatorAssignmentsView.conductors),
          inDrawer: inDrawer,
        ),
      ),
      _NavItem(
        label: "Buses",
        icon: Icons.directions_bus,
        onTap: () => _openPage(
          const OperatorAssignmentsPage(view: OperatorAssignmentsView.buses),
          inDrawer: inDrawer,
        ),
      ),
      _NavItem(
        label: "Trips",
        icon: Icons.route,
        onTap: () => _openPage(const OperatorTripsPage(), inDrawer: inDrawer),
      ),
      _NavItem(
        label: "Platforms",
        icon: Icons.location_city,
        onTap: () => _openPage(const OperatorPlatformsPage(), inDrawer: inDrawer),
      ),
      _NavItem(
        label: "Bus Stats",
        icon: Icons.bar_chart,
        onTap: () => _openPage(const OperatorBusStatsPage(), inDrawer: inDrawer),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 1100;
    final showActionText = width >= 760;

    return Scaffold(
      drawer: isWide
          ? null
          : Drawer(
              child: _Sidebar(
                items: _navItems(inDrawer: true),
                onAddStaff: () => _openStaffRegister(inDrawer: true),
                onAddBus: () => _openBusRegister(inDrawer: true),
              ),
            ),
      appBar: AppBar(
        backgroundColor: _primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: !isWide,
        title: Row(
          children: [
            const CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white,
              child: Icon(Icons.directions_bus, color: _primaryColor, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              "HBTS Operator",
              style: _appFont(size: 18, weight: FontWeight.w700, color: Colors.white),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: showActionText
                ? TextButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(
                      "Logout",
                      style: _appFont(
                        size: 12,
                        weight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                  )
                : IconButton(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                  ),
          ),
        ],
      ),
      body: Row(
        children: [
          if (isWide)
            SizedBox(
              width: 240,
              child: _Sidebar(
                items: _navItems(inDrawer: false),
                onAddStaff: () => _openStaffRegister(inDrawer: false),
                onAddBus: () => _openBusRegister(inDrawer: false),
              ),
            ),
          Expanded(child: _buildDashboardBody(isWide: isWide)),
        ],
      ),
    );
  }

  Widget _buildDashboardBody({required bool isWide}) {
    return Container(
      color: _dashboardBg,
      child: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 24 : 16,
          vertical: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderSection(),
            const SizedBox(height: 20),
            _buildStatsSection(),
            const SizedBox(height: 20),
            _buildAnalyticsSection(),
            const SizedBox(height: 20),
            _buildAssignedTripsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 860;

        final headerText = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "HBTS Operator Dashboard",
              style: _appFont(size: 22, weight: FontWeight.w700, color: _primaryDark),
            ),
            const SizedBox(height: 6),
            Text(
              "Operational overview across staff, buses, and assigned trips.",
              style: _appFont(size: 13, weight: FontWeight.w500, color: Colors.grey.shade700),
            ),
          ],
        );

        final infoCard = _OperatorHeaderCard(
          operatorFuture: _operatorFuture,
          fallbackName: OperatorSession.operatorName,
          fallbackEmail: OperatorSession.operatorEmail,
          onRetry: _reload,
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              headerText,
              const SizedBox(height: 12),
              infoCard,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: headerText),
            const SizedBox(width: 16),
            SizedBox(width: 280, child: infoCard),
          ],
        );
      },
    );
  }

  Widget _buildStatsSection() {
    return FutureBuilder<_OperatorSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        final totalTrips = summary?.trips.length ?? 0;
        final runningTrips = summary == null
            ? 0
            : _countTrips(
                summary.trips,
                {"ongoing", "running", "in_progress"},
              );
        final completedTrips = summary == null
            ? 0
            : _countTrips(
                summary.trips,
                {"completed"},
              );

        final cards = [
          _MetricCardData(
            label: "Drivers",
            value: summary == null ? "--" : summary.drivers.length.toString(),
            footer: "Registered: ${summary?.drivers.length ?? 0}",
            accent: const Color(0xFFF9A826),
            icon: Icons.badge,
          ),
          _MetricCardData(
            label: "Conductors",
            value: summary == null ? "--" : summary.conductors.length.toString(),
            footer: "Registered: ${summary?.conductors.length ?? 0}",
            accent: const Color(0xFFEF4B76),
            icon: Icons.groups,
          ),
          _MetricCardData(
            label: "Buses",
            value: summary == null ? "--" : summary.buses.length.toString(),
            footer: "Fleet size: ${summary?.buses.length ?? 0}",
            accent: const Color(0xFF1FBF75),
            icon: Icons.directions_bus,
          ),
          _MetricCardData(
            label: "Trips",
            value: summary == null ? "--" : totalTrips.toString(),
            footer: "Running: $runningTrips | Done: $completedTrips",
            accent: const Color(0xFF3E5BFA),
            icon: Icons.route,
          ),
        ];

        final grid = _MetricGrid(cards: cards);

        if (snapshot.connectionState == ConnectionState.waiting) {
          return grid;
        }
        if (snapshot.hasError || summary == null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InlineNotice(
                icon: Icons.info_outline,
                title: "Stats unavailable",
                message: "We could not load the latest operator stats.",
                actionLabel: "Retry",
                onAction: _reload,
              ),
              const SizedBox(height: 12),
              grid,
            ],
          );
        }
        return grid;
      },
    );
  }

  Widget _buildAnalyticsSection() {
    return FutureBuilder<_OperatorSummary>(
      future: _summaryFuture,
      builder: (context, snapshot) {
        final summary = snapshot.data;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _AnalyticsSkeleton();
        }
        if (snapshot.hasError || summary == null) {
          return _InlineNotice(
            icon: Icons.warning_amber_outlined,
            title: "Insights unavailable",
            message: "Analytics could not be generated.",
            actionLabel: "Retry",
            onAction: _reload,
          );
        }

        final tripDays = _buildTripDays(summary.trips, 7);
        final busTypes = _busTypeCounts(summary.buses);
        final totalTrips = summary.trips.length;
        final runningTrips =
            _countTrips(summary.trips, {"ongoing", "running", "in_progress"});
        final delayedTrips = _countTrips(summary.trips, {"delayed"});
        final scheduledTrips = _countTrips(summary.trips, {"scheduled"});
        final completedTrips = _countTrips(summary.trips, {"completed"});
        final cancelledTrips = _countTrips(summary.trips, {"cancelled"});

        return LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 980;
            final children = [
              _SectionCard(
                title: "Trips Per Day",
                icon: Icons.stacked_line_chart,
                child: Column(
                  children: [
                    if (tripDays.every((day) => day.count == 0))
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          "No recent trips in the last 7 days.",
                          style: _appFont(size: 12, color: Colors.grey.shade700),
                        ),
                      )
                    else
                      _TripBarChart(days: tripDays),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _MetricMini(label: "Total Trips", value: "$totalTrips"),
                        _MetricMini(label: "Running", value: "$runningTrips"),
                      ],
                    ),
                  ],
                ),
              ),
              _SectionCard(
                title: "Bus Types",
                icon: Icons.donut_large,
                child: _BusTypeBreakdown(
                  typeCounts: busTypes,
                  formatLabel: _titleCase,
                ),
              ),
              _SectionCard(
                title: "Status Overview",
                icon: Icons.track_changes,
                child: Column(
                  children: [
                    _StatusBar(
                      label: "Running",
                      count: runningTrips,
                      total: totalTrips,
                      color: _primaryColor,
                    ),
                    const SizedBox(height: 10),
                    _StatusBar(
                      label: "Scheduled",
                      count: scheduledTrips,
                      total: totalTrips,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(height: 10),
                    _StatusBar(
                      label: "Delayed",
                      count: delayedTrips,
                      total: totalTrips,
                      color: Colors.orange.shade600,
                    ),
                    const SizedBox(height: 10),
                    _StatusBar(
                      label: "Completed",
                      count: completedTrips,
                      total: totalTrips,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(height: 10),
                    _StatusBar(
                      label: "Cancelled",
                      count: cancelledTrips,
                      total: totalTrips,
                      color: Colors.red.shade500,
                    ),
                  ],
                ),
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  for (final child in children) ...[
                    child,
                    const SizedBox(height: 16),
                  ]
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: children[0]),
                const SizedBox(width: 16),
                Expanded(child: children[1]),
                const SizedBox(width: 16),
                Expanded(child: children[2]),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAssignedTripsSection() {
    return _SectionCard(
      title: "Assigned Trips",
      icon: Icons.assignment,
      trailing: TextButton.icon(
        onPressed: _reload,
        icon: const Icon(Icons.refresh, size: 18),
        label: Text(
          "Refresh",
          style: _appFont(size: 12, weight: FontWeight.w600, color: _primaryColor),
        ),
        style: TextButton.styleFrom(foregroundColor: _primaryColor),
      ),
      child: _AssignedTripsSection(
        tripsFuture: _assignedFuture,
        onRetry: _reload,
        onStatusChange: _changeTripStatus,
        statusColor: _statusColor,
      ),
    );
  }
}
