import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../screens/settings_screen.dart' show builtInSoundLabel;
import '../services/device_service.dart';

class AlarmSoundPicker extends StatefulWidget {
  const AlarmSoundPicker({super.key, required this.controller});

  final AppController controller;

  /// Largest audio file that can be imported.
  static const int maxImportMegabytes = 15;

  @override
  State<AlarmSoundPicker> createState() => _AlarmSoundPickerState();
}

class _AlarmSoundPickerState extends State<AlarmSoundPicker> {
  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isBusy = false;

  AppSettings get _settings => widget.controller.settings;

  @override
  void dispose() {
    unawaited(DeviceService.instance.stopSystemSound());
    _player.dispose();
    if (_isRecording) {
      // Closing the sheet mid-recording discards the partial file.
      unawaited(_recorder.cancel());
    }
    _recorder.dispose();
    super.dispose();
  }

  /// Sounds live in the app's private files directory, under `sounds/`,
  /// which is excluded from cloud backup.
  Future<Directory> _soundsDirectory() async {
    final directory = Directory(
      '${(await getApplicationSupportDirectory()).path}/sounds',
    );
    await directory.create(recursive: true);
    return directory;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.text('alarmSound'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.text('soundHelp'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final sound in BuiltInSound.values)
                    _SoundTile(
                      name: builtInSoundLabel(l10n, sound),
                      selected:
                          _settings.builtInSound == sound &&
                          _settings.selectedCustomSound == null,
                      icon: sound == BuiltInSound.silent
                          ? Icons.volume_off_outlined
                          : Icons.music_note_outlined,
                      onTap: () => _selectBuiltIn(sound),
                    ),
                  if (_settings.customAlarmSounds.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        l10n.text('customSounds'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    for (final sound in _settings.customAlarmSounds)
                      _SoundTile(
                        name: sound.name,
                        selected: _settings.alarmSoundPath == sound.path,
                        icon: Icons.audio_file_outlined,
                        onTap: () => _selectCustom(sound),
                        onDelete: () => _deleteCustom(sound),
                        deleteTooltip: l10n.text('deleteSound'),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy || _isRecording ? null : _importAudio,
                    icon: const Icon(Icons.file_upload_outlined),
                    label: Text(l10n.text('importAudio')),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _isBusy ? null : _toggleRecording,
                    style: _isRecording
                        ? FilledButton.styleFrom(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          )
                        : null,
                    icon: Icon(
                      _isRecording ? Icons.stop_rounded : Icons.mic_outlined,
                    ),
                    label: Text(
                      l10n.text(_isRecording ? 'stopRecording' : 'recordAudio'),
                    ),
                  ),
                ),
              ],
            ),
            if (_isRecording) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 10,
                    height: 10,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(l10n.text('recording')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _stopPreview() async {
    await _player.stop();
    await DeviceService.instance.stopSystemSound();
  }

  Future<void> _selectBuiltIn(BuiltInSound sound) async {
    widget.controller.updateSettings(() {
      _settings.builtInSound = sound;
      _settings.alarmSoundPath = null;
    });
    setState(() {});
    await _stopPreview();
    await DeviceService.instance.playSystemSound(sound);
  }

  Future<void> _selectCustom(CustomAlarmSound sound) async {
    widget.controller.updateSettings(() {
      _settings.alarmSoundPath = sound.path;
    });
    setState(() {});
    await _stopPreview();
    try {
      await _player.play(DeviceFileSource(sound.path));
    } catch (_) {
      if (mounted) _showMessage(context.l10n.text('audioPlaybackFailed'));
    }
  }

  Future<void> _deleteCustom(CustomAlarmSound sound) async {
    await _stopPreview();
    widget.controller.updateSettings(() {
      _settings.customAlarmSounds.removeWhere((item) => item.id == sound.id);
      if (_settings.alarmSoundPath == sound.path) {
        _settings.alarmSoundPath = null;
      }
    });
    if (mounted) setState(() {});
    try {
      await File(sound.path).delete();
    } on FileSystemException {
      // Already gone.
    }
  }

  void _addCustomSound(CustomAlarmSound sound) {
    widget.controller.updateSettings(() {
      _settings.customAlarmSounds.add(sound);
    });
  }

  Future<void> _importAudio() async {
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );
      if (result == null || !mounted) return;
      final picked = result.files.single;
      if (picked.size > AlarmSoundPicker.maxImportMegabytes * 1024 * 1024) {
        _showMessage(
          context.l10n.text('audioTooLarge', {
            'size': AlarmSoundPicker.maxImportMegabytes,
          }),
        );
        return;
      }
      if (picked.path == null) throw StateError('No readable audio file');
      final directory = await _soundsDirectory();
      final extension = picked.extension?.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      );
      final destination =
          '${directory.path}/import_${DateTime.now().microsecondsSinceEpoch}'
          '${extension == null || extension.isEmpty ? '' : '.$extension'}';
      await File(picked.path!).copy(destination);
      final sound = CustomAlarmSound(
        id: 'import-${DateTime.now().microsecondsSinceEpoch}',
        name: picked.name,
        path: destination,
      );
      _addCustomSound(sound);
      await _selectCustom(sound);
    } catch (_) {
      if (mounted) _showMessage(context.l10n.text('audioImportFailed'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  /// Explains why the microphone is needed before Android asks for it.
  Future<bool> _confirmMicrophoneUse() async {
    if (_settings.microphoneRationaleShown) return true;
    final l10n = context.l10n;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.mic_outlined),
        title: Text(l10n.text('microphoneRationaleTitle')),
        content: Text(l10n.text('microphoneRationale')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.text('notNow')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.text('continue')),
          ),
        ],
      ),
    );
    if (accepted != true) return false;
    widget.controller.updatePreferences(
      () => _settings.microphoneRationaleShown = true,
    );
    return true;
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    if (!await _confirmMicrophoneUse() || !mounted) return;
    setState(() => _isBusy = true);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) _showMessage(context.l10n.text('microphoneRequired'));
        return;
      }
      final directory = await _soundsDirectory();
      final path =
          '${directory.path}/recording_'
          '${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _stopPreview();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      if (mounted) setState(() => _isRecording = true);
    } catch (_) {
      if (mounted) _showMessage(context.l10n.text('recordingFailed'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _stopRecording() async {
    setState(() => _isBusy = true);
    final recordedSoundName = context.l10n.text('recordedSound');
    try {
      final path = await _recorder.stop();
      if (path == null) throw StateError('Recording did not return a path');
      final number = _settings.customAlarmSounds.length + 1;
      final sound = CustomAlarmSound(
        id: 'recording-${DateTime.now().microsecondsSinceEpoch}',
        name: '$recordedSoundName $number',
        path: path,
      );
      _addCustomSound(sound);
      if (mounted) setState(() => _isRecording = false);
      await _selectCustom(sound);
    } catch (_) {
      if (mounted) _showMessage(context.l10n.text('recordingFailed'));
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _isRecording = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile({
    required this.name,
    required this.selected,
    required this.icon,
    required this.onTap,
    this.onDelete,
    this.deleteTooltip,
  });

  final String name;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final String? deleteTooltip;

  @override
  Widget build(BuildContext context) {
    final status = selected
        ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary)
        : const Icon(Icons.play_arrow_rounded);
    return ListTile(
      selected: selected,
      leading: Icon(icon),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: onDelete == null
          ? status
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                status,
                IconButton(
                  tooltip: deleteTooltip,
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
      onTap: onTap,
    );
  }
}
