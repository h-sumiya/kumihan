import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumihan/kumihan.dart' hide Text;
import 'package:kumihan_example/dsl_sample.dart';

void main() {
  runApp(const KumihanExampleApp());
}

enum ReaderViewMode { book, paged, singlePage, scroll }

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
  Uri? _documentBaseUri;
  Document? _document;
  ReaderViewMode _viewMode = ReaderViewMode.paged;
  KumihanSpreadMode _bookSpreadMode = KumihanSpreadMode.doublePage;
  int? _maxPages;
  bool _bookPageTurnAnimationEnabled = true;
  bool _disableBookGutterShadow = false;
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
    bodyPadding: KumihanBookBodyPadding(inner: 20, outer: 20),
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

  Future<ui.Image?> _loadImage(String source) async {
    try {
      final uri = Uri.tryParse(source);
      late final Uint8List bytes;
      if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https')) {
        final data = await NetworkAssetBundle(uri).load(source);
        bytes = data.buffer.asUint8List();
      } else {
        final filePath = uri != null && uri.scheme == 'file'
            ? uri.toFilePath()
            : source;
        bytes = await File(filePath).readAsBytes();
      }
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
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
    _documentBaseUri = file.path == null ? null : Uri.file(file.path!);
    _loadDocument(
      fileName: file.name,
      document: lowerName.endsWith('.md') || lowerName.endsWith('.markdown')
          ? const MarkdownParser().parse(text)
          : const AozoraParser().parse(text),
    );
  }

  void _loadDslSample() {
    _documentBaseUri = null;
    _loadDocument(fileName: 'DSLサンプル', document: buildDslSampleDocument());
  }

  bool get _canNavigate =>
      _viewMode != ReaderViewMode.singlePage && _pagedSnapshot.totalPages > 0;

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

  KumihanThemeData get _readerTheme =>
      KumihanThemeData(disableGutterShadow: _disableBookGutterShadow);

  Widget _buildFrontCover() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[Color(0xFF304A67), Color(0xFF1B2D40)],
        ),
        border: Border.all(color: const Color(0xFFC8A96F), width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'KUMIHAN',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: const Color(0xFFE8D4A2),
                letterSpacing: 3.0,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              _fileName ?? 'Sample Book',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackCover() {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[Color(0xFF223748), Color(0xFF101C26)],
        ),
        border: Border.all(color: const Color(0xFFC8A96F), width: 1.6),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            const Spacer(),
            Icon(
              Icons.auto_stories_rounded,
              color: const Color(0xFFE8D4A2).withValues(alpha: 0.92),
              size: 42,
            ),
            const SizedBox(height: 12),
            Text(
              'Back Cover',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
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
      ReaderViewMode.singlePage => 'Single',
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
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
                        value: ReaderViewMode.singlePage,
                        label: Text('Single'),
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
                  if (_viewMode == ReaderViewMode.book) ...<Widget>[
                    const SizedBox(width: 8),
                    SegmentedButton<KumihanSpreadMode>(
                      segments: const <ButtonSegment<KumihanSpreadMode>>[
                        ButtonSegment(
                          value: KumihanSpreadMode.doublePage,
                          label: Text('見開き'),
                        ),
                        ButtonSegment(
                          value: KumihanSpreadMode.single,
                          label: Text('シングル'),
                        ),
                      ],
                      selected: <KumihanSpreadMode>{_bookSpreadMode},
                      onSelectionChanged: (selection) {
                        setState(() {
                          _bookSpreadMode = selection.first;
                        });
                      },
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('アニメーション'),
                        Switch(
                          value: _bookPageTurnAnimationEnabled,
                          onChanged: (value) {
                            setState(() {
                              _bookPageTurnAnimationEnabled = value;
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const Text('中央影を無効化'),
                        Switch(
                          value: _disableBookGutterShadow,
                          onChanged: (value) {
                            setState(() {
                              _disableBookGutterShadow = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  if (_viewMode == ReaderViewMode.book ||
                      _viewMode == ReaderViewMode.paged) ...<Widget>[
                    const SizedBox(width: 8),
                    DropdownButton<int?>(
                      value: _maxPages,
                      hint: const Text('Max pages'),
                      items: const <DropdownMenuItem<int?>>[
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Max: all'),
                        ),
                        DropdownMenuItem<int?>(value: 1, child: Text('Max: 1')),
                        DropdownMenuItem<int?>(value: 3, child: Text('Max: 3')),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _maxPages = value;
                        });
                      },
                    ),
                  ],
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
                  SizedBox(
                    width: 220,
                    child: Text(
                      _fileName ?? '未選択',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
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
                      ReaderViewMode.book => KumihanBook(
                        document: _document!,
                        controller: _pagedController,
                        theme: _readerTheme,
                        baseUri: _documentBaseUri,
                        imageLoader: _loadImage,
                        maxPages: _maxPages,
                        spreadMode: _bookSpreadMode,
                        pageTurnAnimationEnabled: _bookPageTurnAnimationEnabled,
                        frontCover: _buildFrontCover(),
                        backCover: _buildBackCover(),
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
                      ReaderViewMode.paged => KumihanPagedView(
                        document: _document!,
                        controller: _pagedController,
                        theme: _readerTheme,
                        baseUri: _documentBaseUri,
                        imageLoader: _loadImage,
                        maxPages: _maxPages,
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
                      ReaderViewMode.singlePage => KumihanSinglePageView(
                        document: _document!,
                        theme: _readerTheme,
                        baseUri: _documentBaseUri,
                        imageLoader: _loadImage,
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
                      ReaderViewMode.scroll => KumihanScrollView(
                        document: _document!,
                        controller: _scrollController,
                        theme: _readerTheme,
                        baseUri: _documentBaseUri,
                        imageLoader: _loadImage,
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
