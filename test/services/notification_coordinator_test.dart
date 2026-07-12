import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/core/services/notification_coordinator.dart';
import 'package:stallhop/core/services/notification_service.dart';
import 'package:stallhop/models/user.dart';

/// Records notifications instead of touching the platform plugin.
class RecordingNotificationService extends NotificationService {
  final List<({int id, String title, String body})> shown = [];

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
  }) async {
    shown.add((id: id, title: title, body: body));
  }
}

AppUser user(String uid, String role) {
  final now = DateTime.now();
  return AppUser(
    uid: uid,
    name: 'Test $role',
    email: '$uid@test.com',
    phone: '0123456789',
    role: role,
    createdAt: now,
    updatedAt: now,
  );
}

Map<String, dynamic> orderDoc({
  required String customerUid,
  required String vendorUid,
  String status = 'preparing',
  String pickupCode = 'A001',
  DateTime? createdAt,
}) {
  final ts = Timestamp.fromDate(createdAt ?? DateTime.now());
  return {
    'orderId': 'o1',
    'customerUid': customerUid,
    'customerName': 'Alice',
    'stallId': 'stall1',
    'vendorUid': vendorUid,
    'stallName': 'Nasi Corner',
    'subtotal': 700,
    'serviceFee': 50,
    'total': 750,
    'status': status,
    'pickupCode': pickupCode,
    'createdAt': ts,
    'updatedAt': ts,
  };
}

// Let the fake's snapshot streams deliver.
Future<void> pump() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late FakeFirebaseFirestore db;
  late RecordingNotificationService notifications;
  late NotificationCoordinator coordinator;

  setUp(() {
    db = FakeFirebaseFirestore();
    notifications = RecordingNotificationService();
    coordinator =
        NotificationCoordinator(notifications: notifications, db: db);
  });

  tearDown(() => coordinator.stop());

  group('customer', () {
    test('notified when their order becomes ready', () async {
      final ref = await db.collection('orders').add(
          orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
      coordinator.sync(user('cust1', 'customer'));
      await pump();
      expect(notifications.shown, isEmpty); // seed snapshot, no notify

      await ref.update({'status': 'ready'});
      await pump();

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.title, contains('ready'));
      expect(notifications.shown.single.title, contains('A001'));
    });

    test('notified with refund amount when order is cancelled', () async {
      final ref = await db.collection('orders').add(
          orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
      coordinator.sync(user('cust1', 'customer'));
      await pump();

      await ref.update({'status': 'cancelled', 'refunded': true});
      await pump();

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.body, contains('RM 7.50'));
    });

    test('placing their own order does not notify', () async {
      coordinator.sync(user('cust1', 'customer'));
      await pump();

      await db.collection('orders').add(
          orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
      await pump();

      expect(notifications.shown, isEmpty);
    });
  });

  group('vendor', () {
    test('notified when a new order arrives', () async {
      coordinator.sync(user('vend1', 'vendor'));
      await pump();

      await db.collection('orders').add(
          orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
      await pump();

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.title, contains('New order'));
      expect(notifications.shown.single.body, contains('RM 7.50'));
    });

    test('pre-existing orders at login do not notify', () async {
      await db.collection('orders').add(
          orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
      coordinator.sync(user('vend1', 'vendor'));
      await pump();

      expect(notifications.shown, isEmpty);
    });

    test('own status updates do not notify', () async {
      final ref = await db.collection('orders').add(
          orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
      coordinator.sync(user('vend1', 'vendor'));
      await pump();

      await ref.update({'status': 'ready'});
      await pump();

      expect(notifications.shown, isEmpty);
    });
  });

  group('announcements', () {
    test('new announcement notifies any signed-in user', () async {
      coordinator.sync(user('cust1', 'customer'));
      await pump();

      await db.collection('announcements').add({
        'announcementId': 'a1',
        'title': 'Venue closing early',
        'message': 'We close at 8pm today.',
        'createdBy': 'admin1',
        'createdAt': Timestamp.now(),
      });
      await pump();

      expect(notifications.shown, hasLength(1));
      expect(notifications.shown.single.title, 'Venue closing early');
    });

    test('authors do not get notified of their own announcement', () async {
      coordinator.sync(user('admin1', 'admin'));
      await pump();

      await db.collection('announcements').add({
        'announcementId': 'a1',
        'title': 'Hello',
        'message': 'World',
        'createdBy': 'admin1',
        'createdAt': Timestamp.now(),
      });
      await pump();

      expect(notifications.shown, isEmpty);
    });
  });

  test('stop() ends all listening', () async {
    coordinator.sync(user('vend1', 'vendor'));
    await pump();
    coordinator.stop();

    await db.collection('orders').add(
        orderDoc(customerUid: 'cust1', vendorUid: 'vend1'));
    await pump();

    expect(notifications.shown, isEmpty);
  });
}
