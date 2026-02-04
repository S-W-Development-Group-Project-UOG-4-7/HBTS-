import 'package:flutter/material.dart';
import '../../services/report_api.dart';
import '../theme/app_theme.dart';

class DriverStatusReportPage extends StatefulWidget {
  const DriverStatusReportPage({super.key});

  @override
  State<DriverStatusReportPage> createState() =>
      _DriverStatusReportPageState();
}

class _DriverStatusReportPageState extends State<DriverStatusReportPage> {
  bool loading = true;
  List data = [];

  @override
  void initState() {
    super.initState();
    loadReport();
  }

  Future<void> loadReport() async {
    final result = await ReportApi.driverStatus();
    setState(() {
      data = result;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Driver Status Report"),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
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
                      child: Icon(
                        Icons.person,
                        color: color,
                      ),
                    ),
                    title: Text(status),
                    trailing: Text(
                      item['total'].toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

