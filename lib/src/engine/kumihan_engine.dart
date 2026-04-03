import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../ast.dart';
import '../document.dart';
import '../kumihan_controller.dart';
import '../kumihan_page_paint_context.dart';
import '../kumihan_theme.dart';
import '../kumihan_types.dart';
import 'constants.dart';
import 'document_compiler.dart';
import 'helpers.dart';
import 'layout_primitives.dart';
import 'table_renderer.dart';
import 'warichu.dart';

part 'kumihan_page_renderer.dart';

final RegExp _cjkIdeographPattern = RegExp('[⺀-⻳㐁-䶮一-龻豈-龎仝々〆〇ヶ]');

enum _IndexKind { headingLarge, headingMedium, headingSmall, anchor }

class _IndexEntry {
  _IndexEntry({
    required this.endIndex,
    required this.paragraphNo,
    required this.startIndex,
    required this.kind,
    this.anchorName,
  });

  final String? anchorName;
  final int endIndex;
  final _IndexKind kind;
  final int paragraphNo;
  final int startIndex;
}

class PositionInfo {
  PositionInfo({
    required this.leftToRight,
    required this.length,
    required this.offset,
    required this.paragraphNo,
    required this.shift1page,
  });

  bool leftToRight;
  int length;
  int offset;
  int paragraphNo;
  bool shift1page;
}

class ChapterEntry {
  ChapterEntry({required this.label, required this.pageNo});

  final String label;
  final int pageNo;
}

class PageInfo {
  PageInfo({
    this.line = 0,
    this.centering = false,
    this.usesFullPageAlignment = false,
  });

  final int line;
  final bool centering;
  final bool usesFullPageAlignment;
}

class ClickableArea {
  ClickableArea({
    required this.data,
    required this.height,
    required this.type,
    required this.width,
    required this.x,
    required this.y,
  });

  final String type;
  final double x;
  final double y;
  final double width;
  final double height;
  final String data;

  bool hit(double px, double py) {
    return px >= x && py >= y && px < x + width && py < y + height;
  }
}

class LineGroup {
  LineGroup(this.primary) : lines = <LayoutTextLine>[primary];

  final LayoutTextLine primary;
  final List<LayoutTextLine> lines;

  double get width => primary.width;
}

class RendererSettings {
  const RendererSettings({
    this.fontSize = 18,
    this.rubyColor = fontColor,
    this.smallBouten = true,
    this.widenLineSpace = false,
  });

  final double fontSize;
  final Color rubyColor;
  final bool smallBouten;
  final bool widenLineSpace;
}

typedef KumihanImageLoader = Future<ui.Image?> Function(String path);

class KumihanEngine implements LayoutEnvironment, KumihanViewport {
  KumihanEngine({
    required this.baseUri,
    required int initialPage,
    this.layout = const KumihanLayoutData(),
    this.theme = const KumihanThemeData(),
    required this.onInvalidate,
    required this.onSnapshot,
    this.imageLoader,
  }) : _initialPage = initialPage,
       _currentPosition = PositionInfo(
         leftToRight: false,
         length: 0,
         offset: 0,
         paragraphNo: 0,
         shift1page: false,
       ) {
    fontColor = theme.textColor;
    paperColor = theme.paperColor;
    _updateSizes();
  }

  final Uri? baseUri;
  final VoidCallback onInvalidate;
  final ValueChanged<KumihanSnapshot> onSnapshot;
  final KumihanImageLoader? imageLoader;
  final int _initialPage;
  KumihanLayoutData layout;
  KumihanThemeData theme;
  final RendererSettings _settings = const RendererSettings();

  @override
  final List<String> gothicFontFamilies = defaultGothicFontFamilies;
  @override
  final List<String> fixedGothicFontFamilies = defaultFixedGothicFontFamilies;
  @override
  final List<String> fixedMinchoFontFamilies = defaultFixedMinchoFontFamilies;
  @override
  final List<String> minchoFontFamilies = defaultMinchoFontFamilies;

  @override
  late Color fontColor;
  @override
  late Color paperColor;

  List<AstCompiledEntry> _entries = const <AstCompiledEntry>[];
  int _layoutToken = 0;
  final String _currentState = 'vsingle';
  final bool _shift1page = false;
  final bool _forceIndent = false;
  PositionInfo _currentPosition;
  final List<LayoutTextBlock> _blocks = <LayoutTextBlock>[];
  final List<LineGroup> _lines = <LineGroup>[];
  final List<PageInfo> _pages = <PageInfo>[PageInfo(), PageInfo()];
  final List<_IndexEntry> _indexes = <_IndexEntry>[];
  final List<ChapterEntry> _chapterList = <ChapterEntry>[];
  final Map<String, int> _anchorList = <String, int>{};
  final Map<String, ui.Image?> _images = <String, ui.Image?>{};
  final Map<String, Future<ui.Image?>> _imageTasks =
      <String, Future<ui.Image?>>{};
  final Map<AstCompiledTableEntry, RenderedTableBlock> _tables =
      <AstCompiledTableEntry, RenderedTableBlock>{};
  List<ClickableArea> _clickable = <ClickableArea>[];
  List<KumihanSelectableGlyph> _selectableGlyphs = <KumihanSelectableGlyph>[];
  int _selectableGlyphOrder = 0;

  double _width = 1;
  double _height = 1;
  double _fontSize = 18;
  double _lineSpace = 0;
  double _pageLeadingInset = 0;
  double _pageInlineOverflow = 0;
  double _pageMarginTop = 0;
  double _pageWidth = 0;
  double _pagePaintWidth = 0;
  double _pageHeight = 0;
  double _currentPageWidth = 0;
  int _currentPageNo = -1;
  final int _lastPageNo = 0;
  int _currentFontType = 0;
  bool _currentFontBold = false;
  bool _currentFontItalic = false;
  double _currentFontSize = 0;
  String _currentTextRotation = 'v';
  String _headerTitle = '';
  bool _inCaption = false;
  bool _inYokogumi = false;
  double _firstTopMargin = 0;
  double _restTopMargin = 0;
  double _bottomMargin = 0;
  bool _alignBottom = false;
  bool _frameDrawing = false;
  bool _quoteDrawing = false;
  double _frameTop = 0;
  double _frameBottom = 0;

  final double _fontScaleL = 1.2;
  final double _fontScaleS = 0.85;

  bool get _hasLayoutContent => _entries.isNotEmpty;

  int get _contentPageCount => math.max(_pages.length - 2, 0);

  int get _lastDocumentPage => math.max(snapshot.totalPages - 1, 0);

  int _documentToInternalPageNo(int pageNo) => pageNo + 1;

  int _internalToDocumentPageNo(int pageNo) => pageNo - 1;

  @override
  KumihanSnapshot get snapshot => KumihanSnapshot(
    currentPage: math.max(_currentPageNo, 0),
    totalPages: _contentPageCount,
  );

  String get headerTitle => _headerTitle;

  List<KumihanSelectableGlyph> get selectableGlyphs =>
      List<KumihanSelectableGlyph>.unmodifiable(_selectableGlyphs);

