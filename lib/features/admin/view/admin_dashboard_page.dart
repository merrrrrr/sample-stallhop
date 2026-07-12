import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../view_model/admin_dashboard_vm.dart';
import 'admin_settings_page.dart';
import 'disputes_page.dart';
import 'vendor_management_page.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _index = 0;

  static const _pages = [
    _DashboardTab(),
    VendorManagementPage(),
    DisputesPage(),
    AdminSettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.insights_outlined),
            selectedIcon: Icon(Icons.insights),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront),
            label: 'Vendors',
          ),
          NavigationDestination(
            icon: Icon(Icons.gavel_outlined),
            selectedIcon: Icon(Icons.gavel),
            label: 'Disputes',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}

class _DashboardTab extends StatelessWidget {
  const _DashboardTab();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminDashboardViewModel(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AdminDashboardViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Overview')),
      body: vm.isLoading
          ? const LoadingIndicator()
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Hi, ${user?.name ?? 'Admin'}',
                    style: AppTextStyles.bodySecondary),
                const SizedBox(height: 12),
                _RangeSelector(vm: vm),
                const SizedBox(height: 16),
                _KpiGrid(vm: vm),
                const SizedBox(height: 24),
                Text('Peak hours', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                _PeakHoursChart(data: vm.ordersByHour),
                const SizedBox(height: 24),
                Text('Top stalls', style: AppTextStyles.h3),
                const SizedBox(height: 8),
                _TopStalls(stalls: vm.topStalls),
              ],
            ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  final AdminDashboardViewModel vm;
  const _RangeSelector({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<DateRange>(
      segments: const [
        ButtonSegment(value: DateRange.today, label: Text('Today')),
        ButtonSegment(value: DateRange.week, label: Text('Week')),
        ButtonSegment(value: DateRange.month, label: Text('Month')),
      ],
      selected: {vm.range},
      onSelectionChanged: (s) => vm.setRange(s.first),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final AdminDashboardViewModel vm;
  const _KpiGrid({required this.vm});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.6,
      children: [
        _KpiTile(
          icon: Icons.receipt_long,
          label: 'Total orders',
          value: '${vm.totalOrders}',
        ),
        _KpiTile(
          icon: Icons.payments,
          label: 'Revenue',
          value: centsToRM(vm.revenue),
        ),
        _KpiTile(
          icon: Icons.storefront,
          label: 'Active stalls',
          value: '${vm.activeStalls}',
          badge: vm.pendingStalls > 0 ? '${vm.pendingStalls} pending' : null,
        ),
        _KpiTile(
          icon: Icons.schedule,
          label: 'Avg prep',
          value: vm.avgPrepMinutes == 0
              ? '—'
              : '${vm.avgPrepMinutes.toStringAsFixed(0)} min',
        ),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? badge;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.orange, size: 20),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTextStyles.h3),
            ),
            Text(label, style: AppTextStyles.caption),
            if (badge != null)
              Text(badge!,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.orange)),
          ],
        ),
      ),
    );
  }
}

/// Bar chart of order counts by hour of day.
class _PeakHoursChart extends StatelessWidget {
  final List<int> data;
  const _PeakHoursChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxY = data.isEmpty
        ? 1.0
        : (data.reduce((a, b) => a > b ? a : b)).toDouble();
    if (maxY == 0) {
      return const Card(
        child: SizedBox(
          height: 180,
          child: EmptyState(
            icon: Icons.bar_chart,
            title: 'No orders in this range',
          ),
        ),
      );
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: SizedBox(
          height: 180,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                leftTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: true, reservedSize: 28),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final hour = value.toInt();
                      if (hour % 4 != 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('$hour',
                            style: AppTextStyles.caption),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var hour = 0; hour < data.length; hour++)
                  BarChartGroupData(
                    x: hour,
                    barRods: [
                      BarChartRodData(
                        toY: data[hour].toDouble(),
                        color: AppColors.orange,
                        width: 6,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopStalls extends StatelessWidget {
  final List<(String, int)> stalls;
  const _TopStalls({required this.stalls});

  @override
  Widget build(BuildContext context) {
    if (stalls.isEmpty) {
      return const Card(
        child: SizedBox(
          height: 120,
          child: EmptyState(icon: Icons.storefront, title: 'No data yet'),
        ),
      );
    }
    return Card(
      child: Column(
        children: [
          for (var i = 0; i < stalls.length; i++)
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.orangeLight,
                child: Text('${i + 1}',
                    style: AppTextStyles.title
                        .copyWith(color: AppColors.orange)),
              ),
              title: Text(stalls[i].$1),
              trailing: Text('${stalls[i].$2} orders',
                  style: AppTextStyles.caption),
            ),
        ],
      ),
    );
  }
}
