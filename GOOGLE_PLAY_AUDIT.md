# Google Play 審査・技術監査レポート (2026/03/08)

このドキュメントは、`universal_tap_support` アプリが Google Play ストアの「ユーザー補助権限（AccessibilityService）」審査を通過するために、現状のコードおよび設定から特定された致命的なリスクと改善策をまとめたものである。

---

## 🚨 致命的なリスク 1：Android 14 以降の「フォアグラウンドサービス」要件

### 【現状】
`AndroidManifest.xml` および `SupportForegroundService.kt` で `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` を指定している。

### 【リスク】
Android 14 (API 34) 以降、`specialUse` タイプのフォアグラウンドサービスを使用する場合、Google Play Console 上でその正当性を詳細に説明し、Google の個別承認を得る必要がある。「なぜ他の標準タイプ（remoteMessaging 等）ではいけないのか？」という厳しい追及に対し、明確な回答ができない場合、**即リジェクト対象**となる。

### 【改善策】
*   **案A（推奨）**: 独自のフォアグラウンドサービスを廃止する。`AccessibilityService` 自体がバックグラウンドで永続動作する権利を持っているため、別途サービスを立てる必要はない。通知が必要な場合は通常の `Notification` で十分。
*   **案B**: 使用を継続する場合、Google Play Console の申告フォームで「運動機能障がい者向けのリアルタイム監視ステータス表示に不可欠である」という論理武装を徹底する。

---

## 🚨 致命的なリスク 2：アクセシビリティ設定（XML）の過剰な権限要求

### 【現状】
`res/xml/accessibility_service_config.xml` に以下の設定がある。
`android:accessibilityFlags="...|flagIncludeNotImportantViews"`

### 【リスク】
`flagIncludeNotImportantViews` は、通常はユーザーが操作しない「装飾用ビュー」までスキャン対象にする。Google は「最小限のデータアクセス」をポリシーとして掲げており、このフラグは「プライバシーの過剰侵害」とみなされ、**リジェクトの強力な動機**となる。

### 【改善策】
*   このフラグを削除する。標準的なボタンやテキスト（重要とマークされたビュー）だけであれば、デフォルトの設定で十分に検出可能である。

---

## 🚨 致命的なリスク 3：バイブレーション権限の宣言漏れ

### 【現状】
`UniversalSupportService.kt` 内で `Vibrator` を使用し、実行時に触覚フィードバックを与えているが、マニフェストに宣言がない。

### 【リスク】
審査官が実機でテストした際、タップ支援が実行された瞬間に **アプリがクラッシュ（SecurityException）** する。動作不良（Broken App）としてリジェクトされる。

### 【改善策】
*   `AndroidManifest.xml` に以下を追加する。
    `<uses-permission android:name="android.permission.VIBRATE" />`

---

## ⚠️ その他の改善推奨ポイント

### 1. リソース（strings.xml）の不足
*   `accessibility_service_config.xml` で `@string/accessibility_service_description` を参照しているが、これが定義されていない場合、Android の設定画面でサービスの説明が空欄になり、不審なアプリに見える。ユーザーの信頼を得るために丁寧な説明文を `strings.xml` に記述すべき。

### 2. 同意フローの順序（Consent Flow）
*   `lib/main.dart` で「通知許可」を求めた直後に「アクセシビリティ設定」へ誘導している。Google は「アクセシビリティの同意を得た直後に、余計なダイアログを挟まず設定画面へ飛ばす」ことを推奨している。順序を整理し、ユーザー体験をスムーズにする必要がある。

---

## 🛠 今後のアクションプラン

1.  **マニフェストの修正**: バイブレーション権限の追加。
2.  **XML 設定の最適化**: `flagIncludeNotImportantViews` の削除。
3.  **文字列リソースの整備**: ユーザー補助サービスの説明文を日本語・英語等で適切に設定。
4.  **フォアグラウンドサービスの要否検討**: `AccessibilityService` への統合による簡略化。
