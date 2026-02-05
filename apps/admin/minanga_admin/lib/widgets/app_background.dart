import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBackground extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final bool showSkyline;

  const AppBackground({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    this.showSkyline = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppGradients.background),
      child: Stack(
        children: [
          const Positioned(
            top: -80,
            left: -40,
            child: _GlowOrb(size: 180),
          ),
          const Positioned(
            top: 120,
            right: -60,
            child: _GlowOrb(size: 140),
          ),
          if (showSkyline)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _Skyline(),
            ),
          SafeArea(
            child: Padding(
              padding: padding,
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final double size;

  const _GlowOrb({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: AppGradients.glow,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Skyline extends StatelessWidget {
  const _Skyline();

  Widget _bar(double height, double radius) {
    return Expanded(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF7E97FF).withAlpha((0.55 * 255).round()),
            borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 110,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _bar(50, 10),
          _bar(72, 14),
          _bar(60, 12),
          _bar(90, 16),
          _bar(40, 10),
          _bar(82, 14),
          _bar(64, 12),
          _bar(78, 12),
          _bar(48, 10),
        ],
      ),
    );
  }
}

