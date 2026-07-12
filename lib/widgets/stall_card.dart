import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import '../core/theme/app_colors.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/constants.dart';
import '../models/stall.dart';

class StallCard extends StatelessWidget {
  final Stall stall;
  final VoidCallback? onTap;

  const StallCard({super.key, required this.stall, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = stall.status == AppConstants.stallOpen;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                _StallImage(url: stall.imageUrl),
                Positioned(
                  top: 10,
                  right: 10,
                  child: _StatusBadge(isOpen: isOpen),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    stall.name,
                    style: AppTextStyles.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stall.cuisine.isEmpty ? 'Food' : stall.cuisine,
                    style: AppTextStyles.bodySecondary,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      RatingBarIndicator(
                        rating: stall.averageRating,
                        itemCount: 5,
                        itemSize: 16,
                        unratedColor: AppColors.divider,
                        itemBuilder: (_, _) => const Icon(
                          Icons.star,
                          color: AppColors.orange,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        stall.totalReviews > 0
                            ? '${stall.averageRating.toStringAsFixed(1)} '
                                '(${stall.totalReviews})'
                            : 'New',
                        style: AppTextStyles.caption,
                      ),
                      const Spacer(),
                      const Icon(Icons.schedule,
                          size: 14, color: AppColors.warmGrey),
                      const SizedBox(width: 4),
                      Text(
                        '${stall.prepTimeMinutes} min',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StallImage extends StatelessWidget {
  final String? url;
  const _StallImage({this.url});

  @override
  Widget build(BuildContext context) {
    const height = 120.0;
    if (url == null || url!.isEmpty) {
      return Container(
        height: height,
        width: double.infinity,
        color: AppColors.offWhite,
        child: const Icon(Icons.storefront,
            size: 48, color: AppColors.warmGrey),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        height: height,
        color: AppColors.offWhite,
      ),
      errorWidget: (_, _, _) => Container(
        height: height,
        color: AppColors.offWhite,
        child: const Icon(Icons.broken_image, color: AppColors.warmGrey),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;
  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? AppColors.teal : AppColors.warmGrey,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isOpen ? 'Open' : 'Closed',
        style: AppTextStyles.caption.copyWith(
          color: AppColors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
