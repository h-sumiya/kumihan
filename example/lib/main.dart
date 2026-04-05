import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kumihan/kumihan.dart' hide Text;
import 'package:kumihan_example/dsl_sample.dart';

void main() {
  runApp(const KumihanExampleApp());
}

enum ReaderViewMode { book, paged, scroll }

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
  final KumihanPagedController _pagedController = KumihanPagedController();
  final KumihanScrollController _scrollController = KumihanScrollController();
  final TextEditingController _pageController = TextEditingController(
    text: '1',
  );

  String? _fileName;
  Document? _document;
  ReaderViewMode _viewMode = ReaderViewMode.paged;
  bool _selectable = true;
  KumihanPagedSnapshot _pagedSnapshot = const KumihanPagedSnapshot(
    currentPage: 0,
    totalPages: 0,
  );
  KumihanScrollSnapshot _scrollSnapshot = const KumihanScrollSnapshot(
    viewportWidth: 0,
    viewportHeight: 0,
    scrollOffset: 0,
    maxScrollOffset: 0,
    contentWidth: 0,
    visibleRange: Rect.zero,
  );
  static const KumihanBookLayoutData _bookLayout = KumihanBookLayoutData(
    fontSize: 18,
    topUiPadding: EdgeInsets.fromLTRB(36, 8, 36, 0),
    bodyPadding: KumihanBookBodyPadding(inner: 20, outer: 8),
    bottomUiPadding: EdgeInsets.fromLTRB(36, 0, 36, 8),
  );

  Document _documentWithHeaderTitle(Document document, String fileName) {
    if (document.headerTitle == fileName) {
      return document;
    }
    return Document.fromAst(
      document.ast,
      headerTitle: fileName,
      value: document.value,
    );
  }

  void _loadDocument({required String fileName, required Document document}) {
    setState(() {
      _fileName = fileName;
      _document = _documentWithHeaderTitle(document, fileName);
      _pagedSnapshot = const KumihanPagedSnapshot(
        currentPage: 0,
        totalPages: 0,
      );
      _scrollSnapshot = const KumihanScrollSnapshot(
        viewportWidth: 0,
        viewportHeight: 0,
        scrollOffset: 0,
        maxScrollOffset: 0,
        contentWidth: 0,
        visibleRange: Rect.zero,
      );
      _pageController.text = '1';
    });
  }

  @override
  void dispose() {
    _pagedController.dispose();
    _scrollController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['txt', 'md', 'markdown'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return;
    }

    final bytes = file.bytes ?? await File(file.path!).readAsBytes();
    final text = utf8.decode(bytes, allowMalformed: true);
    final lowerName = file.name.toLowerCase();
    _loadDocument(
      fileName: file.name,
      document: lowerName.endsWith('.md') || lowerName.endsWith('.markdown')
          ? const MarkdownParser().parse(text)
          : const AozoraParser().parse(text),
    );
  }

  void _loadDslSample() {
    _loadDocument(fileName: 'DSLサンプル', document: buildDslSampleDocument());
  }

  bool get _canNavigate => _pagedSnapshot.totalPages > 0;

  Future<void> _jumpToPage() async {
    final requested = int.tryParse(_pageController.text);
    if (requested == null || requested <= 0) {
      return;
    }
    await _pagedController.showPage(requested - 1);
  }

  Future<void> _nextPage() async {
    await _pagedController.next();
  }

  Future<void> _prevPage() async {
    await _pagedController.prev();
  }

  Future<void> _scrollByViewport(double direction) async {
    final delta = _scrollSnapshot.viewportWidth * 0.9 * direction;
    await _scrollController.scrollBy(delta);
  }

  Widget _buildViewportControls() {
    if (_viewMode == ReaderViewMode.scroll) {
      final offset = _scrollSnapshot.scrollOffset.toStringAsFixed(0);
      final maxOffset = _scrollSnapshot.maxScrollOffset.toStringAsFixed(0);

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: <Widget>[
            Text(
              'Scroll $offset / $maxOffset',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(width: 12),
            IconButton(
              onPressed: () => _scrollByViewport(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            const SizedBox(width: 8),
            Text('右端から左へ連続表示', style: Theme.of(context).textTheme.bodyMedium),
            const Spacer(),
            IconButton(
              onPressed: () => _scrollByViewport(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      );
    }

    final pageInfo = _pagedSnapshot.totalPages > 0
        ? '${_pagedSnapshot.currentPage + 1} / ${_pagedSnapshot.totalPages}'
        : '-';
    final modeLabel = switch (_viewMode) {
      ReaderViewMode.book => 'Book',
      ReaderViewMode.paged => 'Page',
      ReaderViewMode.scroll => 'Scroll',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: <Widget>[
          Text(
            '$modeLabel $pageInfo',
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
    final title = _fileName ?? 'kumihan example';
    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                SegmentedButton<ReaderViewMode>(
                  segments: const <ButtonSegment<ReaderViewMode>>[
                    ButtonSegment(
                      value: ReaderViewMode.book,
                      label: Text('Book'),
                    ),
                    ButtonSegment(
                      value: ReaderViewMode.paged,
                      label: Text('Paged'),
                    ),
                    ButtonSegment(
                      value: ReaderViewMode.scroll,
                      label: Text('Scroll'),
                    ),
                  ],
                  selected: <ReaderViewMode>{_viewMode},
                  onSelectionChanged: (selection) {
                    setState(() {
                      _viewMode = selection.first;
                    });
                  },
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Text('文字選択'),
                    Switch(
                      value: _selectable,
                      onChanged: (value) {
                        setState(() {
                          _selectable = value;
                        });
                      },
                    ),
                  ],
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
                    child: Center(
                      child: Text('青空文庫テキストまたは Markdown を選択してください'),
                    ),
                  )
                : DecoratedBox(
                    decoration: const BoxDecoration(color: Color(0xfffffdf1)),
                    child: switch (_viewMode) {
                      ReaderViewMode.book => KumihanBookCanvas(
                        document: _document!,
                        controller: _pagedController,
                        layout: _bookLayout,
                        selectable: _selectable,
                        onSnapshotChanged: (snapshot) {
                          setState(() {
                            _pagedSnapshot = snapshot;
                            _pageController.text =
                                '${snapshot.currentPage + 1}';
                          });
                        },
                      ),
                      ReaderViewMode.paged => KumihanPagedCanvas(
                        document: _document!,
                        controller: _pagedController,
                        layout: const KumihanLayoutData(
                          fontSize: 18,
                          pagePadding: EdgeInsets.all(16),
                        ),
                        selectable: _selectable,
                        onSnapshotChanged: (snapshot) {
                          setState(() {
                            _pagedSnapshot = snapshot;
                            _pageController.text =
                                '${snapshot.currentPage + 1}';
                          });
                        },
                      ),
                      ReaderViewMode.scroll => KumihanScrollCanvas(
                        document: _document!,
                        controller: _scrollController,
                        layout: const KumihanLayoutData(
                          fontSize: 18,
                          pagePadding: EdgeInsets.all(16),
                        ),
                        selectable: _selectable,
                        onSnapshotChanged: (snapshot) {
                          setState(() {
                            _scrollSnapshot = snapshot;
                          });
                        },
                      ),
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
