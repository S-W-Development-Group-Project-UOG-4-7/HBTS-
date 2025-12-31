import 'package:flutter/material.dart';

import '../services/token_store.dart';
import '../services/user_api.dart';
import '../models/user_model.dart';
import '../app_routes.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  AppUser? _user;

  @override
  void initState() {
    super.initState();
    _initHome();
  }

  Future<void> _initHome() async {
    // (Optional) tiny yield to let storage finish writes in some flows
    await Future.delayed(Duration.zero);

    final loggedIn = await TokenStore.isLoggedIn();
    final isAdmin = await TokenStore.isAdmin();

    // Passenger app only; admins go to admin area (or login)
    if (!loggedIn || isAdmin) {
      _goLogin();
      return;
    }

    try {
      final me = await UserApi.fetchLoggedInUser();
      if (!mounted) return;
      setState(() {
        _user = me;
        _loading = false;
      });
    } catch (e) {
      // Stop infinite spinner + show a message
      debugPrint("HOME INIT ERROR => $e");
      if (!mounted) return;
      setState(() {
        _loading = false;
        _user = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to load profile: $e")),
      );
    }
  }

  void _goLogin() {
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(
      context,
      AppRoutes.login,
      (_) => false,
    );
  }

  Future<void> _logout() async {
    await TokenStore.clear();
    _goLogin();
  }

  void _openProfile() {
    final u = _user;
    if (u == null) return;

    Navigator.pushNamed(
      context,
      AppRoutes.profile,
      arguments: ProfileArgs(
        id: u.id,
        name: u.name,
        email: u.email,
        phone: u.phone,
        photoUrl: u.profileImage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // If loading finished but user is still null, show a safe error UI
    if (_user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("HBTS")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 48),
                const SizedBox(height: 12),
                const Text(
                  "Couldn't reach server / load profile.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _initHome,
                    child: const Text("Retry"),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _logout,
                    child: const Text("Logout"),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = _user!;
    final hasPhoto =
        user.profileImage != null && user.profileImage!.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("HBTS"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () async {
               await _logout();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openProfile,
              child: CircleAvatar(
                radius: 18,
                backgroundImage: hasPhoto
                  ? NetworkImage(user.profileImage!)
                  : null,
                child: !hasPhoto
                  ? Text(
                    user.name.isNotEmpty
                      ? user.name[0].toUpperCase()
                      : "U",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
              ),
            ),
          ),
        ],

      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 👋 Welcome Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.shade100),
            ),
            child: Text(
              "Welcome, ${user.name} 👋",
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 🚀 Main Actions
          GridView.count(
            crossAxisCount: MediaQuery.of(context).size.width > 900 ? 4 : 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              _ActionCard(
                icon: Icons.schedule,
                title: "Schedule",
                subtitle: "Search buses & book seats",
                onTap: () => Navigator.pushNamed(context, AppRoutes.schedule),
              ),
              _ActionCard(
                icon: Icons.receipt_long,
                title: "My Bookings",
                subtitle: "Tickets & history",
                onTap: () => Navigator.pushNamed(context, AppRoutes.myBookings),
              ),
              _ActionCard(
                icon: Icons.location_searching,
                title: "Track My Booking",
                subtitle: "Track using booking",
                onTap: () => Navigator.pushNamed(context, AppRoutes.trackMyBooking),
              ),
              _ActionCard(
                icon: Icons.directions_bus,
                title: "Track a Bus",
                subtitle: "Without booking",
                onTap: () => Navigator.pushNamed(context, AppRoutes.trackBus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 32, color: Colors.blue.shade700),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
