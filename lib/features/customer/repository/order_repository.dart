import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/app_exceptions.dart';
import '../../../core/utils/constants.dart';
import '../../../models/order.dart';
import '../../../models/order_item.dart';
import '../../../models/stall.dart';
import '../../../models/transaction.dart';
import '../../../models/user.dart';

/// Order lifecycle: placing (atomic payment + pickup code), reading, watching,
/// and cancel/refund. The place-order and refund paths run as single Firestore
/// transactions to keep wallets, the order, and the ledger consistent.
class OrderRepository {
  final FirebaseFirestore _db;

  OrderRepository({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _db.collection(AppConstants.ordersCollection);

  DocumentReference<Map<String, dynamic>> _userRef(String uid) =>
      _db.collection(AppConstants.usersCollection).doc(uid);

  DocumentReference<Map<String, dynamic>> get _venueRef => _db
      .collection(AppConstants.configCollection)
      .doc(AppConstants.venueConfigDoc);

  /// Places one order for one stall. Atomically: validates the customer has
  /// funds, generates a pickup code, deducts the customer, credits the vendor
  /// (minus commission), and writes the order + two ledger entries.
  Future<FoodOrder> placeOrder({
    required AppUser customer,
    required Stall stall,
    required List<OrderItem> items,
    int serviceFeeCents = AppConstants.serviceFeeCents,
  }) async {
    final subtotal = items.fold<int>(0, (acc, i) => acc + i.subtotal);
    final total = subtotal + serviceFeeCents;
    final now = DateTime.now();
    late FoodOrder order;

    await _db.runTransaction((txn) async {
      final customerRef = _userRef(customer.uid);
      final vendorRef = _userRef(stall.vendorUid);

      // --- reads first (Firestore requires all reads before writes) ---
      final customerSnap = await txn.get(customerRef);
      final vendorSnap = await txn.get(vendorRef);
      final venueSnap = await txn.get(_venueRef);

      final custBefore = (customerSnap.data()?['walletBalance'] ?? 0) as int;
      if (custBefore < total) throw const InsufficientBalanceException();
      final vendBefore = (vendorSnap.data()?['walletBalance'] ?? 0) as int;

      // Pickup codes restart each day (replaces the plan's scheduled
      // resetPickupCodeDaily Cloud Function — automation is client-side).
      final todayKey = _dateKey(now);
      final storedDate = venueSnap.data()?['pickupCodeDate'] as String?;
      final isNewDay = storedDate != todayKey;
      final prefix = isNewDay
          ? 'A'
          : (venueSnap.data()?['pickupCodePrefix'] ?? 'A') as String;
      final counter = isNewDay
          ? 0
          : (venueSnap.data()?['pickupCodeCounter'] ?? 0) as int;
      final nextCounter = counter + 1;
      final pickupCode = '$prefix${nextCounter.toString().padLeft(3, '0')}';

      final venueRate = (venueSnap.data()?['defaultCommission'] ??
              AppConstants.defaultCommissionRate)
          .toDouble();
      final rate = stall.commissionRate ?? venueRate;
      final vendorEarning = (subtotal * (1 - rate)).round();
      final custAfter = custBefore - total;
      final vendAfter = vendBefore + vendorEarning;

      final orderRef = _orders.doc();
      order = FoodOrder(
        orderId: orderRef.id,
        customerUid: customer.uid,
        customerName: customer.name,
        stallId: stall.stallId,
        vendorUid: stall.vendorUid,
        stallName: stall.name,
        items: items,
        subtotal: subtotal,
        serviceFee: serviceFeeCents,
        total: total,
        commissionRate: rate,
        vendorEarning: vendorEarning,
        status: AppConstants.orderPreparing,
        pickupCode: pickupCode,
        createdAt: now,
        updatedAt: now,
      );

      // --- writes ---
      txn.set(orderRef, order.toJson());
      txn.update(customerRef, {
        'walletBalance': custAfter,
        'updatedAt': Timestamp.fromDate(now),
      });
      txn.update(vendorRef, {
        'walletBalance': vendAfter,
        'updatedAt': Timestamp.fromDate(now),
      });
      txn.set(_venueRef, {
        'pickupCodePrefix': prefix,
        'pickupCodeCounter': nextCounter,
        'pickupCodeDate': todayKey,
        'updatedAt': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      _writeTxn(
        txn,
        userId: customer.uid,
        type: AppConstants.txnPayment,
        amount: total,
        before: custBefore,
        after: custAfter,
        description: 'Order ${order.pickupCode} • ${stall.name}',
        orderId: orderRef.id,
      );
      _writeTxn(
        txn,
        userId: stall.vendorUid,
        type: AppConstants.txnEarning,
        amount: vendorEarning,
        before: vendBefore,
        after: vendAfter,
        description: 'Earning • Order ${order.pickupCode}',
        orderId: orderRef.id,
      );
    });

    return order;
  }

  /// Cancels an order and refunds the customer the full total, clawing back
  /// the vendor's earning. Sets status `cancelled` and `refunded = true`.
  Future<void> cancelAndRefund(FoodOrder order) async {
    if (order.refunded) return;
    final now = DateTime.now();
    await _db.runTransaction((txn) async {
      final orderRef = _orders.doc(order.orderId);
      final customerRef = _userRef(order.customerUid);
      final vendorRef = _userRef(order.vendorUid);

      final customerSnap = await txn.get(customerRef);
      final vendorSnap = await txn.get(vendorRef);

      final custBefore = (customerSnap.data()?['walletBalance'] ?? 0) as int;
      final vendBefore = (vendorSnap.data()?['walletBalance'] ?? 0) as int;
      final vendorEarning = order.vendorEarning;
      final custAfter = custBefore + order.total;
      final vendAfter = vendBefore - vendorEarning;

      txn.update(orderRef, {
        'status': AppConstants.orderCancelled,
        'refunded': true,
        'updatedAt': Timestamp.fromDate(now),
        'cancelledAt': Timestamp.fromDate(now),
      });
      txn.update(customerRef, {
        'walletBalance': custAfter,
        'updatedAt': Timestamp.fromDate(now),
      });
      txn.update(vendorRef, {
        'walletBalance': vendAfter,
        'updatedAt': Timestamp.fromDate(now),
      });
      _writeTxn(
        txn,
        userId: order.customerUid,
        type: AppConstants.txnRefund,
        amount: order.total,
        before: custBefore,
        after: custAfter,
        description: 'Refund • Order ${order.pickupCode}',
        orderId: order.orderId,
      );
      _writeTxn(
        txn,
        userId: order.vendorUid,
        type: AppConstants.txnRefund,
        amount: vendorEarning,
        before: vendBefore,
        after: vendAfter,
        description: 'Reversal • Order ${order.pickupCode}',
        orderId: order.orderId,
      );
    });
  }

  /// Calendar-day key (`yyyy-MM-dd`) used to detect when the pickup-code
  /// counter should reset.
  static String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  void _writeTxn(
    Transaction txn, {
    required String userId,
    required String type,
    required int amount,
    required int before,
    required int after,
    required String description,
    String? orderId,
  }) {
    final ref = _db.collection(AppConstants.transactionsCollection).doc();
    txn.set(
      ref,
      WalletTransaction(
        txnId: ref.id,
        userId: userId,
        type: type,
        amount: amount,
        balanceBefore: before,
        balanceAfter: after,
        description: description,
        relatedOrderId: orderId,
        createdAt: DateTime.now(),
      ).toJson(),
    );
  }

  Future<void> updateStatus(String orderId, String status) {
    final now = DateTime.now();
    final data = <String, dynamic>{
      'status': status,
      'updatedAt': Timestamp.fromDate(now),
    };
    if (status == AppConstants.orderReady) {
      data['readyAt'] = Timestamp.fromDate(now);
    } else if (status == AppConstants.orderCollected) {
      data['collectedAt'] = Timestamp.fromDate(now);
    }
    return _orders.doc(orderId).update(data);
  }

  Future<FoodOrder?> getOrder(String orderId) async {
    final snap = await _orders.doc(orderId).get();
    final data = snap.data();
    return data == null ? null : FoodOrder.fromJson(data);
  }

  Stream<FoodOrder?> listenToOrder(String orderId) {
    return _orders.doc(orderId).snapshots().map(
          (snap) =>
              snap.data() == null ? null : FoodOrder.fromJson(snap.data()!),
        );
  }

  Stream<List<FoodOrder>> watchCustomerOrders(String customerUid) {
    return _orders
        .where('customerUid', isEqualTo: customerUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FoodOrder.fromJson(d.data())).toList());
  }

  Stream<List<FoodOrder>> watchVendorOrders(
    String vendorUid, {
    List<String>? statuses,
  }) {
    var query = _orders.where('vendorUid', isEqualTo: vendorUid);
    if (statuses != null && statuses.isNotEmpty) {
      query = query.where('status', whereIn: statuses);
    }
    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => FoodOrder.fromJson(d.data())).toList());
  }
}
