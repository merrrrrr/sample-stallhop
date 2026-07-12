import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/core/utils/app_exceptions.dart';
import 'package:stallhop/features/customer/repository/wallet_repository.dart';
import 'package:stallhop/features/customer/view_model/wallet_vm.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WalletRepository repo;
  late WalletViewModel vm;

  Future<int> balance(String uid) async =>
      (await db.collection('users').doc(uid).get()).data()!['walletBalance']
          as int;

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = WalletRepository(db: db);
    vm = WalletViewModel(repository: repo);
    await db.collection('users').doc('u1').set({
      'uid': 'u1',
      'walletBalance': 1000,
      'updatedAt': Timestamp.now(),
    });
  });

  group('WalletViewModel.topUp', () {
    test('adds to the balance and records a topup transaction', () async {
      final ok = await vm.topUp('u1', 2000);

      expect(ok, isTrue);
      expect(vm.error, isNull);
      expect(vm.isProcessing, isFalse);
      expect(await balance('u1'), 3000);

      final txns = await db.collection('transactions').get();
      expect(txns.docs, hasLength(1));
      final txn = txns.docs.single.data();
      expect(txn['type'], 'topup');
      expect(txn['amount'], 2000);
      expect(txn['balanceBefore'], 1000);
      expect(txn['balanceAfter'], 3000);
    });

    test('fails cleanly for an unknown user', () async {
      final ok = await vm.topUp('ghost', 2000);

      expect(ok, isFalse);
      expect(vm.error, isNotNull);
      expect(vm.isProcessing, isFalse);
    });
  });

  group('WalletRepository payments', () {
    test('deductPayment subtracts and records a payment', () async {
      await repo.deductPayment('u1', 750, orderId: 'o1');

      expect(await balance('u1'), 250);
      final txn =
          (await db.collection('transactions').get()).docs.single.data();
      expect(txn['type'], 'payment');
      expect(txn['relatedOrderId'], 'o1');
    });

    test('deductPayment rejects insufficient balance and changes nothing',
        () async {
      await expectLater(
        repo.deductPayment('u1', 1001),
        throwsA(isA<InsufficientBalanceException>()),
      );

      expect(await balance('u1'), 1000);
      expect((await db.collection('transactions').get()).docs, isEmpty);
    });

    test('withdraw subtracts and records a withdrawal', () async {
      await repo.withdraw('u1', 400);

      expect(await balance('u1'), 600);
      final txn =
          (await db.collection('transactions').get()).docs.single.data();
      expect(txn['type'], 'withdrawal');
      expect(txn['amount'], 400);
    });

    test('refund credits the balance', () async {
      await repo.refund('u1', 500, orderId: 'o9');

      expect(await balance('u1'), 1500);
      final txn =
          (await db.collection('transactions').get()).docs.single.data();
      expect(txn['type'], 'refund');
      expect(txn['relatedOrderId'], 'o9');
    });
  });
}
