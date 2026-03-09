import 'package:auto_tap_screen/label_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansTextTheme(
          Theme.of(context).textTheme,
        ),
      ),
      home: const MyHomePage(title: 'ユニバーサルタップサポート'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const platform = MethodChannel('com.kasouzou.universal_tap_support/tap');
  
  // 【独自変数】今、監視エンジンが動いているかどうかを管理
  bool _isMonitoring = false;

  @override
  void initState() {
    super.initState();
    _loadMonitoringStatus();
  }

  Future<void> _loadMonitoringStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isMonitoring = prefs.getBool('is_monitoring_enabled') ?? false;
    });
  }

  Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint("設定画面が開けません: '${e.message}'.");
    }
  }

  Future<bool> _isServiceEnabled() async {
    try {
      return await platform.invokeMethod('isAccessibilityServiceEnabled') ?? false;
    } catch (e) {
      return false;
    }
  }

  // 監視の「開始」と「停止」を切り替えるメインロジック
  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      // 停止（内部フラグをOFFにする。サービスがそれを検知してdisableSelf()を呼び出す）
      await _invokeNativeMethod('stopMonitoring');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_monitoring_enabled', false);
      setState(() => _isMonitoring = false);
      _showSnackBar('サービスを完全に停止し、権限を解除しました。');
    } else {
      // 開始：まずシステム設定で有効かチェック
      bool isServiceEnabledInSystem = await _isServiceEnabled();
      
      if (!isServiceEnabledInSystem) {
        // システム設定がOFFなら、同意ダイアログを表示して設定画面へ
        bool proceed = await _showPermissionDialog();
        if (!proceed) return;

        // 内部フラグをONにし、設定画面へ飛ばす
        await _invokeNativeMethod('startMonitoring');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_monitoring_enabled', true);
        setState(() => _isMonitoring = true);
        
        _showSnackBar('設定画面で「ユニバーサルタップサポート」を有効にしてください。');
        await Future.delayed(const Duration(milliseconds: 500));
        await _openAccessibilitySettings();
      } else {
        // すでにシステム設定がONなら、即座に内部フラグをONにするだけでOK
        await _invokeNativeMethod('startMonitoring');
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_monitoring_enabled', true);
        setState(() => _isMonitoring = true);
        _showSnackBar('タップ支援サービスを稼働しました。');
      }
    }
  }

  // Googleが求める「事前の明確な開示」のためのダイアログ
  Future<bool> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ユーザー補助権限の利用について'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '本アプリは、身体的な操作が困難な方を支援するため「ユーザー補助サービス」を利用します。',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16),
              Text('■ アクセスする情報'),
              Text('・画面上のテキスト（設定した文字を探すため）'),
              SizedBox(height: 8),
              Text('■ 使用目的'),
              Text('・ユーザーが設定した文字を検出し、自動でタップを補助するため'),
              SizedBox(height: 8),
              Text('■ データの安全性'),
              Text('・取得したデータは外部へ送信されません'),
              Text('・他アプリのデータを収集・共有しません'),
              SizedBox(height: 16),
              Text(
                '次の設定画面で「ユニバーサルタップサポート」を有効にしてください。',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('同意して設定へ'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _invokeNativeMethod(String methodName) async {
    try {
      await platform.invokeMethod(methodName);
    } on PlatformException catch (e) {
      debugPrint("Nativeエラー ($methodName): '${e.message}'.");
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: Text(widget.title),
        // 横画面時にAppBarがデカすぎると邪魔なので少しスリムに
        toolbarHeight: MediaQuery.of(context).orientation == Orientation.landscape ? 40 : null,
      ),
      // 【マクロな視点】横画面でのオーバーフローを防ぐための必須スクロール設定
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // 状態アイコンとテキスト
              Icon(
                _isMonitoring ? Icons.visibility : Icons.visibility_off,
                size: 80,
                color: _isMonitoring ? Colors.green : Colors.grey,
              ),
              const SizedBox(height: 10),
              Text(
                _isMonitoring ? "稼働中" : "停止中",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 30),
              
              // 独立した「設定で許可」ボタンを削除。開始ボタンに集約。
              
              ElevatedButton.icon(
                onPressed: _toggleMonitoring,
                icon: Icon(_isMonitoring ? Icons.stop : Icons.play_arrow),
                label: Text(_isMonitoring ? 'タップ支援サービスを停止' : 'タップ支援サービスを開始'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isMonitoring ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 30),
              // 動的に中身が変わるガイドセクション
              _buildGuideSection(),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LabelSettingsPage()),
                  );
                },
                icon: const Icon(Icons.list),
                label: const Text('支援の対象の編集'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: Colors.blueGrey.shade50,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGuideSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        // 稼働中は緑っぽく、停止中はグレーにする
        color: _isMonitoring ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isMonitoring ? Colors.green.shade200 : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isMonitoring ? Icons.verified_user : Icons.list_alt,
                size: 20,
                color: _isMonitoring ? Colors.green : Colors.black87,
              ),
              const SizedBox(width: 8),
              Text(
                _isMonitoring ? 'アプリ稼働状況' : 'セットアップ手順',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 監視中の場合はステータス表示、停止中は手順を表示
          if (_isMonitoring) ...[
            _buildStatusRow(Icons.check, "バックグラウンド監視：アクティブ"),
            _buildStatusRow(Icons.check, "ユーザー補助権限：有効"),
            _buildStatusRow(Icons.sync, "ターゲットの出現を待機中..."),
          ] else ...[
            _buildStepRow('1', '支援対象単語の設定', '「支援の対象の編集」から、自動タップしたい単語を登録してください。'),
            _buildDivider(),
            _buildStepRow('2', 'タップ支援サービスの開始', '「タップ支援サービスを開始」ボタンを押し、権限に同意してください。'),
            _buildDivider(),
            _buildStepRow('3', 'ユーザー補助の有効化', '自動で設定画面が開くので「ユニバーサルタップサポート」をONにしてください。'),
          ],
        ],
      ),
    );
  }

  // 稼働中用の無機質なステータス行
  Widget _buildStatusRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.green),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.black87)),
        ],
      ),
    );
  }

  // 手順行（高さを抑えるために微調整）
  Widget _buildStepRow(String stepNumber, String title, String description) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stepNumber, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.orange.withOpacity(0.5))),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              Text(description, style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Divider(height: 1, color: Colors.grey.shade300));
  }
}
