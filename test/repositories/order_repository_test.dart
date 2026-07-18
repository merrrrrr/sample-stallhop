import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/features/customer/repository/order_repository.dart';
import 'package:stallhop/models/order_item.dart';
import 'package:stallhop/models/stall.dart';
import 'package:stallhop/models/user.dart';

void main() {
  late FakeFirebaseFirestore db;
  late OrderRepository repo;
  final now = DateTime.now();

  final customer = AppUser(
    uid: 'cust1',
    name: 'Alice',
    email: 'alice@test.com',
    phone: '0123456789',
    role: 'customer',
    walletBalance: 10000,
    createdAt: now,
    updatedAt: now,
  );

  final stall = Stall(
    stallId: 'stall1',
    vendorUid: 'vend1',
    name: 'Nasi Corner',
    status: 'open',
    createdAt: now,
    updatedAt: now,
  );

  final items = [
    OrderItem(itemId: 'i1', name: 'Nasi Lemak', unitPrice: 700, quantity: 1),
  ];

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = OrderRepository(db: db);
    await db.collection('users').doc('cust1').set(customer.toJson());
    await db.collection('users').doc('vend1').set({
      'uid': 'vend1',
      'walletBalance': 0,
      'updatedAt': Timestamp.fromDate(now),
    });
  });

  group('pickup codes', () {
    test('increment within the same day', () async {
      final o1 = await repo.placeOrder(
          customer: customer, stall: stall, items: items);
      final o2 = await repo.placeOrder(
          customer: customer, stall: stall, items: items);
      expect(o1.pickupCode, 'A001');
      expect(o2.pickupCode, 'A002');
    });

    test('counter resets when the stored date is a previous day', () async {
      await db.collection('config').doc('venue').set({
        'pickupCodePrefix': 'A',
        'pickupCodeCounter': 42,
        'pickupCodeDate': '2020-01-01',
      });

      final order = await repo.placeOrder(
          customer: customer, stall: stall, items: items);

      expect(order.pickupCode, 'A001');
      final venue = await db.collection('config').doc('venue').get();
      expect(venue.data()!['pickupCodeCounter'], 1);
      expect(venue.data()!['pickupCodeDate'], isNot('2020-01-01'));
    });

    test('counter continues when the stored date is today', () async {
      final first = await repo.placeOrder(
          customer: customer, stall: stall, items: items);
      expect(first.pickupCode, 'A001');

      final second = await repo.placeOrder(
          customer: customer, stall: stall, items: items);
      expect(second.pickupCode, 'A002');
      final venue = await db.collection('config').doc('venue').get();
      expect(venue.data()!['pickupCodeCounter'], 2);
    });
  });

  group('wallets', () {
    test('placeOrder deducts customer and credits vendor minus commission',
        () async {
      await repo.placeOrder(customer: customer, stall: stall, items: items);

      final cust = await db.collection('users').doc('cust1').get();
      final vend = await db.collection('users').doc('vend1').get();
      // total = 700 subtotal + 50 service fee
      expect(cust.data()!['walletBalance'], 10000 - 750);
      // no stall override and no venue doc, so the 10% default applies
      expect(vend.data()!['walletBalance'], 700 - 70);
    });

    test('a null stall rate inherits the venue default', () async {
      await db.collection('config').doc('venue').set({
        'defaultCommission': 0.15,
      });

      final order = await repo.placeOrder(
          customer: customer, stall: stall, items: items);

      final vend = await db.collection('users').doc('vend1').get();
      expect(vend.data()!['walletBalance'], 700 - 105);
      expect(order.commissionRate, 0.15);
      expect(order.vendorEarning, 700 - 105);
    });

    test('an explicit stall rate overrides the venue default', () async {
      await db.collection('config').doc('venue').set({
        'defaultCommission': 0.15,
      });

      final order = await repo.placeOrder(
        customer: customer,
        stall: stall.copyWith(commissionRate: 0.05),
        items: items,
      );

      final vend = await db.collection('users').doc('vend1').get();
      expect(vend.data()!['walletBalance'], 700 - 35);
      expect(order.commissionRate, 0.05);
      expect(order.vendorEarning, 700 - 35);
    });

    test('cancelAndRefund restores customer and claws back vendor', () async {
      final order = await repo.placeOrder(
          customer: customer, stall: stall, items: items);
      await repo.cancelAndRefund(order);

      final cust = await db.collection('users').doc('cust1').get();
      final vend = await db.collection('users').doc('vend1').get();
      expect(cust.data()!['walletBalance'], 10000);
      expect(vend.data()!['walletBalance'], 0);

      final stored = await db.collection('orders').doc(order.orderId).get();
      expect(stored.data()!['status'], 'cancelled');
      expect(stored.data()!['refunded'], true);
    });

    test('refund at a non-default rate returns both wallets to par', () async {
      await db.collection('config').doc('venue').set({
        'defaultCommission': 0.15,
      });

      final order = await repo.placeOrder(
        customer: customer,
        stall: stall.copyWith(commissionRate: 0.05),
        items: items,
      );
      await repo.cancelAndRefund(order);

      // Reversing the stored vendorEarning rather than recomputing at a
      // hardcoded 10% is what keeps these exact.
      final cust = await db.collection('users').doc('cust1').get();
      final vend = await db.collection('users').doc('vend1').get();
      expect(cust.data()!['walletBalance'], 10000);
      expect(vend.data()!['walletBalance'], 0);
    });

    test('cancelAndRefund is idempotent', () async {
      final order = await repo.placeOrder(
          customer: customer, stall: stall, items: items);
      await repo.cancelAndRefund(order);
      await repo.cancelAndRefund(order.copyWith(refunded: true));

      final cust = await db.collection('users').doc('cust1').get();
      final vend = await db.collection('users').doc('vend1').get();
      expect(cust.data()!['walletBalance'], 10000);
      expect(vend.data()!['walletBalance'], 0);
    });
  });
}
