package com.mezmur.zelideta

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import com.mezmur.zelideta.widget.SinksarCompactWidgetProvider
import com.mezmur.zelideta.widget.SinksarExpandedWidgetProvider
import com.mezmur.zelideta.widget.SinksarWidgetData
import com.mezmur.zelideta.widget.SinksarWidgetManager
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceFragmentActivity() {

    private var sinksChannel: MethodChannel? = null
    private var pendingLaunchPayload: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        wakeAndUnlock(intent)
        handleWidgetIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        wakeAndUnlock(intent)
        handleWidgetIntent(intent)
    }

    private fun wakeAndUnlock(intent: Intent?) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
            val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
            km?.requestDismissKeyguard(this, null)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }
    }

    private fun handleWidgetIntent(intent: Intent?) {
        if (intent == null) return
        val payload = intent.getStringExtra("payload")
            ?: intent.data?.let { uri ->
                if (uri.scheme == "mezmurzelideta" && uri.host == "open") {
                    val path = uri.path?.removePrefix("/") ?: ""
                    if (path.startsWith("sinksar/")) {
                        val d = path.removePrefix("sinksar/")
                        "sinksar:$d"
                    } else if (path == "sinksar") {
                        "sinksar"
                    } else {
                        null
                    }
                } else {
                    null
                }
            }

        if (!payload.isNullOrBlank()) {
            pendingLaunchPayload = payload
            sinksChannel?.invokeMethod("onWidgetLaunch", mapOf("payload" to payload))
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Settings channel (notifications and security)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mezmur/settings").setMethodCallHandler { call, result ->
            when (call.method) {
                "openNotificationSettings" -> {
                    val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    } else {
                        Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                    }
                    startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                    result.success(true)
                }
                "setSecure" -> {
                    if (call.argument<Boolean>("on") == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && pm != null) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignoring)
                }
                "requestIgnoreBatteryOptimizations" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        try {
                            startActivity(intent)
                            result.success(true)
                        } catch (_: Exception) {
                            val fallback = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(fallback)
                            result.success(true)
                        }
                    } else {
                        result.success(true)
                    }
                }
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val am = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
                        result.success(am?.canScheduleExactAlarms() ?: true)
                    } else {
                        result.success(true)
                    }
                }
                "openExactAlarmSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(intent)
                        result.success(true)
                    } else {
                        result.success(false)
                    }
                }
                "turnScreenOnAndUnlock" -> {
                    wakeAndUnlock(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Sinksar Android Home-Screen Widget channel
        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mezmur/sinksar_widget")
        sinksChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "updateWidgetData" -> {
                    @Suppress("UNCHECKED_CAST")
                    val map = call.arguments as? Map<String, Any?>
                    if (map != null) {
                        val data = SinksarWidgetData.fromMap(map, isOffline = false)
                        data.saveToPrefs(this)
                        SinksarWidgetManager.updateAllWidgets(this, data)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "Expected Map<String, Any?>", null)
                    }
                }
                "isWidgetPinned" -> {
                    val appWidgetManager = AppWidgetManager.getInstance(this)
                    val compact = appWidgetManager.getAppWidgetIds(ComponentName(this, SinksarCompactWidgetProvider::class.java)).isNotEmpty()
                    val expanded = appWidgetManager.getAppWidgetIds(ComponentName(this, SinksarExpandedWidgetProvider::class.java)).isNotEmpty()
                    result.success(mapOf("hasWidgets" to (compact || expanded), "compact" to compact, "expanded" to expanded))
                }
                "requestPinWidget" -> {
                    val type = call.argument<String>("type") ?: "expanded"
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val appWidgetManager = getSystemService(AppWidgetManager::class.java)
                        if (appWidgetManager != null && appWidgetManager.isRequestPinAppWidgetSupported) {
                            val targetClass = if (type == "compact") {
                                SinksarCompactWidgetProvider::class.java
                            } else {
                                SinksarExpandedWidgetProvider::class.java
                            }
                            val provider = ComponentName(this, targetClass)
                            val successCallback = PendingIntent.getBroadcast(
                                this,
                                3003,
                                Intent(this, targetClass).apply { action = AppWidgetManager.ACTION_APPWIDGET_UPDATE },
                                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                            )
                            val pinned = appWidgetManager.requestPinAppWidget(provider, null, successCallback)
                            result.success(pinned)
                            return@setMethodCallHandler
                        }
                    }
                    result.success(false)
                }
                "getPendingLaunchPayload" -> {
                    val p = pendingLaunchPayload
                    pendingLaunchPayload = null
                    result.success(p)
                }
                "refreshWidget" -> {
                    SinksarWidgetManager.fetchLatestSinksarInBackground(this) { success ->
                        result.success(success)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Replay any pending launch payload
        pendingLaunchPayload?.let { p ->
            channel.invokeMethod("onWidgetLaunch", mapOf("payload" to p))
        }
    }
}
