import 'package:adl_reminder/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('alarm sound settings expose import and recording controls', (
    tester,
  ) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alarm sound'));
    await tester.pumpAndSettle();

    expect(find.text('Import audio'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Gentle bell'), findsWidgets);
    expect(find.text('Silent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
