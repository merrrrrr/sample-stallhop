import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/order_status_stepper.dart';
import '../../../widgets/qr_scanner_widget.dart';
import '../view_model/order_detail_vm.dart';

/// Vendor order detail with pickup verification. When the order is Ready, the
/// vendor scans the customer's QR; a match enables "Complete" (→ collected).
/// Cancelling triggers an automatic refund.
class VendorOrderDetailPage extends StatelessWidget {
  final String orderId;
  const VendorOrderDetailPage({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VendorOrderDetailViewModel(orderId),
      child: const _DetailView(),
    );
  }
}

class _DetailView extends StatefulWidget {
  const _DetailView();

  @override
  State<_DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<_DetailView> {
  bool _verified = false;

  Future<void> _scan(FoodOrder order) async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScannerPage()),
    );
    if (code == null || !mounted) return;
    final match = code.trim() == order.pickupCode.trim();
    setState(() => _verified = match);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(match
            ? 'Code verified ✓ — you can complete the order.'
            : 'Code mismatch. Scanned "$code".'),
        backgroundColor: match ? AppColors.teal : AppColors.error,
      ),
    );
  }

  Future<void> _complete(
    VendorOrderDetailViewModel vm,
    String orderId,
  ) async {
    await vm.markCollected(orderId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order completed')),
      );
    }
  }

  Future<void> _cancel(
    VendorOrderDetailViewModel vm,
    FoodOrder order,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel order?'),
        content: const Text(
          'The customer will be automatically refunded the full amount.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep order'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel & refund'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await vm.cancel(order);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order cancelled and refunded')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorOrderDetailViewModel>();
    final order = vm.order;
    return Scaffold(
      appBar: AppBar(title: const Text('Order')),
      body: vm.isLoading
          ? const LoadingIndicator()
          : order == null
              ? const Center(child: Text('Order not found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('#${order.pickupCode}',
                                    style: AppTextStyles.h2.copyWith(
                                        color: AppColors.orange)),
                                Text(order.status,
                                    style: AppTextStyles.title),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Customer: ${order.customerName}',
                                style: AppTextStyles.bodySecondary),
                            Text('Placed ${formatDateTime(order.createdAt)}',
                                style: AppTextStyles.caption),
                            const SizedBox(height: 16),
                            OrderStatusStepper(status: order.status),
                          ],
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
                              _ItemRow(item: item),
                            const Divider(),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Total', style: AppTextStyles.title),
                                Text(centsToRM(order.total),
                                    style: AppTextStyles.title),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _Actions(
                      order: order,
                      verified: _verified,
                      onMarkReady: () => vm.markReady(order.orderId),
                      onScan: () => _scan(order),
                      onComplete: () => _complete(vm, order.orderId),
                      onCancel: () => _cancel(vm, order),
                    ),
                  ],
                ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  final dynamic item;
  const _ItemRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      ...item.customizations.values.map((v) => v.toString()),
      ...item.addOns.map((a) => a['name'].toString()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text('${item.quantity}× ${item.name}')),
              Text(centsToRM(item.subtotal)),
            ],
          ),
          if (details.isNotEmpty)
            Text(details.join(', '), style: AppTextStyles.caption),
          if (item.specialInstructions.isNotEmpty)
            Text('Note: ${item.specialInstructions}',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.orange,
                )),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  final FoodOrder order;
  final bool verified;
  final VoidCallback onMarkReady;
  final VoidCallback onScan;
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const _Actions({
    required this.order,
    required this.verified,
    required this.onMarkReady,
    required this.onScan,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (order.status == AppConstants.orderCollected) {
      return const Center(child: Text('This order has been collected.'));
    }
    if (order.status == AppConstants.orderCancelled) {
      return const Center(child: Text('This order was cancelled.'));
    }
    return Column(
      children: [
        if (order.status == AppConstants.orderPreparing)
          ElevatedButton.icon(
            icon: const Icon(Icons.restaurant),
            label: const Text('Mark ready'),
            onPressed: onMarkReady,
          ),
        if (order.status == AppConstants.orderReady) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.offWhite,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Text('Expected code: '),
                Text(order.pickupCode,
                    style: AppTextStyles.title
                        .copyWith(color: AppColors.orange)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan QR'),
            onPressed: onScan,
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal),
            icon: const Icon(Icons.check),
            label: const Text('Complete'),
            onPressed: verified ? onComplete : null,
          ),
        ],
        const SizedBox(height: 8),
        TextButton.icon(
          icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
          label: const Text('Cancel order',
              style: TextStyle(color: AppColors.error)),
          onPressed: onCancel,
        ),
      ],
    );
  }
}
