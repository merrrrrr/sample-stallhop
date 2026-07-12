import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/stall.dart';
import '../repository/vendor_order_repository.dart';

/// Drives the vendor dashboard: the vendor's stall, today's totals, and a
/// preview of active orders.
class VendorDashboardViewModel extends ChangeNotifier {
  final VendorOrderRepository _repository;
  final String vendorUid;

  StreamSubscription<Stall?>? _stallSub;
  StreamSubscription<List<FoodOrder>>? _ordersSub;

  Stall? _stall;
  List<FoodOrder> _orders = [];
  bool _loadingStall = true;
  bool _updating = false;

  VendorDashboardViewModel(
    this.vendorUid, {
    VendorOrderRepository? repository,
  }) : _repository = repository ?? VendorOrderRepository() {
    _stallSub = _repository.watchMyStall(vendorUid).listen(
      (stall) {
        _stall = stall;
        _loadingStall = false;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('VendorDashboardViewModel stall stream error: $e');
        _loadingStall = false;
        notifyListeners();
      },
    );
    _ordersSub = _repository.watchAllOrders(vendorUid).listen(
      (orders) {
        _orders = orders;
        notifyListeners();
      },
      onError: (Object e) {
        debugPrint('VendorDashboardViewModel orders stream error: $e');
      },
    );
  }

  Stall? get stall => _stall;
  bool get loadingStall => _loadingStall;
  bool get hasStall => _stall != null;
  bool get isUpdating => _updating;

  List<FoodOrder> get activeOrders => _orders
      .where((o) =>
          o.status == AppConstants.orderPreparing ||
          o.status == AppConstants.orderReady)
      .toList();

  List<FoodOrder> get _todayOrders {
    final now = DateTime.now();
    return _orders.where((o) {
      final d = o.createdAt;
      return d.year == now.year &&
          d.month == now.month &&
          d.day == now.day &&
          o.status != AppConstants.orderCancelled;
    }).toList();
  }

  int get todayOrderCount => _todayOrders.length;

  /// Today's gross earnings for this vendor (subtotal minus commission), cents.
  int get todayEarnings {
    final rate = _stall?.commissionRate ?? AppConstants.defaultCommissionRate;
    return _todayOrders.fold(
      0,
      (acc, o) => acc + (o.subtotal * (1 - rate)).round(),
    );
  }

  Future<void> toggleOpen(bool open) async {
    final stall = _stall;
    if (stall == null) return;
    _updating = true;
    notifyListeners();
    try {
      await _repository.setOpen(stall.stallId, open);
    } finally {
      _updating = false;
      notifyListeners();
    }
  }

  Future<void> updatePrepTime(int minutes) async {
    final stall = _stall;
    if (stall == null) return;
    await _repository.setPrepTime(stall.stallId, minutes);
  }

  Future<void> createStall({
    required String name,
    required String cuisine,
    required String description,
    required int prepTimeMinutes,
  }) async {
    _updating = true;
    notifyListeners();
    try {
      await _repository.createStall(
        vendorUid: vendorUid,
        name: name,
        cuisine: cuisine,
        description: description,
        prepTimeMinutes: prepTimeMinutes,
      );
    } finally {
      _updating = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stallSub?.cancel();
    _ordersSub?.cancel();
    super.dispose();
  }
}
