import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/menu_item.dart';
import '../../../models/order_item.dart';
import '../../../models/stall.dart';
import '../view_model/cart_vm.dart';

/// Full-screen item customization. Renders single-select customization groups,
/// add-on checkboxes, special instructions, and a quantity stepper with a live
/// price, then adds an [OrderItem] to the cart.
class ItemDetailPage extends StatefulWidget {
  final Stall stall;
  final MenuItem item;

  const ItemDetailPage({super.key, required this.stall, required this.item});

  @override
  State<ItemDetailPage> createState() => _ItemDetailPageState();
}

class _ItemDetailPageState extends State<ItemDetailPage> {
  final Map<String, String> _selectedCustomizations = {};
  final Set<int> _selectedAddOns = {};
  final _instructionsController = TextEditingController();
  int _quantity = 1;

  @override
  void initState() {
    super.initState();
    // Default each customization group to its first option.
    for (final group in widget.item.customizations) {
      final name = group['name'] as String?;
      final options = (group['options'] as List?)?.cast<dynamic>();
      if (name != null && options != null && options.isNotEmpty) {
        _selectedCustomizations[name] = options.first.toString();
      }
    }
  }

  @override
  void dispose() {
    _instructionsController.dispose();
    super.dispose();
  }

  int get _addOnsTotal {
    var total = 0;
    final addOns = widget.item.addOns;
    for (final idx in _selectedAddOns) {
      if (idx < addOns.length) {
        total += ((addOns[idx]['price'] ?? 0) as num).toInt();
      }
    }
    return total;
  }

  int get _unitPrice => widget.item.price + _addOnsTotal;
  int get _lineTotal => _unitPrice * _quantity;

  void _addToCart() {
    final addOns = <Map<String, dynamic>>[];
    for (final idx in _selectedAddOns) {
      final a = widget.item.addOns[idx];
      addOns.add({'name': a['name'], 'price': a['price']});
    }
    final orderItem = OrderItem(
      itemId: widget.item.itemId,
      name: widget.item.name,
      unitPrice: widget.item.price,
      quantity: _quantity,
      customizations: Map<String, dynamic>.from(_selectedCustomizations),
      addOns: addOns,
      specialInstructions: _instructionsController.text.trim(),
    );
    context.read<CartViewModel>().addItem(widget.stall, orderItem);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.item.name} added to cart')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: _addToCart,
            child: Text('Add to cart • ${centsToRM(_lineTotal)}'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (item.description.isNotEmpty) ...[
            Text(item.description, style: AppTextStyles.bodySecondary),
            const SizedBox(height: 8),
          ],
          Text(centsToRM(item.price), style: AppTextStyles.price),
          const Divider(height: 32),
          for (final group in item.customizations)
            _CustomizationGroup(
              group: group,
              selected: _selectedCustomizations[group['name']],
              onSelected: (value) => setState(() =>
                  _selectedCustomizations[group['name'] as String] = value),
            ),
          if (item.addOns.isNotEmpty) ...[
            Text('Add-ons', style: AppTextStyles.title),
            const SizedBox(height: 4),
            for (var i = 0; i < item.addOns.length; i++)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _selectedAddOns.contains(i),
                title: Text(item.addOns[i]['name']?.toString() ?? ''),
                secondary: Text(
                  '+ ${centsToRM(((item.addOns[i]['price'] ?? 0) as num).toInt())}',
                  style: AppTextStyles.caption,
                ),
                onChanged: (checked) => setState(() {
                  if (checked == true) {
                    _selectedAddOns.add(i);
                  } else {
                    _selectedAddOns.remove(i);
                  }
                }),
              ),
            const SizedBox(height: 8),
          ],
          Text('Special instructions', style: AppTextStyles.title),
          const SizedBox(height: 8),
          TextField(
            controller: _instructionsController,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'e.g. no chilli, less sugar',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('Quantity', style: AppTextStyles.title),
              const Spacer(),
              _QuantityStepper(
                quantity: _quantity,
                onChanged: (q) => setState(() => _quantity = q),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomizationGroup extends StatelessWidget {
  final Map<String, dynamic> group;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _CustomizationGroup({
    required this.group,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final name = group['name']?.toString() ?? '';
    final options =
        (group['options'] as List?)?.map((e) => e.toString()).toList() ?? [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, style: AppTextStyles.title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final opt in options)
              ChoiceChip(
                label: Text(opt),
                selected: selected == opt,
                onSelected: (_) => onSelected(opt),
              ),
          ],
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.filledTonal(
          onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text('$quantity', style: AppTextStyles.h3),
        ),
        IconButton.filledTonal(
          onPressed: () => onChanged(quantity + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
