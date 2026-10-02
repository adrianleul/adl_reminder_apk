import 'package:adl_reminder/main.dart';
import 'package:adl_reminder/widgets/logo_mark.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('alarm sound settings expose import and recording controls', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Settings');
    await tester.tap(find.text('Alarm sound'));
    await tester.pumpAndSettle();

    expect(find.text('Import audio'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Default notification sound'), findsWidgets);
    expect(find.text('Alarm tone'), findsOneWidget);
    expect(find.text('Silent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings end with the app logo and name', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Settings');
    await tester.scrollUntilVisible(find.byType(LogoMark), 200);

    expect(find.byType(LogoMark), findsOneWidget);
    expect(find.text('ADL Reminder'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
