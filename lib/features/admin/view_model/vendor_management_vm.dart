import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/utils/constants.dart';
import '../../../models/stall.dart';
import '../repository/admin_stall_repository.dart';

/// Splits stalls into pending-approval and active/managed buckets.
class VendorManagementViewModel extends ChangeNotifier {
  final AdminStallRepository _repository;
  StreamSubscription<List<Stall>>? _sub;

  List<Stall> _stalls = [];
  bool _loading = true;

  VendorManagementViewModel({AdminStallRepository? repository})
      : _repository = repository ?? AdminStallRepository() {
    _sub = _repository.watchAllStalls().listen((stalls) {
      _stalls = stalls;
      _loading = false;
      notifyListeners();
    });
  }

  bool get isLoading => _loading;

  List<Stall> get pending => _stalls
      .where((s) => s.status == AppConstants.stallPending)
      .toList();

  /// Approved stalls (open/closed) plus suspended ones the admin can restore.
  List<Stall> get managed => _stalls
      .where((s) => const [
            AppConstants.stallOpen,
            AppConstants.stallClosed,
            AppConstants.stallSuspended,
          ].contains(s.status))
      .toList();

  Future<void> approve(Stall stall) => _repository.approve(stall.stallId);
  Future<void> reject(Stall stall) => _repository.reject(stall.stallId);
  Future<void> suspend(Stall stall) => _repository.suspend(stall.stallId);
  Future<void> reactivate(Stall stall) =>
      _repository.reactivate(stall.stallId);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
