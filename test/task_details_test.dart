import 'package:adl_reminder/app_controller.dart';
import 'package:adl_reminder/main.dart';
import 'package:adl_reminder/models.dart';
import 'package:adl_reminder/screens/alarm_screen.dart';
import 'package:adl_reminder/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  Future<void> openTaskFromLists(WidgetTester tester, String title) async {
    await openTab(tester, 'Lists');
    await tester.tap(find.text(title));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping a task opens its details', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTaskFromLists(tester, 'Prepare production deployment');

    expect(find.text('STEPS'), findsOneWidget);
    expect(find.text('Run smoke tests'), findsOneWidget);
    expect(find.text('COMING UP'), findsOneWidget);
    expect(find.text('Mark as done'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a task can be deleted and restored with Undo', (tester) async {
    usePhoneScreen(tester);
    final controller = AppController();
    await tester.pumpWidget(ReminderApp(controller: controller));
    await openTaskFromLists(tester, 'Renew driving license');

    await tester.tap(find.byTooltip('More actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete task'));
    await tester.pumpAndSettle();

    expect(controller.taskById('task-1'), isNull);
    expect(find.text('Task deleted'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(controller.taskById('task-1'), isNotNull);
  });

  testWidgets('a task can be edited', (tester) async {
    usePhoneScreen(tester);
    final controller = AppController();
    await tester.pumpWidget(ReminderApp(controller: controller));
    await openTaskFromLists(tester, 'Renew driving license');

    await tester.tap(find.bySemanticsLabel('Edit task'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Renew driving license'),
      'Renew passport',
    );
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();

    expect(controller.taskById('task-1')?.title, 'Renew passport');
    expect(find.text('Renew passport'), findsWidgets);
    // The confirmation says how long until it fires (due in 2 days at 9:00).
    expect(find.textContaining('Reminder in'), findsOneWidget);
  });

  testWidgets('a reminder can be created from the + button', (tester) async {
    usePhoneScreen(tester);
    final controller = AppController();
    await tester.pumpWidget(ReminderApp(controller: controller));
    final before = controller.tasks.length;

    await tester.tap(find.byTooltip('New task'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Pay rent');
    await tester.tap(find.text('Monthly'));
    await tester.pumpAndSettle();
    final alarm = find.text('Alarm');
    await tester.scrollUntilVisible(
      alarm,
      200,
      scrollable: find
          .ancestor(
            of: find.text('HOW OFTEN'),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(alarm);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Set reminder'));
    await tester.pumpAndSettle();

    expect(controller.tasks.length, before + 1);
    final created = controller.tasks.last;
    expect(created.title, 'Pay rent');
    expect(created.schedule.recurrenceUnit, RecurrenceUnit.monthly);
    expect(created.schedule.delivery, ReminderDelivery.alarm);
    expect(find.textContaining('Alarm rings in'), findsOneWidget);
  });

  testWidgets('duplicate category names are rejected', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await openTab(tester, 'Lists');
    await tester.tap(find.byTooltip('Add category'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextFormField),
      ),
      'work',
    );
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();

    expect(
      find.text('A category with this name already exists.'),
      findsOneWidget,
    );
  });

  testWidgets('deleting a category can be undone', (tester) async {
    usePhoneScreen(tester);
    final controller = AppController();
    await tester.pumpWidget(ReminderApp(controller: controller));
    await openTab(tester, 'Lists');
    await tester.longPress(find.text('Personal').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete category'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(controller.categoryById('personal'), isNull);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(controller.categoryById('personal'), isNotNull);
  });

  testWidgets('schedules are described in Amharic', (tester) async {
    usePhoneScreen(tester);
    final controller = AppController();
    controller.setLanguage(AppLanguage.amharic);
    await tester.pumpWidget(ReminderApp(controller: controller));
    await openTab(tester, 'ዝርዝሮች');

    // "Drink water" is a daily 10:00 reminder.
    expect(find.textContaining('በየቀኑ'), findsWidgets);
    expect(find.textContaining('Every day'), findsNothing);
  });

  testWidgets('Today shows the next reminder and the calendar tab lists '
      'what is coming', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(const ReminderApp());
    await tester.pumpAndSettle();

    expect(find.text('NEXT UP'), findsOneWidget);

    await openTab(tester, 'Calendar');
    expect(find.text('Next 30 days'), findsOneWidget);
    expect(find.text('Drink water'), findsWidgets);
  });

  testWidgets('alarm screen offers done, snooze and dismiss', (tester) async {
    usePhoneScreen(tester);
    final controller = AppController();
    addTearDown(controller.dispose);
    final task = controller.taskById('task-3')!;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: AlarmScreen(controller: controller, task: task),
      ),
    );
    await tester.pump();

    expect(find.text('Drink water'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('+10 min'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(
      controller.taskById('task-3')!.stateAt(DateTime.now()),
      DashboardTaskState.completed,
    );
  });
}
