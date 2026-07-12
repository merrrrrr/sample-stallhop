import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../repository/order_repository.dart';
import 'order_tracking_page.dart';

class OrdersListPage extends StatelessWidget {
  const OrdersListPage({super.key});

  static const _active = [
    AppConstants.orderPreparing,
    AppConstants.orderReady,
  ];
  static const _past = [
    AppConstants.orderCollected,
    AppConstants.orderCancelled,
  ];

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthViewModel>().currentUser?.uid;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My orders'),
          bottom: const TabBar(
            tabs: [Tab(text: 'Active'), Tab(text: 'Past')],
          ),
        ),
        body: uid == null
            ? const LoadingIndicator()
            : TabBarView(
                children: [
                  _OrderList(uid: uid, statuses: _active, emptyActive: true),
                  _OrderList(uid: uid, statuses: _past, emptyActive: false),
                ],
              ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  final String uid;
  final List<String> statuses;
  final bool emptyActive;

  const _OrderList({
    required this.uid,
    required this.statuses,
    required this.emptyActive,
  });

  @override
  Widget build(BuildContext context) {
    final repo = OrderRepository();
    return StreamBuilder<List<FoodOrder>>(
      stream: repo.watchCustomerOrders(uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }
        final orders = (snapshot.data ?? [])
            .where((o) => statuses.contains(o.status))
            .toList();
        if (orders.isEmpty) {
          return EmptyState(
            icon: emptyActive
                ? Icons.receipt_long_outlined
                : Icons.history,
            title: emptyActive ? 'No active orders' : 'No past orders',
            subtitle: emptyActive
                ? 'Your in-progress orders will appear here.'
                : 'Completed and cancelled orders appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _OrderTile(order: orders[i]),
        );
      },
    );
  }
}

class _OrderTile extends StatelessWidget {
  final FoodOrder order;
  const _OrderTile({required this.order});

  Color get _statusColor {
    switch (order.status) {
      case AppConstants.orderReady:
        return AppColors.teal;
      case AppConstants.orderCancelled:
        return AppColors.error;
      case AppConstants.orderCollected:
        return AppColors.warmGrey;
      default:
        return AppColors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        title: Text(order.stallName, style: AppTextStyles.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${order.items.length} item(s) • '
                '${centsToRM(order.total)}'),
            Text(timeAgo(order.createdAt), style: AppTextStyles.caption),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                order.status,
                style: AppTextStyles.caption.copyWith(
                  color: _statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text('#${order.pickupCode}', style: AppTextStyles.caption),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderTrackingPage(orderId: order.orderId),
          ),
        ),
      ),
    );
  }
}
