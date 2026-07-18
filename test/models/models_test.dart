import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/models/announcement.dart';
import 'package:stallhop/models/menu_item.dart';
import 'package:stallhop/models/order.dart';
import 'package:stallhop/models/order_item.dart';
import 'package:stallhop/models/review.dart';
import 'package:stallhop/models/stall.dart';
import 'package:stallhop/models/transaction.dart';
import 'package:stallhop/models/user.dart';
import 'package:stallhop/models/venue_config.dart';

/// Round-trips a model through toJson -> fromJson and asserts the resulting
/// JSON maps are identical. Comparing the serialized maps (as strings) gives a
/// deterministic deep comparison that also handles Timestamps.
void expectRoundTrip(
  Map<String, dynamic> original,
  Map<String, dynamic> roundTripped,
) {
  expect(roundTripped.toString(), original.toString());
}

void main() {
  final now = DateTime(2026, 6, 26, 12, 30);
  final later = DateTime(2026, 6, 26, 13, 0);

  test('AppUser round-trips', () {
    final user = AppUser(
      uid: 'u1',
      name: 'Alice',
      email: 'alice@example.com',
      phone: '0123456789',
      role: 'customer',
      profileImageUrl: 'http://img/a.png',
      walletBalance: 1500,
      fcmToken: 'token123',
      createdAt: now,
      updatedAt: later,
    );
    expectRoundTrip(
      user.toJson(),
      AppUser.fromJson(user.toJson()).toJson(),
    );
  });

  test('Stall round-trips', () {
    final stall = Stall(
      stallId: 's1',
      vendorUid: 'v1',
      name: 'Nasi Lemak Corner',
      description: 'Best in town',
      cuisine: 'Malay',
      imageUrl: 'http://img/s.png',
      status: 'open',
      prepTimeMinutes: 12,
      averageRating: 4.5,
      totalReviews: 20,
      commissionRate: 0.12,
      latitude: 3.139,
      longitude: 101.6869,
      createdAt: now,
      updatedAt: later,
    );
    expectRoundTrip(
      stall.toJson(),
      Stall.fromJson(stall.toJson()).toJson(),
    );
  });

  test('Stall round-trips a null commissionRate as null', () {
    final stall = Stall(
      stallId: 's2',
      vendorUid: 'v1',
      name: 'Inherits The Default',
      createdAt: now,
      updatedAt: later,
    );
    expect(stall.commissionRate, isNull);
    final back = Stall.fromJson(stall.toJson());
    expect(back.commissionRate, isNull,
        reason: 'null means "inherit the venue default" and must not be '
            'coerced to a concrete rate on the way back');
    expectRoundTrip(stall.toJson(), back.toJson());
  });

  test('Stall.fromJson treats a missing commissionRate as inherit', () {
    final json = Stall(
      stallId: 's3',
      vendorUid: 'v1',
      name: 'No Rate Key',
      createdAt: now,
      updatedAt: later,
    ).toJson()
      ..remove('commissionRate');
    expect(Stall.fromJson(json).commissionRate, isNull);
  });

  test('Stall.copyWith preserves an override but clears it on request', () {
    final overridden = Stall(
      stallId: 's4',
      vendorUid: 'v1',
      name: 'Negotiated Rate',
      commissionRate: 0.05,
      createdAt: now,
      updatedAt: later,
    );

    expect(overridden.copyWith(name: 'Renamed').commissionRate, 0.05);
    expect(overridden.copyWith(commissionRate: null).commissionRate, 0.05,
        reason: 'passing null cannot mean "clear" — it is indistinguishable '
            'from "leave unchanged"');
    expect(overridden.copyWith(commissionRate: 0.20).commissionRate, 0.20);
    expect(overridden.copyWith(clearCommissionRate: true).commissionRate,
        isNull);
  });

  test('MenuItem round-trips with customizations and add-ons', () {
    final item = MenuItem(
      itemId: 'i1',
      stallId: 's1',
      name: 'Fried Rice',
      description: 'Wok-fried',
      price: 800,
      category: 'Mains',
      imageUrl: 'http://img/i.png',
      available: true,
      customizations: [
        {
          'name': 'Spice',
          'options': ['Mild', 'Hot'],
        },
      ],
      addOns: [
        {'name': 'Extra egg', 'price': 150},
      ],
      createdAt: now,
      updatedAt: later,
    );
    expectRoundTrip(
      item.toJson(),
      MenuItem.fromJson(item.toJson()).toJson(),
    );
  });

  test('OrderItem round-trips and computes subtotal', () {
    final orderItem = OrderItem(
      itemId: 'i1',
      name: 'Fried Rice',
      unitPrice: 800,
      quantity: 2,
      customizations: {'Spice': 'Hot'},
      addOns: [
        {'name': 'Extra egg', 'price': 150},
      ],
      specialInstructions: 'No onions',
    );
    // (800 + 150) * 2 = 1900
    expect(orderItem.subtotal, 1900);
    expectRoundTrip(
      orderItem.toJson(),
      OrderItem.fromJson(orderItem.toJson()).toJson(),
    );
  });

  test('FoodOrder round-trips with nested items', () {
    final order = FoodOrder(
      orderId: 'o1',
      customerUid: 'u1',
      customerName: 'Alice',
      stallId: 's1',
      vendorUid: 'v1',
      stallName: 'Nasi Lemak Corner',
      items: [
        OrderItem(
          itemId: 'i1',
          name: 'Fried Rice',
          unitPrice: 800,
          quantity: 1,
          addOns: [
            {'name': 'Extra egg', 'price': 150},
          ],
        ),
      ],
      subtotal: 950,
      serviceFee: 50,
      total: 1000,
      commissionRate: 0.15,
      vendorEarning: 808,
      status: 'preparing',
      pickupCode: 'A001',
      refunded: false,
      createdAt: now,
      updatedAt: later,
      readyAt: later,
    );
    expectRoundTrip(
      order.toJson(),
      FoodOrder.fromJson(order.toJson()).toJson(),
    );
  });

  test('FoodOrder dispute flags round-trip', () {
    final order = FoodOrder(
      orderId: 'o2',
      customerUid: 'u1',
      customerName: 'Alice',
      stallId: 's1',
      vendorUid: 'v1',
      stallName: 'Nasi Lemak Corner',
      subtotal: 950,
      serviceFee: 50,
      total: 1000,
      status: 'cancelled',
      pickupCode: 'A002',
      refunded: true,
      dismissed: true,
      createdAt: now,
      updatedAt: later,
      cancelledAt: later,
    );
    final back = FoodOrder.fromJson(order.toJson());
    expect(back.refunded, isTrue);
    expect(back.dismissed, isTrue);
    expect(back.cancelledAt, later);
    // An argument-less copyWith preserves both flags rather than resetting
    // them to their constructor defaults.
    expect(FoodOrder.fromJson(order.copyWith().toJson()).refunded, isTrue);
    expect(FoodOrder.fromJson(order.copyWith().toJson()).dismissed, isTrue);
  });

  test('FoodOrder carries the applied rate and earning through copyWith', () {
    final order = FoodOrder(
      orderId: 'o4',
      customerUid: 'u1',
      customerName: 'Alice',
      stallId: 's1',
      vendorUid: 'v1',
      stallName: 'Nasi Lemak Corner',
      subtotal: 1000,
      serviceFee: 50,
      total: 1050,
      commissionRate: 0.15,
      vendorEarning: 850,
      pickupCode: 'A004',
      createdAt: now,
      updatedAt: now,
    );

    final back = FoodOrder.fromJson(order.toJson());
    expect(back.commissionRate, 0.15);
    expect(back.vendorEarning, 850);

    // Both must survive a status transition, because cancelAndRefund reverses
    // the stored earning long after placement.
    final cancelled = order.copyWith(status: 'cancelled', refunded: true);
    expect(cancelled.commissionRate, 0.15);
    expect(cancelled.vendorEarning, 850);
  });

  test('a fresh order defaults to an open dispute', () {
    final order = FoodOrder(
      orderId: 'o3',
      customerUid: 'u1',
      customerName: 'Alice',
      stallId: 's1',
      vendorUid: 'v1',
      stallName: 'Nasi Lemak Corner',
      subtotal: 950,
      serviceFee: 50,
      total: 1000,
      pickupCode: 'A003',
      createdAt: now,
      updatedAt: now,
    );
    expect(order.refunded, isFalse);
    expect(order.dismissed, isFalse);
    final back = FoodOrder.fromJson(order.toJson());
    expect(back.refunded, isFalse);
    expect(back.dismissed, isFalse);
  });

  test('WalletTransaction round-trips', () {
    final txn = WalletTransaction(
      txnId: 't1',
      userId: 'u1',
      type: 'topup',
      amount: 1000,
      balanceBefore: 500,
      balanceAfter: 1500,
      description: 'Top up',
      relatedOrderId: null,
      createdAt: now,
    );
    expectRoundTrip(
      txn.toJson(),
      WalletTransaction.fromJson(txn.toJson()).toJson(),
    );
  });

  test('Review round-trips', () {
    final review = Review(
      reviewId: 'r1',
      orderId: 'o1',
      stallId: 's1',
      customerUid: 'u1',
      customerName: 'Alice',
      rating: 5,
      comment: 'Delicious!',
      createdAt: now,
    );
    expectRoundTrip(
      review.toJson(),
      Review.fromJson(review.toJson()).toJson(),
    );
  });

  test('Announcement round-trips', () {
    final ann = Announcement(
      announcementId: 'a1',
      title: 'Closed Monday',
      message: 'Venue closed for maintenance',
      createdBy: 'admin1',
      createdAt: now,
    );
    expectRoundTrip(
      ann.toJson(),
      Announcement.fromJson(ann.toJson()).toJson(),
    );
  });

  test('VenueConfig round-trips', () {
    final config = VenueConfig(
      venueName: 'StallHop Central',
      defaultCommission: 0.10,
      serviceFee: 50,
      pickupCodePrefix: 'A',
      pickupCodeCounter: 42,
      latitude: 3.139,
      longitude: 101.6869,
      updatedAt: now,
    );
    expectRoundTrip(
      config.toJson(),
      VenueConfig.fromJson(config.toJson()).toJson(),
    );
  });

  test('Timestamp conversion preserves the instant', () {
    final user = AppUser(
      uid: 'u1',
      name: 'A',
      email: 'a@b.com',
      phone: '0123456789',
      role: 'customer',
      createdAt: now,
      updatedAt: later,
    );
    final back = AppUser.fromJson(user.toJson());
    expect(back.createdAt, now);
    expect(back.updatedAt, later);
    expect((user.toJson()['createdAt'] as Timestamp).toDate(), now);
  });
}
