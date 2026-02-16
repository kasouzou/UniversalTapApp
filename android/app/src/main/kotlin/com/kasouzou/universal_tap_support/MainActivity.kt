package com.kasouzou.universal_tap_support

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
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

                // 監視スタート（赤いボタンを表示）
                "startMonitoring" -> {
                    val intent = Intent(this, SupportForegroundService::class.java)
                    // Android 8.0(Oreo)以上はフォアグラウンド制限があるため分岐
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }

                // 監視ストップ（赤いボタンを消す）
                "stopMonitoring" -> {
                    stopService(Intent(this, SupportForegroundService::class.java))
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

                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // 💡 解説：通知を出すための「道路」を作る独自の関数
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "タップ支援サービス状況"
            val descriptionText = "サービスの稼働状態を通知します"
            val importance = NotificationManager.IMPORTANCE_LOW // 音を鳴らさない控えめな設定
            val channel = NotificationChannel("SUPPORT_CHANNEL", name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
}