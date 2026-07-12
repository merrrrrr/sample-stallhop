import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/order.dart';
import '../repository/order_repository.dart';

/// Live order tracking via [OrderRepository.listenToOrder].
class OrderTrackingViewModel extends ChangeNotifier {
  final OrderRepository _repository;
  StreamSubscription<FoodOrder?>? _sub;

  FoodOrder? _order;
  bool _loading = true;

  FoodOrder? get order => _order;
  bool get isLoading => _loading;

  OrderTrackingViewModel(String orderId, {OrderRepository? repository})
      : _repository = repository ?? OrderRepository() {
    _sub = _repository.listenToOrder(orderId).listen((order) {
      _order = order;
      _loading = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
