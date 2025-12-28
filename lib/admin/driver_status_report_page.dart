import 'package:flutter/material.dart';
import '../../services/report_api.dart';

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
              itemCount: data.length,
              itemBuilder: (context, index) {
                final item = data[index];
                return ListTile(
                  title: Text(item['status'].toString().toUpperCase()),
                  trailing: Text(
                    item['total'].toString(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
            ),
    );
  }
}
