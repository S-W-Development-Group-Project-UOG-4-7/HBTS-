import 'dart:async';
import 'package:flutter/material.dart';

class InAppNotificationBanner {
  static OverlayEntry? _entry;
  static Timer? _timer;

  // Used to animate out before removing overlay
  static _BannerController? _controller;

  static void show(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onTap,
    Duration duration = const Duration(seconds: 4),
  }) {
    // dismiss previous nicely
    _timer?.cancel();
    _timer = null;

    final prev = _controller;
    _controller = null;

    if (prev != null) {
      prev.dismiss(); // animated
    } else {
      _entry?.remove();
      _entry = null;
    }

    final overlay = Overlay.of(context, rootOverlay: true);

    late final OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) => _BannerWidget(
        title: title,
        message: message,
        onTap: () {
          hide();
          onTap?.call();
        },
        onClose: hide,
        onReady: (c) {
          _controller = c;
          c._bindRemove(() {
            if (_entry == entry) {
              _entry?.remove();
              _entry = null;
            }
            if (_controller == c) _controller = null;
          });
        },
      ),
    );

    _entry = entry;
    overlay.insert(entry);

    _timer = Timer(duration, hide);
  }

  static void hide() {
    _timer?.cancel();
    _timer = null;

    final c = _controller;
    _controller = null;

    if (c != null) {
      c.dismiss(); // animated
      return;
    }

    _entry?.remove();
    _entry = null;
  }
}

class _BannerController {
  _BannerController(this._dismiss);
  final Future<void> Function() _dismiss;

  VoidCallback? _removeOverlay;

  void _bindRemove(VoidCallback removeOverlay) {
    _removeOverlay = removeOverlay;
  }

  void dismiss() async {
    await _dismiss();
    _removeOverlay?.call();
  }
}

class _BannerWidget extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onTap;
  final VoidCallback onClose;

  // gives the parent a controller to dismiss with animation
  final void Function(_BannerController controller) onReady;

  const _BannerWidget({
    required this.title,
    required this.message,
    required this.onTap,
    required this.onClose,
    required this.onReady,
  });

  @override
  State<_BannerWidget> createState() => _BannerWidgetState();
}

class _BannerWidgetState extends State<_BannerWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<Offset> _slide;
  late final Animation<double> _fade;

  bool _dismissing = false;

  @override
  void initState() {
    super.initState();

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
      reverseDuration: const Duration(milliseconds: 200),
    );

    _slide = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutCubic));

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    widget.onReady(_BannerController(_dismissAnimated));

    _c.forward();
  }

  Future<void> _dismissAnimated() async {
    if (_dismissing) return;
    _dismissing = true;
    try {
      await _c.reverse();
    } catch (_) {}
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ✅ IMPORTANT FIX:
    // SafeArea already applies status-bar padding.
    // Don't add MediaQuery.padding.top again, or banner may be pushed off-screen.

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.only(top: 8), // ✅ fixed small spacing
          child: SlideTransition(
            position: _slide,
            child: FadeTransition(
              opacity: _fade,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Material(
                  color: Colors.transparent,
                  child: Dismissible(
                    key: const ValueKey('in_app_banner'),
                    direction: DismissDirection.up,
                    onDismissed: (_) => widget.onClose(),
                    child: InkWell(
                      onTap: widget.onTap,
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.blue.shade100),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 16,
                              offset: Offset(0, 6),
                              color: Color(0x22000000),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _IconBadge(),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      widget.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.blue.shade800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      widget.message,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.25,
                                        color: Colors.grey.shade800,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              InkWell(
                                onTap: widget.onClose,
                                borderRadius: BorderRadius.circular(999),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.close,
                                    size: 18,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Icon(
        Icons.notifications_active,
        color: Colors.blue.shade700,
        size: 20,
      ),
    );
  }
}
