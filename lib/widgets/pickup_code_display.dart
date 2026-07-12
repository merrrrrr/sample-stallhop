import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';

/// Shows the order's QR code and human-readable pickup code, for the vendor to
/// scan at collection.
class PickupCodeDisplay extends StatelessWidget {
  final String pickupCode;
  final double size;

  const PickupCodeDisplay({
    super.key,
    required this.pickupCode,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.divider),
          ),
          child: QrImageView(
            data: pickupCode,
            size: size,
            backgroundColor: AppColors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: AppColors.navy,
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: AppColors.navy,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text('Pickup code', style: AppTextStyles.caption),
        Text(
          pickupCode,
          style: AppTextStyles.h1.copyWith(
            color: AppColors.orange,
            letterSpacing: 4,
          ),
        ),
      ],
    );
  }
}
