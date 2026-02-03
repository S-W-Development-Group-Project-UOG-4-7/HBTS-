import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../state/notification_store.dart';
import '../models/notification_model.dart';
import '../widgets/in_app_notification_banner.dart';

enum _NGroup { payment, booking, status, other }

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // ensure we have latest once page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationStore>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<NotificationStore>();
    final items = store.items;

    // Priority-based grouping: Payment > Booking > Status > Other
    final status = <PassengerNotification>[];
    final bookings = <PassengerNotification>[];
    final payments = <PassengerNotification>[];
    final others = <PassengerNotification>[];

    for (final n in items) {
      switch (_groupFor(n)) {
        case _NGroup.payment:
          payments.add(n);
          break;
        case _NGroup.booking:
          bookings.add(n);
          break;
        case _NGroup.status:
          status.add(n);
          break;
        case _NGroup.other:
          others.add(n);
          break;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.blue.shade700,
        foregroundColor: Colors.white,
        actions: [
          if (store.unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: _UnreadChip(count: store.unreadCount),
              ),
            ),
        ],
      ),
      body: store.loading && items.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? _EmptyState(onRefresh: store.refresh)
              : RefreshIndicator(
                  onRefresh: store.refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    children: [
                      const _TestBannerButton(),
                      const SizedBox(height: 12),
                      _Section(
                        title: "Status updates",
                        icon: Icons.warning_amber_rounded,
                        items: status,
                        onTap: (n) => _handleTap(context, store, n),
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        title: "Bookings",
                        icon: Icons.confirmation_number_outlined,
                        items: bookings,
                        onTap: (n) => _handleTap(context, store, n),
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        title: "Payments",
                        icon: Icons.payments_outlined,
                        items: payments,
                        onTap: (n) => _handleTap(context, store, n),
                      ),
                      const SizedBox(height: 14),
                      _Section(
                        title: "Other",
                        icon: Icons.notifications_none,
                        items: others,
                        onTap: (n) => _handleTap(context, store, n),
                      ),
                    ],
                  ),
                ),
    );
  }

  _NGroup _groupFor(PassengerNotification n) {
    final t = n.type.toUpperCase();
    final c = n.category.toLowerCase();

    // Payment first
    if (c == "payment" || t.contains("PAY")) return _NGroup.payment;

    // Booking next
    if (c == "booking" || t.contains("BOOK")) return _NGroup.booking;

    // Status next (do NOT treat category == system as status)
    if (t.contains("DELAY") || t.contains("CANCEL") || t.contains("STATUS")) return _NGroup.status;

    // Fallback
    return _NGroup.other;
  }

  Future<void> _handleTap(
    BuildContext context,
    NotificationStore store,
    PassengerNotification n,
  ) async {
    // Mark read in store so badge updates instantly everywhere
    await store.markRead(n.id);

    // Navigation later based on payload
    // Example (future):
    // if (n.data["tripId"] != null) Navigator.pushNamed(context, AppRoutes.tripDetails, arguments: ...);
    // if (n.data["bookingId"] != null) Navigator.pushNamed(context, AppRoutes.bookingDetails, arguments: ...);

    // For now just show a clean bottom sheet preview:
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) => _DetailsSheet(n: n),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<PassengerNotification> items;
  final void Function(PassengerNotification n) onTap;

  const _Section({
    required this.title,
    required this.icon,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.blue.shade100),
        boxShadow: const [
          BoxShadow(
            blurRadius: 16,
            offset: Offset(0, 6),
            color: Color(0x11000000),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade100),
                  ),
                  child: Icon(icon, color: Colors.blue.shade700, size: 18),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...items.map((n) => _NotificationTile(n: n, onTap: () => onTap(n))),
          ],
        ),
      ),
    );
  }
}

class _TestBannerButton extends StatelessWidget {
  const _TestBannerButton();

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        final ctx = navigatorKey.currentContext;
        debugPrint("CTX = $ctx");
        InAppNotificationBanner.show(
          ctx!,
          title: "Manual Test",
          message: "If you see this, banner works",
        );
      },
      child: const Text("Test Popup"),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final PassengerNotification n;
  final VoidCallback onTap;

  const _NotificationTile({required this.n, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final time = _formatTime(n.createdAt);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: n.isRead ? Colors.white : Colors.blue.shade50.withAlpha((0.55 * 255).round()),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: n.isRead ? Colors.black12 : Colors.blue.shade200,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeftDot(isRead: n.isRead),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              n.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: Colors.grey.shade900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n.message,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right, color: Colors.grey.shade500),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return "$h:$m";
  }
}

class _LeftDot extends StatelessWidget {
  final bool isRead;
  const _LeftDot({required this.isRead});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: isRead ? Colors.transparent : Colors.blue.shade700,
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: isRead ? Colors.black12 : Colors.blue.shade700,
        ),
      ),
    );
  }
}

class _UnreadChip extends StatelessWidget {
  final int count;
  const _UnreadChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha((0.20 * 255).round()),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withAlpha((0.35 * 255).round())),
      ),
      child: Text(
        "$count new",
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final Future<void> Function() onRefresh;
  const _EmptyState({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _TestBannerButton(),
            const SizedBox(height: 12),
            Icon(Icons.notifications_none, size: 54, color: Colors.blue.shade200),
            const SizedBox(height: 12),
            Text(
              "No notifications yet",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "When a trip is delayed/cancelled, or a booking/payment updates,\nyou'll see it here instantly.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh"),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsSheet extends StatelessWidget {
  final PassengerNotification n;
  const _DetailsSheet({required this.n});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            n.message,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 10),
          if (n.data.isNotEmpty) ...[
            const Divider(),
            Text(
              "Payload",
              style: TextStyle(
                fontWeight: FontWeight.w900,
                color: Colors.grey.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              n.data.toString(),
              style: TextStyle(
                fontFamily: "monospace",
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.check),
              label: const Text(
                "OK",
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

