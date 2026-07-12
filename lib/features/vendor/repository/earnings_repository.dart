import '../../../core/utils/constants.dart';
import '../../../models/transaction.dart';
import '../../customer/repository/wallet_repository.dart';

/// Vendor earnings view over the shared wallet ledger — earnings and
/// withdrawals only.
class EarningsRepository {
  final WalletRepository _wallet;

  EarningsRepository({WalletRepository? wallet})
      : _wallet = wallet ?? WalletRepository();

  static const _types = [
    AppConstants.txnEarning,
    AppConstants.txnWithdrawal,
    AppConstants.txnRefund,
  ];

  Stream<List<WalletTransaction>> watchEarnings(String vendorUid) {
    return _wallet.watchTransactions(vendorUid, types: _types);
  }

  Future<void> withdraw(String vendorUid, int amountCents) {
    return _wallet.withdraw(vendorUid, amountCents);
  }
}
