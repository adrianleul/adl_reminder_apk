import 'package:adl_reminder/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('drawer language toggle switches the app to Amharic', (
    tester,
  ) async {
    await tester.pumpWidget(const ReminderApp());

    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();

    expect(find.text('All tasks'), findsOneWidget);

    await tester.tap(find.text('አማ'));
    await tester.pumpAndSettle();

    expect(find.text('ሁሉም ተግባሮች'), findsOneWidget);
    expect(find.text('ቋንቋ'), findsOneWidget);
  });
}
