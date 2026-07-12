import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/menu_item.dart';
import '../../../widgets/empty_state.dart';
import '../../../widgets/loading_indicator.dart';
import '../view_model/menu_management_vm.dart';
import 'add_edit_item_page.dart';

class MenuManagementPage extends StatelessWidget {
  final String stallId;
  const MenuManagementPage({super.key, required this.stallId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuManagementViewModel(stallId),
      child: _MenuView(stallId: stallId),
    );
  }
}

class _MenuView extends StatelessWidget {
  final String stallId;
  const _MenuView({required this.stallId});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<MenuManagementViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Menu')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AddEditItemPage(stallId: stallId),
          ),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add item'),
      ),
      body: vm.isLoading
          ? const LoadingIndicator()
          : vm.items.isEmpty
              ? const EmptyState(
                  icon: Icons.restaurant_menu,
                  title: 'No menu items',
                  subtitle: 'Tap "Add item" to create your first dish.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: vm.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _MenuRow(item: vm.items[i], vm: vm, stallId: stallId),
                ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final MenuItem item;
  final MenuManagementViewModel vm;
  final String stallId;

  const _MenuRow({
    required this.item,
    required this.vm,
    required this.stallId,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name, style: AppTextStyles.title),
      subtitle: Text(
        '${centsToRM(item.price)}'
        '${item.category.isEmpty ? '' : ' • ${item.category}'}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Switch(
                value: item.available,
                onChanged: (_) => vm.toggleAvailable(item),
              ),
              Text(
                item.available ? 'Available' : 'Sold out',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditItemPage(stallId: stallId, item: item),
                  ),
                );
              } else if (value == 'delete') {
                vm.delete(item);
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(
                value: 'delete',
                child: Text('Delete',
                    style: TextStyle(color: AppColors.error)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
