import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../view_model/disputes_vm.dart';

class DisputesPage extends StatelessWidget {
  const DisputesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DisputesViewModel(),
      child: const _DisputesView(),
    );
  }
}

class _DisputesView extends StatelessWidget {
  const _DisputesView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DisputesViewModel>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Disputes'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Open (${vm.open.length})'),
              Tab(text: 'Resolved (${vm.resolved.length})'),
            ],
          ),
        ),
        body: vm.isLoading
            ? const LoadingIndicator()
            : TabBarView(
                children: [
                  _DisputeList(orders: vm.open, vm: vm, isOpen: true),
                  _DisputeList(orders: vm.resolved, vm: vm, isOpen: false),
                ],
              ),
      ),
    );
  }
}

class _DisputeList extends StatelessWidget {
  final List<FoodOrder> orders;
  final DisputesViewModel vm;
  final bool isOpen;

  const _DisputeList({
    required this.orders,
    required this.vm,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return EmptyState(
        icon: isOpen ? Icons.gavel_outlined : Icons.check_circle_outline,
        title: isOpen ? 'No open disputes' : 'No resolved disputes',
        subtitle: isOpen
            ? 'Cancelled orders awaiting a refund decision appear here.'
            : null,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: orders.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (_, i) =>
          _DisputeCard(order: orders[i], vm: vm, isOpen: isOpen),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  final FoodOrder order;
  final DisputesViewModel vm;
  final bool isOpen;

  const _DisputeCard({
    required this.order,
    required this.vm,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
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
                    style: AppTextStyles.title
                        .copyWith(color: AppColors.orange)),
                Text(centsToRM(order.total), style: AppTextStyles.title),
              ],
            ),
            const SizedBox(height: 4),
            Text('${order.stallName} • ${order.customerName}',
                style: AppTextStyles.bodySecondary),
            Text('Cancelled ${timeAgo(order.cancelledAt ?? order.updatedAt)}',
                style: AppTextStyles.caption),
            if (!isOpen) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    order.refunded ? Icons.payments : Icons.block,
                    size: 16,
                    color: order.refunded
                        ? AppColors.teal
                        : AppColors.warmGrey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    order.refunded ? 'Refunded' : 'Dismissed',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ],
            if (isOpen) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          vm.isBusy ? null : () => vm.dismiss(order),
                      child: const Text('Dismiss'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.teal),
                      onPressed: vm.isBusy ? null : () => vm.refund(order),
                      child: Text('Refund ${centsToRM(order.total)}'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
