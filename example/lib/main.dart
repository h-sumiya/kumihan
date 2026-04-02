import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kumihan/kumihan.dart' hide Text;
import 'package:kumihan_example/dsl_sample.dart';

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
  Document? _document;
  KumihanSnapshot _snapshot = const KumihanSnapshot(
    currentPage: 0,
    totalPages: 0,
  );

  void _loadDocument({required String fileName, required Document document}) {
    setState(() {
      _fileName = fileName;
      _document = document;
      _snapshot = const KumihanSnapshot(currentPage: 0, totalPages: 0);
      _pageController.text = '1';
    });
  }

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
    _loadDocument(
      fileName: file.name,
      document: const AozoraParser().parse(text),
    );
  }

  void _loadDslSample() {
    _loadDocument(fileName: 'DSLサンプル', document: buildDslSampleDocument());
  }

  bool get _canNavigate => _snapshot.totalPages > 0;

  Future<void> _jumpToPage() async {
    final requested = int.tryParse(_pageController.text);
    if (requested == null || requested <= 0) {
      return;
    }
    await _controller.showPage(requested - 1);
  }

  Future<void> _nextPage() async {
    await _controller.next();
  }

  Future<void> _prevPage() async {
    await _controller.prev();
  }

  Widget _buildViewportControls() {
    final pageInfo = _snapshot.totalPages > 0
        ? '${_snapshot.currentPage + 1} / ${_snapshot.totalPages}'
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Text(
            'Page $pageInfo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: _canNavigate ? _prevPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
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
            onPressed: _canNavigate ? _jumpToPage : null,
            child: const Text('ジャンプ'),
          ),
          const Spacer(),
          IconButton(
            onPressed: _canNavigate ? _nextPage : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: _loadDslSample,
                  child: const Text('DSL'),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(_fileName ?? '未選択')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildViewportControls(),
          Expanded(
            child: _document == null
                ? const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xfffffdf1)),
                    child: Center(child: Text('青空文庫テキストを選択してください')),
                  )
                : DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xfffffdf1)),
                    child: KumihanCanvas(
                      document: _document!,
                      controller: _controller,
                      layout: const KumihanLayoutData(fontSize: 18),
                      onSnapshotChanged: (snapshot) {
                        setState(() {
                          _snapshot = snapshot;
                          _pageController.text = '${snapshot.currentPage + 1}';
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
