import 'package:flutter/material.dart';
import 'driver_review_form.dart';


class DriversDashboard extends StatefulWidget {
  const DriversDashboard({super.key});

  @override
  State<DriversDashboard> createState() => _DriversDashboardState();
}

class _DriversDashboardState extends State<DriversDashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drivers Management'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Approved'),
            Tab(text: 'Pending'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          ApprovedDriversTab(),
          PendingDriversTab(),
          RejectedDriversTab(),
        ],
      ),
    );
  }
}

/* ---------------- TAB PAGES (TEMP UI) ---------------- */

class ApprovedDriversTab extends StatelessWidget {
  const ApprovedDriversTab({super.key});

  final List<Map<String, String>> approvedDrivers = const [
    {
      'name': 'Sunil Fernando',
      'license': 'A4455667',
      'operator': 'SL Bus Company',
    },
    {
      'name': 'Ruwan Perera',
      'license': 'B9988776',
      'operator': 'Private Owner',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (approvedDrivers.isEmpty) {
      return const Center(child: Text('No approved drivers'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: approvedDrivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final driver = approvedDrivers[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 4,
                offset: Offset(0, 2),
              )
            ],
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.green,
                child: Icon(Icons.check, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('License: ${driver['license']}'),
                    Text('Operator: ${driver['operator']}'),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'APPROVED',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}

class PendingDriversTab extends StatelessWidget {
  const PendingDriversTab({super.key});

  final List<Map<String, String>> pendingDrivers = const [
    {
      'name': 'Kamal Perera',
      'license': 'B1234567',
      'operator': 'SL Bus Company',
    },
    {
      'name': 'Nimal Silva',
      'license': 'C9876543',
      'operator': 'Private Owner',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (pendingDrivers.isEmpty) {
      return const Center(child: Text('No pending drivers'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: pendingDrivers.length,
      itemBuilder: (context, index) {
        final driver = pendingDrivers[index];

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.orange,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(driver['name']!),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('License: ${driver['license']}'),
                Text('Operator: ${driver['operator']}'),
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'PENDING',
                style: TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            
              onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DriverReviewForm(
        driverData: {
          'name': driver['name']!,
          'license': driver['license']!,
          'operator': driver['operator']!,
          'phone': '0771234567',
        },
      ),
    ),
  );
},

          ),
        );
      },
    );
  }
}

class RejectedDriversTab extends StatelessWidget {
  const RejectedDriversTab({super.key});

  final List<Map<String, String>> rejectedDrivers = const [
    {
      'name': 'Mahesh Kumara',
      'license': 'D3344556',
      'operator': 'Private Owner',
      'reason': 'Invalid license document',
    },
    {
      'name': 'Ajith Silva',
      'license': 'C1122334',
      'operator': 'SL Bus Company',
      'reason': 'Incomplete details',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (rejectedDrivers.isEmpty) {
      return const Center(child: Text('No rejected drivers'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: rejectedDrivers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final driver = rejectedDrivers[index];

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 24,
                backgroundColor: Colors.red,
                child: Icon(Icons.close, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      driver['name']!,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'License: ${driver['license']}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    Text(
                      'Operator: ${driver['operator']}',
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Reason: ${driver['reason']}',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'REJECTED',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }
}


