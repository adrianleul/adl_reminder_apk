import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';

class AlarmSoundPicker extends StatefulWidget {
  const AlarmSoundPicker({super.key, required this.controller});

  final AppController controller;

  @override
  State<AlarmSoundPicker> createState() => _AlarmSoundPickerState();
}

class _AlarmSoundPickerState extends State<AlarmSoundPicker> {
  static const _builtInSounds = [
    'Gentle bell',
    'Digital alarm',
    'Soft chime',
    'Classic reminder',
    'Silent',
  ];

  final AudioPlayer _player = AudioPlayer();
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isBusy = false;

  AppSettings get _settings => widget.controller.settings;

  @override
  void dispose() {
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.text('alarmSound'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final sound in _builtInSounds)
                    _SoundTile(
                      name: sound,
                      selected:
                          _settings.alarmSound == sound &&
                          _settings.alarmSoundPath == null,
                      icon: sound == 'Silent'
                          ? Icons.volume_off_outlined
                          : Icons.music_note_outlined,
                      onTap: () => _selectSound(sound),
                    ),
                  if (_settings.customAlarmSounds.isNotEmpty) ...[
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      child: Text(
                        context.l10n.text('customSounds'),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                    for (final sound in _settings.customAlarmSounds)
                      _SoundTile(
                        name: sound.name,
                        selected: _settings.alarmSoundPath == sound.path,
                        icon: Icons.audio_file_outlined,
                        onTap: () => _selectSound(sound.name, path: sound.path),
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
                    label: Text(context.l10n.text('importAudio')),
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
                      context.l10n.text(
                        _isRecording ? 'stopRecording' : 'recordAudio',
                      ),
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
                  Text(context.l10n.text('recording')),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _selectSound(String name, {String? path}) async {
    widget.controller.updateSettings(() {
      _settings.alarmSound = name;
      _settings.alarmSoundPath = path;
    });
    setState(() {});
    await _preview(path, silent: name == 'Silent');
  }

  Future<void> _preview(String? path, {bool silent = false}) async {
    await _player.stop();
    if (silent) return;
    try {
      if (path == null) {
        await SystemSound.play(SystemSoundType.alert);
      } else {
        await _player.play(DeviceFileSource(path));
      }
    } catch (_) {
      if (mounted) {
        _showMessage(context.l10n.text('audioPlaybackFailed'));
      }
    }
  }

  Future<void> _importAudio() async {
    setState(() => _isBusy = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || !mounted) return;
      final picked = result.files.single;
      final directory = await getApplicationDocumentsDirectory();
      final extension = picked.extension?.replaceAll(
        RegExp(r'[^a-zA-Z0-9]'),
        '',
      );
      final destination =
          '${directory.path}/alarm_import_${DateTime.now().microsecondsSinceEpoch}'
          '${extension == null || extension.isEmpty ? '' : '.$extension'}';
      if (picked.path != null) {
        await File(picked.path!).copy(destination);
      } else if (picked.bytes != null) {
        await File(destination).writeAsBytes(picked.bytes!, flush: true);
      } else {
        throw StateError('No readable audio data');
      }
      final sound = CustomAlarmSound(
        id: 'import-${DateTime.now().microsecondsSinceEpoch}',
        name: picked.name,
        path: destination,
      );
      widget.controller.updateSettings(() {
        _settings.customAlarmSounds.add(sound);
      });
      await _selectSound(sound.name, path: sound.path);
    } catch (_) {
      if (mounted) _showMessage(context.l10n.text('audioImportFailed'));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecording();
      return;
    }
    setState(() => _isBusy = true);
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) _showMessage(context.l10n.text('microphoneRequired'));
        return;
      }
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/alarm_recording_'
          '${DateTime.now().microsecondsSinceEpoch}.m4a';
      await _player.stop();
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
      final sound = CustomAlarmSound(
        id: 'recording-${DateTime.now().microsecondsSinceEpoch}',
        name: recordedSoundName,
        path: path,
      );
      widget.controller.updateSettings(() {
        _settings.customAlarmSounds.add(sound);
      });
      if (mounted) setState(() => _isRecording = false);
      await _selectSound(sound.name, path: sound.path);
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
  });

  final String name;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      leading: Icon(icon),
      title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: selected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : const Icon(Icons.play_arrow_rounded),
      onTap: onTap,
    );
  }
}
