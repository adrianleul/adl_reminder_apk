package et.adlreminder.adl_reminder

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "et.adlreminder.adl_reminder/settings"
        ).setMethodCallHandler { call, result ->
            val intent = when (call.method) {
                "openNotificationSettings" -> Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                "openExactAlarmSettings" -> Intent(
                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                    Uri.parse("package:$packageName")
                )
                "openAppSettings" -> Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:$packageName")
                )
                else -> {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
            }
            try {
                startActivity(intent)
                result.success(null)
            } catch (_: Exception) {
                result.error("SETTINGS_UNAVAILABLE", "Could not open app settings", null)
            }
        }
    }
}
