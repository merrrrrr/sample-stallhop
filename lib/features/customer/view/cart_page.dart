import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/app_exceptions.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../auth/view_model/auth_view_model.dart';
import '../repository/order_repository.dart';
import '../view_model/cart_vm.dart';
import 'order_placed_page.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _orderRepository = OrderRepository();
  bool _placing = false;

  Future<void> _placeOrder() async {
    final cart = context.read<CartViewModel>();
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null || cart.isEmpty) return;

    if (user.walletBalance < cart.grandTotal) {
      _snack('Insufficient wallet balance. Please top up.', isError: true);
      return;
    }

    setState(() => _placing = true);
    final placed = <FoodOrder>[];
    try {
      // One atomic order per stall group.
      for (final stallId in cart.stallIds) {
        final order = await _orderRepository.placeOrder(
          customer: user,
          stall: cart.stallFor(stallId),
          items: cart.itemsFor(stallId),
          serviceFeeCents: cart.getServiceFee(stallId),
        );
        placed.add(order);
      }
      cart.clear();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => OrderPlacedPage(orders: placed),
        ),
      );
    } on InsufficientBalanceException {
      _snack('Insufficient wallet balance. Please top up.', isError: true);
    } catch (e) {
      _snack('Could not place order. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  void _snack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartViewModel>();
    final user = context.watch<AuthViewModel>().currentUser;
    final balance = user?.walletBalance ?? 0;
    final insufficient = balance < cart.grandTotal;

    return Scaffold(
      appBar: AppBar(title: const Text('Your cart')),
      bottomNavigationBar: cart.isEmpty
          ? null
          : _CheckoutBar(
              total: cart.grandTotal,
              balance: balance,
              insufficient: insufficient,
              placing: _placing,
              onPlaceOrder: _placeOrder,
            ),
      body: cart.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final stallId in cart.stallIds)
                  _StallGroup(stallId: stallId, cart: cart),
                const SizedBox(height: 8),
                _SummaryCard(cart: cart),
              ],
            ),
    );
  }
}

class _StallGroup extends StatelessWidget {
  final String stallId;
  final CartViewModel cart;
  const _StallGroup({required this.stallId, required this.cart});

  @override
  Widget build(BuildContext context) {
    final stall = cart.stallFor(stallId);
    final items = cart.itemsFor(stallId);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.storefront, size: 18,
                    color: AppColors.orange),
                const SizedBox(width: 6),
                Text(stall.name, style: AppTextStyles.title),
              ],
            ),
            const Divider(),
            for (var i = 0; i < items.length; i++)
              _CartLine(stallId: stallId, index: i, item: items[i]),
          ],
        ),
      ),
    );
  }
}

class _CartLine extends StatelessWidget {
  final String stallId;
  final int index;
  final OrderItem item;

  const _CartLine({
    required this.stallId,
    required this.index,
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartViewModel>();
    final details = <String>[
      ...item.customizations.values.map((v) => v.toString()),
      ...item.addOns.map((a) => a['name'].toString()),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.body),
                if (details.isNotEmpty)
                  Text(details.join(', '), style: AppTextStyles.caption),
                if (item.specialInstructions.isNotEmpty)
                  Text('Note: ${item.specialInstructions}',
                      style: AppTextStyles.caption),
                const SizedBox(height: 4),
                Text(centsToRM(item.subtotal), style: AppTextStyles.price),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: () => cart.decrementItem(stallId, index),
              ),
              Text('${item.quantity}', style: AppTextStyles.title),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => cart.incrementItem(stallId, index),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final CartViewModel cart;
  const _SummaryCard({required this.cart});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Subtotal', centsToRM(cart.grandSubtotal)),
            const SizedBox(height: 6),
            _row('Service fee', centsToRM(cart.totalServiceFee)),
            const Divider(height: 24),
            _row('Total', centsToRM(cart.grandTotal), bold: true),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? AppTextStyles.title : AppTextStyles.body;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(label, style: style), Text(value, style: style)],
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final int total;
  final int balance;
  final bool insufficient;
  final bool placing;
  final VoidCallback onPlaceOrder;

  const _CheckoutBar({
    required this.total,
    required this.balance,
    required this.insufficient,
    required this.placing,
    required this.onPlaceOrder,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Wallet balance', style: AppTextStyles.bodySecondary),
                Text(
                  centsToRM(balance),
                  style: AppTextStyles.body.copyWith(
                    color: insufficient ? AppColors.error : AppColors.navy,
                  ),
                ),
              ],
            ),
            if (insufficient)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber,
                        size: 16, color: AppColors.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Not enough balance. Top up in the Wallet tab.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: (insufficient || placing) ? null : onPlaceOrder,
              child: placing
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text('Place order • ${centsToRM(total)}'),
            ),
          ],
        ),
      ),
    );
  }
}
