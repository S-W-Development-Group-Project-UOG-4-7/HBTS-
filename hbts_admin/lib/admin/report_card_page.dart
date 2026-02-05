import "package:flutter/material.dart";
import "../services/report_api.dart";
import "../theme/app_theme.dart";
import "../utils/download_helper.dart";

class ReportCardPage extends StatefulWidget {
  const ReportCardPage({super.key});

  @override
  State<ReportCardPage> createState() => _ReportCardPageState();
}

class _ReportCardPageState extends State<ReportCardPage> {
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  bool _loading = true;
  bool _exporting = false;
  String? _error;

  Map<String, dynamic>? _report;
  List<Map<String, dynamic>> _trips = [];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 30));
    _fromCtrl.text = _formatDate(from);
    _toCtrl.text = _formatDate(now);
    _load();
  }

  @override
  void dispose() {
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  String _formatDate(DateTime value) {
    final y = value.year.toString().padLeft(4, "0");
    final m = value.month.toString().padLeft(2, "0");
    final d = value.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final data = await ReportApi.reportSummary(
        from: _fromCtrl.text.trim(),
        to: _toCtrl.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _report = data;
        final trips = (data["trips"] as List? ?? [])
            .cast<Map<String, dynamic>>();
        _trips = trips;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String status) {
    final value = status.toLowerCase();
    if (value.contains("schedule")) return AppColors.warning;
    if (value.contains("progress")) return AppColors.accent;
    if (value.contains("complete")) return AppColors.success;
    if (value.contains("cancel")) return AppColors.danger;
    return AppColors.primary;
  }

  String _safe(dynamic value, {String fallback = "-"}) {
    if (value == null) return fallback;
    final text = value.toString();
    return text.trim().isEmpty ? fallback : text;
  }

  String _dateOnly(dynamic value) {
    if (value == null) return "-";
    final raw = value.toString();
    return raw.contains("T") ? raw.split("T")[0] : raw;
  }

  Future<void> _exportPdf() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ReportApi.downloadSummaryPdf(
        from: _fromCtrl.text.trim(),
        to: _toCtrl.text.trim(),
      );
      final filename =
          "report-summary-${_fromCtrl.text.trim()}-to-${_toCtrl.text.trim()}.pdf";
      final path = await saveBytes(filename, bytes);
      if (!mounted) return;
      final message = path == null
          ? "PDF download started"
          : "PDF saved to $path";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportExcel() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ReportApi.downloadSummaryExcel(
        from: _fromCtrl.text.trim(),
        to: _toCtrl.text.trim(),
      );
      final filename =
          "report-summary-${_fromCtrl.text.trim()}-to-${_toCtrl.text.trim()}.xlsx";
      final path = await saveBytes(filename, bytes);
      if (!mounted) return;
      final message = path == null
          ? "Excel download started"
          : "Excel saved to $path";
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  DateTime _defaultInitialDate() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime? _parseDate(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    return DateTime.tryParse(trimmed);
  }

  String _formatDateValue(DateTime value) {
    final y = value.year.toString().padLeft(4, "0");
    final m = value.month.toString().padLeft(2, "0");
    final d = value.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final initial = _parseDate(controller.text) ?? _defaultInitialDate();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000, 1, 1),
      lastDate: DateTime(2100, 12, 31),
    );
    if (picked == null) return;
    controller.text = _formatDateValue(picked);
  }

  @override
  Widget build(BuildContext context) {
    final summary = _report?["summary"] as Map<String, dynamic>? ?? {};
    final range = _report?["range"] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(title: const Text("Report Card")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withAlpha((0.15 * 255).round()),
                    AppColors.accent.withAlpha((0.18 * 255).round()),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withAlpha((0.2 * 255).round()),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.assessment_outlined,
                      color: AppColors.primary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Passenger & Trips Report",
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Generate summaries and export as PDF or Excel.",
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fromCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(_fromCtrl),
                            decoration: const InputDecoration(
                              labelText: "From",
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _toCtrl,
                            readOnly: true,
                            onTap: () => _pickDate(_toCtrl),
                            decoration: const InputDecoration(
                              labelText: "To",
                              suffixIcon: Icon(Icons.calendar_today),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: _loading ? null : _load,
                              icon: const Icon(Icons.analytics_outlined, size: 18),
                              label: const Text("Generate Report"),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: _exporting ? null : _exportPdf,
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text("Export PDF"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.danger,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: _exporting ? null : _exportExcel,
                              icon: const Icon(Icons.grid_on, size: 18),
                              label: const Text("Export Excel"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (range.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.date_range,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Report Range: ${_safe(range["from"])} → ${_safe(range["to"])}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                _error!,
                style: const TextStyle(color: AppColors.danger),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.primary.withAlpha((0.15 * 255).round()),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.insights_outlined,
                                size: 16,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Summary",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _SummaryTile(
                              label: "Total Passengers",
                              value: _safe(summary["passengers_total"]),
                              color: AppColors.primary,
                            ),
                            _SummaryTile(
                              label: "New Passengers",
                              value: _safe(summary["passengers_new"]),
                              color: AppColors.accent,
                            ),
                            _SummaryTile(
                              label: "Total Trips",
                              value: _safe(summary["trips_total"]),
                              color: AppColors.warning,
                            ),
                            _SummaryTile(
                              label: "Scheduled",
                              value: _safe(summary["trips_scheduled"]),
                              color: AppColors.warning,
                            ),
                            _SummaryTile(
                              label: "In Progress",
                              value: _safe(summary["trips_in_progress"]),
                              color: AppColors.accent,
                            ),
                            _SummaryTile(
                              label: "Completed",
                              value: _safe(summary["trips_completed"]),
                              color: AppColors.success,
                            ),
                            _SummaryTile(
                              label: "Cancelled",
                              value: _safe(summary["trips_cancelled"]),
                              color: AppColors.danger,
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Container(
                              width: 26,
                              height: 26,
                              decoration: BoxDecoration(
                                color: AppColors.accent.withAlpha((0.18 * 255).round()),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.route_outlined,
                                size: 16,
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Trips",
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_trips.isEmpty)
                          const Center(child: Text("No trips found"))
                        else
                          ..._trips.map((trip) {
                            final tripId = _safe(
                              trip["trip_id"] ?? trip["tripId"] ?? trip["id"],
                            );
                            final routeName = _safe(
                              trip["route_name"] ??
                                  trip["routeName"] ??
                                  trip["route_code"] ??
                                  trip["routeCode"],
                            );
                            final plate = _safe(
                              trip["license_plate_no"] ??
                                  trip["license_plate"] ??
                                  trip["plate_no"],
                            );
                            final driver = _safe(
                              trip["driver_name"] ??
                                  trip["driverName"] ??
                                  trip["name"],
                            );
                            final status = _safe(trip["status"]);
                            return Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            routeName,
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _statusColor(status)
                                                .withAlpha((0.12 * 255).round()),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            status.toUpperCase(),
                                            style: TextStyle(
                                              color: _statusColor(status),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text("Trip ID: $tripId"),
                                    Text("Bus: $plate"),
                                    Text("Driver: $driver"),
                                    Text(
                                      "Date: ${_dateOnly(trip["trip_date"])}",
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.04 * 255).round()),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

