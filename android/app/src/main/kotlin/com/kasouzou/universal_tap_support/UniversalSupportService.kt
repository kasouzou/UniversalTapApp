package com.kasouzou.universal_tap_support

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.os.Vibrator
import android.content.Context

class UniversalSupportService : AccessibilityService() {

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // 【解説】画面の内容が変わった、またはウィンドウの状態が変わった時だけ処理
        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || 
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
            
            val rootNode = rootInActiveWindow ?: return

            // 【マクロな視点】特定のアプリに依存せず、すべての画面を対象にする
            // ユーザーが設定した「支援が必要な文字列」をストレージから取得する
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
	        // キー名を "target_labels" から "flutter.support_labels" へ
            val savedTerms = prefs.getStringSet("flutter.support_labels", setOf<String>()) ?: setOf<String>()

            for (term in savedTerms) {
                // 【解説】指定されたテキストを持つノード（ボタン等）を検索
                val nodes = rootNode.findAccessibilityNodeInfosByText(term)
                if (nodes != null) {
                    for (node in nodes) {
                        // ユーザーに見えていて、かつクリック可能な場合のみ実行
                        if (node.isVisibleToUser && isClickableRecursive(node)) {
                            // 実行時の触覚フィードバック
                            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
                            v.vibrate(50)
                            
                            Log.d("SupportService", "Interaction supported for: $term")
                            return 
                        }
                    }
                }
            }
        }
    }

    private fun isClickableRecursive(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        // 【解説】ノード自体がクリック可能ならアクション実行。そうでなければ親に遡る
        if (node.isClickable) {
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }
        return isClickableRecursive(node.parent)
    }

    override fun onInterrupt() {
        // サービス中断時のクリーンアップ処理（必要に応じて）
    }
}
