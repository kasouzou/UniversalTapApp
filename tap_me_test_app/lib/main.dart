import 'dart:async';
import 'package:flutter/material.dart';

void main() {
  runApp(const TapMeApp());
}

class TapMeApp extends StatelessWidget {
  const TapMeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TapMe Test App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;
  bool _showProceedButton = false;
  Timer? _dynamicTimer;

  void _onTap(String label) {
    setState(() {
      _counter++;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label Clicked! (Total: $_counter)'),
        duration: const Duration(milliseconds: 500),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startDynamicContent() {
    setState(() {
      _showProceedButton = false;
    });
    _dynamicTimer?.cancel();
    _dynamicTimer = Timer(const Duration(seconds: 5), () {
      setState(() {
        _showProceedButton = true;
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Processing... Dynamic button will appear in 5s...')),
    );
  }

  // ボタンをアクセシビリティサービスが検出しやすいように、余計なラップを避けてシンプルに実装
  Widget _buildAccessibleButton(String label, VoidCallback? onPressed, {Color? color, Color? textColor}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: color != null ? ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: textColor) : null,
      child: Text(label),
    );
  }

  @override
  void dispose() {
    _dynamicTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TapMe Test App (for Review)'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'Accessibility Service Demo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                'Total Taps Detected: $_counter',
                style: const TextStyle(fontSize: 16),
              ),
              const Divider(height: 40),
              
              // 静的なボタン（Semantics対応済み）
              Wrap(
                spacing: 20,
                children: [
                  _buildAccessibleButton('TapMe', () => _onTap('TapMe')),
                  _buildAccessibleButton('Next', () => _onTap('Next')),
                ],
              ),
              const SizedBox(height: 20),
              _buildAccessibleButton('Confirm', () => _onTap('Confirm')),
              
              const Divider(height: 60),
              
              // 動的コンテンツシミュレーション
              const Text('Dynamic Content Scenario:'),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _startDynamicContent,
                icon: const Icon(Icons.play_circle_fill),
                label: const Text('Start Simulation (Wait 5s)'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100),
              ),
              const SizedBox(height: 20),
              
              // 遅延して現れる「Proceed」ボタン（Semantics対応済み）
              AnimatedOpacity(
                opacity: _showProceedButton ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                child: _showProceedButton
                    ? _buildAccessibleButton(
                        'Proceed',
                        () => _onTap('Proceed'),
                        color: Colors.blue.shade400,
                        textColor: Colors.white,
                      )
                    : const SizedBox(height: 50, child: Center(child: Text('Waiting for Dynamic Button...'))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