  @override
  MeasuredText layoutText(LayoutAtom atom, String text, Color color) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: atom.createTextStyle(this, color: color),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    final metrics = painter.computeLineMetrics();
    final line = metrics.isNotEmpty ? metrics.first : null;
    return MeasuredText(
      painter: painter,
      ascent: line?.ascent ?? painter.height,
      descent: line?.descent ?? 0,
      width: painter.width,
    );
  }

  @override
  Future<void> open(Document document) async {
    final compiled = compileAst(document);
    _entries = compiled.entries;
    _headerTitle = document.headerTitle;
    _currentPosition = PositionInfo(
      leftToRight: false,
      length: 0,
      offset: 0,
      paragraphNo: 0,
      shift1page: _shift1page,
    );
    await _relayout(false);
  }

  Future<void> updateLayout(KumihanLayoutData nextLayout) async {
    if (nextLayout == layout) {
      return;
    }

    layout = nextLayout;

    if (_hasLayoutContent) {
      await _relayout(true);
    } else {
      _updateSizes();
      onSnapshot(snapshot);
      onInvalidate();
    }
  }

  Future<void> updateTheme(KumihanThemeData nextTheme) async {
    if (nextTheme == theme) {
      return;
    }

    theme = nextTheme;
    fontColor = theme.textColor;
    paperColor = theme.paperColor;

    if (_hasLayoutContent) {
      await _relayout(true);
    } else {
      onSnapshot(snapshot);
      onInvalidate();
    }
  }

  @override
  Future<void> resize(double width, double height) async {
    _width = math.max(1, width);
    _height = math.max(1, height);
    _updateSizes();

    if (_hasLayoutContent) {
      await _relayout(true);
    } else {
      onSnapshot(snapshot);
      onInvalidate();
    }
  }

  @override
  Future<void> nextPage([int? amount]) async {
    if (_currentPageNo >= 0) {
      _showPage(_currentPageNo + (amount ?? _step()));
    }
  }

  @override
  Future<void> prevPage([int? amount]) async {
    if (_currentPageNo > 0) {
      _showPage(math.max(_currentPageNo - (amount ?? _step()), 0));
    }
  }

  @override
  Future<void> showPage(int page) async {
    _showPage(page);
  }

  @override
  Future<void> showFirstPage() async {
    _showPage(0);
  }

  @override
  Future<void> showLastPage() async {
    _showPage(_lastDocumentPage);
  }

  @override
  Future<void> nextStop() async {
    final stops = _getStopList();
    var target = _currentPageNo + 1;
    if (_currentState.endsWith('double')) {
      target += 1;
    }
    for (final stop in stops) {
      if (stop >= target) {
        _showPage(stop);
        return;
      }
    }
    _showPage(_lastDocumentPage);
  }

  @override
  Future<void> prevStop() async {
    if (_currentPageNo <= 0) {
      return;
    }
    final stops = _getStopList();
    for (var index = stops.length - 1; index >= 0; index -= 1) {
      if (stops[index] < _currentPageNo) {
        _showPage(stops[index]);
        return;
      }
    }
    _showPage(0);
  }

  int _step() => 1;

  double _pageMarginSideFor(
    int pageNo, {
    KumihanFullPageAlignment? inlineAlignment,
  }) {
    final page = _pages[pageNo];
    final alignment =
        inlineAlignment ??
        (page.usesFullPageAlignment
            ? layout.fullPageAlignment
            : KumihanFullPageAlignment.right);
    final inlineOffset = switch (alignment) {
      KumihanFullPageAlignment.left => 0.0,
      KumihanFullPageAlignment.center => _pageInlineOverflow / 2,
      KumihanFullPageAlignment.right => _pageInlineOverflow,
    };
    return _pageLeadingInset + inlineOffset;
  }

  void _markLastPageAsFull() {
    if (_pages.isEmpty) {
      return;
    }
    final last = _pages.last;
    _pages[_pages.length - 1] = PageInfo(
      line: last.line,
      centering: last.centering,
      usesFullPageAlignment: true,
    );
  }

  Future<void> _relayout(bool preservePosition) async {
    final token = ++_layoutToken;
    final position = preservePosition && _blocks.isNotEmpty
        ? _getPositionInfo(true)
        : _currentPosition;

    _updateSizes();
    await _ensureImagesLoaded(token);
    if (token != _layoutToken) {
      return;
    }

    _currentPosition = position;
    _tables.clear();
    await _ensureTablesPrepared(token);
    if (token != _layoutToken) {
      return;
    }

    _layoutDocument();
    if (token != _layoutToken) {
      return;
    }

    if (!preservePosition && _initialPage > 0) {
      _showPage(_initialPage);
      return;
    }

    _showPage(_currentPageNo >= 0 ? _currentPageNo : 0);
  }

  Future<void> _ensureTablesPrepared(int token) async {
    final tables = _entries.whereType<AstCompiledTableEntry>().toList();
    await Future.wait<void>(
      tables.map((entry) async {
        if (token != _layoutToken || _tables.containsKey(entry)) {
          return;
        }
        _tables[entry] = await renderTableBlock(
          table: entry,
          fontColor: fontColor,
          fontSize: _fontSize,
          gothicFontFamilies: gothicFontFamilies,
          maxHeight: _pageHeight,
          minchoFontFamilies: minchoFontFamilies,
          maxWidth: _pageWidth,
        );
      }),
    );
  }

  Future<void> _ensureImagesLoaded(int token) async {
    if (imageLoader == null) {
      return;
    }

    final paths = <String>{};
    for (final entry in _entries) {
      if (entry is! AstCompiledParagraphEntry) {
        continue;
      }
      for (final extra in entry.extras) {
        if ((extra.kind == AstParagraphExtraKind.inlineImage ||
                extra.kind == AstParagraphExtraKind.outsideImage) &&
            extra.imagePath != null &&
            extra.imagePath!.isNotEmpty) {
          paths.add(extra.imagePath!);
        }
      }
    }

    await Future.wait<void>(
      paths.map((path) async {
        if (token != _layoutToken || _images.containsKey(path)) {
          return;
        }
        final task = _imageTasks.putIfAbsent(path, () async {
          final image = await imageLoader!.call(_resolveImagePath(path));
          _images[path] = image;
          return image;
        });
        await task;
      }),
    );
  }

  String _resolveImagePath(String path) {
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:') ||
        path.startsWith('blob:') ||
        path.startsWith('airzoshiproxy')) {
      return path;
    }
    try {
      return baseUri?.resolve(path).toString() ?? path;
    } catch (_) {
      return path;
    }
  }

  void _updateSizes() {
    _fontSize = layout.fontSize.roundToDouble();
    _lineSpace = _fontSize * (_settings.widenLineSpace ? 0.8 : 0.63);
    final customPadding = layout.pagePadding;
    final leftInset = customPadding?.left ?? 0;
    final rightInset = customPadding?.right ?? 0;
    final topInset = customPadding?.top ?? 0;
    final bottomInset = customPadding?.bottom ?? 0;
    final minPageWidth = _fontSize * 6;
    final minPageHeight = _fontSize * 6;
    final maxHorizontalInset = math.max(_width - minPageWidth, 0.0);
    final horizontalFactor =
        leftInset + rightInset > maxHorizontalInset &&
            leftInset + rightInset > 0
        ? maxHorizontalInset / (leftInset + rightInset)
        : 1.0;
    final maxVerticalInset = math.max(_height - minPageHeight, 0.0);
    final verticalFactor =
        topInset + bottomInset > maxVerticalInset && topInset + bottomInset > 0
        ? maxVerticalInset / (topInset + bottomInset)
        : 1.0;
    final leadingInset = leftInset * horizontalFactor;
    _pageMarginTop = topInset * verticalFactor;
    final availableWidth = _width - (leftInset + rightInset) * horizontalFactor;
    final snappedPageWidth =
        availableWidth -
        (availableWidth + _lineSpace) % (_fontSize + _lineSpace);
    _pageWidth = availableWidth;
    _pagePaintWidth = math.max(snappedPageWidth, _fontSize);
    _pageLeadingInset = leadingInset;
    _pageInlineOverflow = math.max(availableWidth - _pagePaintWidth, 0);
    _pageHeight = _height - (topInset + bottomInset) * verticalFactor;
  }

  void _layoutDocument() {
    _lines.clear();
    _pages
      ..clear()
      ..add(PageInfo())
      ..add(PageInfo());
    _blocks.clear();
    _indexes.clear();
    _chapterList.clear();
    _anchorList.clear();
    _clickable = <ClickableArea>[];
    _selectableGlyphs = <KumihanSelectableGlyph>[];
    _selectableGlyphOrder = 0;
    _currentPageWidth = -_lineSpace;
    _currentPageNo = -1;
    _resetParagraphState();

    final pageInlineSize = _pageWidth;
    final pageBlockSize = _pageHeight;

    for (final entry in _entries) {
      final paragraphNo = _blocks.length;

      if (entry is AstCommandEntry) {
        _handleAstCommandEntry(entry, pageBlockSize);
        continue;
      }

      if (entry is AstCompiledTableEntry) {
        _layoutPreparedTable(
          entry,
          pageBlockSize: pageBlockSize,
          pageInlineSize: pageInlineSize,
          paragraphNo: paragraphNo,
        );
        continue;
      }

      if (entry is! AstCompiledParagraphEntry) {
        continue;
      }

      var paragraph = entry.text;
      final extras = <AstParagraphExtra>[
        if (_quoteDrawing && !entry.suppressQuote)
          const AstParagraphExtra(kind: AstParagraphExtraKind.quote),
        if (_frameDrawing &&
            !entry.extras.any(
              (extra) => extra.kind == AstParagraphExtraKind.frame,
            ))
          const AstParagraphExtra(
            kind: AstParagraphExtraKind.frame,
            frameKind: AstFrameKind.middle,
          ),
        ...entry.extras,
      ];

      if (paragraph.isEmpty) {
        paragraph = ' ';
      }

      final block = LayoutTextBlock(this)
        ..setText(
          paragraph,
          _currentFontSize,
          _currentFontType,
          _currentFontBold,
          _currentFontItalic,
          _currentTextRotation,
        )
        ..userData = LayoutBlockUserData();
      _blocks.add(block);

      for (final style in entry.styles) {
        _applyStyle(block, style.startIndex, style.endIndex, style);
      }

      for (final extra in entry.extras) {
        if (extra.kind == AstParagraphExtraKind.outsideImage) {
          _insertImage(
            block,
            extra.startIndex ?? 0,
            extra.imagePath ?? '',
            0,
            _currentFontSize,
          );
          continue;
        }
        if (extra.kind == AstParagraphExtraKind.inlineImage) {
          _insertImage(
            block,
            extra.startIndex ?? 0,
            extra.imagePath ?? '',
            extra.imageWidth ?? 0,
            extra.imageHeight ?? 0,
          );
        }
      }

      if (_inCaption) {
        _applyStyle(
          block,
          0,
          block.rawtext.length,
          const AstStyleSpan(
            startIndex: 0,
            endIndex: 0,
            kind: AstStyleKind.caption,
          ),
        );
      }
      if (_inYokogumi) {
        _applyStyle(
          block,
          0,
          block.rawtext.length,
          const AstStyleSpan(
            startIndex: 0,
            endIndex: 0,
            kind: AstStyleKind.yokogumi,
          ),
        );
      }
      if (_currentState.startsWith('v') && _currentTextRotation == 'v') {
        for (final tcy in entry.tcyRanges) {
          block.setTCY(tcy.startIndex, tcy.endIndex);
        }
      }

      _insertTextLine(block, entry.inserts);
      _adjustRubies(block, entry.rubies, entry.inserts);
      _layoutPreparedBlock(
        alignBottom: entry.alignBottom || _alignBottom,
        block: block,
        bottomMargin: entry.alignBottom
            ? entry.bottomMargin * _currentFontSize
            : _bottomMargin,
        extras: extras,
        firstTopMargin: entry.firstTopMargin > 0
            ? entry.firstTopMargin * _currentFontSize
            : _firstTopMargin,
        inserts: entry.inserts,
        nonBreak: entry.nonBreak,
        pageBlockSize: pageBlockSize,
        pageInlineSize: pageInlineSize,
        paragraphNo: paragraphNo,
        restTopMargin: entry.restTopMargin > 0
            ? entry.restTopMargin * _currentFontSize
            : _restTopMargin,
        rubies: entry.rubies,
        chapterIndexes: entry.chapterIndexes,
      );
    }

    if (_lines.length > _pages.last.line) {
      _pages.add(PageInfo(line: _lines.length));
    }
    if (_currentPageNo < 0) {
      _currentPageNo = 0;
    }

    _updateChapterList();
  }

  void _layoutPreparedBlock({
    required bool alignBottom,
    required LayoutTextBlock block,
    required double bottomMargin,
    required List<AstParagraphExtra> extras,
    required List<AstChapterIndex> chapterIndexes,
    required double firstTopMargin,
    required List<AstInlineInsert> inserts,
    required bool nonBreak,
    required double pageBlockSize,
    required double pageInlineSize,
    required int paragraphNo,
    required double restTopMargin,
    required List<AstRubySpan> rubies,
  }) {
    var initialTop = firstTopMargin;
    if (_forceIndent &&
        initialTop == _firstTopMargin &&
        block.rawtext.isNotEmpty &&
        !'　（〔［｛〈《「『【｟〘〖​‌⁠￼'.contains(charAt(block.rawtext, 0))) {
      initialTop += block.atom.first.getFontSize();
    }

    var availableHeight = pageBlockSize - initialTop - bottomMargin;
    if (availableHeight < _fontSize) {
      availableHeight = _fontSize;
      initialTop = math.max(pageBlockSize - bottomMargin - availableHeight, 0);
    }

    var line = block.createTextLine(null, availableHeight, true);
    if (line == null) {
      return;
    }

    line.y = alignBottom
        ? initialTop + availableHeight - line.textWidth
        : initialTop;

    _pushLine(line, pageInlineSize, nonBreak);
    line.pageIndex ??= _pages.length - 1;
    _updateCurrentPageForPosition(paragraphNo, block, line);

    var nextTop = restTopMargin;
    availableHeight = pageBlockSize - nextTop - bottomMargin;
    if (availableHeight < _fontSize) {
      availableHeight = _fontSize;
      nextTop = math.max(pageBlockSize - bottomMargin - availableHeight, 0);
    }

    while ((line = block.createTextLine(line, availableHeight, true)) != null) {
      line!.y = nextTop;
      _pushLine(line, pageInlineSize, false);
      line.pageIndex = _pages.length - 1;
      _updateCurrentPageForPosition(paragraphNo, block, line);
      availableHeight = pageBlockSize - nextTop - bottomMargin;
    }

    for (final chapter in chapterIndexes) {
      _indexes.add(
        _IndexEntry(
          endIndex: chapter.endIndex,
          kind: switch (chapter.kind) {
            AstChapterKind.large => _IndexKind.headingLarge,
            AstChapterKind.medium => _IndexKind.headingMedium,
            AstChapterKind.small => _IndexKind.headingSmall,
            AstChapterKind.anchor => _IndexKind.anchor,
          },
          paragraphNo: paragraphNo,
          startIndex: chapter.startIndex,
          anchorName: chapter.anchorName,
        ),
      );
    }
    _attachParagraphDecorations(block, inserts, rubies, extras, paragraphNo);
  }

  void _layoutPreparedTable(
    AstCompiledTableEntry entry, {
    required double pageBlockSize,
    required double pageInlineSize,
    required int paragraphNo,
  }) {
    final rendered = _tables[entry];
    if (rendered == null) {
      return;
    }

    final block = LayoutTextBlock(this)
      ..setText(
        '￼',
        _currentFontSize,
        _currentFontType,
        _currentFontBold,
        _currentFontItalic,
        _currentTextRotation,
      )
      ..userData = LayoutBlockUserData();
    if (block.atom.isEmpty) {
      return;
    }

    final atom = block.atom.first;
    atom
      ..picture = rendered.picture
      ..width = rendered.width
      ..height = rendered.height
      ..tracking = 0;

    _blocks.add(block);
    _layoutPreparedBlock(
      alignBottom: _alignBottom,
      block: block,
      bottomMargin: _bottomMargin,
      extras: const <AstParagraphExtra>[],
      firstTopMargin: _firstTopMargin,
      inserts: const <AstInlineInsert>[],
      nonBreak: false,
      pageBlockSize: pageBlockSize,
      pageInlineSize: pageInlineSize,
      paragraphNo: paragraphNo,
      restTopMargin: _restTopMargin,
      rubies: const <AstRubySpan>[],
      chapterIndexes: const <AstChapterIndex>[],
    );
  }

  void _resetParagraphState() {
    _currentFontType = 0;
    _currentFontBold = false;
    _currentFontItalic = false;
    _currentFontSize = _fontSize;
    _currentTextRotation = _currentState.startsWith('h') ? 'h' : 'v';
    _inCaption = false;
    _inYokogumi = false;
    _firstTopMargin = 0;
    _restTopMargin = 0;
    _bottomMargin = 0;
    _alignBottom = false;
    _frameDrawing = false;
    _quoteDrawing = false;
    _frameTop = 0;
    _frameBottom = 0;
  }

  void _handleAstCommandEntry(AstCommandEntry entry, double pageBlockSize) {
    final pageEmpty = _lines.length == _pages.last.line;
    switch (entry.kind) {
      case AstCommandKind.indentStart:
        _firstTopMargin = entry.indentLine * _currentFontSize;
        _restTopMargin =
            (entry.indentHanging ?? entry.indentLine) * _currentFontSize;
      case AstCommandKind.indentEnd:
        _firstTopMargin = 0;
        _restTopMargin = 0;
      case AstCommandKind.quoteStart:
        _quoteDrawing = true;
        _firstTopMargin = math.max(_firstTopMargin, _currentFontSize);
        _restTopMargin = math.max(_restTopMargin, _currentFontSize);
      case AstCommandKind.quoteEnd:
        _quoteDrawing = false;
        _firstTopMargin = 0;
        _restTopMargin = 0;
      case AstCommandKind.bottomAlignStart:
        _bottomMargin = entry.bottomAlignKind == AstBottomAlignKind.bottom
            ? 0
            : entry.bottomAlignOffset * _currentFontSize;
        _alignBottom = true;
      case AstCommandKind.bottomAlignEnd:
        _bottomMargin = 0;
        _alignBottom = false;
      case AstCommandKind.jizumeStart:
        final width = entry.jizumeWidth ?? 0;
        if (_alignBottom) {
          _firstTopMargin = math.max(
            pageBlockSize - _bottomMargin - width * _currentFontSize,
            0,
          );
          _restTopMargin = _firstTopMargin;
        } else {
          _bottomMargin = math.max(
            pageBlockSize - _firstTopMargin - width * _currentFontSize,
            0,
          );
        }
      case AstCommandKind.jizumeEnd:
        if (_alignBottom) {
          _firstTopMargin = 0;
          _restTopMargin = 0;
        } else {
          _bottomMargin = 0;
        }
      case AstCommandKind.boldStart:
        _currentFontType = 2;
      case AstCommandKind.boldEnd:
        _currentFontType = 0;
      case AstCommandKind.italicStart:
        _currentFontItalic = true;
      case AstCommandKind.italicEnd:
        _currentFontItalic = false;
      case AstCommandKind.captionStart:
        _inCaption = true;
      case AstCommandKind.captionEnd:
        _inCaption = false;
      case AstCommandKind.yokogumiStart:
        _inYokogumi = true;
        _currentTextRotation = 'h';
      case AstCommandKind.yokogumiEnd:
        _inYokogumi = false;
        _currentTextRotation = _currentState.startsWith('h') ? 'h' : 'v';
      case AstCommandKind.headingStart:
        _currentFontType = 2;
        _currentFontSize = switch (entry.headingLevel) {
          AstHeadingLevel.large => _fontSize * _fontScaleL * _fontScaleL,
          AstHeadingLevel.medium => _fontSize * _fontScaleL,
          _ => _fontSize,
        };
      case AstCommandKind.headingEnd:
        _currentFontSize = _fontSize;
        _currentFontType = 0;
      case AstCommandKind.fontScaleStart:
        final steps = entry.fontScaleSteps ?? 0;
        _currentFontSize =
            entry.fontScaleDirection == AstFontScaleDirection.larger
            ? _fontSize * math.pow(_fontScaleL, steps)
            : _fontSize * math.pow(_fontScaleS, steps);
      case AstCommandKind.fontScaleEnd:
        _currentFontSize = _fontSize;
      case AstCommandKind.frameStart:
        _frameDrawing = true;
        _frameTop = math.min(_firstTopMargin, _restTopMargin);
        _frameBottom = pageBlockSize - _bottomMargin;
        _firstTopMargin += _fontSize;
        _restTopMargin += _fontSize;
        _bottomMargin += _fontSize;
      case AstCommandKind.frameEnd:
        _firstTopMargin = math.max(_firstTopMargin - _fontSize, 0);
        _restTopMargin = math.max(_restTopMargin - _fontSize, 0);
        _bottomMargin = math.max(_bottomMargin - _fontSize, 0);
        _frameDrawing = false;
      case AstCommandKind.pageBreak:
        switch (entry.pageBreakKind) {
          case AstPageBreakKind.kaidan:
          case AstPageBreakKind.kaipage:
            if (!pageEmpty) {
              _pages.add(PageInfo(line: _lines.length));
            }
          case AstPageBreakKind.kaicho:
            if (_pages.length.isOdd) {
              _pages.add(PageInfo(line: _lines.length));
            } else if (!pageEmpty) {
              _pages.add(PageInfo(line: _lines.length));
              _pages.add(PageInfo(line: _lines.length));
            }
          case AstPageBreakKind.kaimihiraki:
            if (_pages.length.isEven) {
              _pages.add(PageInfo(line: _lines.length));
            } else if (!pageEmpty) {
              _pages.add(PageInfo(line: _lines.length));
              _pages.add(PageInfo(line: _lines.length));
            }
          case null:
            break;
        }
        _currentPageWidth = -_lineSpace;
      case AstCommandKind.pageCenter:
        if (pageEmpty) {
          _pages[_pages.length - 1] = PageInfo(
            line: _pages.last.line,
            centering: true,
          );
        } else {
          _pages.add(PageInfo(line: _lines.length, centering: true));
        }
        _currentPageWidth = -_lineSpace;
    }
  }

  void _pushLine(LayoutTextLine line, double pageInlineSize, bool nonBreak) {
    if (nonBreak && _lines.isNotEmpty) {
      final previous = _lines.last;
      final baseLine = previous.primary;
      if (line.y > baseLine.y + baseLine.textWidth) {
        previous.lines.add(line);
      } else {
        _lines.add(LineGroup(line));
        _currentPageWidth += line.width + _lineSpace;
      }
    } else {
      _lines.add(LineGroup(line));
      _currentPageWidth += line.width + _lineSpace;
    }

    if (_currentPageWidth > pageInlineSize) {
      _markLastPageAsFull();
      _pages.add(PageInfo(line: _lines.length - 1));
      _currentPageWidth = line.width;
    }
  }

  void _updateCurrentPageForPosition(
    int paragraphNo,
    LayoutTextBlock block,
    LayoutTextLine line,
  ) {
    if (_currentPageNo < 0 &&
        _currentPosition.paragraphNo == paragraphNo &&
        block.getAtomIndexAt(_currentPosition.offset) < line.end) {
      _currentPageNo = _internalToDocumentPageNo(_pages.length - 1);
      if (_currentState.endsWith('double')) {
        _currentPageNo &= ~1;
      }
    }
  }

  void _attachParagraphDecorations(
    LayoutTextBlock block,
    List<AstInlineInsert> inserts,
    List<AstRubySpan> rubies,
    List<AstParagraphExtra> extras,
    int paragraphNo,
  ) {
    for (final insert in inserts) {
      final line = block.getTextLineAtCharIndex(insert.startIndex);
      if (line == null || insert.tl == null) {
        continue;
      }
      final atomIndex = block.getAtomIndexAt(insert.startIndex);
      insert.tl!.y = line.y + line.getAtomY(atomIndex);
      line.attachments.add(
        InlineDecorationAttachment(kind: insert.type, line: insert.tl!),
      );
    }

    for (final ruby in rubies) {
      final initialLine = block.getTextLineAtCharIndex(ruby.startIndex);
      if (initialLine == null) {
        continue;
      }
      LayoutTextLine line = initialLine;

      final startAtom = block.getAtomIndexAt(ruby.startIndex);
      final startY =
          line.y + line.getAtomY(startAtom, includeTrailingTracking: true);
      final endAtom = block.getAtomIndexAt(ruby.endIndex);
      final endY = endAtom > line.end
          ? line.y + line.textWidth
          : line.y + line.getAtomY(endAtom);
      var segmentHeight =
          endY -
          startY -
          _inlineInsertExtentInRange(
            block,
            inserts,
            ruby.startIndex,
            math.min(ruby.endIndex, _lineEndOffset(block, line)),
          );
      final rubyBlock = ruby.tb!;
      var rubyLine = endAtom > line.end
          ? rubyBlock.createTextLine(null, segmentHeight + ruby.trackingStart)
          : rubyBlock.createTextLine();

      if (rubyLine == null) {
        continue;
      }

      rubyLine.attachments.clear();
      var offset = (rubyLine.textWidth - segmentHeight) / 2;
      rubyLine.y = startY - offset;

      if (offset > 0) {
        if (ruby.trackingStart == 0 && ruby.trackingEnd != 0) {
          rubyLine.y += math.max(
            line.y + line.getAtomY(startAtom) - rubyLine.y,
            math.max(line.rubyBottom[ruby.type] ?? 0, 0) - rubyLine.y,
          );
        } else if (ruby.trackingStart != 0 && ruby.trackingEnd == 0) {
          rubyLine.y = line.y + line.getAtomY(startAtom) - ruby.trackingStart;
        }
      }

      line.attachments.add(
        InlineDecorationAttachment(kind: ruby.type, line: rubyLine),
      );
      line.rubyBottom[ruby.type] = math.max(
        line.rubyBottom[ruby.type] ?? 0,
        rubyLine.y + rubyLine.textWidth,
      );

      while (endAtom > line.end) {
        final nextLine = line.nextLine;
        if (nextLine == null) {
          break;
        }
        line = nextLine;

        segmentHeight = endAtom > line.end
            ? line.textWidth
            : line.getAtomY(endAtom);
        segmentHeight -= _inlineInsertExtentInRange(
          block,
          inserts,
          line.start < block.atom.length
              ? block.atom[line.start].index
              : block.rawtext.length,
          math.min(ruby.endIndex, _lineEndOffset(block, line)),
        );
        rubyLine = endAtom > line.end
            ? rubyBlock.createTextLine(rubyLine, segmentHeight)
            : rubyBlock.createTextLine(rubyLine);
        if (rubyLine == null) {
          break;
        }

        rubyLine.attachments.clear();
        offset = (rubyLine.textWidth - segmentHeight) / 2;
        rubyLine.y = line.y - offset;
        line.attachments.add(
          InlineDecorationAttachment(kind: ruby.type, line: rubyLine),
        );
        line.rubyBottom[ruby.type] = math.max(
          line.rubyBottom[ruby.type] ?? 0,
          rubyLine.y + rubyLine.textWidth,
        );
      }
    }

    for (final extra in extras) {
      if (extra.kind == AstParagraphExtraKind.warichu) {
        _attachWarichu(block, extra);
      } else if (extra.kind == AstParagraphExtraKind.noteReference) {
        final startIndex = extra.startIndex ?? 0;
        final line = block.getTextLineAtCharIndex(startIndex);
        if (line == null) {
          continue;
        }

        final markerBlock = LayoutTextBlock(this)
          ..setText(
            '＊',
            _fontSize / 2,
            0,
            false,
            false,
            _currentState.startsWith('h') ? 'h' : 'v',
          );
        final markerLine = markerBlock.createTextLine()!;
        final atomIndex = block.getAtomIndexAt(startIndex);
        markerLine.color = const Color(0xff008800);
        markerLine.attachments.clear();
        markerLine.y =
            line.y +
            line.getAtomY(atomIndex) +
            block.getAtomHeight(atomIndex) -
            0.4 * line.width;
        line.attachments.add(
          InlineDecorationAttachment(
            kind: LayoutInlineDecorationKind.referenceNote,
            line: markerLine,
          ),
        );
        line.attachments.add(
          NoteMarker(
            annotation: extra.noteText ?? '',
            height: markerLine.textWidth,
            kind: LayoutNoteMarkerKind.reference,
            markType: '※',
            top: markerLine.y,
            width: markerLine.width,
          ),
        );
      } else if (extra.kind == AstParagraphExtraKind.span ||
          extra.kind == AstParagraphExtraKind.ruledLine ||
          extra.kind == AstParagraphExtraKind.link) {
        final startIndex = extra.startIndex ?? 0;
        final endIndex = (extra.endIndex ?? 1) - 1;
        var startLine = block.getTextLineAtCharIndex(startIndex);
        final endLine = block.getTextLineAtCharIndex(math.max(endIndex, 0));
        if (startLine == null || endLine == null) {
          continue;
        }

        final startAtom = block.getAtomIndexAt(startIndex);
        var top =
            startLine.y +
            startLine.getAtomY(
              startAtom,
              includeTrailingTracking:
                  extra.kind == AstParagraphExtraKind.ruledLine,
            );
        final endAtom = block.getAtomIndexAt(endIndex);
        final bottom =
            endLine.y +
            endLine.getAtomY(
              endAtom,
              includeTrailingTracking:
                  extra.kind == AstParagraphExtraKind.ruledLine,
            ) +
            block.getAtomHeight(endAtom);

        if (extra.kind == AstParagraphExtraKind.link) {
          final linkColor = (extra.linkTarget?.startsWith('#') ?? false)
              ? theme.internalLinkColor
              : theme.linkColor;
          for (var index = startAtom; index <= endAtom; index += 1) {
            block.atom[index].color = linkColor;
          }
          final linkEnd = block.getAtomIndexAt(extra.endIndex ?? 0);
          LayoutTextLine? currentLine = startLine;
          var currentStart = startAtom;
          while (currentLine != null) {
            currentLine.attachments.add(
              LinkMarker(
                endAtom: math.min(linkEnd, currentLine.end),
                startAtom: currentStart,
                linkTarget: extra.linkTarget ?? '',
              ),
            );
            if (linkEnd <= currentLine.end) {
              break;
            }
            currentLine = currentLine.nextLine;
            currentStart = currentLine?.start ?? 0;
          }
          continue;
        }

        LayoutTextLine? currentLine = startLine;
        var isStart = true;
        while (currentLine != null && !identical(currentLine, endLine)) {
          currentLine.attachments.add(
            SpanMarker(
              bottom: currentLine.y + currentLine.textWidth,
              kind: _spanMarkerKind(extra),
              isEnd: false,
              isStart: isStart,
              markType: '',
              top: top,
            ),
          );
          isStart = false;
          currentLine = currentLine.nextLine;
          top = currentLine?.y ?? 0;
        }

        currentLine?.attachments.add(
          SpanMarker(
            bottom: bottom,
            kind: _spanMarkerKind(extra),
            isEnd: true,
            isStart: isStart,
            markType: '',
            top: top,
          ),
        );
      } else if (extra.kind == AstParagraphExtraKind.frame) {
        var line = block.textLine;
        while (line != null) {
          line.attachments.add(
            SpanMarker(
              bottom: _frameBottom,
              kind: _spanMarkerKind(extra),
              markType: '',
              top: _frameTop,
            ),
          );
          line = line.nextLine;
        }
      } else if (extra.kind == AstParagraphExtraKind.emphasis) {
        final emphasisChar = switch (extra.emphasisKind) {
          AstEmphasisKind.whiteSesame => '﹆',
          AstEmphasisKind.blackCircle => '⬤',
          AstEmphasisKind.whiteCircle => '○',
          AstEmphasisKind.blackTriangle => '▲',
          AstEmphasisKind.whiteTriangle => '△',
          AstEmphasisKind.bullseye => '◎',
          AstEmphasisKind.fisheye => '◉',
          AstEmphasisKind.saltire => '❌',
          _ => '﹅',
        };
        final size =
            ((emphasisChar != '﹅' && emphasisChar != '﹆') ||
                _settings.smallBouten)
            ? 0.48 * _fontSize
            : _fontSize;

        for (
          var index = extra.startIndex ?? 0;
          index < (extra.endIndex ?? 0);
          index += 1
        ) {
          final line = block.getTextLineAtCharIndex(index);
          if (line == null) {
            continue;
          }
          final markerBlock = LayoutTextBlock(this)
            ..setText(
              emphasisChar,
              size,
              0,
              false,
              false,
              _currentState.startsWith('h') ? 'h' : 'v',
            );
          final markerLine = markerBlock.createTextLine()!;
          final atomIndex = block.getAtomIndexAt(index);
          markerLine.attachments.clear();
          markerLine.y =
              line.y +
              line.getAtomY(atomIndex) +
              (block.getAtomHeight(atomIndex) - markerLine.textWidth) / 2;
          line.attachments.add(
            InlineDecorationAttachment(
              kind: (extra.rightSide ?? true)
                  ? LayoutInlineDecorationKind.rightEmphasis
                  : LayoutInlineDecorationKind.leftEmphasis,
              line: markerLine,
            ),
          );
        }
      } else if (extra.kind == AstParagraphExtraKind.note) {
        final endIndex = (extra.endIndex ?? 0) - 1;
        final line = block.getTextLineAtCharIndex(endIndex < 0 ? 0 : endIndex);
        if (line == null) {
          continue;
        }

        final markerBlock = LayoutTextBlock(this)
          ..setText(
            '＊',
            _fontSize / 2,
            0,
            false,
            false,
            _currentState.startsWith('h') ? 'h' : 'v',
          );
        final markerLine = markerBlock.createTextLine()!;
        markerLine.color = const Color(0xffff0000);
        markerLine.attachments.clear();

        if (endIndex >= 0) {
          final atomIndex = block.getAtomIndexAt(endIndex);
          markerLine.y =
              line.y +
              line.getAtomY(atomIndex) +
              block.getAtomHeight(atomIndex) -
              0.4 * line.width;
        } else {
          markerLine.y = line.y - 0.4 * line.width;
        }

        line.attachments.add(
          InlineDecorationAttachment(
            kind: LayoutInlineDecorationKind.annotationNote,
            line: markerLine,
          ),
        );
        line.attachments.add(
          NoteMarker(
            annotation: extra.noteText ?? '',
            height: markerLine.textWidth,
            kind: LayoutNoteMarkerKind.annotation,
            markType: '注',
            top: markerLine.y,
            width: markerLine.width,
          ),
        );
      } else if (extra.kind == AstParagraphExtraKind.quote) {
        var line = block.textLine;
        while (line != null) {
          line.attachments.add(const QuoteMarker());
          line = line.nextLine;
        }
      }
    }
  }

  void _insertImage(
    LayoutTextBlock block,
    int offset,
    String path,
    double width,
    double height,
  ) {
    final image = _images[path];
    if (image == null) {
      return;
    }

    var imageWidth = width;
    var imageHeight = height;

    if (imageWidth <= 0 && imageHeight <= 0) {
      imageWidth = image.width.toDouble();
      imageHeight = image.height.toDouble();
    } else if (imageWidth <= 0) {
      imageWidth = (imageHeight * image.width) / image.height;
    } else {
      imageHeight = (imageWidth * image.height) / image.width;
    }

    final fittedWidth = math.min(
      math.min((imageWidth * _pageHeight) / imageHeight, imageWidth),
      _pageWidth,
    );
    final fittedHeight = math.min(
      math.min((imageHeight * _pageWidth) / imageWidth, imageHeight),
      _pageHeight,
    );
    final atomIndex = block.getAtomIndexAt(offset);
    if (atomIndex >= block.atom.length) {
      return;
    }

    final atom = block.atom[atomIndex];
    if (_currentState.startsWith('v')) {
      atom.width = fittedWidth.floorToDouble();
      atom.height = fittedHeight.floorToDouble();
    } else {
      atom.width = fittedHeight.floorToDouble();
      atom.height = fittedWidth.floorToDouble();
    }
    atom.image = image;
  }

  void _insertTextLine(LayoutTextBlock block, List<AstInlineInsert> inserts) {
    for (final insert in inserts) {
      final atomIndex = block.splitAtom(insert.startIndex);
      block.splitAtom(insert.startIndex + 1);
      if (atomIndex >= block.atom.length) {
        continue;
      }
      final atom = block.atom[atomIndex];
      final fontSize = atom.getFontSize();
      final markerBlock = LayoutTextBlock(this)
        ..setText(
          insert.text,
          fontSize / 2,
          0,
          false,
          false,
          _currentState.startsWith('h') ? 'h' : 'v',
        );
      if (insert.type == LayoutInlineDecorationKind.kaeri) {
        if (insert.text == '一レ') {
          markerBlock.splitAtom(1);
          markerBlock.atom[1].tracking = -0.27 * fontSize;
        } else if (charAt(insert.text, 1) == 'レ') {
          markerBlock.atom[0].tracking = -0.1 * fontSize;
        }
      }
      final markerLine = markerBlock.createTextLine()!;
      markerLine.attachments.clear();
      insert.tl = markerLine;
      if (block.getAtomHeight(atomIndex, includeTracking: true) <
          markerLine.textWidth) {
        atom.tracking = markerLine.textWidth;
      }
    }
  }

  void _applyStyle(
    LayoutTextBlock block,
    int startIndex,
    int endIndex,
    AstStyleSpan style,
  ) {
    if (endIndex <= math.max(startIndex, 0)) {
      return;
    }

    final start = block.splitAtom(startIndex < 0 ? 0 : startIndex);
    final end = block.splitAtom(endIndex);
    final atoms = block.atom;

    switch (style.kind) {
      case AstStyleKind.headingLarge:
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(_fontSize * _fontScaleL * _fontScaleL)
            ..setFontGothic();
        }
      case AstStyleKind.headingMedium:
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(_fontSize * _fontScaleL)
            ..setFontGothic();
        }
      case AstStyleKind.headingSmall:
      case AstStyleKind.bold:
        for (var index = start; index < end; index += 1) {
          atoms[index].setFontGothic();
        }
      case AstStyleKind.italic:
        for (var index = start; index < end; index += 1) {
          atoms[index].setFontItalic();
        }
      case AstStyleKind.textColor:
        final colorValue = style.colorValue;
        if (colorValue == null) {
          return;
        }
        final color = Color(colorValue);
        for (var index = start; index < end; index += 1) {
          atoms[index].color = color;
        }
      case AstStyleKind.caption:
        for (var index = start; index < end; index += 1) {
          atoms[index].color = theme.captionColor;
        }
      case AstStyleKind.yokogumi:
        for (var index = start; index < end; index += 1) {
          atoms[index].setRotated();
        }
      case AstStyleKind.kaeri:
        for (var index = start; index < end; index += 1) {
          atoms[index].offsetX = -atoms[index].getFontSize() / 8;
        }
      case AstStyleKind.okuri:
        for (var index = start; index < end; index += 1) {
          atoms[index].offsetX = atoms[index].getFontSize() / 8;
        }
      case AstStyleKind.lineRightSmall:
      case AstStyleKind.superscript:
        final size = 0.6 * _currentFontSize;
        final offset = 0.2 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(size)
            ..offsetX = offset;
        }
      case AstStyleKind.lineLeftSmall:
      case AstStyleKind.subscript:
        final size = 0.6 * _currentFontSize;
        final offset = -0.2 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(size)
            ..offsetX = offset;
        }
      case AstStyleKind.warichuPlaceholder:
        final size = 0.5 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(size)
            ..color = const Color(0x00000000);
        }
      case AstStyleKind.warichuBracket:
        final advance = 0.5 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          final text = block.getAtomText(index);
          atoms[index]
            ..height = advance
            ..offsetY = openingBrackets.contains(text) ? -advance : 0;
        }
      case AstStyleKind.fontScale:
        var value = style.fontScaleSteps ?? 0;
        if (value > 5) {
          value = 5;
        }
        final size = style.fontScaleDirection == AstFontScaleDirection.larger
            ? _fontSize * math.pow(_fontScaleL, value)
            : _fontSize * math.pow(_fontScaleS, value);
        for (var index = start; index < end; index += 1) {
          atoms[index].setFontSize(size.toDouble());
        }
    }
  }

  void _adjustRubies(
    LayoutTextBlock block,
    List<AstRubySpan> rubies,
    List<AstInlineInsert> inserts,
  ) {
    final line = block.createTextLine();
    if (line == null) {
      return;
    }

    for (final ruby in rubies) {
      final start = block.splitAtom(ruby.startIndex);
      final end = block.splitAtom(ruby.endIndex);
      final startY = line.getAtomY(start, includeTrailingTracking: true);
      final insertCount = _inlineInsertCountInRange(
        inserts,
        ruby.startIndex,
        ruby.endIndex,
      );
      final segmentHeight =
          line.getAtomY(end) -
          startY -
          _inlineInsertExtentInRange(
            block,
            inserts,
            ruby.startIndex,
            ruby.endIndex,
          );
      final rubyBlock = LayoutTextBlock(this)
        ..setText(
          ruby.ruby,
          _fontSize / 2,
          0,
          false,
          false,
          _currentState.startsWith('h') ? 'h' : 'v',
        );
      for (final span in ruby.spans) {
        _applyStyle(rubyBlock, span.startIndex, span.endIndex, span);
      }
      ruby
        ..tb = rubyBlock
        ..trackingStart = 0
        ..trackingEnd = 0;

      var overflow = rubyBlock.createTextLine()!.textWidth - segmentHeight;
      if (overflow > 0) {
        var startPadding = 0.0;
        var endPadding = 0.0;

        if (start > 0) {
          final overlapsStart = rubies.any(
            (candidate) =>
                candidate.type == ruby.type &&
                candidate.startIndex < ruby.startIndex &&
                candidate.endIndex >= ruby.startIndex,
          );
          final previousText = block.getAtomText(start - 1);
          if (!overlapsStart &&
              !_cjkIdeographPattern.hasMatch(
                charAt(previousText, previousText.length - 1),
              )) {
            startPadding = _fontSize / 2;
          }
        }

        final overlapsEnd = rubies.any(
          (candidate) =>
              candidate.type == ruby.type &&
              candidate.startIndex <= ruby.endIndex &&
              candidate.endIndex > ruby.endIndex,
        );
        if (!overlapsEnd && end < block.atom.length) {
          final nextText = block.getAtomText(end);
          if (!_cjkIdeographPattern.hasMatch(charAt(nextText, 0))) {
            endPadding = _fontSize / 2;
          }
        }

        overflow -= startPadding + endPadding;
        if (overflow > 0) {
          final visibleAtomCount = math.max(end - start + 1 - insertCount, 1);
          final tracking = overflow / visibleAtomCount;
          for (
            var index = math.min(end, block.atom.length - 1);
            index >= start;
            index -= 1
          ) {
            block.atom[index].tracking += tracking;
          }
        }

        ruby
          ..trackingStart = startPadding
          ..trackingEnd = endPadding;
      } else if (overflow + _fontSize / 2 < 0 && ruby.tb!.atom.length > 1) {
        final tracking =
            -(overflow + _fontSize / 2) / (ruby.tb!.atom.length - 1);
        for (var index = ruby.tb!.atom.length - 1; index > 0; index -= 1) {
          ruby.tb!.atom[index].tracking = tracking;
        }
      }
    }
  }

  void _attachWarichu(LayoutTextBlock block, AstParagraphExtra extra) {
    final body = extra.warichuText ?? '';
    final rows = splitWarichuText(body);
    final startIndex = extra.startIndex ?? 0;
    final endIndex = extra.endIndex ?? startIndex;
    final innerStart = startIndex + 1;
    final innerEnd = math.max(innerStart, endIndex - 1);
    if ((rows.upper.isEmpty && rows.lower.isEmpty) || innerEnd <= innerStart) {
      return;
    }

    var upperConsumed = 0;
    var lowerConsumed = 0;
    var line = block.getTextLineAtCharIndex(innerStart);
    while (line != null &&
        (upperConsumed < rows.upper.length ||
            lowerConsumed < rows.lower.length)) {
      final lineStartOffset = block.atom[line.start].index;
      final lineEndOffset = _lineEndOffset(block, line);
      final segmentStart = math.max(innerStart, lineStartOffset);
      final segmentEnd = math.min(innerEnd, lineEndOffset);

      if (segmentEnd > segmentStart) {
        final segmentUnits = segmentEnd - segmentStart;
        final upperEnd = math.min(
          rows.upper.length,
          upperConsumed + segmentUnits,
        );
        final lowerEnd = math.min(
          rows.lower.length,
          lowerConsumed + segmentUnits,
        );
        final upperText = rows.upper.substring(upperConsumed, upperEnd);
        final lowerText = rows.lower.substring(lowerConsumed, lowerEnd);
        upperConsumed = upperEnd;
        lowerConsumed = lowerEnd;

        final upperLine = _buildWarichuLine(
          upperText,
          segmentUnits * _currentFontSize / 2,
        );
        final lowerLine = _buildWarichuLine(
          lowerText,
          segmentUnits * _currentFontSize / 2,
        );

        final startAtom = block.getAtomIndexAt(segmentStart);
        final endAtom = block.getAtomIndexAt(segmentEnd);
        final segmentTop = line.y + line.getAtomY(startAtom);
        final segmentBottom = line.y + line.getAtomY(endAtom);
        final segmentExtent = segmentBottom - segmentTop;

        if (upperLine != null) {
          upperLine.y =
              segmentTop + _warichuRowOffset(upperLine, segmentExtent);
        }
        if (lowerLine != null) {
          lowerLine.y =
              segmentTop + _warichuRowOffset(lowerLine, segmentExtent);
        }

        line.attachments.add(
          WarichuMarker(lowerLine: lowerLine, upperLine: upperLine),
        );
      }

      if (segmentEnd >= innerEnd) {
        break;
      }
      line = line.nextLine;
    }
  }

  LayoutTextLine? _buildWarichuLine(String text, double extent) {
    if (text.isEmpty) {
      return null;
    }

    final block = LayoutTextBlock(this)
      ..setText(
        text,
        _currentFontSize / 2,
        _currentFontType,
        _currentFontBold,
        _currentFontItalic,
        _currentTextRotation,
      );
    var line = block.createTextLine();
    if (line == null) {
      return null;
    }

    if (block.atom.length > 1) {
      final tracking = (extent - line.textWidth) / (block.atom.length - 1);
      if (tracking != 0) {
        for (var index = block.atom.length - 1; index > 0; index -= 1) {
          block.atom[index].tracking = tracking;
        }
        line = block.createTextLine();
      }
    }

    return line;
  }

  int _lineEndOffset(LayoutTextBlock block, LayoutTextLine line) {
    return line.end < block.atom.length
        ? block.atom[line.end].index
        : block.rawtext.length;
  }

  int _inlineInsertCountInRange(
    List<AstInlineInsert> inserts,
    int startOffset,
    int endOffset,
  ) {
    return inserts
        .where(
          (insert) =>
              insert.startIndex >= startOffset && insert.startIndex < endOffset,
        )
        .length;
  }

  double _inlineInsertExtentInRange(
    LayoutTextBlock block,
    List<AstInlineInsert> inserts,
    int startOffset,
    int endOffset,
  ) {
    var extent = 0.0;
    for (final insert in inserts) {
      if (insert.startIndex < startOffset || insert.startIndex >= endOffset) {
        continue;
      }
      final atomIndex = block.getAtomIndexAt(insert.startIndex);
      extent += block.getAtomHeight(atomIndex, includeTracking: true);
    }
    return extent;
  }

  LayoutSpanMarkerKind _spanMarkerKind(AstParagraphExtra extra) {
    if (extra.kind == AstParagraphExtraKind.frame) {
      return switch (extra.frameKind) {
        AstFrameKind.start => LayoutSpanMarkerKind.frameStart,
        AstFrameKind.end => LayoutSpanMarkerKind.frameEnd,
        _ => LayoutSpanMarkerKind.frameMiddle,
      };
    }
    if (extra.ruledLineKind == AstRuledLineKind.frameBox) {
      return LayoutSpanMarkerKind.frameBox;
    }
    if (extra.ruledLineKind == AstRuledLineKind.cancel) {
      return LayoutSpanMarkerKind.cancel;
    }
    final right = extra.rightSide ?? true;
    return switch ((right, extra.ruledLineKind)) {
      (true, AstRuledLineKind.doubleLine) => LayoutSpanMarkerKind.rightDouble,
      (true, AstRuledLineKind.chain) => LayoutSpanMarkerKind.rightChain,
      (true, AstRuledLineKind.dashed) => LayoutSpanMarkerKind.rightDashed,
      (true, AstRuledLineKind.wave) => LayoutSpanMarkerKind.rightWave,
      (true, _) => LayoutSpanMarkerKind.rightSolid,
      (false, AstRuledLineKind.doubleLine) => LayoutSpanMarkerKind.leftDouble,
      (false, AstRuledLineKind.chain) => LayoutSpanMarkerKind.leftChain,
      (false, AstRuledLineKind.dashed) => LayoutSpanMarkerKind.leftDashed,
      (false, AstRuledLineKind.wave) => LayoutSpanMarkerKind.leftWave,
      (false, _) => LayoutSpanMarkerKind.leftSolid,
    };
  }

  double _warichuRowOffset(LayoutTextLine line, double segmentExtent) {
    final slack = segmentExtent - line.textWidth;
    return slack > 0 ? slack / 2 : 0;
  }

  void _updateChapterList() {
    _chapterList
      ..clear()
      ..add(ChapterEntry(label: '巻頭', pageNo: 0));
    _anchorList.clear();

    for (final index in _indexes) {
      final block = index.paragraphNo < _blocks.length
          ? _blocks[index.paragraphNo]
          : null;
      final line = block?.getTextLineAtCharIndex(index.startIndex);
      if (block == null || line == null) {
        continue;
      }
      final pageIndex = line.pageIndex;
      if (pageIndex == null) {
        continue;
      }
      final pageNo = _internalToDocumentPageNo(pageIndex);
      if (index.kind == _IndexKind.anchor) {
        _anchorList['#${index.anchorName ?? ''}'] = pageNo;
      } else {
        var label = block.rawtext.substring(index.startIndex, index.endIndex);
        if (index.kind == _IndexKind.headingMedium) {
          label = '　$label';
        } else if (index.kind == _IndexKind.headingSmall) {
          label = '　　$label';
        }
        _chapterList.add(ChapterEntry(label: label, pageNo: pageNo));
      }
    }

    _chapterList.add(ChapterEntry(label: '巻末', pageNo: -2));
  }

  void _showPage(int pageNo) {
    if (pageNo < 0) {
      pageNo = _currentPageNo;
    }
    if (pageNo < 0) {
      pageNo = _lastDocumentPage;
    }
    if (pageNo < 0) {
      return;
    }

    final last = _lastDocumentPage;
    if (pageNo > last) {
      pageNo = last;
    }

    _currentPageNo = pageNo;
    _clickable = <ClickableArea>[];
    _selectableGlyphs = <KumihanSelectableGlyph>[];
    _selectableGlyphOrder = 0;
    onSnapshot(snapshot);
    onInvalidate();
  }

  void paint(ui.Canvas canvas) {
    if (_width <= 0 || _height <= 0 || _pageWidth <= 0 || _pageHeight <= 0) {
      return;
    }
    if (snapshot.totalPages <= 0) {
      _drawPaperSurface(canvas, Rect.fromLTWH(0, 0, _width, _height));
      return;
    }

    resetPaintState();
    _drawPaperSurface(canvas, Rect.fromLTWH(0, 0, _width, _height));

    final pageNo = _currentPageNo < 0 ? 0 : _currentPageNo;
    if (pageNo <= _lastDocumentPage) {
      paintPage(
        canvas,
        pageNo,
        PagePaintContext(contentRect: Rect.fromLTWH(0, 0, _width, _height)),
      );
    }
  }

  void resetPaintState() {
    _clickable = <ClickableArea>[];
    _selectableGlyphs = <KumihanSelectableGlyph>[];
    _selectableGlyphOrder = 0;
  }

  void paintPage(ui.Canvas canvas, int pageNo, PagePaintContext context) {
    if (_width <= 0 || _height <= 0 || _pageWidth <= 0 || _pageHeight <= 0) {
      return;
    }
    if (snapshot.totalPages <= 0 ||
        pageNo < 0 ||
        pageNo >= snapshot.totalPages) {
      return;
    }

    _paintDocumentPage(canvas, _documentToInternalPageNo(pageNo), context);
  }

  void _drawPaperSurface(ui.Canvas canvas, Rect rect) {
    canvas.drawRect(rect, Paint()..color = paperColor);
  }

  void _drawWavyLine(
    ui.Canvas canvas,
    Paint paint,
    double x,
    double top,
    double bottom,
  ) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(x - 100, top, x + 100, bottom));
    final path = Path()..moveTo(x, top);
    const wave = 3.0;
    var count = 0;
    for (
      var position = top;
      position < bottom;
      position += 2 * wave, count += 1
    ) {
      if (count.isOdd) {
        path.quadraticBezierTo(
          x - wave,
          position + wave,
          x,
          position + 2 * wave,
        );
      } else {
        path.quadraticBezierTo(
          x + wave,
          position + wave,
          x,
          position + 2 * wave,
        );
      }
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  void _drawWavyLineYoko(
    ui.Canvas canvas,
    Paint paint,
    double y,
    double left,
    double right,
  ) {
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(left, y - 100, right, y + 100));
    final path = Path()..moveTo(left, y);
    const wave = 3.0;
    var count = 0;
    for (
      var position = left;
      position < right;
      position += 2 * wave, count += 1
    ) {
      if (count.isOdd) {
        path.quadraticBezierTo(
          position + wave,
          y - wave,
          position + 2 * wave,
          y,
        );
      } else {
        path.quadraticBezierTo(
          position + wave,
          y + wave,
          position + 2 * wave,
          y,
        );
      }
    }
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  List<int> _getStopList() {
    final stops = <int>[_lastPageNo];
    for (final chapter in _chapterList) {
      stops.add(chapter.pageNo);
    }
    stops.sort();
    return stops;
  }

  PositionInfo _getPositionInfo([bool leftPage = false]) {
    var pageNo = _currentPageNo;
    if (_currentPageNo >= 0 && pageNo >= 0) {
      final internalPageNo = _documentToInternalPageNo(pageNo);
      if (internalPageNo < 0 || internalPageNo >= _pages.length) {
        return _currentPosition;
      }
      var lineIndex = _pages[internalPageNo].line;
      if (lineIndex >= _lines.length) {
        lineIndex = _lines.length - 1;
      }
      final line = _lines[lineIndex].primary;
      return PositionInfo(
        leftToRight: false,
        length: 0,
        offset: line.block.atom[line.start].index,
        paragraphNo: _blocks.indexOf(line.block),
        shift1page: _shift1page,
      );
    }
    return _currentPosition;
  }
}
