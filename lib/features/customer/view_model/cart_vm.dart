import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/order_item.dart';
import '../../../models/stall.dart';

/// Global cart state, provided app-wide so it survives screen navigation.
///
/// Lines are [OrderItem]s grouped by stallId. Each stall group becomes one
/// order at checkout (with its own service fee). Identical lines (same item +
/// customizations + add-ons + instructions) are merged by quantity.
class CartViewModel extends ChangeNotifier {
  final Map<String, List<OrderItem>> _itemsByStall = {};
  final Map<String, Stall> _stalls = {};

  Map<String, List<OrderItem>> get itemsByStall =>
      Map.unmodifiable(_itemsByStall);

  List<String> get stallIds => _itemsByStall.keys.toList();

  Stall stallFor(String stallId) => _stalls[stallId]!;

  List<OrderItem> itemsFor(String stallId) =>
      List.unmodifiable(_itemsByStall[stallId] ?? const []);

  bool get isEmpty => _itemsByStall.isEmpty;
  bool get isNotEmpty => _itemsByStall.isNotEmpty;

  int get totalItemCount => _itemsByStall.values
      .expand((list) => list)
      .fold(0, (acc, i) => acc + i.quantity);

  String _signature(OrderItem item) =>
      '${item.itemId}|${item.customizations}|${item.addOns}|'
      '${item.specialInstructions}';

  void addItem(Stall stall, OrderItem item) {
    _stalls[stall.stallId] = stall;
    final list = _itemsByStall.putIfAbsent(stall.stallId, () => []);
    final sig = _signature(item);
    final idx = list.indexWhere((e) => _signature(e) == sig);
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        quantity: list[idx].quantity + item.quantity,
      );
    } else {
      list.add(item);
    }
    notifyListeners();
  }

  void updateQuantity(String stallId, int index, int quantity) {
    final list = _itemsByStall[stallId];
    if (list == null || index < 0 || index >= list.length) return;
    if (quantity <= 0) {
      removeItem(stallId, index);
      return;
    }
    list[index] = list[index].copyWith(quantity: quantity);
    notifyListeners();
  }

  void incrementItem(String stallId, int index) {
    final list = _itemsByStall[stallId];
    if (list == null || index < 0 || index >= list.length) return;
    updateQuantity(stallId, index, list[index].quantity + 1);
  }

  void decrementItem(String stallId, int index) {
    final list = _itemsByStall[stallId];
    if (list == null || index < 0 || index >= list.length) return;
    updateQuantity(stallId, index, list[index].quantity - 1);
  }

  void removeItem(String stallId, int index) {
    final list = _itemsByStall[stallId];
    if (list == null || index < 0 || index >= list.length) return;
    list.removeAt(index);
    if (list.isEmpty) {
      _itemsByStall.remove(stallId);
      _stalls.remove(stallId);
    }
    notifyListeners();
  }

  void clearStall(String stallId) {
    _itemsByStall.remove(stallId);
    _stalls.remove(stallId);
    notifyListeners();
  }

  void clear() {
    _itemsByStall.clear();
    _stalls.clear();
    notifyListeners();
  }

  /// Subtotal for one stall group, in cents.
  int getSubtotal(String stallId) {
    final list = _itemsByStall[stallId];
    if (list == null) return 0;
    return list.fold(0, (acc, i) => acc + i.subtotal);
  }

  /// Service fee for one stall group, in cents.
  int getServiceFee(String stallId) =>
      _itemsByStall.containsKey(stallId) ? AppConstants.serviceFeeCents : 0;

  /// Total for one stall group (subtotal + service fee), in cents.
  int getStallTotal(String stallId) =>
      getSubtotal(stallId) + getServiceFee(stallId);

  /// Sum of all stall subtotals, in cents.
  int get grandSubtotal =>
      stallIds.fold(0, (acc, id) => acc + getSubtotal(id));

  /// Total service fees across all stall groups, in cents.
  int get totalServiceFee =>
      stallIds.fold(0, (acc, id) => acc + getServiceFee(id));

  /// Grand total the customer pays across all stall groups, in cents.
  int get grandTotal => grandSubtotal + totalServiceFee;
}
