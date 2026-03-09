package com.kasouzou.universal_tap_support

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import android.util.Log
import android.os.Vibrator
import android.os.VibrationEffect
import android.os.Build
import android.content.Context

class UniversalSupportService : AccessibilityService(), android.content.SharedPreferences.OnSharedPreferenceChangeListener {

    private var lastTapTime: Long = 0
    private var prefs: android.content.SharedPreferences? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        // 共有設定の監視を開始
        prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs?.registerOnSharedPreferenceChangeListener(this)
        
        // 接続時に既にフラグがOFFなら即座に自分を無効化する
        checkAndDisableIfNeeded()
    }

    override fun onSharedPreferenceChanged(sharedPreferences: android.content.SharedPreferences?, key: String?) {
        if (key == "flutter.is_monitoring_enabled") {
            checkAndDisableIfNeeded()
        }
    }

    private fun checkAndDisableIfNeeded() {
        val isEnabled = prefs?.getBoolean("flutter.is_monitoring_enabled", false) ?: false
        if (!isEnabled) {
            Log.d("SupportService", "Disabling service per user request for transparency.")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                disableSelf()
            }
        }
    }

    override fun onDestroy() {
        prefs?.unregisterOnSharedPreferenceChangeListener(this)
        super.onDestroy()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent) {
        // クールダウンを800msに調整して、連続した操作の反応性を高める
        val currentTime = System.currentTimeMillis()
        if (currentTime - lastTapTime < 800L) return

        if (event.eventType == AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED || 
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED) {
            
            val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean("flutter.is_monitoring_enabled", false)
            if (!isEnabled) return

            // セットのコピーを作成し、安全に読み取れるようにする
            val savedTerms = prefs.getStringSet("flutter.support_labels", null)?.toSet() ?: emptySet()
            if (savedTerms.isEmpty()) return

            // --- 探索戦略：効率と網羅性のバランス ---

            // 1. まずイベントのソース（変更があった場所）を優先的にチェック
            val source = event.source
            if (source != null) {
                if (searchAndTap(source, savedTerms)) {
                    lastTapTime = System.currentTimeMillis()
                    source.recycle()
                    return
                }
                source.recycle()
            }

            // 2. アクティブなウィンドウ全体をチェック
            val rootNode = rootInActiveWindow
            if (rootNode != null) {
                if (searchAndTap(rootNode, savedTerms)) {
                    lastTapTime = System.currentTimeMillis()
                    rootNode.recycle()
                    return
                }
                rootNode.recycle()
            }

            // 3. 全てのウィンドウ（ダイアログやオーバーレイを含む）を走査
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val wins = windows
                if (wins != null) {
                    for (window in wins) {
                        val root = window.root
                        if (root != null) {
                            if (searchAndTap(root, savedTerms)) {
                                lastTapTime = System.currentTimeMillis()
                                root.recycle()
                                return 
                            }
                            root.recycle()
                        }
                    }
                }
            }
        }
    }

    private fun searchAndTap(node: AccessibilityNodeInfo?, targetTerms: Set<String>): Boolean {
        if (node == null) return false

        // このノードがターゲット単語を含んでいるかチェック
        val nodeText = node.text?.toString() ?: ""
        val contentDesc = node.contentDescription?.toString() ?: ""
        
        for (term in targetTerms) {
            if (term.isNotBlank() && (nodeText.contains(term, ignoreCase = true) || contentDesc.contains(term, ignoreCase = true))) {
                // 見つかった！
                // node.isVisibleToUser は Flutter 等で稀に false を返すことがあるため、
                // クリック可能であれば試行する。
                if (performClickRecursive(node)) {
                    Log.d("SupportService", "Interaction successful for term: $term")
                    vibrateFeedback()
                    return true
                }
            }
        }

        // 子ノードを再帰的に探索
        for (i in 0 until node.childCount) {
            val child = node.getChild(i)
            if (searchAndTap(child, targetTerms)) {
                child?.recycle()
                return true
            }
            child?.recycle()
        }
        return false
    }

    private fun performClickRecursive(node: AccessibilityNodeInfo?): Boolean {
        if (node == null) return false
        
        // ノードの状態を最新にする（重要：Staleなノードへのアクションを防ぐ）
        node.refresh()

        // デバッグログ追加：クリック試行
        // Log.d("SupportService", "Trying to click node: ${node.className}, clickable=${node.isClickable}")

        if (node.isClickable) {
            val success = node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
            if (success) {
                // Log.d("SupportService", "Click action sent successfully")
                return true
            } else {
                // Log.d("SupportService", "Click action failed on clickable node")
            }
        }
        
        val parent = node.parent
        val result = performClickRecursive(parent)
        parent?.recycle()
        return result
    }

    private fun vibrateFeedback() {
        try {
            val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                v.vibrate(VibrationEffect.createOneShot(50, VibrationEffect.DEFAULT_AMPLITUDE))
            } else {
                @Suppress("DEPRECATION")
                v.vibrate(50)
            }
        } catch (e: Exception) {
            Log.e("SupportService", "Vibration failed", e)
        }
    }

    override fun onInterrupt() {
    }
}
