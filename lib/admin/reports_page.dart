import 'package:flutter/material.dart';
import '../../services/report_api.dart';

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
              children: reportData.map((item) {
                return ListTile(
                  title: Text(item['status'].toString().toUpperCase()),
                  trailing: Text(item['total'].toString()),
                );
              }).toList(),
            ),
    );
  }
}
