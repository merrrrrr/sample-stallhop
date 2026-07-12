import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../models/order.dart';
import '../repository/dispute_repository.dart';

class DisputesViewModel extends ChangeNotifier {
  final DisputeRepository _repository;
  StreamSubscription<List<FoodOrder>>? _sub;

  List<FoodOrder> _cancelled = [];
  bool _loading = true;
  bool _busy = false;

  DisputesViewModel({DisputeRepository? repository})
      : _repository = repository ?? DisputeRepository() {
    _sub = _repository.watchCancelledOrders().listen(
      (orders) {
        _cancelled = orders;
        _loading = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('DisputesViewModel stream error: $e');
        _loading = false;
        notifyListeners();
      },
    );
  }

  bool get isLoading => _loading;
  bool get isBusy => _busy;

  /// Cancelled orders neither refunded nor dismissed.
  List<FoodOrder> get open =>
      _cancelled.where((o) => !o.refunded && !o.dismissed).toList();

  List<FoodOrder> get resolved =>
      _cancelled.where((o) => o.refunded || o.dismissed).toList();

  Future<void> refund(FoodOrder order) async {
    _busy = true;
    notifyListeners();
    try {
      await _repository.refund(order);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> dismiss(FoodOrder order) async {
    _busy = true;
    notifyListeners();
    try {
      await _repository.dismiss(order);
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
