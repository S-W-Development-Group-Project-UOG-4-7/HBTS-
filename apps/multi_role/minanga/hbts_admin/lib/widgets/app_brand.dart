import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppBrand extends StatelessWidget {
  final String title;
  final String subtitle;

  const AppBrand({
    super.key,
    this.title = "HBTS+",
    this.subtitle = "Admin Console",
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.15 * 255).round()),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.support_agent_rounded,
            color: AppColors.accent,
            size: 48,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
        ),
      ],
    );
  }
}

