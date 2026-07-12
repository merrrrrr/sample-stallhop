import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../view_model/order_queue_vm.dart';
import 'order_detail_page.dart';

class OrderQueuePage extends StatelessWidget {
  const OrderQueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthViewModel>().currentUser?.uid;
    if (uid == null) return const LoadingIndicator();
    return ChangeNotifierProvider(
      create: (_) => OrderQueueViewModel(uid),
      child: const _QueueView(),
    );
  }
}

class _QueueView extends StatelessWidget {
  const _QueueView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<OrderQueueViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Order queue'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Preparing (${vm.preparing.length})'),
              Tab(text: 'Ready (${vm.ready.length})'),
            ],
          ),
        ),
        body: vm.isLoading
            ? const LoadingIndicator()
            : TabBarView(
                children: [
                  _OrderColumn(
                    orders: vm.preparing,
                    emptyTitle: 'No orders to prepare',
                    primaryLabel: 'Mark ready',
                    onPrimary: (o) => vm.markReady(o.orderId),
                  ),
                  _OrderColumn(
                    orders: vm.ready,
                    emptyTitle: 'No orders awaiting pickup',
                    primaryLabel: 'Verify & complete',
                    onPrimary: (o) => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            VendorOrderDetailPage(orderId: o.orderId),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _OrderColumn extends StatelessWidget {
  final List<FoodOrder> orders;
  final String emptyTitle;
  final String primaryLabel;
  final void Function(FoodOrder) onPrimary;

  const _OrderColumn({
    required this.orders,
    required this.emptyTitle,
    required this.primaryLabel,
    required this.onPrimary,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(icon: Icons.inbox_outlined, title: emptyTitle);
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final order = orders[i];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('#${order.pickupCode}',
                        style: AppTextStyles.h3
                            .copyWith(color: AppColors.orange)),
                    Text(timeAgo(order.createdAt),
                        style: AppTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Text(order.customerName,
                    style: AppTextStyles.bodySecondary),
                const Divider(),
                for (final item in order.items)
                  Text('${item.quantity}× ${item.name}',
                      style: AppTextStyles.body),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VendorOrderDetailPage(
                                orderId: order.orderId),
                          ),
                        ),
                        child: const Text('Details'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => onPrimary(order),
                        child: Text(primaryLabel),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
