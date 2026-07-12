import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../models/order.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../view_model/vendor_dashboard_vm.dart';
import 'menu_management_page.dart';
import 'order_detail_page.dart';
import 'order_queue_page.dart';
import 'vendor_earnings_page.dart';

class VendorDashboardPage extends StatelessWidget {
  const VendorDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthViewModel>().currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: LoadingIndicator());
    }
    return ChangeNotifierProvider(
      create: (_) => VendorDashboardViewModel(uid),
      child: const _VendorShell(),
    );
  }
}

class _VendorShell extends StatefulWidget {
  const _VendorShell();

  @override
  State<_VendorShell> createState() => _VendorShellState();
}

class _VendorShellState extends State<_VendorShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = const [
      _DashboardTab(),
      OrderQueuePage(),
      _MenuTab(),
      VendorEarningsPage(),
    ];
    return Scaffold(
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.restaurant_menu_outlined),
            selectedIcon: Icon(Icons.restaurant_menu),
            label: 'Menu',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments),
            label: 'Earnings',
          ),
        ],
      ),
    );
  }
}

class _MenuTab extends StatelessWidget {
  const _MenuTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    if (vm.loadingStall) {
      return const Scaffold(body: LoadingIndicator());
    }
    if (!vm.hasStall) {
      return const Scaffold(
        body: EmptyState(
          icon: Icons.storefront_outlined,
          title: 'Create your stall first',
          subtitle: 'Set up your stall on the Dashboard tab to add a menu.',
        ),
      );
    }
    return MenuManagementPage(stallId: vm.stall!.stallId);
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<VendorDashboardViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => context.read<AuthViewModel>().logout(),
          ),
        ],
      ),
      body: vm.loadingStall
          ? const LoadingIndicator()
          : !vm.hasStall
              ? _CreateStallForm(vm: vm)
              : RefreshIndicator(
                  onRefresh: () async {},
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text('Hi, ${user?.name ?? 'Vendor'}',
                          style: AppTextStyles.bodySecondary),
                      const SizedBox(height: 8),
                      _StallHeader(vm: vm),
                      const SizedBox(height: 16),
                      _StatsRow(vm: vm),
                      const SizedBox(height: 24),
                      Text('Active orders', style: AppTextStyles.h3),
                      const SizedBox(height: 8),
                      _ActiveOrdersPreview(orders: vm.activeOrders),
                    ],
                  ),
                ),
    );
  }
}

class _StallHeader extends StatelessWidget {
  final VendorDashboardViewModel vm;
  const _StallHeader({required this.vm});

  @override
  Widget build(BuildContext context) {
    final stall = vm.stall!;
    final isPending = stall.status == AppConstants.stallPending;
    final isSuspended = stall.status == AppConstants.stallSuspended;
    final canToggle = !isPending && !isSuspended;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stall.name, style: AppTextStyles.h3),
                      Text(stall.cuisine,
                          style: AppTextStyles.bodySecondary),
                    ],
                  ),
                ),
                if (canToggle)
                  Column(
                    children: [
                      Switch(
                        value: stall.status == AppConstants.stallOpen,
                        onChanged: vm.isUpdating
                            ? null
                            : (v) => vm.toggleOpen(v),
                      ),
                      Text(
                        stall.status == AppConstants.stallOpen
                            ? 'Open'
                            : 'Closed',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
              ],
            ),
            if (isPending)
              _Banner(
                color: AppColors.orange,
                icon: Icons.hourglass_top,
                text: 'Awaiting admin approval.',
              ),
            if (isSuspended)
              _Banner(
                color: AppColors.error,
                icon: Icons.block,
                text: 'Your stall has been suspended.',
              ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.schedule,
                    size: 18, color: AppColors.warmGrey),
                const SizedBox(width: 8),
                Text('Prep time: ${stall.prepTimeMinutes} min'),
                const Spacer(),
                TextButton(
                  onPressed: () => _editPrepTime(context, vm),
                  child: const Text('Edit'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editPrepTime(
    BuildContext context,
    VendorDashboardViewModel vm,
  ) async {
    final controller = TextEditingController(
      text: vm.stall!.prepTimeMinutes.toString(),
    );
    final minutes = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Prep time (minutes)'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(ctx, int.tryParse(controller.text)),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (minutes != null && minutes > 0) {
      await vm.updatePrepTime(minutes);
    }
  }
}

class _Banner extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Banner({
    required this.color,
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final VendorDashboardViewModel vm;
  const _StatsRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: "Today's orders",
            value: '${vm.todayOrderCount}',
            icon: Icons.receipt_long,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: "Today's earnings",
            value: centsToRM(vm.todayEarnings),
            icon: Icons.payments,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.orange),
            const SizedBox(height: 8),
            Text(value, style: AppTextStyles.h3),
            Text(label, style: AppTextStyles.caption),
          ],
        ),
      ),
    );
  }
}

class _ActiveOrdersPreview extends StatelessWidget {
  final List<FoodOrder> orders;
  const _ActiveOrdersPreview({required this.orders});

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return const EmptyState(
        icon: Icons.inbox_outlined,
        title: 'No active orders',
      );
    }
    return Column(
      children: [
        for (final order in orders.take(5))
          Card(
            child: ListTile(
              title: Text('#${order.pickupCode} • ${order.customerName}'),
              subtitle: Text('${order.items.length} item(s) • '
                  '${order.status}'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      VendorOrderDetailPage(orderId: order.orderId),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _CreateStallForm extends StatefulWidget {
  final VendorDashboardViewModel vm;
  const _CreateStallForm({required this.vm});

  @override
  State<_CreateStallForm> createState() => _CreateStallFormState();
}

class _CreateStallFormState extends State<_CreateStallForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cuisine = TextEditingController();
  final _description = TextEditingController();
  final _prepTime = TextEditingController(text: '15');

  @override
  void dispose() {
    _name.dispose();
    _cuisine.dispose();
    _description.dispose();
    _prepTime.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await widget.vm.createStall(
      name: _name.text.trim(),
      cuisine: _cuisine.text.trim(),
      description: _description.text.trim(),
      prepTimeMinutes: int.tryParse(_prepTime.text) ?? 15,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Stall created — pending admin approval.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Set up your stall', style: AppTextStyles.h2),
            const SizedBox(height: 4),
            Text(
              'Tell customers about your stall. It will go live after admin '
              'approval.',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Stall name'),
              validator: (v) => Validators.required(v, 'Stall name'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _cuisine,
              decoration: const InputDecoration(
                labelText: 'Cuisine (e.g. Malay, Chinese)',
              ),
              validator: (v) => Validators.required(v, 'Cuisine'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _prepTime,
              keyboardType: TextInputType.number,
              decoration:
                  const InputDecoration(labelText: 'Prep time (minutes)'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: widget.vm.isUpdating ? null : _submit,
              child: widget.vm.isUpdating
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create stall'),
            ),
          ],
        ),
      ),
    );
  }
}
