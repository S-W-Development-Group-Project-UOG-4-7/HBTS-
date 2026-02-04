import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/conductor_store.dart';

import 'conductor_home_page.dart';
import 'scan_qr_page.dart';
import 'conductor_notifications_page.dart';
import 'conductor_more_page.dart';

class ConductorShell extends StatefulWidget {
  const ConductorShell({super.key});

  @override
  State<ConductorShell> createState() => _ConductorShellState();
}

class _ConductorShellState extends State<ConductorShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // start ws once for conductor module
      context.read<ConductorStore>().startRealtime();

    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const ConductorHomePage(),
      const ConductorScanPage(),
      const ConductorNotificationsPage(),
      const ConductorMorePage(),
    ];

    return Scaffold(
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.route_rounded), label: "Trip"),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner_rounded), label: "Scan"),
          NavigationDestination(icon: Icon(Icons.notifications_none_rounded), label: "Notifications"),
          NavigationDestination(icon: Icon(Icons.more_horiz_rounded), label: "More"),
        ],
      ),
    );
  }
}
