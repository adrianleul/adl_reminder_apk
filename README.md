# ADL Reminder — Flutter Android Starter

An Android-first Material 3 reminder app starter based on the requested UX.

## Included in the starter

- Dashboard summary with **Done**, **Overdue**, and **Undone** totals.
- Expandable schedule breakdown for one-time, daily, weekly, monthly, and yearly reminders.
- Dashboard tabs: **Active**, **Overdue**, and **Completed**.
- Tasks grouped by category inside every tab.
- Drawer menu with all reminder categories, task counts, category filtering, add-category action, and Settings.
- Search for task titles and subtasks.
- Task completion checkbox with a four-second **Undo** snackbar.
- Expandable tasks and individual subtask completion.
- Floating **New task** button.
- Guided reminder creation flow:
  1. Category selection and category creation.
  2. Task title and optional multiple subtasks.
  3. Specific date, everyday, weekly, monthly, or yearly schedule.
  4. Ethiopian or Gregorian calendar selection and time selection.
- Built-in Ethiopian calendar picker with conversion to Gregorian `DateTime` for Android scheduling.
- Settings UI for notifications, alarm sound, priority, vibration, vibration pattern, snooze duration, and default calendar.
- Light/dark theme following the Android system theme.
- Seed data for reviewing the design immediately.

## Current scope

This package is a functional UI and in-memory state prototype. Creating tasks, categorizing them, searching, completing them, undoing completion, viewing overall and recurrence-based task summaries, editing settings, and Ethiopian/Gregorian date selection work in the running app.

The summary treats the three dashboard statuses as mutually exclusive: **Done** means completed, **Overdue** means unfinished and past due, and **Undone** means unfinished but not overdue. Each recurring reminder is counted once in its Daily, Weekly, Monthly, or Yearly group.

The following production services are intentionally left as the next implementation layer:

- SQLite/Drift persistence for tasks, categories, recurrence rules, and settings.
- Android local-notification scheduling and cancellation.
- Notification actions such as **Done** and **Snooze**.
- Recalculation of the next occurrence after a recurring task is completed.
- Rescheduling after reboot, timezone change, app update, or device clock change.
- Custom sound files under `android/app/src/main/res/raw/`.

## Run the project

Flutter was not installed in the environment that generated this starter, so it could not be compiled here. On a machine with a current Flutter SDK:

```bash
cd adl_reminder_flutter
./bootstrap_android.sh
flutter pub get
flutter test
flutter run
```

`bootstrap_android.sh` creates the Android host project in a temporary directory and copies only the generated Android files into this starter, so the included Dart source and `pubspec.yaml` remain untouched.

## Suggested production packages

Add these after the UI is approved:

```yaml
dependencies:
  flutter_local_notifications: ^22.2.0
  timezone: ^0.11.1
  shared_preferences: ^2.5.5
  # Choose one durable database layer:
  # drift: <compatible-current-version>
  # sqlite3_flutter_libs: <compatible-current-version>
```

Use `shared_preferences` only for non-critical preferences such as default calendar or snooze duration. Tasks and schedules should use a database.

## Recommended architecture

```text
lib/
  core/
    calendar/
    notifications/
    persistence/
  features/
    dashboard/
    reminders/
    categories/
    settings/
  models/
```

For the next phase, move `AppController` behind repositories:

```text
ReminderController
  -> TaskRepository
  -> CategoryRepository
  -> SettingsRepository
  -> NotificationScheduler
  -> RecurrenceCalculator
```

Store every scheduled instant internally as Gregorian UTC plus timezone metadata. Keep the user's selected calendar system and original Ethiopian date fields for display/editing.

## Android notification details

The production app should:

1. Request notification permission on Android 13+.
2. Request exact-alarm access only when exact timing is genuinely required.
3. Register scheduled-notification and boot receivers.
4. Use timezone-aware scheduling.
5. Create distinct Android notification channels for different sound/vibration combinations.

On Android 8+, sound and vibration settings are attached to a notification channel when that channel is first created. Changing the selected sound while reusing the same channel ID will not update the channel. A practical approach is to version channel IDs, for example:

```text
reminders_gentle_standard_v1
reminders_digital_pulse_v1
reminders_silent_none_v1
```

See `docs/android_manifest_snippet.xml` for the manifest additions.

## Recurrence behavior recommendation

- **Specific date:** one notification, then no next occurrence.
- **Every day:** next selected local time after now.
- **Weekly:** one or more selected weekdays at the chosen time.
- **Monthly:** same day number; when absent, either use the month's last day or ask the user which behavior they prefer.
- **Yearly:** same calendar date in the selected calendar system.
- Ethiopian yearly recurrence should be calculated in the Ethiopian calendar first, then converted to Gregorian for scheduling.

## Important data fields

A production task record should include:

```text
id
category_id
title
status
calendar_system
ethiopian_year / month / day (nullable)
gregorian_local_date
local_time
timezone_id
recurrence_type
selected_weekdays
notification_enabled
sound_profile
vibration_profile
next_trigger_at_utc
completed_at
created_at
updated_at
```
