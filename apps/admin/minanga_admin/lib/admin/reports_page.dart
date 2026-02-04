import 'package:flutter/material.dart';
import '../../services/report_api.dart';
import '../theme/app_theme.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  List reportData = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    final data = await ReportApi.driverStatus();
    setState(() {
      reportData = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Status Report")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: reportData.map((item) {
                final status = item['status'].toString().toUpperCase();
                final color = status == "APPROVED"
                    ? AppColors.success
                    : status == "PENDING"
                        ? AppColors.warning
                        : AppColors.danger;
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color.withAlpha((0.15 * 255).round()),
                      child: Icon(Icons.bar_chart, color: color),
                    ),
                    title: Text(status),
                    trailing: Text(
                      item['total'].toString(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
    );
  }
}

