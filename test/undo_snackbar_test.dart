import 'package:adl_reminder/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('undo snackbar begins dismissing after five seconds', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Lists');

    // Pump at a steady frame rate, like a device: the snackbar's timer only
    // starts on the frame after its entrance animation completes.
    Future<void> advance(Duration total) async {
      const step = Duration(milliseconds: 50);
      for (var elapsed = Duration.zero; elapsed < total; elapsed += step) {
        await tester.pump(step);
      }
    }

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await advance(const Duration(milliseconds: 250));
    expect(find.text('Undo'), findsOneWidget);

    await advance(const Duration(milliseconds: 4650));
    expect(find.text('Undo'), findsOneWidget);

    await advance(const Duration(milliseconds: 900));
    expect(find.text('Undo'), findsNothing);
  });

  testWidgets('undo snackbar stays for screen reader users', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(accessibleNavigation: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Lists');

    await tester.tap(find.byType(Checkbox).first);
    for (var i = 0; i < 160; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('Undo'), findsOneWidget);
  });
}
