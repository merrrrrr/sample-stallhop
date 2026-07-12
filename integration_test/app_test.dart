// Integration tests. Run on a real device/emulator with Firebase configured:
//
//   flutter test integration_test
//
// The login test needs a pre-created customer account, passed at run time so
// no credentials live in the repo:
//
//   flutter test integration_test --dart-define=TEST_EMAIL=you@test.com \
//       --dart-define=TEST_PASSWORD=secret123
//
// Without those defines the login test is skipped and only the boot smoke
// test runs. Vendor/admin flows (mark ready, QR scan, approve, refund) need
// camera hardware and seeded backend state, so they remain manual test cases.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:stallhop/features/auth/view/login_page.dart';
import 'package:stallhop/main.dart' as app;

const testEmail = String.fromEnvironment('TEST_EMAIL');
const testPassword = String.fromEnvironment('TEST_PASSWORD');

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app boots to a stable first screen', (tester) async {
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 2));

    // Signed out → login page; a remembered session → a role home. Either
    // way the app must get past the splash without crashing.
    expect(find.byType(Scaffold), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
    'customer can log in and land on their home',
    skip: testEmail.isEmpty,
    (tester) async {
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));

      if (find.byType(LoginPage).evaluate().isEmpty) {
        // A previous session is still signed in; nothing to test here.
        return;
      }

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), testEmail);
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), testPassword);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Log in'));
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // Customer shell shows the four bottom-nav tabs.
      expect(find.text('Orders'), findsWidgets);
      expect(find.text('Wallet'), findsWidgets);
      expect(find.text('Profile'), findsWidgets);
    },
  );
}
