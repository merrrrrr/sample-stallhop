import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/constants.dart';

/// Horizontal Preparing → Ready → Collected stepper. A cancelled order shows a
/// single cancelled state instead.
class OrderStatusStepper extends StatelessWidget {
  final String status;
  const OrderStatusStepper({super.key, required this.status});

  static const _steps = [
    (AppConstants.orderPreparing, 'Preparing', Icons.soup_kitchen),
    (AppConstants.orderReady, 'Ready', Icons.check_circle_outline),
    (AppConstants.orderCollected, 'Collected', Icons.shopping_bag),
  ];

  int get _currentIndex {
    final idx = _steps.indexWhere((s) => s.$1 == status);
    return idx < 0 ? 0 : idx;
  }

  @override
  Widget build(BuildContext context) {
    if (status == AppConstants.orderCancelled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: const [
            Icon(Icons.cancel, color: AppColors.error),
            SizedBox(width: 8),
            Text('Order cancelled'),
          ],
        ),
      );
    }

    return Row(
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          _StepNode(
            label: _steps[i].$2,
            icon: _steps[i].$3,
            done: i <= _currentIndex,
            active: i == _currentIndex,
          ),
          if (i < _steps.length - 1)
            Expanded(
              child: Container(
                height: 3,
                color: i < _currentIndex
                    ? AppColors.teal
                    : AppColors.divider,
              ),
            ),
        ],
      ],
    );
  }
}

class _StepNode extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool done;
  final bool active;

  const _StepNode({
    required this.label,
    required this.icon,
    required this.done,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = done ? AppColors.teal : AppColors.warmGrey;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: done ? AppColors.teal : AppColors.divider,
          child: Icon(
            icon,
            color: done ? AppColors.white : AppColors.warmGrey,
            size: 20,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: color,
            fontWeight: active ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
