import 'package:flutter/material.dart';
import '../services/admin_api.dart';

class CustomerDetailsPage extends StatefulWidget {
  final int userId;

  const CustomerDetailsPage({super.key, required this.userId});

  @override
  State<CustomerDetailsPage> createState() => _CustomerDetailsPageState();
}

class _CustomerDetailsPageState extends State<CustomerDetailsPage> {
  Map<String, dynamic>? customer;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCustomer();
  }

  Future<void> _loadCustomer() async {
    try {
      final data = await AdminApi.fetchPassengerDetails(widget.userId);
      if (!mounted) return;
      setState(() {
        customer = data;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  // ================= ADD =================
  Future<void> _addPassenger() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Passenger"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(labelText: "Email"),
              ),
              TextField(
                controller: phoneCtrl,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(labelText: "Password"),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AdminApi.addPassenger({
        "name": nameCtrl.text.trim(),
        "email": emailCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
        "password": passCtrl.text,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passenger added successfully")),
      );

      // 👈 IMPORTANT: go back so list reloads
      Navigator.pop(context);
    }
  }

  // ================= UPDATE =================
  Future<void> _updatePassenger() async {
    if (customer == null) return;

    final nameCtrl = TextEditingController(text: customer!["name"]);
    final phoneCtrl = TextEditingController(text: customer!["phone"]);

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Update Passenger"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: phoneCtrl,
              decoration: const InputDecoration(labelText: "Phone"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Update"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AdminApi.updatePassenger(widget.userId, {
        "name": nameCtrl.text.trim(),
        "phone": phoneCtrl.text.trim(),
      });

      // 🔄 reload from backend (THIS FIXES UPDATE VISIBILITY)
      await _loadCustomer();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passenger updated successfully")),
      );
    }
  }

  // ================= DELETE =================
  Future<void> _deletePassenger() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Passenger"),
        content: const Text(
          "Are you sure you want to delete this passenger?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (ok == true) {
      await AdminApi.deletePassenger(widget.userId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passenger deleted successfully")),
      );

      Navigator.pop(context); // 👈 back to list
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(child: Text(_error!)),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Customer Details")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              customer!["name"] ?? "-",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(customer!["email"] ?? "-"),
            const SizedBox(height: 4),
            Text("Phone: ${customer!["phone"] ?? "-"}"),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                  onPressed: _addPassenger,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.edit),
                  label: const Text("Update"),
                  onPressed: _updatePassenger,
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text("Delete"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                  ),
                  onPressed: _deletePassenger,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
