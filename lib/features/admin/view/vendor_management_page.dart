import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../view_model/vendor_management_vm.dart';

class VendorManagementPage extends StatelessWidget {
  const VendorManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VendorManagementViewModel(),
      child: const _VendorManagementView(),
    );
  }
}

class _VendorManagementView extends StatelessWidget {
  const _VendorManagementView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorManagementViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Vendors')),
      body: vm.isLoading
          ? const LoadingIndicator()
          : (vm.pending.isEmpty && vm.managed.isEmpty)
              ? const EmptyState(
                  icon: Icons.storefront_outlined,
                  title: 'No stalls yet',
                  subtitle: 'Vendor stalls will appear here for approval.',
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Pending approval (${vm.pending.length})',
                        style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    if (vm.pending.isEmpty)
                      Text('Nothing awaiting approval.',
                          style: AppTextStyles.bodySecondary)
                    else
                      for (final stall in vm.pending)
                        _PendingCard(stall: stall, vm: vm),
                    const SizedBox(height: 24),
                    Text('Active stalls (${vm.managed.length})',
                        style: AppTextStyles.h3),
                    const SizedBox(height: 8),
                    if (vm.managed.isEmpty)
                      Text('No active stalls.',
                          style: AppTextStyles.bodySecondary)
                    else
                      for (final stall in vm.managed)
                        _ManagedTile(stall: stall, vm: vm),
                  ],
                ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  final Stall stall;
  final VendorManagementViewModel vm;
  const _PendingCard({required this.stall, required this.vm});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(stall.name, style: AppTextStyles.title),
            Text(stall.cuisine, style: AppTextStyles.bodySecondary),
            if (stall.description.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(stall.description, style: AppTextStyles.caption),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => vm.reject(stall),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.teal),
                    onPressed: () => vm.approve(stall),
                    child: const Text('Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagedTile extends StatelessWidget {
  final Stall stall;
  final VendorManagementViewModel vm;
  const _ManagedTile({required this.stall, required this.vm});

  Color get _color {
    switch (stall.status) {
      case AppConstants.stallOpen:
        return AppColors.teal;
      case AppConstants.stallSuspended:
        return AppColors.error;
      default:
        return AppColors.warmGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final suspended = stall.status == AppConstants.stallSuspended;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(stall.name, style: AppTextStyles.title),
        subtitle: Text(
          '${stall.cuisine} • ${stall.totalReviews} reviews',
          style: AppTextStyles.caption,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                stall.status,
                style: AppTextStyles.caption.copyWith(
                  color: _color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'suspend') vm.suspend(stall);
                if (value == 'reactivate') vm.reactivate(stall);
              },
              itemBuilder: (_) => [
                if (suspended)
                  const PopupMenuItem(
                    value: 'reactivate',
                    child: Text('Reactivate'),
                  )
                else
                  const PopupMenuItem(
                    value: 'suspend',
                    child: Text('Suspend',
                        style: TextStyle(color: AppColors.error)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
