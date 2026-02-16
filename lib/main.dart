import 'package:auto_tap_screen/label_settings_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _openAccessibilitySettings() async {
    try {
      await platform.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (e) {
      debugPrint("設定画面が開けません: '${e.message}'.");
    }
  }

  // 監視の「開始」と「停止」を切り替えるメインロジック
  Future<void> _toggleMonitoring() async {
    if (_isMonitoring) {
      // 停止はそのまま
      await _invokeNativeMethod('stopMonitoring');
      setState(() => _isMonitoring = false);
      _showSnackBar('タップ支援サービスを停止しました。');
    } else {
      // 【解説】いきなり権限を求めず、まずは「説明」を表示する
      bool proceed = await _showPermissionDialog();
      if (!proceed) return;

      var status = await Permission.notification.status;

      if (status.isPermanentlyDenied) {
        // ツッコミ：もうOSはダイアログを出してくれない「絶縁状態」
        _showSnackBar('設定から通知を許可してください。');
        await openAppSettings(); // 直接設定画面へ飛ばす！
        return;
      }
      
      if (await Permission.notification.request().isGranted) {
        // 通知が許可されたら、胸を張ってサービス開始！
        await _invokeNativeMethod('startMonitoring');
        setState(() => _isMonitoring = true);
      } else {
        // 拒否されたら、なぜダメなのかを優しく説明
        _showSnackBar('動作状況を表示するために通知の許可が必要です。');
      }
    }
  }

  // Googleが求める「事前の明確な開示」のためのダイアログ
  Future<bool> _showPermissionDialog() async {
    // showDialogの結果（Future<bool?>）を待ってから、最後に ?? false で判定する
    final result = await showDialog<bool>(
      context: context,
      // builderは「Widgetを返す」だけの役割に専念させる！
      builder: (context) => AlertDialog(
        title: const Text('権限の使用について'),
        content: const Text(
          '本アプリは、タップ支援サービスの稼働状況を通知欄に表示するために「通知」権限を使用します。'
          '\n\nまた、ユーザーが設定した単語を画面上から探し出し、自動でタップ操作を行うために「ユーザー補助（アクセシビリティ）サービス」を利用します。'
          'これらの権限により取得されたデータが、外部に送信されることはありません。'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), // ここでfalseを返す
            child: const Text('キャンセル'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true), // ここでtrueを返す
            child: const Text('同意して進む'),
          ),
        ],
      ),
    );

    // ダイアログの外をタップして閉じられた場合は result が null になるので、
    // その時は false として扱うようにマクロな視点でガードをかける
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
              
              // 横画面時にボタンが横に並ぶと使いやすいが、今回はシンプルに縦並びを維持しつつ間隔を調整
              ElevatedButton.icon(
                onPressed: _openAccessibilitySettings,
                icon: const Icon(Icons.settings_accessibility),
                label: const Text('設定でユーザー補助を許可'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
              
              const SizedBox(height: 15),

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
              // 既存のコードの中にこれを差し込むイメージ！
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
            _buildStatusRow(Icons.sync, "タップ支援サービスの対象を待機中..."),
          ] else ...[
            _buildStepRow('1', 'ユーザー補助権限の有効化', '上の「設定でユーザー補助を許可」ボタンを押して設定から本アプリのユーザー補助をONにしてください。'),
            _buildDivider(),
            _buildStepRow('2', '支援対象単語の設定', '「支援の対象の編集」から、タップしたい単語を登録してください。'),
            _buildDivider(),
            _buildStepRow('3', 'タップ支援サービスの開始', '開始ボタンを押し、通知欄にアイコンが出れば有効です。'),
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