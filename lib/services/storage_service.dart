import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Loads and saves the app's state as a single JSON document.
abstract class ReminderStorage {
  Future<Map<String, Object?>?> load();
  Future<void> save(Map<String, Object?> data);
}

/// Keeps data in memory only. Used by tests and as a fallback when the
/// platform has no file system.
class MemoryReminderStorage implements ReminderStorage {
  MemoryReminderStorage([this.data]);

  Map<String, Object?>? data;

  @override
  Future<Map<String, Object?>?> load() async => data;

  @override
  Future<void> save(Map<String, Object?> data) async {
    this.data = jsonDecode(jsonEncode(data)) as Map<String, Object?>;
  }
}

/// Stores `reminders.json` in the app support directory (Android `files/`),
/// writing to a temporary file first so a crash never leaves a torn file.
class FileReminderStorage implements ReminderStorage {
  FileReminderStorage({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  static const fileName = 'reminders.json';

  final Future<Directory> Function() _directory;
  Future<void> _pendingWrite = Future<void>.value();

  Future<File> _file() async => File('${(await _directory()).path}/$fileName');

  @override
  Future<Map<String, Object?>?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return decoded is Map<String, Object?> ? decoded : null;
    } on FormatException {
      // Keep the unreadable file for diagnosis instead of overwriting it.
      await file.rename('${file.path}.corrupt');
      return null;
    }
  }

  @override
  Future<void> save(Map<String, Object?> data) {
    final encoded = jsonEncode(data);
    // Serialize writes so an older snapshot can never land after a newer one.
    return _pendingWrite = _pendingWrite.catchError((_) {}).then((_) async {
      final file = await _file();
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(encoded, flush: true);
      await temp.rename(file.path);
    });
  }
}
