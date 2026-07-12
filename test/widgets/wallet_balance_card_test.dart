import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/widgets/wallet_balance_card.dart';

Future<void> pumpCard(
  WidgetTester tester, {
  required int cents,
  String? label,
}) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: label == null
            ? WalletBalanceCard(balanceCents: cents)
            : WalletBalanceCard(balanceCents: cents, label: label),
      ),
    ),
  );
}

void main() {
  testWidgets('displays the formatted balance', (tester) async {
    await pumpCard(tester, cents: 12345);

    expect(find.text('RM 123.45'), findsOneWidget);
    expect(find.text('Wallet balance'), findsOneWidget);
  });

  testWidgets('displays zero balance', (tester) async {
    await pumpCard(tester, cents: 0);

    expect(find.text('RM 0.00'), findsOneWidget);
  });

  testWidgets('supports a custom label', (tester) async {
    await pumpCard(tester, cents: 500, label: 'Earnings');

    expect(find.text('Earnings'), findsOneWidget);
    expect(find.text('Wallet balance'), findsNothing);
  });
}
