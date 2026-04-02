import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

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
  final KumihanController _engineController = KumihanController();
  final KumihanController _astController = KumihanController();
  final TextEditingController _pageController = TextEditingController(
    text: '1',
  );

  String? _fileName;
  String? _sourceText;
  KumihanDocument? _engineDocument;
  AozoraData? _astDocument;
  KumihanSnapshot _engineSnapshot = const KumihanSnapshot(
    currentPage: 0,
    totalPages: 0,
  );
  KumihanSnapshot _astSnapshot = const KumihanSnapshot(
    currentPage: 0,
    totalPages: 0,
  );
  int _linkedPage = 0;
  bool _isSyncingPage = false;

  @override
  void dispose() {
    _engineController.dispose();
    _astController.dispose();
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
    final engineDocument = const KumihanAozoraParser().parse(text);
    final astDocument = const AozoraAstParser().parse(text);

    setState(() {
      _fileName = file.name;
      _sourceText = text;
      _engineDocument = engineDocument;
      _astDocument = astDocument;
      _engineSnapshot = const KumihanSnapshot(currentPage: 0, totalPages: 0);
      _astSnapshot = const KumihanSnapshot(currentPage: 0, totalPages: 0);
      _linkedPage = 0;
      _pageController.text = '1';
    });
  }

  int get _maxLinkedPage {
    int? result;
    if (_engineSnapshot.totalPages > 0) {
      result = _engineSnapshot.totalPages - 1;
    }
    if (_astSnapshot.totalPages > 0) {
      final astMax = _astSnapshot.totalPages - 1;
      result = result == null ? astMax : math.min(result, astMax);
    }
    return result ?? 0;
  }

  bool get _canNavigate {
    return _engineSnapshot.totalPages > 0 || _astSnapshot.totalPages > 0;
  }

  int _boundPage(int page, int totalPages) {
    if (totalPages <= 0 || page < 0) {
      return 0;
    }
    if (page >= totalPages) {
      return totalPages - 1;
    }
    return page;
  }

  Future<void> _syncLinkedPage(int page, {KumihanController? source}) async {
    final hasEngine = _engineSnapshot.totalPages > 0;
    final hasAst = _astSnapshot.totalPages > 0;
    if (!hasEngine && !hasAst) {
      return;
    }

    _linkedPage = page.clamp(0, _maxLinkedPage);
    _pageController.text = '${_linkedPage + 1}';
    _isSyncingPage = true;
    try {
      final tasks = <Future<void>>[];
      if (hasEngine && !identical(source, _engineController)) {
        tasks.add(
          _engineController.showPage(
            _boundPage(_linkedPage, _engineSnapshot.totalPages),
          ),
        );
      }
      if (hasAst && !identical(source, _astController)) {
        tasks.add(
          _astController.showPage(
            _boundPage(_linkedPage, _astSnapshot.totalPages),
          ),
        );
      }
      await Future.wait(tasks);
    } finally {
      _isSyncingPage = false;
    }
  }

  void _handleSnapshot({
    required KumihanSnapshot snapshot,
    required bool fromEngine,
  }) {
    setState(() {
      if (fromEngine) {
        _engineSnapshot = snapshot;
      } else {
        _astSnapshot = snapshot;
      }
    });

    if (_isSyncingPage || snapshot.totalPages <= 0) {
      return;
    }

    if (snapshot.currentPage != _linkedPage) {
      _linkedPage = snapshot.currentPage;
      _pageController.text = '${_linkedPage + 1}';
      unawaited(
        _syncLinkedPage(
          _linkedPage,
          source: fromEngine ? _engineController : _astController,
        ),
      );
    }
  }

  Future<void> _jumpToPage() async {
    final requested = int.tryParse(_pageController.text);
    if (requested == null || requested <= 0) {
      return;
    }
    await _syncLinkedPage(requested - 1);
  }

  Future<void> _nextPage() async {
    await _syncLinkedPage(_linkedPage + 1);
  }

  Future<void> _prevPage() async {
    await _syncLinkedPage(_linkedPage - 1);
  }

  Widget _buildViewportControls({required String title}) {
    final engineInfo = _engineSnapshot.totalPages > 0
        ? '${_engineSnapshot.currentPage + 1} / ${_engineSnapshot.totalPages}'
        : '-';
    final astInfo = _astSnapshot.totalPages > 0
        ? '${_astSnapshot.currentPage + 1} / ${_astSnapshot.totalPages}'
        : '-';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _canNavigate ? _prevPage : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Text('連動ページ ${_linkedPage + 1}'),
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
            onPressed: _canNavigate ? _jumpToPage : null,
            child: const Text('ジャンプ'),
          ),
          const SizedBox(width: 12),
          Text('E:$engineInfo / A:$astInfo'),
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
                const SizedBox(width: 12),
                Expanded(child: Text(_fileName ?? '未選択')),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _buildViewportControls(title: 'Page Control'),
          Expanded(
            child:
                _sourceText == null ||
                    _engineDocument == null ||
                    _astDocument == null
                ? const DecoratedBox(
                    decoration: BoxDecoration(color: Color(0xfffffdf1)),
                    child: Center(child: Text('青空文庫テキストを選択してください')),
                  )
                : Column(
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('Engine'),
                      ),
                      Expanded(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xfffffdf1),
                          ),
                          child: KumihanCanvas(
                            document: _engineDocument!,
                            controller: _engineController,
                            layout: const KumihanLayoutData(fontSize: 18),
                            onSnapshotChanged: (snapshot) => _handleSnapshot(
                              snapshot: snapshot,
                              fromEngine: true,
                            ),
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text('AST Engine'),
                      ),
                      Expanded(
                        child: DecoratedBox(
                          decoration: const BoxDecoration(
                            color: Color(0xfffffdf1),
                          ),
                          child: KumihanAstCanvas(
                            data: _astDocument!,
                            controller: _astController,
                            layout: const KumihanLayoutData(fontSize: 18),
                            onSnapshotChanged: (snapshot) => _handleSnapshot(
                              snapshot: snapshot,
                              fromEngine: false,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
