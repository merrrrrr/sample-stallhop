import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stallhop/models/stall.dart';
import 'package:stallhop/widgets/stall_card.dart';

Stall stall({
  String status = 'open',
  String cuisine = 'Malay',
  double rating = 4.5,
  int reviews = 12,
}) {
  final now = DateTime.now();
  return Stall(
    stallId: 's1',
    vendorUid: 'v1',
    name: 'Nasi Corner',
    cuisine: cuisine,
    status: status,
    prepTimeMinutes: 15,
    averageRating: rating,
    totalReviews: reviews,
    createdAt: now,
    updatedAt: now,
  );
}

Future<void> pumpCard(WidgetTester tester, Stall s) {
  return tester.pumpWidget(
    MaterialApp(home: Scaffold(body: StallCard(stall: s))),
  );
}

void main() {
  testWidgets('renders name, cuisine, rating and prep time', (tester) async {
    await pumpCard(tester, stall());

    expect(find.text('Nasi Corner'), findsOneWidget);
    expect(find.text('Malay'), findsOneWidget);
    expect(find.text('4.5 (12)'), findsOneWidget);
    expect(find.text('15 min'), findsOneWidget);
  });

  testWidgets('shows Open badge for an open stall', (tester) async {
    await pumpCard(tester, stall(status: 'open'));

    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Closed'), findsNothing);
  });

  testWidgets('shows Closed badge for a closed stall', (tester) async {
    await pumpCard(tester, stall(status: 'closed'));

    expect(find.text('Closed'), findsOneWidget);
    expect(find.text('Open'), findsNothing);
  });

  testWidgets('shows "New" instead of a rating when unreviewed',
      (tester) async {
    await pumpCard(tester, stall(rating: 0, reviews: 0));

    expect(find.text('New'), findsOneWidget);
  });

  testWidgets('falls back to "Food" when cuisine is empty', (tester) async {
    await pumpCard(tester, stall(cuisine: ''));

    expect(find.text('Food'), findsOneWidget);
  });

  testWidgets('fires onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StallCard(stall: stall(), onTap: () => tapped = true),
        ),
      ),
    );

    await tester.tap(find.text('Nasi Corner'));
    expect(tapped, isTrue);
  });
}
