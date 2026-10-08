import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../app_controller.dart';
import '../l10n/app_localizations.dart';
import '../models.dart';
import '../services/device_service.dart';
import '../services/notification_service.dart';
import '../utils/calendar_utils.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/category_name_dialog.dart';
import '../widgets/ui.dart';
import 'agenda_screen.dart';
import 'alarm_screen.dart';
import 'lists_screen.dart';
import 'settings_screen.dart';
import 'task_detail_screen.dart';
import 'today_screen.dart';

/// Actions every tab can trigger; implemented once by [HomeShell].
abstract class HomeActions {
  Future<void> compose([ReminderTask? existing]);
  Future<void> openTask(ReminderTask task);
  void openSearch();
  Future<void> addCategory();
  Future<void> manageCategory(TaskCategory category);
  Future<void> allowPermission();
  ReminderPermissionIssue? get permissionIssue;
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.controller});

  final AppController controller;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with WidgetsBindingObserver
    implements HomeActions {
  /// Resuming the app tops up rolling reminders at most this often.
  static const Duration _refreshInterval = Duration(minutes: 30);

  int _tab = 0;
  final FocusNode _searchFocus = FocusNode();
  ReminderPermissionIssue? _permissionIssue;
  StreamSubscription<NotificationResponse>? _responses;
  Timer? _clock;
  DateTime? _lastRefresh;

  AppController get _controller => widget.controller;

  @override
  ReminderPermissionIssue? get permissionIssue => _permissionIssue;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _responses = NotificationService.instance.responses.listen(
      _handleNotificationResponse,
    );
    // Countdowns and overdue state depend on the clock.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _onStartup());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _responses?.cancel();
    _clock?.cancel();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      unawaited(_refreshPermission());
      final last = _lastRefresh;
      if (last == null || DateTime.now().difference(last) > _refreshInterval) {
        unawaited(_refreshSchedules());
      }
    }
  }

  Future<void> _onStartup() async {
    await _refreshPermission();
    await _refreshSchedules();
    final launch = await NotificationService.instance.takeLaunchResponse();
    if (launch != null && mounted) _handleNotificationResponse(launch);
  }

  Future<void> _refreshSchedules() async {
    _lastRefresh = DateTime.now();
    await _controller.refreshSchedules();
  }

  bool get _needsExactAlarms => _controller.tasks.any(
    (task) =>
        task.schedule.delivery == ReminderDelivery.alarm && !task.isCompleted,
  );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        final pages = <Widget>[
          TodayScreen(controller: _controller, actions: this),
          AgendaScreen(controller: _controller, actions: this),
          ListsScreen(
            controller: _controller,
            actions: this,
            searchFocus: _searchFocus,
          ),
          SettingsScreen(controller: _controller),
        ];
        return PopScope(
          // Back from another tab returns to Today before leaving the app.
          canPop: _tab == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) setState(() => _tab = 0);
          },
          child: Scaffold(
            extendBody: true,
            body: IndexedStack(index: _tab, children: pages),
            bottomNavigationBar: FloatingNavBar(
              index: _tab,
              onSelected: (index) => setState(() => _tab = index),
              onAdd: () => compose(),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Tasks

  @override
  void openSearch() {
    setState(() => _tab = 2);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _searchFocus.requestFocus(),
    );
  }

  @override
  Future<void> compose([ReminderTask? existing]) async {
    final task = await showModalBottomSheet<ReminderTask>(
      context: context,
      isScrollControlled: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AddTaskSheet(controller: _controller, initialTask: existing),
    );
    if (task == null || !mounted) return;

    // Ask for permission before saving so the first schedule succeeds.
    if (_controller.settings.notificationsEnabled) {
      final issue = await NotificationService.instance.requestPermissions(
        requireExactAlarm: task.schedule.delivery == ReminderDelivery.alarm,
      );
      if (!mounted) return;
      setState(() => _permissionIssue = issue);
      if (issue != null) await _showPermissionDialog(issue);
      if (!mounted) return;
    }

    final saved = existing == null
        ? _controller.addTask(task)
        : _controller.updateTask(task);
    final l10n = context.l10n;
    final message = l10n.text(existing == null ? 'created' : 'taskUpdated', {
      'title': saved.title,
    });
    final countdown = _countdownText(saved);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(countdown == null ? message : '$message\n$countdown'),
        ),
      );
  }

  /// "Alarm rings in 2 days, 3 hours" for a task that will actually fire, or
  /// null when it will not (finished, no future occurrence, notifications off
  /// or not permitted).
  String? _countdownText(ReminderTask task) {
    if (!_controller.settings.notificationsEnabled ||
        _permissionIssue != null) {
      return null;
    }
    final now = DateTime.now();
    if (task.isCompletedAt(now)) return null;
    final next = task.schedule.nextOccurrenceAfter(now);
    if (next == null) return null;
    final l10n = context.l10n;
    return l10n.text(
      task.schedule.delivery == ReminderDelivery.alarm
          ? 'alarmIn'
          : 'reminderIn',
      {'time': formatTimeUntil(l10n, next.difference(now))},
    );
  }

  @override
  Future<void> openTask(ReminderTask task) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TaskDetailScreen(
          controller: _controller,
          taskId: task.id,
          onEdit: (current) => compose(current),
          onDelete: _deleteTask,
        ),
      ),
    );
  }

  void _deleteTask(ReminderTask task) {
    final index = _controller.deleteTask(task);
    if (index < 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: MediaQuery.accessibleNavigationOf(context),
          content: Text(context.l10n.text('taskDeleted')),
          action: SnackBarAction(
            label: context.l10n.text('undo'),
            onPressed: () => _controller.restoreTask(task, index),
          ),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Notifications and permissions

  void _handleNotificationResponse(NotificationResponse response) {
    if (!mounted) return;
    final parsed = parseNotificationPayload(response.payload);
    final task = parsed == null ? null : _controller.taskById(parsed.taskId);
    if (task == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.text('taskNotFound'))),
      );
      return;
    }

    if (response.actionId == doneActionId) {
      toggleTaskCompletion(context, _controller, task, true);
      return;
    }
    if (parsed!.alarm) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (_) => AlarmScreen(controller: _controller, task: task),
        ),
      );
      return;
    }
    // Not an alarm: never leave the app visible over the lock screen.
    unawaited(DeviceService.instance.setShowWhenLocked(false));
    openTask(task);
  }

  Future<void> _refreshPermission() async {
    if (!_controller.settings.notificationsEnabled) {
      if (mounted) setState(() => _permissionIssue = null);
      return;
    }
    final previous = _permissionIssue;
    final issue = await NotificationService.instance.permissionIssue(
      requireExactAlarm: _needsExactAlarms,
    );
    if (!mounted) return;
    setState(() => _permissionIssue = issue);
    // Permission was just granted (e.g. in system settings): schedule now.
    if (previous != null && issue == null) await _refreshSchedules();
  }

  @override
  Future<void> allowPermission() async {
    final result = await NotificationService.instance.requestPermissions(
      requireExactAlarm: _needsExactAlarms,
    );
    if (!mounted) return;
    if (result == null) {
      setState(() => _permissionIssue = null);
      await _refreshSchedules();
    } else {
      await NotificationService.instance.openPermissionSettings(result);
    }
  }

  Future<void> _showPermissionDialog(ReminderPermissionIssue issue) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.notifications_off_outlined),
        title: Text(context.l10n.text('permissionRequired')),
        content: Text(
          context.l10n.text(
            issue == ReminderPermissionIssue.exactAlarms
                ? 'exactAlarmPermissionHelp'
                : 'notificationPermissionHelp',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.text('notNow')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              NotificationService.instance.openPermissionSettings(issue);
            },
            child: Text(context.l10n.text('openSettings')),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Categories

  @override
  Future<void> addCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => CategoryNameDialog(
        title: context.l10n.text('addCategory'),
        actionLabel: context.l10n.text('add'),
        hintText: context.l10n.text('categoryExample'),
        nameExists: _controller.categoryNameExists,
      ),
    );
    if (name != null && name.trim().isNotEmpty && mounted) {
      final category = _controller.addCategory(name);
      _controller.selectCategory(category.id);
    }
  }

  @override
  Future<void> manageCategory(TaskCategory category) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.l10n.text('editCategory')),
                onTap: () => Navigator.pop(sheetContext, 'edit'),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  context.l10n.text('deleteCategory'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => Navigator.pop(sheetContext, 'delete'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    if (action == 'edit') await _renameCategory(category);
    if (action == 'delete') await _deleteCategory(category);
  }

  Future<void> _renameCategory(TaskCategory category) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => CategoryNameDialog(
        title: context.l10n.text('editCategory'),
        actionLabel: context.l10n.text('save'),
        initialValue: category.name,
        nameExists: (name) =>
            _controller.categoryNameExists(name, exceptId: category.id),
      ),
    );
    if (name != null && mounted) _controller.renameCategory(category, name);
  }

  Future<void> _deleteCategory(TaskCategory category) async {
    final taskCount = _controller.categoryTotalTaskCount(category.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.delete_outline),
        title: Text(context.l10n.text('deleteCategory')),
        content: Text(
          context.l10n.text('deleteCategoryMessage', {
            'name': category.name,
            'count': taskCount,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.text('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.text('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = _controller.deleteCategory(category);
    if (deleted == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          persist: MediaQuery.accessibleNavigationOf(context),
          content: Text(
            context.l10n.text('categoryDeleted', {'name': category.name}),
          ),
          action: SnackBarAction(
            label: context.l10n.text('undo'),
            onPressed: () => _controller.restoreCategory(deleted),
          ),
        ),
      );
  }
}
