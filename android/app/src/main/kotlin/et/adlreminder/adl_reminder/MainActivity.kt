package et.adlreminder.adl_reminder

import android.content.Intent
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private var ringtone: Ringtone? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        showOverLockScreenIfAlarm(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        showOverLockScreenIfAlarm(intent)
    }

    override fun onDestroy() {
        ringtone?.stop()
        super.onDestroy()
    }

    /**
     * Alarm notifications launch this activity through a full-screen intent.
     * Only those launches may appear above the lock screen; the Dart alarm
     * screen turns it off again once the alarm is handled.
     */
    private fun showOverLockScreenIfAlarm(intent: Intent?) {
        if (intent?.action != "SELECT_NOTIFICATION") return
        val payload = intent.getStringExtra("payload") ?: return
        val isAlarm = try {
            JSONObject(payload).optBoolean("alarm", false)
        } catch (_: Exception) {
            false
        }
        if (isAlarm) updateShowWhenLocked(true)
    }

    @Suppress("DEPRECATION")
    private fun updateShowWhenLocked(value: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(value)
            setTurnScreenOn(value)
        } else {
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (value) window.addFlags(flags) else window.clearFlags(flags)
        }
    }

    private fun playSystemSound(alarm: Boolean, loop: Boolean) {
        ringtone?.stop()
        val type = if (alarm) RingtoneManager.TYPE_ALARM else RingtoneManager.TYPE_NOTIFICATION
        val uri = RingtoneManager.getActualDefaultRingtoneUri(this, type)
            ?: RingtoneManager.getDefaultUri(type)
            ?: return
        ringtone = RingtoneManager.getRingtone(this, uri)?.apply {
            audioAttributes = AudioAttributes.Builder()
                .setUsage(if (alarm) AudioAttributes.USAGE_ALARM else AudioAttributes.USAGE_NOTIFICATION)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .build()
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) isLooping = loop
            play()
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "et.adlreminder.adl_reminder/settings")
            .setMethodCallHandler { call, result ->
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

        MethodChannel(messenger, "et.adlreminder.adl_reminder/device")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "playSystemSound" -> playSystemSound(
                            call.argument<Boolean>("alarm") ?: false,
                            call.argument<Boolean>("loop") ?: false
                        )
                        "stopSystemSound" -> {
                            ringtone?.stop()
                            ringtone = null
                        }
                        "setShowWhenLocked" -> updateShowWhenLocked(
                            call.argument<Boolean>("value") ?: false
                        )
                        else -> {
                            result.notImplemented()
                            return@setMethodCallHandler
                        }
                    }
                    result.success(null)
                } catch (error: Exception) {
                    result.error("DEVICE_ERROR", error.message, null)
                }
            }
    }
}
