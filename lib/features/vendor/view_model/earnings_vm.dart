import 'package:flutter/foundation.dart';

import '../../../models/transaction.dart';
import '../repository/earnings_repository.dart';

/// Vendor earnings: transaction stream plus a simulated withdrawal.
class EarningsViewModel extends ChangeNotifier {
  final EarningsRepository _repository;

  EarningsViewModel({EarningsRepository? repository})
      : _repository = repository ?? EarningsRepository();

  bool _processing = false;
  String? _error;

  bool get isProcessing => _processing;
  String? get error => _error;

  Stream<List<WalletTransaction>> earnings(String vendorUid) =>
      _repository.watchEarnings(vendorUid);

  Future<bool> withdraw(String vendorUid, int amountCents) async {
    _error = null;
    _processing = true;
    notifyListeners();
    try {
      await _repository.withdraw(vendorUid, amountCents);
      return true;
    } catch (e) {
      _error = 'Withdrawal failed. Check your balance and try again.';
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }
}
