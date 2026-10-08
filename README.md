# ADL Reminder

An Android-first Flutter reminder app with Ethiopian and Gregorian calendar
support, in English and Amharic.

## Features

- Dashboard summary with **Done**, **Overdue** and **Undone** totals, plus a
  breakdown by schedule type (one-time, date range, daily, weekly, monthly,
  yearly).
- **Active**, **Overdue** and **Completed** tabs, grouped by category. Overdue
  status updates every minute.
- Categories with add, rename (duplicate names rejected) and delete with Undo.
  A **Today's tasks** view lists everything that occurs today.
- Search across task titles and subtasks.
- Create, view, edit and delete tasks (delete has Undo). Tasks can have
  subtasks; ticking the last subtask finishes the task.
- Reminder types: specific date, date range, every day, weekly (chosen
  weekdays), monthly and yearly. Monthly and yearly repeat in the calendar the
  task was created in: "every Meskerem 5" follows the Ethiopian calendar, and
  day 31 falls back to the last day of shorter months.
- Completing a recurring task finishes the current occurrence only; the
  reminder comes back for the next one.
- Delivery as a **notification** or a full-screen **alarm** with Done, Snooze
  and Dismiss. Notifications have **Done** and **Snooze** buttons.
- Settings that take effect immediately: notifications on/off, sound (system
  sound, alarm tone, silent, or an imported/recorded custom sound), priority,
  vibration and pattern, snooze length and default calendar.
- Everything is saved on the device and survives restarts and reboots.
- Light/dark theme following the system.

## How reminders are scheduled

- Each task has a persisted `notificationId`. Its platform notifications use
  IDs `notificationId * 32 + slot`, with slot 31 reserved for snoozes. IDs stay
  the same across restarts, so reminders can always be cancelled.
- Daily and weekly reminders repeat on the platform. Monthly, yearly and
  date-range reminders are scheduled one by one, a rolling window ahead (6
  months, 3 years, 21 days), because Android cannot express "last day of the
  month" or Ethiopian months. The window is topped up whenever the app starts
  or is resumed (at most every 30 minutes). Open the app at least that often
  for long date ranges.
- On every start the app rebuilds all reminders from the saved tasks and
  removes notifications that belong to no task.
- Android fixes a channel's sound and vibration once it is created, so each
  combination of sound, vibration and priority gets its own channel ID (for
  example `reminder_high_systemDefault_standard`); unused channels are deleted.
- Custom sound files play on the in-app alarm screen. Notification channels
  use the default notification sound or the alarm tone instead, because
  Android cannot use private app files as channel sounds.

## Project layout

```text
lib/
  app_controller.dart          State, persistence and scheduling sync
  models.dart                  Tasks, schedules, recurrence rules, settings
  l10n/app_localizations.dart  English and Amharic strings
  screens/                     Dashboard, settings, alarm screen
  services/
    notification_service.dart  Platform reminders, channels, actions
    storage_service.dart       JSON file storage (reminders.json)
    device_service.dart        System sounds, show-over-lock-screen
  utils/
    ethiopian_calendar.dart    Calendar conversion
    calendar_utils.dart        Localized date and schedule formatting
  widgets/                     Sheets, dialogs, lists
```

Data lives in `files/reminders.json` (written atomically). Custom sounds live
in `files/sounds/`.

## Run the project

```bash
flutter pub get
flutter test
flutter run
```

`android/` is committed and contains custom code: the `MainActivity` method
channels, notification receivers (scheduled, boot, action), permissions,
`showWhenLocked` handling for alarms, backup rules and release signing.
`bootstrap_android.sh` only recreates `android/` when it is missing and
refuses to overwrite it.

## Release builds

Create `android/key.properties` (it is git-ignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without it, release builds are signed with the debug key and print a warning.
They are fine for local testing but Google Play rejects them.

## Google Play notes

- `USE_FULL_SCREEN_INTENT`: on Android 14+, Play only allows it for alarm and
  calling apps, and requires a declaration in the Play Console. Without the
  permission, Android shows alarms as heads-up notifications instead.
- `SCHEDULE_EXACT_ALARM`: exact timing is requested only for alarm reminders.
  Notifications fall back to inexact scheduling if it is not granted.
- `RECORD_AUDIO`: used only while recording a custom alarm sound. The app
  explains this before Android asks. A privacy policy is required.
- Backups: `reminders.json` is included in cloud backup; recorded sounds are
  only copied during device-to-device transfer.
