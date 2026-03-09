package com.kasouzou.universal_tap_support

import android.content.Context
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    // Flutterと通信するための合言葉の通り道
    private val CHANNEL = "com.kasouzou.universal_tap_support/tap"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            // 【マクロな視点】ここでFlutterからの命令をすべて交通整理する
            when (call.method) {

                "updateLabels" -> {
                    val labels = call.argument<List<String>>("labels")
                    if (labels != null) {
                        // 【重要】FlutterのSharedPreferencesと揃えるための保存処理
                        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                        prefs.edit().putStringSet("flutter.support_labels", labels.toSet()).apply()
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGUMENT", "Labels are null", null)
                    }
                }

                // 監視スタート
                "startMonitoring" -> {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("flutter.is_monitoring_enabled", true).apply()
                    result.success(null)
                }

                // 監視ストップ
                "stopMonitoring" -> {
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("flutter.is_monitoring_enabled", false).commit()
                    // サービスを直接停止させる
                    UniversalSupportService.stopService()
                    result.success(null)
                }

                // 重ね合わせ権限のチェック
                "checkOverlayPermission" -> {
                    result.success(Settings.canDrawOverlays(this))
                }

                // MainActivity.kt の MethodChannel の handle 内に追加
                "openAccessibilitySettings" -> {
                    val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
                    intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                    startActivity(intent)
                    result.success(null)
                }

                "isAccessibilityServiceEnabled" -> {
                    val expectedComponentName = android.content.ComponentName(this, UniversalSupportService::class.java).flattenToString()
                    val enabledServices = Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
                    val isEnabled = enabledServices?.contains(expectedComponentName) == true
                    result.success(isEnabled)
                }

                "stopServiceManually" -> {
                    // This is only for completeness, disableSelf() in Service is the preferred way.
                    // But we can ensure the pref is OFF.
                    val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                    prefs.edit().putBoolean("flutter.is_monitoring_enabled", false).apply()
                    result.success(true)
                }

                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}