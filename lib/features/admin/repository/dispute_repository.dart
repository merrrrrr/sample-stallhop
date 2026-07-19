import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/transaction.dart';

/// Disputes are cancelled orders. One is *open* while it has been neither
/// refunded nor dismissed by an admin.
class DisputeRepository {
  final FirebaseFirestore _db;

  DisputeRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(AppConstants.ordersCollection);

  /// All cancelled orders; the view model splits them into open/resolved.
  Stream<List<FoodOrder>> watchCancelledOrders() {
    return _orders
        .where('status', isEqualTo: AppConstants.orderCancelled)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FoodOrder.fromJson(d.data())).toList());
  }

  /// Credits the customer the full order total and marks the order refunded,
  /// atomically with the ledger entry.
  Future<void> refund(FoodOrder order) async {
    if (order.refunded) return;
    final now = DateTime.now();
    await _db.runTransaction((txn) async {
      final orderRef = _orders.doc(order.orderId);
      final customerRef =
          _db.collection(AppConstants.usersCollection).doc(order.customerUid);

      final customerSnap = await txn.get(customerRef);
      final before = (customerSnap.data()?['walletBalance'] ?? 0) as int;
      final after = before + order.total;

      txn.update(customerRef, {
        'walletBalance': after,
        'updatedAt': Timestamp.fromDate(now),
      });
      txn.update(orderRef, {
        'refunded': true,
        'updatedAt': Timestamp.fromDate(now),
      });

      final txnRef =
          _db.collection(AppConstants.transactionsCollection).doc();
      txn.set(
        txnRef,
        WalletTransaction(
          txnId: txnRef.id,
          userId: order.customerUid,
          type: AppConstants.txnRefund,
          amount: order.total,
          balanceBefore: before,
          balanceAfter: after,
          description: 'Admin refund • Order ${order.pickupCode}',
          relatedOrderId: order.orderId,
          createdAt: now,
        ).toJson(),
      );
    });
  }

  /// Resolves the dispute without refunding.
  Future<void> dismiss(FoodOrder order) {
    return _orders.doc(order.orderId).update({
      'dismissed': true,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }
}
