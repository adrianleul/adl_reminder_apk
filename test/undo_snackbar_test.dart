import 'package:adl_reminder/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('undo snackbar begins dismissing after five seconds', (
    tester,
  ) async {
    await tester.pumpWidget(const ReminderApp());

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 4650));
    expect(find.text('Undo'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Undo'), findsNothing);
  });
}
