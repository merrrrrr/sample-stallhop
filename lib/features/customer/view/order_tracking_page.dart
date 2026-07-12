import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/order_status_stepper.dart';
import '../../../widgets/pickup_code_display.dart';
import '../view_model/order_tracking_vm.dart';
import 'review_page.dart';

class OrderTrackingPage extends StatelessWidget {
  final String orderId;
  const OrderTrackingPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrderTrackingViewModel(orderId),
      child: const _OrderTrackingView(),
    );
  }
}

class _OrderTrackingView extends StatelessWidget {
  const _OrderTrackingView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderTrackingViewModel>();
    final order = vm.order;
    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: vm.isLoading
          ? const LoadingIndicator()
          : order == null
              ? const Center(child: Text('Order not found'))
              : _Body(order: order),
    );
  }
}

class _Body extends StatelessWidget {
  final FoodOrder order;
  const _Body({required this.order});

  @override
  Widget build(BuildContext context) {
    final isReady = order.status == AppConstants.orderReady;
    final isCollected = order.status == AppConstants.orderCollected;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(order.stallName, style: AppTextStyles.h3),
                const SizedBox(height: 16),
                OrderStatusStepper(status: order.status),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (isReady)
          Card(
            color: AppColors.tealLight,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.notifications_active,
                      color: AppColors.teal, size: 32),
                  const SizedBox(height: 8),
                  Text('Your order is ready!',
                      style: AppTextStyles.h3
                          .copyWith(color: AppColors.teal)),
                  const SizedBox(height: 4),
                  Text('Show this code at the stall to collect.',
                      style: AppTextStyles.bodySecondary,
                      textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  PickupCodeDisplay(pickupCode: order.pickupCode),
                ],
              ),
            ),
          )
        else if (!isCollected &&
            order.status != AppConstants.orderCancelled)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: PickupCodeDisplay(
                  pickupCode: order.pickupCode,
                  size: 160,
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Items', style: AppTextStyles.title),
                const Divider(),
                for (final item in order.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text('${item.quantity}× ${item.name}'),
                        ),
                        Text(centsToRM(item.subtotal)),
                      ],
                    ),
                  ),
                const Divider(),
                _row('Subtotal', centsToRM(order.subtotal)),
                _row('Service fee', centsToRM(order.serviceFee)),
                const SizedBox(height: 4),
                _row('Total', centsToRM(order.total), bold: true),
              ],
            ),
          ),
        ),
        if (isCollected) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.star_outline),
            label: const Text('Leave a review'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ReviewPage(order: order)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? AppTextStyles.title : AppTextStyles.body;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
