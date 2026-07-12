import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Friendly placeholder for empty lists ("No orders yet", etc.).
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Full layout needs ~200px of height; fall back to a smaller icon and
        // tighter spacing when hosted in short containers (e.g. fixed-height
        // dashboard cards) so the Column never overflows.
        final compact =
            constraints.maxHeight.isFinite && constraints.maxHeight < 200;
        return Center(
          child: Padding(
            padding: EdgeInsets.all(compact ? 12 : 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon,
                    size: compact ? 32 : 64, color: AppColors.warmGrey),
                SizedBox(height: compact ? 8 : 16),
                Text(title,
                    style: compact ? AppTextStyles.title : AppTextStyles.h3,
                    textAlign: TextAlign.center),
                if (subtitle != null && !compact) ...[
                  const SizedBox(height: 8),
                  Text(
                    subtitle!,
                    style: AppTextStyles.bodySecondary,
                    textAlign: TextAlign.center,
                  ),
                ],
                if (action != null) ...[
                  SizedBox(height: compact ? 12 : 20),
                  action!,
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
