import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/firestore_service.dart';
import '../../../core/utils/app_exceptions.dart';
import '../../../core/utils/constants.dart';
import '../../../models/transaction.dart';

/// Wallet balance + ledger operations. All balance-changing methods run inside
/// a Firestore transaction so the balance and its ledger entry stay in sync.
class WalletRepository {
  final FirebaseFirestore _db;
  final FirestoreService _firestore;

  WalletRepository({FirebaseFirestore? db, FirestoreService? firestore})
      : _db = db ?? FirebaseFirestore.instance,
        _firestore = firestore ?? FirestoreService();

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  CollectionReference<Map<String, dynamic>> get _txns =>
      _db.collection(AppConstants.transactionsCollection);

  /// Adds [amountCents] to a customer wallet and records a `topup` entry.
  Future<void> topUp(String uid, int amountCents) {
    return _applyDelta(
      uid: uid,
      delta: amountCents,
      type: AppConstants.txnTopUp,
      description: 'Top up',
    );
  }

  /// Credits [amountCents] back to a wallet (used by refunds).
  Future<void> refund(
    String uid,
    int amountCents, {
    String? orderId,
    String description = 'Refund',
  }) {
    return _applyDelta(
      uid: uid,
      delta: amountCents,
      type: AppConstants.txnRefund,
      description: description,
      relatedOrderId: orderId,
    );
  }

  /// Deducts [amountCents] from a wallet as a `payment` (used outside the
  /// place-order transaction, e.g. manual adjustments).
  Future<void> deductPayment(
    String uid,
    int amountCents, {
    String? orderId,
    String description = 'Payment',
  }) {
    return _applyDelta(
      uid: uid,
      delta: -amountCents,
      type: AppConstants.txnPayment,
      description: description,
      relatedOrderId: orderId,
      requireFunds: true,
    );
  }

  /// Vendor withdrawal: debits [amountCents] and records a `withdrawal` entry.
  Future<void> withdraw(String uid, int amountCents) {
    return _applyDelta(
      uid: uid,
      delta: -amountCents,
      type: AppConstants.txnWithdrawal,
      description: 'Withdrawal',
      requireFunds: true,
    );
  }

  Future<void> _applyDelta({
    required String uid,
    required int delta,
    required String type,
    required String description,
    String? relatedOrderId,
    bool requireFunds = false,
  }) async {
    await _db.runTransaction((txn) async {
      final ref = _userRef(uid);
      final snap = await txn.get(ref);
      if (!snap.exists) throw const NotFoundException('User not found');
      final before = (snap.data()!['walletBalance'] ?? 0) as int;
      final after = before + delta;
      if (requireFunds && after < 0) {
        throw const InsufficientBalanceException();
      }
      txn.update(ref, {
        'walletBalance': after,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      final txnRef = _txns.doc();
      txn.set(
        txnRef,
        WalletTransaction(
          txnId: txnRef.id,
          userId: uid,
          type: type,
          amount: delta.abs(),
          balanceBefore: before,
          balanceAfter: after,
          description: description,
          relatedOrderId: relatedOrderId,
          createdAt: DateTime.now(),
        ).toJson(),
      );
    });
  }

  Future<List<WalletTransaction>> getTransactions(
    String uid, {
    List<String>? types,
  }) async {
    final rows = await _firestore.getCollection(
      AppConstants.transactionsCollection,
      query: (q) {
        var query = q.where('userId', isEqualTo: uid);
        if (types != null && types.isNotEmpty) {
          query = query.where('type', whereIn: types);
        }
        return query.orderBy('createdAt', descending: true);
      },
    );
    return rows.map(WalletTransaction.fromJson).toList();
  }

  Stream<List<WalletTransaction>> watchTransactions(
    String uid, {
    List<String>? types,
  }) {
    return _firestore
        .collectionStream(
          AppConstants.transactionsCollection,
          query: (q) {
            var query = q.where('userId', isEqualTo: uid);
            if (types != null && types.isNotEmpty) {
              query = query.where('type', whereIn: types);
            }
            return query.orderBy('createdAt', descending: true);
          },
        )
        .map((rows) => rows.map(WalletTransaction.fromJson).toList());
  }
}
