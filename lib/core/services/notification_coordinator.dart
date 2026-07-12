import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/user.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';
import 'notification_service.dart';

/// Client-side replacement for the plan's notification Cloud Functions
/// (`onOrderCreated`, `onOrderStatusChange`, `onAnnouncementCreated`).
///
/// Watches Firestore for the signed-in user and raises local notifications:
/// - customer: their order turns ready / collected / cancelled
/// - vendor: a new order arrives for their stall
/// - everyone: a new venue announcement is published
///
/// Limitation (accepted): notifications only arrive while the app process is
/// alive, since there is no server to push to a killed app.
class NotificationCoordinator {
  final FirebaseFirestore _db;
  final NotificationService _notifications;

  NotificationCoordinator({
    required NotificationService notifications,
    FirebaseFirestore? db,
  })  : _notifications = notifications,
        _db = db ?? FirebaseFirestore.instance;

  String? _activeUid;
  String? _activeRole;
  final List<StreamSubscription<QuerySnapshot<Map<String, dynamic>>>> _subs =
      [];

  /// Order statuses seen so far, keyed by orderId. Seeded from the first
  /// snapshot so pre-existing orders don't fire notifications on login.
  Map<String, String>? _orderStatuses;

  /// Syncs listeners with the signed-in user. Idempotent: call freely on
  /// every auth change; listeners restart only when the uid or role changes.
  void sync(AppUser? user) {
    if (user?.uid == _activeUid && user?.role == _activeRole) return;
    stop();
    if (user == null) return;
    _activeUid = user.uid;
    _activeRole = user.role;

    _watchAnnouncements(user.uid);
    if (user.role == AppConstants.roleCustomer) {
      _watchCustomerOrders(user.uid);
    } else if (user.role == AppConstants.roleVendor) {
      _watchVendorOrders(user.uid);
    }
  }

  void stop() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _orderStatuses = null;
    _activeUid = null;
    _activeRole = null;
  }

  // --- announcements (all roles) ---

  void _watchAnnouncements(String uid) {
    // Only announcements created after login; no seeding needed.
    final query = _db
        .collection(AppConstants.announcementsCollection)
        .where('createdAt', isGreaterThan: Timestamp.now());
    _listen(query, (snap) {
      for (final change in snap.docChanges) {
        if (change.type != DocumentChangeType.added) continue;
        final data = change.doc.data();
        if (data == null || data['createdBy'] == uid) continue;
        _notifications.show(
          id: _stableId(change.doc.id),
          title: (data['title'] ?? 'Announcement') as String,
          body: (data['message'] ?? '') as String,
        );
      }
    });
  }

  // --- customer: order status changes ---

  void _watchCustomerOrders(String uid) {
    final query = _db
        .collection(AppConstants.ordersCollection)
        .where('customerUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20);
    _listen(query, (snap) {
      final seeded = _orderStatuses != null;
      final statuses = _orderStatuses ??= {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '') as String;
        final previous = statuses[doc.id];
        statuses[doc.id] = status;
        // Notify only on a transition observed after the initial snapshot.
        // A newly placed order (previous == null) is the customer's own
        // action and needs no notification.
        if (!seeded || previous == null || previous == status) continue;
        _notifyCustomerStatus(doc.id, data, status);
      }
    });
  }

  void _notifyCustomerStatus(
    String orderId,
    Map<String, dynamic> data,
    String status,
  ) {
    final stall = (data['stallName'] ?? 'the stall') as String;
    final code = (data['pickupCode'] ?? '') as String;
    String? title;
    String? body;
    switch (status) {
      case AppConstants.orderReady:
        title = 'Order $code is ready!';
        body = 'Show your QR code at $stall to collect it.';
      case AppConstants.orderCollected:
        title = 'Order $code collected';
        body = 'Enjoy your meal from $stall!';
      case AppConstants.orderCancelled:
        final total = (data['total'] ?? 0) as int;
        title = 'Order $code cancelled';
        body = '${centsToRM(total)} has been refunded to your wallet.';
    }
    if (title == null || body == null) return;
    _notifications.show(id: _stableId(orderId), title: title, body: body);
  }

  // --- vendor: new incoming orders ---

  void _watchVendorOrders(String uid) {
    final query = _db
        .collection(AppConstants.ordersCollection)
        .where('vendorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(20);
    _listen(query, (snap) {
      final seeded = _orderStatuses != null;
      final statuses = _orderStatuses ??= {};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] ?? '') as String;
        final isNew = !statuses.containsKey(doc.id);
        statuses[doc.id] = status;
        if (!seeded || !isNew) continue;
        final code = (data['pickupCode'] ?? '') as String;
        final total = (data['total'] ?? 0) as int;
        _notifications.show(
          id: _stableId(doc.id),
          title: 'New order $code',
          body: '${data['customerName'] ?? 'A customer'} • '
              '${centsToRM(total)} — start preparing!',
        );
      }
    });
  }

  // --- helpers ---

  void _listen(
    Query<Map<String, dynamic>> query,
    void Function(QuerySnapshot<Map<String, dynamic>>) onData,
  ) {
    _subs.add(query.snapshots().listen(
      onData,
      onError: (Object e) =>
          debugPrint('NotificationCoordinator stream error: $e'),
    ));
  }

  /// Stable non-negative notification id derived from a document id, so a
  /// later update to the same subject replaces its notification.
  static int _stableId(String docId) => docId.hashCode & 0x7fffffff;
}
