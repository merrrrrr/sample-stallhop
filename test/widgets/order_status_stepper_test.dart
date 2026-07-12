import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/core/theme/app_colors.dart';
import 'package:stallhop/widgets/order_status_stepper.dart';

Future<void> pumpStepper(WidgetTester tester, String status) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: OrderStatusStepper(status: status))),
  );
}

/// Number of step circles filled teal (i.e. reached).
int doneSteps(WidgetTester tester) => tester
    .widgetList<CircleAvatar>(find.byType(CircleAvatar))
    .where((c) => c.backgroundColor == AppColors.teal)
    .length;

void main() {
  testWidgets('preparing highlights only the first step', (tester) async {
    await pumpStepper(tester, 'preparing');

    expect(find.text('Preparing'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);
    expect(find.text('Collected'), findsOneWidget);
    expect(doneSteps(tester), 1);
  });

  testWidgets('ready fills the first two steps', (tester) async {
    await pumpStepper(tester, 'ready');

    expect(doneSteps(tester), 2);
  });

  testWidgets('collected fills all three steps', (tester) async {
    await pumpStepper(tester, 'collected');

    expect(doneSteps(tester), 3);
  });

  testWidgets('cancelled shows the cancelled banner instead of steps',
      (tester) async {
    await pumpStepper(tester, 'cancelled');

    expect(find.text('Order cancelled'), findsOneWidget);
    expect(find.text('Preparing'), findsNothing);
    expect(find.byType(CircleAvatar), findsNothing);
  });
}
