import 'package:adl_reminder/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('new category can be cancelled without an exception', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Lists');
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('blank category name is safely rejected', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Lists');
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Enter a category name.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category deletion is confirmed and removes the category', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Lists');

    expect(find.text('Personal'), findsWidgets);
    await tester.longPress(find.text('Personal').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
