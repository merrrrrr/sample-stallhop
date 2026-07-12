import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../../../widgets/stall_card.dart';
import '../view_model/stall_browsing_vm.dart';
import 'stall_menu_page.dart';

class StallBrowsingPage extends StatelessWidget {
  const StallBrowsingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => StallBrowsingViewModel(),
      child: const _StallBrowsingView(),
    );
  }
}

class _StallBrowsingView extends StatelessWidget {
  const _StallBrowsingView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<StallBrowsingViewModel>();
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _Header(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                onChanged: vm.setSearch,
                decoration: const InputDecoration(
                  hintText: 'Search stalls',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _FilterRow(vm: vm),
            Expanded(child: _StallList(vm: vm)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          const Icon(Icons.place, color: AppColors.orange),
          const SizedBox(width: 6),
          Text('StallHop Food Court', style: AppTextStyles.h3),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final StallBrowsingViewModel vm;
  const _FilterRow({required this.vm});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: vm.cuisine == null,
                  onSelected: (_) => vm.setCuisine(null),
                ),
                const SizedBox(width: 8),
                for (final c in vm.cuisines) ...[
                  FilterChip(
                    label: Text(c),
                    selected: vm.cuisine == c,
                    onSelected: (_) => vm.setCuisine(c),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          PopupMenuButton<StallSort>(
            icon: const Icon(Icons.sort),
            onSelected: vm.setSort,
            itemBuilder: (_) => const [
              PopupMenuItem(value: StallSort.rating, child: Text('Top rated')),
              PopupMenuItem(
                  value: StallSort.prepTime, child: Text('Fastest')),
              PopupMenuItem(value: StallSort.name, child: Text('Name A–Z')),
            ],
          ),
        ],
      ),
    );
  }
}

class _StallList extends StatelessWidget {
  final StallBrowsingViewModel vm;
  const _StallList({required this.vm});

  @override
  Widget build(BuildContext context) {
    if (vm.isLoading) return const LoadingIndicator();
    if (vm.error != null) {
      return EmptyState(
        icon: Icons.error_outline,
        title: 'Something went wrong',
        subtitle: vm.error,
      );
    }
    final stalls = vm.stalls;
    if (stalls.isEmpty) {
      return const EmptyState(
        icon: Icons.storefront_outlined,
        title: 'No stalls found',
        subtitle: 'Try a different search or filter.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stalls.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final stall = stalls[i];
        return StallCard(
          stall: stall,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => StallMenuPage(stall: stall),
            ),
          ),
        );
      },
    );
  }
}
