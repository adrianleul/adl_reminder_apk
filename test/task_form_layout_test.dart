import 'package:adl_reminder/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('custom recurrence selection does not overflow', (tester) async {
    await tester.pumpWidget(const ReminderApp());

    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    final selectedSchedule = find.text('On a specific date');
    await tester.ensureVisible(selectedSchedule);
    await tester.tap(selectedSchedule);
    await tester.pumpAndSettle();
    await tester.tap(
      find.text('Specific days / weekly / monthly / yearly').last,
    );
    await tester.pumpAndSettle();

    expect(find.text('Custom recurrence'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('selected date range is highlighted', (tester) async {
    await tester.pumpWidget(const ReminderApp());
    await tester.tap(find.text('New task'));
    await tester.pumpAndSettle();

    final selectedSchedule = find.text('On a specific date');
    await tester.ensureVisible(selectedSchedule);
    await tester.tap(selectedSchedule);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date range').last);
    await tester.pumpAndSettle();

    expect(find.text('Selected date range'), findsOneWidget);
    expect(find.text('Start date'), findsOneWidget);
    expect(find.text('End date'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
