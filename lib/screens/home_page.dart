import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/token_store.dart';
import '../services/user_api.dart';
import '../models/user_model.dart';
import '../app_routes.dart' as routes;
import '../state/notification_store.dart';
import '../api/booking_api.dart';
import '../models/my_booking_item.dart';
import 'booking_details_page.dart';
import 'schedule_page.dart';


class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  AppUser? _user;

  int _navIndex = 0;
  UpcomingTripUiModel? _upcomingTrip;
  MyBookingItem? _upcomingBooking;
  final TextEditingController _fromSearchCtrl = TextEditingController();
  final TextEditingController _toSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initHome();
  }

  @override
  void dispose() {
    _fromSearchCtrl.dispose();
    _toSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _initHome() async {
    await Future.delayed(Duration.zero);

    final loggedIn = await TokenStore.isLoggedIn();
    final isAdmin = await TokenStore.isAdmin();

    if (!loggedIn || isAdmin) {
      _goLogin();
      return;
    }

    try {
      final me = await UserApi.fetchLoggedInUser();
      // Attempt to fetch bookings to compute nearest upcoming
      List<MyBookingItem> myBookings = const [];
      try {
        myBookings = await BookingApi.getMyBookings();
      } catch (_) {}

      final now = DateTime.now();
      final nowLocal = now;
      debugPrint("upcoming count before filter = ${myBookings.length}");
      for (final b in myBookings) {
        debugPrint(
          "HOME booking ${b.bookingId} tripStatus=${b.tripStatus} "
          "depUtc=${b.departureTime} depLocal=${b.departureTime.toLocal()} now=$nowLocal",
        );
      }
      final upcoming = myBookings
          .where((b) {
            final trip = b.tripStatus.toLowerCase().trim();
            final st = b.status.toLowerCase().trim();
            if (trip == 'cancelled' || st == 'cancelled' || trip == 'completed') return false;
            return b.departureTime.toLocal().isAfter(now);
          })
          .toList()
        ..sort((a, b) => a.departureTime.compareTo(b.departureTime));
      debugPrint("upcoming count after filter = ${upcoming.length}");

      UpcomingTripUiModel? up;
      MyBookingItem? upBooking;
      if (upcoming.isNotEmpty) {
        final first = upcoming.first;
        final dep = first.departureTime.toLocal();
        final dateText = "${dep.day.toString().padLeft(2, '0')}/${dep.month.toString().padLeft(2, '0')}/${dep.year}";
        final hh = ((dep.hour % 12 == 0) ? 12 : (dep.hour % 12));
        final mm = dep.minute.toString().padLeft(2, '0');
        final ampm = dep.hour >= 12 ? 'PM' : 'AM';
        final timeText = "$hh:$mm $ampm";
        up = UpcomingTripUiModel(
          from: first.fromLocation,
          to: first.toLocation,
          dateText: dateText,
          timeText: timeText,
          seatText: "Seat: ${first.seatLabel}",
          status: first.tripStatus,
        );
        upBooking = first;
      }

      if (!mounted) return;
      debugPrint("HOME upcomingTrip is ${up != null ? 'NOT NULL' : 'NULL'}");
      setState(() {
        _user = me;
        _upcomingTrip = up;
        _upcomingBooking = upBooking;
        _loading = false;
      });
    } catch (e) {
      debugPrint("HOME INIT ERROR => $e");
      if (!mounted) return;
      if (e.toString().contains("AUTH_EXPIRED")) {
        await TokenStore.clear();
        _goLogin();
        return;
      }
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
    Navigator.pushNamedAndRemoveUntil(context, routes.AppRoutes.login, (_) => false);
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
      routes.AppRoutes.profile,
      arguments: routes.ProfileArgs(
        id: u.id,
        name: u.name,
        email: u.email,
        phone: u.phone,
        photoUrl: u.profileImage,
      ),
    );
  }

  // -------------------------
  // Navigation targets (routes you already have)
  // -------------------------
  void _goReserve() => Navigator.pushNamed(context, routes.AppRoutes.schedule);
  void _goBookings() => Navigator.pushNamed(context, routes.AppRoutes.myBookings);

  // This should become your "Upcoming Schedules (today)" page later.
  // For now it can go to myBookings so you don't break anything.
void _goUpcomingSchedules() {
  final route = routes.AppRoutes.upcomingToday;
  if (route != null) {
    Navigator.pushNamed(context, route);
  }
}

  void _goTrackBooking() => Navigator.pushNamed(context, routes.AppRoutes.trackMyBooking);
  void _goTrackBus() => Navigator.pushNamed(context, routes.AppRoutes.trackBus);

  void _searchSchedules() {
    final from = _fromSearchCtrl.text.trim();
    final to = _toSearchCtrl.text.trim();
    if (from.isEmpty || to.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter From and To locations")),
      );
      return;
    }

    Navigator.pushNamed(
      context,
      routes.AppRoutes.schedule,
      arguments: ScheduleArgs(from: from, to: to),
    );
  }

  // Nearest trip card → booking details
  // Wire args later using your existing logic/models.
  void _goNearestTripDetails() {
    final b = _upcomingBooking;
    if (b == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingDetailsPage(item: b)),
    );
  }

  void _onBottomNavTap(int index) {
    setState(() => _navIndex = index);

    // Bottom nav behavior:
    // - Home stays here
    // - Reserve center button opens schedule
    // - Others route to their pages
    switch (index) {
      case 0:
        return;
      case 1:
        _goBookings();
        return;
      case 2:
        _goReserve(); // center +
        return;
      case 3:
        _goTrackBooking();
        return;
      case 4:
        _openProfile();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
    final hasPhoto = user.profileImage != null && user.profileImage!.trim().isNotEmpty;

    final UpcomingTripUiModel? upcomingTrip = _upcomingTrip;

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAFF),
      body: Column(
        children: [
          _StylishTopBar(
            hasPhoto: hasPhoto,
            userName: user.name,
            photoUrl: user.profileImage,
            onNotifications: () {
              Navigator.pushNamed(context, routes.AppRoutes.notifications);
            },
            onProfile: _openProfile,
            onLogout: _logout,
          ),
          Expanded(
            child: _HomeBody(
              userName: user.name,
              upcomingTrip: upcomingTrip,
              onUpcomingTripTap: _goNearestTripDetails,
              onSearch: _searchSchedules,
              onUpcomingSchedules: _goUpcomingSchedules,
              onTrackBooking: _goTrackBooking,
              onTrackBus: _goTrackBus,
              fromCtrl: _fromSearchCtrl,
              toCtrl: _toSearchCtrl,
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SpotlightBottomNav(
        selectedIndex: _navIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

// ------------------------------------
// UI MODELS (wire real data later)
// ------------------------------------
class UpcomingTripUiModel {
  final String from;
  final String to;
  final String dateText;
  final String timeText;
  final String seatText;
  final String status;

  const UpcomingTripUiModel({
    required this.from,
    required this.to,
    required this.dateText,
    required this.timeText,
    required this.seatText,
    required this.status,
  });
}

// ------------------------------------
// TOP BAR (stylish strip w/ rounded bottom)
// ------------------------------------
class _StylishTopBar extends StatelessWidget {
  final bool hasPhoto;
  final String userName;
  final String? photoUrl;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onLogout;

  const _StylishTopBar({
    required this.hasPhoto,
    required this.userName,
    required this.photoUrl,
    required this.onNotifications,
    required this.onProfile,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      padding: EdgeInsets.fromLTRB(16, topPadding + 10, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade600,
          ],
        ),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(22),
          bottomRight: Radius.circular(22),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.10 * 255).round()),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          // App icon bubble
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withAlpha((0.18 * 255).round()),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withAlpha((0.25 * 255).round())),
            ),
            child: const Icon(Icons.directions_bus_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              "HBTS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
          ),

          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                tooltip: "Notifications",
                onPressed: onNotifications,
                icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              ),
              Positioned(
                right: 10,
                top: 10,
                child: Selector<NotificationStore, int>(
                  selector: (_, store) => store.unreadCount,
                  builder: (context, unreadCount, child) {
                    if (unreadCount <= 0) return const SizedBox.shrink();
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),

          GestureDetector(
            onTap: onProfile,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: Colors.white.withAlpha((0.22 * 255).round()),
              backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
              child: !hasPhoto
                  ? Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : "U",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    )
                  : null,
            ),
          ),

          const SizedBox(width: 6),

          IconButton(
            tooltip: "Logout",
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------
// BODY (no section headers; action-driven)
// ------------------------------------
class _HomeBody extends StatelessWidget {
  final String userName;

  // upcoming trip card first after welcome (if available)
  final UpcomingTripUiModel? upcomingTrip;
  final VoidCallback onUpcomingTripTap;

  final VoidCallback onSearch;
  final VoidCallback onUpcomingSchedules;
  final VoidCallback onTrackBooking;
  final VoidCallback onTrackBus;
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;

  const _HomeBody({
    required this.userName,
    required this.upcomingTrip,
    required this.onUpcomingTripTap,
    required this.onSearch,
    required this.onUpcomingSchedules,
    required this.onTrackBooking,
    required this.onTrackBus,
    required this.fromCtrl,
    required this.toCtrl,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint("HOME BODY upcomingTrip = ${upcomingTrip == null ? 'NULL' : 'HAS DATA'}");

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
      children: [
        // Welcome message (clean, colorful)
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.blue.shade50,
                Colors.blue.shade100.withAlpha((0.55 * 255).round()),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "${_timeGreeting()}, $userName 👋",
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                "Ready for your next trip?",
                style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 1) Upcoming trip card FIRST (or empty state)
        if (upcomingTrip != null) ...[
          _UpcomingTripCard(trip: upcomingTrip!, onTap: onUpcomingTripTap),
          const SizedBox(height: 14),
        ] else ...[
          _EmptyUpcomingCard(onTapReserve: onSearch),
          const SizedBox(height: 14),
        ],


        // 2) Search card
        Container(
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.blue.shade100),
          ),
          child: _CardShell(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Find Your Bus",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 14),
                _InputLikeTile(
                  icon: Icons.location_on_outlined,
                  label: "From",
                  controller: fromCtrl,
                ),
                const SizedBox(height: 10),
                _InputLikeTile(
                  icon: Icons.location_on_outlined,
                  label: "To",
                  controller: toCtrl,
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onSearch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700, // Changed to blue to match design
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text(
                      "Search Buses",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // 3) Two action buttons (no section header)
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 90, // Fixed height for both action tiles
                child: _ActionTile(
                  icon: Icons.calendar_month_rounded,
                  title: "Upcoming trips",
                  subtitle: "",
                  onTap: onUpcomingSchedules,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 90, // Fixed height for both action tiles
                child: _ActionTile(
                  icon: Icons.my_location_rounded,
                  title: "Track my booking",
                  subtitle: "",
                  onTap: onTrackBooking,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 14),

        // 4) Track a bus (without booking)
        _BigActionCard(
          icon: Icons.directions_bus_filled_rounded,
          title: "Track a bus",
          subtitle: "Without a booking",
          onTap: onTrackBus,
        ),
      ],
    );
  }

  String _timeGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return "Good morning";
    if (h < 17) return "Good afternoon";
    return "Good evening";
  }
}

// ------------------------------------
// Cards / Tiles
// ------------------------------------
class _CardShell extends StatelessWidget {
  final Widget child;
  const _CardShell({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha((0.06 * 255).round()),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _InputLikeTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final TextEditingController controller;

  const _InputLikeTile({
    required this.icon,
    required this.label,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          border: InputBorder.none,
          prefixIcon: Icon(icon, color: Colors.blue.shade700),
          hintText: label,
          hintStyle: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w600),
        ),
        textInputAction: label == "From" ? TextInputAction.next : TextInputAction.search,
      ),
    );
  }
}

class _UpcomingTripCard extends StatelessWidget {
  final UpcomingTripUiModel trip;
  final VoidCallback onTap;

  const _UpcomingTripCard({required this.trip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue.shade700;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [blue, Colors.blue.shade500]),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.10 * 255).round()),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "${trip.from}  →  ${trip.to}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade400,
                    border: Border.all(color: Colors.red, width: 2),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    trip.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(trip.dateText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const SizedBox(width: 16),
                const Icon(Icons.schedule_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(trip.timeText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.event_seat_rounded, size: 18, color: Colors.white),
                const SizedBox(width: 6),
                Text(trip.seatText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                const Spacer(),
                const Text(
                  "View details →",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyUpcomingCard extends StatelessWidget {
  final VoidCallback onTapReserve;

  const _EmptyUpcomingCard({required this.onTapReserve});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.event_busy_rounded, color: Colors.blue.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "No upcoming trips yet",
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  "Reserve a seat to see it here.",
                  style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton(
            onPressed: onTapReserve,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.blue.shade700,
              side: BorderSide(color: Colors.blue.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Reserve"),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.blue.shade100), // Blue border
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withAlpha((0.08 * 255).round()), // Blue-tinted shadow
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.blue.shade100, // Stronger blue background
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.blue.shade800), // Slightly darker icon for better contrast
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Center(
                child: Text(
                  title, 
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _BigActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade100, // Neutral grey background
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.grey.shade300), // Slightly darker border
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((0.06 * 255).round()),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey.shade200, // Neutral grey for the icon background
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Icon(icon, color: Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: Colors.grey.shade700),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------
// BOTTOM NAV with center spotlight (+)
// Index mapping: 0 Home, 1 Bookings, 2 Reserve, 3 Track, 4 Profile
// ------------------------------------
class _SpotlightBottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _SpotlightBottomNav({
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue.shade700;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        child: SizedBox(
          height: 90, // ✅ give room so + button is never clipped
          child: Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.none,
            children: [
              // Bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  height: 66,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((0.10 * 255).round()),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      _NavItem(
                        icon: Icons.home_rounded,
                        label: "Home",
                        active: selectedIndex == 0,
                        onTap: () => onTap(0),
                      ),
                      _NavItem(
                        icon: Icons.receipt_long,
                        label: "Bookings",
                        active: selectedIndex == 1,
                        onTap: () => onTap(1),
                      ),
                      const SizedBox(width: 74), // space for center button
                      _NavItem(
                        icon: Icons.my_location_rounded,
                        label: "Track",
                        active: selectedIndex == 3,
                        onTap: () => onTap(3),
                      ),
                      _NavItem(
                        icon: Icons.person_rounded,
                        label: "Profile",
                        active: selectedIndex == 4,
                        onTap: () => onTap(4),
                      ),
                    ],
                  ),
                ),
              ),

              // Center spotlight button
              Positioned(
                bottom: 10, // ✅ lowered so it sits nicer and doesn't clip
                child: GestureDetector(
                  onTap: () => onTap(2),
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: blue.withAlpha((0.35 * 255).round()),
                          blurRadius: 22,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: Colors.white, size: 34),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final blue = Colors.blue.shade700;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: active ? blue : Colors.grey.shade600),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: active ? blue : Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

