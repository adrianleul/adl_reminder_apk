import 'package:adl_reminder/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  testWidgets('settings language switch changes the app to Amharic', (
    tester,
  ) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Settings');

    expect(find.text('Language and calendar'), findsOneWidget);

    await tester.tap(find.text('አማርኛ'));
    await tester.pumpAndSettle();

    expect(find.text('ቋንቋ እና የቀን መቁጠሪያ'), findsOneWidget);
    // The tab bar is translated too.
    expect(find.byTooltip('ዛሬ'), findsOneWidget);
  });
}
