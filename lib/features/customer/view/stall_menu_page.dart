import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/menu_item.dart';
import '../../../models/stall.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../repository/stall_repository.dart';
import '../view_model/cart_vm.dart';
import 'cart_page.dart';
import 'item_detail_page.dart';

/// Menu for one stall: category sections, item rows (sold-out greyed out), and
/// a sticky "View cart" bar when this stall has items in the cart.
class StallMenuPage extends StatelessWidget {
  final Stall stall;
  const StallMenuPage({super.key, required this.stall});

  @override
  Widget build(BuildContext context) {
    final repo = StallRepository();
    return Scaffold(
      appBar: AppBar(title: Text(stall.name)),
      bottomNavigationBar: const _ViewCartBar(),
      body: StreamBuilder<List<MenuItem>>(
        stream: repo.watchMenuItems(stall.stallId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingIndicator();
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.restaurant_menu,
              title: 'No menu items yet',
              subtitle: 'This stall has not added any items.',
            );
          }
          final categories = <String, List<MenuItem>>{};
          for (final item in items) {
            final cat = item.category.isEmpty ? 'Menu' : item.category;
            categories.putIfAbsent(cat, () => []).add(item);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (stall.status != AppConstants.stallOpen)
                const _ClosedBanner(),
              for (final entry in categories.entries) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(entry.key, style: AppTextStyles.h3),
                ),
                for (final item in entry.value)
                  _MenuItemRow(
                    stall: stall,
                    item: item,
                    enabled: stall.status == AppConstants.stallOpen,
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ClosedBanner extends StatelessWidget {
  const _ClosedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warmGrey.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: AppColors.warmGrey),
          SizedBox(width: 8),
          Expanded(
            child: Text('This stall is currently closed for orders.'),
          ),
        ],
      ),
    );
  }
}

class _MenuItemRow extends StatelessWidget {
  final Stall stall;
  final MenuItem item;
  final bool enabled;

  const _MenuItemRow({
    required this.stall,
    required this.item,
    required this.enabled,
  });

  @override
  Widget build(BuildContext context) {
    final soldOut = !item.available;
    final disabled = soldOut || !enabled;
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(item.name, style: AppTextStyles.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.description.isNotEmpty)
              Text(
                item.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySecondary,
              ),
            const SizedBox(height: 4),
            Text(
              soldOut ? 'Sold out' : centsToRM(item.price),
              style: AppTextStyles.price.copyWith(
                color: soldOut ? AppColors.warmGrey : AppColors.orange,
              ),
            ),
          ],
        ),
        trailing: disabled
            ? null
            : IconButton.filledTonal(
                icon: const Icon(Icons.add),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailPage(stall: stall, item: item),
                  ),
                ),
              ),
        onTap: disabled
            ? null
            : () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ItemDetailPage(stall: stall, item: item),
                  ),
                ),
      ),
    );
  }
}

class _ViewCartBar extends StatelessWidget {
  const _ViewCartBar();

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    if (cart.isEmpty) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CartPage()),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('View cart (${cart.totalItemCount})'),
              Text(centsToRM(cart.grandTotal)),
            ],
          ),
        ),
      ),
    );
  }
}
