import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../repository/vendor_order_repository.dart';

/// Live order queue for a vendor, split into Preparing and Ready buckets.
class OrderQueueViewModel extends ChangeNotifier {
  final VendorOrderRepository _repository;
  StreamSubscription<List<FoodOrder>>? _sub;

  List<FoodOrder> _orders = [];
  bool _loading = true;

  OrderQueueViewModel(String vendorUid, {VendorOrderRepository? repository})
      : _repository = repository ?? VendorOrderRepository() {
    _sub = _repository.watchActiveOrders(vendorUid).listen(
      (orders) {
        _orders = orders;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('OrderQueueViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  bool get isLoading => _loading;

  List<FoodOrder> get preparing => _orders
      .where((o) => o.status == AppConstants.orderPreparing)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  List<FoodOrder> get ready => _orders
      .where((o) => o.status == AppConstants.orderReady)
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<void> markReady(String orderId) => _repository.markReady(orderId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
