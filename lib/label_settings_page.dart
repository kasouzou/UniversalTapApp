import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class LabelSettingsPage extends StatefulWidget {
  const LabelSettingsPage({super.key});

  @override
  State<LabelSettingsPage> createState() => _LabelSettingsPageState();
}

class _LabelSettingsPageState extends State<LabelSettingsPage> {
  // 【独自変数】ユーザーが登録したターゲット単語のリスト
  List<String> _labels = [];
  final TextEditingController _controller = TextEditingController();
  static const platform = MethodChannel('com.kasouzou.universal_tap_support/tap');

  @override
  void initState() {
    super.initState() ;
    _loadLabels();
  }

  // データをスマホから読み込む
  Future<void> _loadLabels() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 【マクロな視点】
    // 1. まずデータがあるか確認。
    // 2. なければ「これが初めての起動か？」をチェックし、デフォルトを入れる。
    final List<String>? savedLabels = prefs.getStringList('support_labels');
    
    if (savedLabels == null) {
      // <String>[] と書くことで、List<String> 型であることを明示しエラーを防ぐ。
      final List<String> defaultLabels = <String>[];
      setState(() {
        _labels = defaultLabels;
      });
      await prefs.setStringList('support_labels', defaultLabels);
    } else {
      // 2回目以降は、空リストであっても保存された状態を尊重する
      setState(() {
        _labels = savedLabels;
      });
    }
    _syncWithNative();
  }

  // データを保存して、ネイティブ（Kotlin）にも通知する
  Future<void> _saveAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    // ここでリストが空っぽでも、そのまま「空リスト」として保存される
    await prefs.setStringList('support_labels', _labels);
    _syncWithNative();
  }

  // 【マクロな視点】Kotlin側のメモリを最新状態に更新する
  Future<void> _syncWithNative() async {
    try {
      await platform.invokeMethod('updateLabels', {'labels': _labels});
    } catch (e) {
      debugPrint("同期エラー: $e");
    }
  }

  void _addLabel() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _labels.add(_controller.text);
        _controller.clear();
      });
      _saveAndSync();
    }
  }

  void _removeLabel(int index) {
    setState(() {
      _labels.removeAt(index);
    });
    _saveAndSync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('支援対象テキストの設定')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      labelText: '新しい支援サービス対象テキストを入力',
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.add_circle, color: Colors.orange), onPressed: _addLabel),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _labels.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_labels[index]),
                  trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _removeLabel(index)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}