import 'package:cloud_firestore/cloud_firestore.dart';

import 'order_item.dart';

/// A customer order for a single stall. Named [FoodOrder] to avoid clashing
/// with Firestore's `Order` concepts and Dart conventions.
///
/// `status` is one of: `preparing`, `ready`, `collected`, `cancelled`.
class FoodOrder {
  final String orderId;
  final String customerUid;
  final String customerName;
  final String stallId;
  final String vendorUid;
  final String stallName;
  final List<OrderItem> items;
  final int subtotal; // cents
  final int serviceFee; // cents
  final int total; // cents
  final String status;
  final String pickupCode;
  final bool refunded;

  /// Admin dismissed the dispute for this cancelled order without refunding.
  /// A cancelled order is an *open dispute* while neither [refunded] nor
  /// [dismissed] is true.
  final bool dismissed;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? readyAt;
  final DateTime? collectedAt;
  final DateTime? cancelledAt;

  FoodOrder({
    required this.orderId,
    required this.customerUid,
    required this.customerName,
    required this.stallId,
    required this.vendorUid,
    required this.stallName,
    this.items = const [],
    required this.subtotal,
    required this.serviceFee,
    required this.total,
    this.status = 'preparing',
    required this.pickupCode,
    this.refunded = false,
    this.dismissed = false,
    required this.createdAt,
    required this.updatedAt,
    this.readyAt,
    this.collectedAt,
    this.cancelledAt,
  });

  static DateTime? _ts(dynamic value) =>
      value == null ? null : (value as Timestamp).toDate();

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    return FoodOrder(
      orderId: json['orderId'] ?? '',
      customerUid: json['customerUid'] ?? '',
      customerName: json['customerName'] ?? '',
      stallId: json['stallId'] ?? '',
      vendorUid: json['vendorUid'] ?? '',
      stallName: json['stallName'] ?? '',
      items: json['items'] == null
          ? []
          : (json['items'] as List)
              .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
      subtotal: (json['subtotal'] ?? 0) as int,
      serviceFee: (json['serviceFee'] ?? 0) as int,
      total: (json['total'] ?? 0) as int,
      status: json['status'] ?? 'preparing',
      pickupCode: json['pickupCode'] ?? '',
      refunded: json['refunded'] ?? false,
      dismissed: json['dismissed'] ?? false,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      readyAt: _ts(json['readyAt']),
      collectedAt: _ts(json['collectedAt']),
      cancelledAt: _ts(json['cancelledAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'orderId': orderId,
        'customerUid': customerUid,
        'customerName': customerName,
        'stallId': stallId,
        'vendorUid': vendorUid,
        'stallName': stallName,
        'items': items.map((e) => e.toJson()).toList(),
        'subtotal': subtotal,
        'serviceFee': serviceFee,
        'total': total,
        'status': status,
        'pickupCode': pickupCode,
        'refunded': refunded,
        'dismissed': dismissed,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'readyAt': readyAt == null ? null : Timestamp.fromDate(readyAt!),
        'collectedAt':
            collectedAt == null ? null : Timestamp.fromDate(collectedAt!),
        'cancelledAt':
            cancelledAt == null ? null : Timestamp.fromDate(cancelledAt!),
      };

  FoodOrder copyWith({
    String? status,
    bool? refunded,
    bool? dismissed,
    DateTime? updatedAt,
    DateTime? readyAt,
    DateTime? collectedAt,
    DateTime? cancelledAt,
  }) {
    return FoodOrder(
      orderId: orderId,
      customerUid: customerUid,
      customerName: customerName,
      stallId: stallId,
      vendorUid: vendorUid,
      stallName: stallName,
      items: items,
      subtotal: subtotal,
      serviceFee: serviceFee,
      total: total,
      status: status ?? this.status,
      pickupCode: pickupCode,
      refunded: refunded ?? this.refunded,
      dismissed: dismissed ?? this.dismissed,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      readyAt: readyAt ?? this.readyAt,
      collectedAt: collectedAt ?? this.collectedAt,
      cancelledAt: cancelledAt ?? this.cancelledAt,
    );
  }
}
