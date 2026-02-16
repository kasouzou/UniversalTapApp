package com.kasouzou.universal_tap_support

import android.app.*
import android.content.*
import android.os.Build
import android.os.IBinder
import android.widget.Toast
import androidx.core.app.NotificationCompat
import android.util.Log

class SupportForegroundService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Log.d("FloatingService", "支援サービス起動！")
        
        // 1. フォアグラウンド通知を開始（これでアプリが裏でも死ななくなる）
        startForegroundServiceWithNotification()

        // 2. ユーザーへのフィードバック
        // これが出れば、ボタンがなくても「あ、動いたな」とわかる
        Toast.makeText(this, "支援サービスを開始しました。", Toast.LENGTH_SHORT).show()
    }

    private fun startForegroundServiceWithNotification() {
        val channelId = "floating_btn_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, 
                "支援サービスの対象を探しています。", 
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }

        val notification = NotificationCompat.Builder(this, channelId)
            .setContentTitle("支援サービス稼働中")
            .setSmallIcon(android.R.drawable.ic_menu_view)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()

        // --- Android 14 (API 34) 対応の修正 ---
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            // 【公式定数】FOREGROUND_SERVICE_TYPE_SPECIAL_USE: タップ支援などの特殊な用途に使用
            startForeground(
                2, 
                notification, 
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            // Android 13以下はこれまでの書き方でOK
            startForeground(2, notification)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d("SupportForegroundService", "支援サービス停止！")
    }
}