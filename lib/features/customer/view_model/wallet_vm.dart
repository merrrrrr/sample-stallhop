import 'package:flutter/foundation.dart';

import '../../../models/transaction.dart';
import '../repository/wallet_repository.dart';

/// Handles top-ups and exposes the user's transaction stream. The live balance
/// itself comes from the auth user document (AuthViewModel).
class WalletViewModel extends ChangeNotifier {
  final WalletRepository _repository;

  WalletViewModel({WalletRepository? repository})
      : _repository = repository ?? WalletRepository();

  bool _processing = false;
  String? _error;

  bool get isProcessing => _processing;
  String? get error => _error;

  Stream<List<WalletTransaction>> transactions(String uid) =>
      _repository.watchTransactions(uid);

  Future<bool> topUp(String uid, int amountCents) async {
    _error = null;
    _processing = true;
    notifyListeners();
    try {
      await _repository.topUp(uid, amountCents);
      return true;
    } catch (e) {
      _error = 'Top-up failed. Please try again.';
      return false;
    } finally {
      _processing = false;
      notifyListeners();
    }
  }
}
