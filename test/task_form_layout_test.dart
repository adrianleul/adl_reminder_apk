import 'package:adl_reminder/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('the composer sentence follows the chosen frequency', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).first, 'Pay rent');
    await tester.pump();
    expect(find.text('Pay rent'), findsWidgets);

    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    expect(find.text('month'), findsOneWidget);
    expect(find.text('Starts on'), findsOneWidget);

    await tester.tap(find.text('Weekly'));
    await tester.pumpAndSettle();
    expect(find.text('Mon'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a date range shows start and end dates', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Date range'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('End date'),
      200,
      scrollable: find
          .ancestor(
            of: find.text('HOW OFTEN'),
            matching: find.byType(Scrollable),
          )
          .first,
    );

    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty title is rejected', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Set reminder'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a task title.'), findsOneWidget);
  });
}
