import 'package:flutter/services.dart';

import '../models.dart';

/// Android features with no plugin: playing the system notification or alarm
/// tone, and showing the alarm screen above the lock screen.
class DeviceService {
  DeviceService._();

  static final DeviceService instance = DeviceService._();

  static const _channel = MethodChannel('et.adlreminder.adl_reminder/device');

  Future<void> playSystemSound(BuiltInSound sound, {bool loop = false}) async {
    if (sound == BuiltInSound.silent) return;
    await _invoke('playSystemSound', {
      'alarm': sound == BuiltInSound.systemAlarm,
      'loop': loop,
    });
  }

  Future<void> stopSystemSound() => _invoke('stopSystemSound');

  /// Lets the alarm screen appear over the lock screen. Turned off again as
  /// soon as the alarm is handled so the task list never shows while locked.
  Future<void> setShowWhenLocked(bool value) =>
      _invoke('setShowWhenLocked', {'value': value});

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Not available in widget tests.
    } on PlatformException {
      // The device could not perform the request; nothing else to do.
    }
  }
}
