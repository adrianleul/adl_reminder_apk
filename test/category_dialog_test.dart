import 'package:adl_reminder/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('new category can be cancelled without an exception', (
    tester,
  ) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  testWidgets('blank category name is safely rejected', (tester) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(find.text('Add category'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('category deletion is confirmed and removes the category', (
    tester,
  ) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsWidgets);
    await tester.tap(find.byTooltip('Delete category').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(find.text('Personal'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
