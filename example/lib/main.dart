import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  runApp(const KumihanExampleApp());
}

class KumihanExampleApp extends StatelessWidget {
  const KumihanExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ReaderScreen());
  }
}

class ReaderScreen extends StatefulWidget {
  const ReaderScreen({super.key});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  final KumihanController _controller = KumihanController();
  final TextEditingController _pageController = TextEditingController(
    text: '1',
  );

  String? _fileName;
  AozoraData? _document;
  KumihanSnapshot _snapshot = const KumihanSnapshot(
    currentPage: 0,
    totalPages: 0,
  );

  @override
  void dispose() {
    _controller.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['txt'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return;
    }

    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    final document = const AozoraAstParser().parse(text);
    setState(() {
      _fileName = file.name;
      _document = document;
      _snapshot = const KumihanSnapshot(currentPage: 0, totalPages: 0);
      _pageController.text = '1';
    });
  }

  Future<void> _jumpToPage() async {
    final requested = int.tryParse(_pageController.text);
    if (requested == null || requested <= 0) {
      return;
    }
    await _controller.showPage(requested - 1);
  }

  @override
  Widget build(BuildContext context) {
    final totalPages = _snapshot.totalPages == 0 ? 0 : _snapshot.totalPages;
    final currentPage = totalPages == 0 ? 0 : _snapshot.currentPage + 1;

    return Scaffold(
      appBar: AppBar(title: const Text('kumihan example')),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                ElevatedButton(
                  onPressed: _pickFile,
                  child: const Text('ファイルを選択'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_fileName ?? '未選択')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: totalPages == 0 ? null : _controller.prev,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text('ページ $currentPage / $totalPages'),
                const SizedBox(width: 12),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _pageController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: '移動'),
                    onSubmitted: (_) => _jumpToPage(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: totalPages == 0 ? null : _jumpToPage,
                  child: const Text('ジャンプ'),
                ),
                const Spacer(),
                IconButton(
                  onPressed: totalPages == 0 ? null : _controller.next,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xfffffdf1)),
              child: _document == null
                  ? const Center(child: Text('青空文庫テキストを選択してください'))
                  : KumihanAstCanvas(
                      data: _document!,
                      controller: _controller,
                      layout: const KumihanLayoutData(fontSize: 18),
                      onSnapshotChanged: (snapshot) {
                        setState(() {
                          _snapshot = snapshot;
                        });
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
