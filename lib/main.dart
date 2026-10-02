import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'app_controller.dart';
import 'screens/home_shell.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  final controller = await AppController.load(storage: FileReminderStorage());
  runApp(ReminderApp(controller: controller));
}

class ReminderApp extends StatefulWidget {
  /// Without a [controller] the app runs on in-memory demo data (tests).
  const ReminderApp({super.key, this.controller});

  final AppController? controller;

  @override
  State<ReminderApp> createState() => _ReminderAppState();
}

class _ReminderAppState extends State<ReminderApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = widget.controller ?? AppController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Only a language change needs to rebuild MaterialApp; task changes are
    // handled by the screens that show them.
    return ValueListenableBuilder<AppLanguage>(
      valueListenable: controller.languageNotifier,
      builder: (context, _, _) => MaterialApp(
        title: 'ADL Reminder',
        debugShowCheckedModeBanner: false,
        locale: controller.locale,
        supportedLocales: const [Locale('en'), Locale('am')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        // The design is light-only: ink on white with an orange accent.
        theme: buildAppTheme(),
        home: HomeShell(controller: controller),
      ),
    );
  }
}
