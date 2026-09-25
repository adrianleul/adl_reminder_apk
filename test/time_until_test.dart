import 'package:adl_reminder/l10n/app_localizations.dart';
import 'package:adl_reminder/utils/calendar_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = AppLocalizations(const Locale('en'));
  final am = AppLocalizations(const Locale('am'));
  String format(Duration value) => formatTimeUntil(en, value);

  test('24 hours or more counts days, hours and minutes', () {
    expect(
      format(const Duration(days: 2, hours: 3, minutes: 5)),
      '2 days, 3 hours, 5 minutes',
    );
    expect(
      format(const Duration(days: 1, hours: 1, minutes: 1)),
      '1 day, 1 hour, 1 minute',
    );
    expect(format(const Duration(hours: 24)), '1 day');
  });

  test('less than a day shows hours and minutes', () {
    expect(
      format(const Duration(hours: 5, minutes: 30)),
      '5 hours, 30 minutes',
    );
    expect(
      format(const Duration(hours: 23, minutes: 59)),
      '23 hours, 59 minutes',
    );
    expect(format(const Duration(hours: 2)), '2 hours');
  });

  test('less than an hour shows minutes only', () {
    expect(format(const Duration(minutes: 45)), '45 minutes');
    expect(format(const Duration(minutes: 1)), '1 minute');
  });

  test('rounds up to the next minute, like a phone alarm', () {
    expect(format(const Duration(minutes: 4, seconds: 1)), '5 minutes');
    expect(
      format(const Duration(hours: 23, minutes: 59, seconds: 30)),
      '1 day',
    );
    expect(format(const Duration(seconds: 20)), '1 minute');
    expect(format(Duration.zero), 'less than a minute');
  });

  test('Amharic uses Amharic units and separator', () {
    expect(
      formatTimeUntil(am, const Duration(days: 2, hours: 3, minutes: 5)),
      '2 ቀናት፣ 3 ሰዓታት፣ 5 ደቂቃዎች',
    );
  });
}
