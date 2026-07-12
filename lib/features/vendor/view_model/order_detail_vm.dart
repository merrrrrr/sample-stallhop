import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/order.dart';
import '../repository/vendor_order_repository.dart';

/// Live single-order state for the vendor detail/verification screen.
class VendorOrderDetailViewModel extends ChangeNotifier {
  final VendorOrderRepository _repository;
  StreamSubscription<FoodOrder?>? _sub;

  FoodOrder? _order;
  bool _loading = true;

  FoodOrder? get order => _order;
  bool get isLoading => _loading;

  VendorOrderDetailViewModel(String orderId, {VendorOrderRepository? repository})
      : _repository = repository ?? VendorOrderRepository() {
    _sub = _repository.listenToOrder(orderId).listen(
      (order) {
        _order = order;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('VendorOrderDetailViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> markReady(String orderId) => _repository.markReady(orderId);

  Future<void> markCollected(String orderId) =>
      _repository.markCollected(orderId);

  Future<void> cancel(FoodOrder order) => _repository.cancelOrder(order);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
