import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/pickup_code_display.dart';
import 'order_tracking_page.dart';

/// Confirmation after checkout. Shows a success header plus a QR + pickup code
/// and summary for each order placed (one per stall).
class OrderPlacedPage extends StatelessWidget {
  final List<FoodOrder> orders;
  const OrderPlacedPage({super.key, required this.orders});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Order placed'),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Done'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          const Icon(Icons.check_circle, color: AppColors.teal, size: 64),
          const SizedBox(height: 8),
          Text(
            orders.length == 1
                ? 'Order placed!'
                : '${orders.length} orders placed!',
            style: AppTextStyles.h2,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Show your pickup code at the stall when ready.',
            style: AppTextStyles.bodySecondary,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          for (final order in orders) _OrderCard(order: order),
        ],
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final FoodOrder order;
  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(order.stallName, style: AppTextStyles.h3),
            const SizedBox(height: 16),
            PickupCodeDisplay(pickupCode: order.pickupCode),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total paid', style: AppTextStyles.bodySecondary),
                Text(centsToRM(order.total), style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => OrderTrackingPage(orderId: order.orderId),
                ),
              ),
              child: const Text('Track order'),
            ),
          ],
        ),
      ),
    );
  }
}
