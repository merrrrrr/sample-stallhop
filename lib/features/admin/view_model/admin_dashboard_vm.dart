import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/stall.dart';
import '../repository/admin_stall_repository.dart';

enum DateRange { today, week, month }

/// Aggregates orders and stalls into the admin KPI tiles, peak-hours chart,
/// and top-stalls list, filtered by [DateRange].
class AdminDashboardViewModel extends ChangeNotifier {
  final FirestoreService _firestore;
  final AdminStallRepository _stallRepository;

  StreamSubscription<List<Map<String, dynamic>>>? _ordersSub;
  StreamSubscription<List<Stall>>? _stallsSub;

  List<FoodOrder> _orders = [];
  List<Stall> _stalls = [];
  bool _loading = true;
  DateRange _range = DateRange.today;

  AdminDashboardViewModel({
    FirestoreService? firestore,
    AdminStallRepository? stallRepository,
  })  : _firestore = firestore ?? FirestoreService(),
        _stallRepository = stallRepository ?? AdminStallRepository() {
    _ordersSub = _firestore
        .collectionStream(AppConstants.ordersCollection)
        .listen((rows) {
      _orders = rows.map(FoodOrder.fromJson).toList();
      _loading = false;
      notifyListeners();
    });
    _stallsSub = _stallRepository.watchAllStalls().listen((stalls) {
      _stalls = stalls;
      notifyListeners();
    });
  }

  bool get isLoading => _loading;
  DateRange get range => _range;

  void setRange(DateRange range) {
    _range = range;
    notifyListeners();
  }

  DateTime get _rangeStart {
    final now = DateTime.now();
    switch (_range) {
      case DateRange.today:
        return DateTime(now.year, now.month, now.day);
      case DateRange.week:
        return now.subtract(const Duration(days: 7));
      case DateRange.month:
        return now.subtract(const Duration(days: 30));
    }
  }

  /// Orders within the selected range, excluding cancelled ones.
  List<FoodOrder> get _rangeOrders {
    final start = _rangeStart;
    return _orders
        .where((o) =>
            o.createdAt.isAfter(start) &&
            o.status != AppConstants.orderCancelled)
        .toList();
  }

  int get totalOrders => _rangeOrders.length;

  /// Gross value of orders in range, in cents.
  int get revenue => _rangeOrders.fold(0, (acc, o) => acc + o.total);

  int get activeStalls =>
      _stalls.where((s) => s.status == AppConstants.stallOpen).length;

  int get pendingStalls =>
      _stalls.where((s) => s.status == AppConstants.stallPending).length;

  /// Mean minutes from order creation to ready, over orders that reached ready.
  double get avgPrepMinutes {
    final withReady =
        _rangeOrders.where((o) => o.readyAt != null).toList();
    if (withReady.isEmpty) return 0;
    final total = withReady.fold<int>(
      0,
      (acc, o) => acc + o.readyAt!.difference(o.createdAt).inMinutes,
    );
    return total / withReady.length;
  }

  /// Order counts bucketed by hour of day (index 0–23).
  List<int> get ordersByHour {
    final buckets = List<int>.filled(24, 0);
    for (final order in _rangeOrders) {
      buckets[order.createdAt.hour]++;
    }
    return buckets;
  }

  /// Top stalls by order count, as (stallName, orderCount), max 5.
  List<(String, int)> get topStalls {
    final counts = <String, int>{};
    for (final order in _rangeOrders) {
      counts[order.stallName] = (counts[order.stallName] ?? 0) + 1;
    }
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).map((e) => (e.key, e.value)).toList();
  }

  @override
  void dispose() {
    _ordersSub?.cancel();
    _stallsSub?.cancel();
    super.dispose();
  }
}
