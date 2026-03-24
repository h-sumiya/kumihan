import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../kumihan_controller.dart';
import '../kumihan_document.dart';
import '../kumihan_tap.dart';
import '../kumihan_theme.dart';
import '../kumihan_types.dart';
import 'constants.dart';
import 'document_compiler.dart';
import 'generated/gaiji_table.dart';
import 'helpers.dart';
import 'layout_primitives.dart';
import 'table_renderer.dart';

final RegExp _cjkIdeographPattern = RegExp('[⺀-⻳㐁-䶮一-龻豈-龎仝々〆〇ヶ]');
final RegExp _imageAnnotationPattern = RegExp(
  r'［＃([^［]*?)（([^（、]*?)(、横([0-9]+)×縦([0-9]+)|)）入る］',
);
final RegExp _engineImageAnnotationPattern = RegExp(
  r'￹[外画]￺([^\t￻]+)\t([^\t￻]*)\t([^\t￻]*)￻',
);
const String _warichuPlaceholder = '　';

int _findEndBracket(String text, int position) {
  var index = position;
  while (index < text.length) {
    final character = charAt(text, index);
    if (character == '「') {
      index = _findEndBracket(text, index + 1);
      if (index < 0) {
        break;
      }
    } else if (character == '」') {
      return index;
    }
    index += 1;
  }
  return -1;
}

int _skipLastAnnotation(String text, int position) {
  var index = position;
  while (index >= 0 && charAt(text, index) == '￻') {
    index = text.lastIndexOf('￹', index) - 1;
  }
  return index;
}

String _jointTargetString(String text, String target) {
  var end = _skipLastAnnotation(text, text.length - 1);
  var start = 0;
  var targetIndex = 0;

  while (end >= target.length - 1) {
    var candidate = end;
    targetIndex = target.length - 1;

    while (candidate >= 0 && targetIndex >= 0) {
      candidate = _skipLastAnnotation(text, candidate);
      if (charAt(text, candidate) != charAt(target, targetIndex)) {
        break;
      }
      candidate -= 1;
      targetIndex -= 1;
    }

    if (targetIndex < 0) {
      start = candidate + 1;
      break;
    }

    end = _skipLastAnnotation(text, end - 1);
  }

  if (targetIndex < 0) {
    var adjustedStart = start;
    var adjustedEnd = end;
    var code = text.codeUnitAt(adjustedStart);

    if (code >= 0xd800 && code <= 0xdbff) {
      adjustedStart += 1;
    }
    adjustedStart += 1;

    code = text.codeUnitAt(adjustedEnd);
    if (code >= 0xdc00 && code <= 0xdfff) {
      adjustedEnd -= 1;
    }

    if (adjustedStart < adjustedEnd) {
      return '${text.substring(0, adjustedStart)}⁠${text.substring(adjustedStart, adjustedEnd)}⁠${text.substring(adjustedEnd)}';
    }
    if (adjustedStart == adjustedEnd) {
      return '${text.substring(0, adjustedStart)}⁠${text.substring(adjustedEnd)}';
    }
  }

  return text;
}

class IndexEntry {
  IndexEntry({
    required this.endIndex,
    required this.paragraphNo,
    required this.startIndex,
    required this.type,
  });

  final int endIndex;
  final int paragraphNo;
  final int startIndex;
  final String type;
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
  PageInfo({this.line = 0, this.centering = false});

  final int line;
  final bool centering;
}

class ParagraphMargins {
  ParagraphMargins({
    required this.alignBottom,
    required this.bottomMargin,
    required this.firstTopMargin,
    required this.restTopMargin,
  });

  bool alignBottom;
  double bottomMargin;
  double firstTopMargin;
  double restTopMargin;
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
    this.backPageAlpha = 0.08,
    this.fontSize = 18,
    this.rubyColor = fontColor,
    this.smallBouten = true,
    this.widenLineSpace = false,
  });

  final double backPageAlpha;
  final double fontSize;
  final Color rubyColor;
  final bool smallBouten;
  final bool widenLineSpace;
}

typedef KumihanImageLoader = Future<ui.Image?> Function(String path);

class KumihanEngine implements LayoutEnvironment, KumihanViewport {
  KumihanEngine({
    required this.baseUri,
    ui.Image? coverImage,
    required int initialPage,
    required KumihanSpreadMode initialSpread,
    required KumihanWritingMode initialWritingMode,
    this.layout = const KumihanLayoutData(),
    this.theme = const KumihanThemeData(),
    ui.Image? paperTexture,
    required this.onExternalOpen,
    this.onUnhandledTap,
    this.tapHandler = KumihanTapHandlers.pageTurnByHorizontalPosition,
    required this.onInvalidate,
    required this.onSnapshot,
    this.imageLoader,
  }) : _currentState =
           '${initialWritingMode == KumihanWritingMode.horizontal ? 'h' : 'v'}${initialSpread == KumihanSpreadMode.single ? 'single' : 'double'}',
       _currentTextRotation =
           initialWritingMode == KumihanWritingMode.horizontal ? 'h' : 'v',
       _coverImage = coverImage,
       _initialPage = initialPage,
       _currentPosition = PositionInfo(
         leftToRight: initialWritingMode == KumihanWritingMode.horizontal,
         length: 0,
         offset: 0,
         paragraphNo: 0,
         shift1page: false,
       ) {
    _applyTheme(theme, paperTexture: paperTexture);
    _updateSizes();
  }

  final Uri? baseUri;
  ValueChanged<String>? onExternalOpen;
  ValueChanged<KumihanTapDetails>? onUnhandledTap;
  KumihanTapHandler tapHandler;
  final VoidCallback onInvalidate;
  final ValueChanged<KumihanSnapshot> onSnapshot;
  final KumihanImageLoader? imageLoader;
  final int _initialPage;
  KumihanLayoutData layout;
  final KumihanThemeData theme;
  final RendererSettings _settings = const RendererSettings();
  late final KumihanTapActions _tapActions = KumihanTapActions(this);

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

  String _headerTitle = '';
  KumihanCoverBlock? _cover;
  ui.Image? _coverImage;
  ui.Image? _paperTexture;
  late KumihanThemeData _theme;
  List<CompiledKumihanEntry> _entries = const <CompiledKumihanEntry>[];
  String _sourceText = '';
  int _layoutToken = 0;
  String _currentState;
  bool _shift1page = false;
  bool _forceIndent = false;
  PositionInfo _currentPosition;
  final List<LayoutTextBlock> _blocks = <LayoutTextBlock>[];
  final List<LineGroup> _lines = <LineGroup>[];
  final List<PageInfo> _pages = <PageInfo>[PageInfo(), PageInfo()];
  final List<IndexEntry> _indexes = <IndexEntry>[];
  final List<ChapterEntry> _chapterList = <ChapterEntry>[];
  final Map<String, int> _anchorList = <String, int>{};
  final List<String> _links = <String>[];
  final Map<String, ui.Image?> _images = <String, ui.Image?>{};
  final Map<String, Future<ui.Image?>> _imageTasks =
      <String, Future<ui.Image?>>{};
  final Map<int, RenderedTableBlock> _renderedTables =
      <int, RenderedTableBlock>{};
  List<ClickableArea> _clickable = <ClickableArea>[];

  double _width = 1;
  double _height = 1;
  double _fontSize = 18;
  double _lineSpace = 0;
  double _pageMarginSide = 0;
  double _pageMarginCenter = 0;
  double _pageMarginTop = 0;
  double _pageMarginBottom = 0;
  double _pageWidth = 0;
  double _pageHeight = 0;
  double _currentPageWidth = 0;
  int _currentPageNo = -1;
  int _lastPageNo = 0;
  int _currentFontType = 0;
  bool _currentFontBold = false;
  bool _currentFontItalic = false;
  double _currentFontSize = 0;
  String _currentTextRotation;
  bool _inCaption = false;
  bool _inYokogumi = false;
  double _firstTopMargin = 0;
  double _restTopMargin = 0;
  double _bottomMargin = 0;
  bool _alignBottom = false;
  bool _frameDrawing = false;
  double _frameTop = 0;
  double _frameBottom = 0;

  final double _fontScaleL = 1.2;
  final double _fontScaleS = 0.85;

  Color get _coverAccentColor =>
      Color.lerp(fontColor, _theme.linkColor, _theme.isDark ? 0.55 : 0.28) ??
      fontColor;

  bool get _hasCover => _cover != null || _coverImage != null;

  bool get _hasLayoutContent => _entries.isNotEmpty || _hasCover;

  int get _contentPageCount => math.max(_pages.length - 2, 0);

  int get _lastDocumentPage => math.max(snapshot.totalPages - 1, 0);

  bool _isCoverPage(int pageNo) => _hasCover && pageNo == 0;

  int _documentToInternalPageNo(int pageNo) => pageNo + (_hasCover ? 0 : 1);

  int _internalToDocumentPageNo(int pageNo) => pageNo - (_hasCover ? 0 : 1);

  @override
  KumihanSnapshot get snapshot => KumihanSnapshot(
    currentPage: math.max(_currentPageNo, 0),
    spreadMode: getSpreadFromState(_currentState),
    totalPages: _contentPageCount + (_hasCover ? 1 : 0),
    writingMode: getWritingModeFromState(_currentState),
  );

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

  void _applyTheme(KumihanThemeData theme, {ui.Image? paperTexture}) {
    _theme = theme;
    fontColor = theme.textColor;
    paperColor = theme.paperColor;
    _paperTexture = paperTexture;
  }

  @override
  Future<void> open(KumihanDocument document) async {
    final compiled = compileKumihanDocument(document);
    _cover = compiled.cover;
    _entries = compiled.entries
        .expand<CompiledKumihanEntry>(
          (entry) => switch (entry) {
            CompiledKumihanTextEntry() => _preprocessText(
              entry.text,
            ).split('\n').map(CompiledKumihanTextEntry.new),
            CompiledKumihanTableEntry() => <CompiledKumihanEntry>[entry],
          },
        )
        .toList(growable: false);
    _headerTitle = compiled.headerTitle;
    _sourceText = _preprocessText(compiled.sourceText);
    _currentPosition = PositionInfo(
      leftToRight: _currentState.startsWith('h'),
      length: 0,
      offset: 0,
      paragraphNo: 0,
      shift1page: _shift1page,
    );
    await _relayout(false);
  }

  Future<void> setCoverImage(ui.Image? coverImage) async {
    if (identical(_coverImage, coverImage)) {
      return;
    }
    _coverImage = coverImage;

    if (_hasLayoutContent) {
      await _relayout(true);
    } else {
      onSnapshot(snapshot);
      onInvalidate();
    }
  }

  Future<void> updateTheme(
    KumihanThemeData theme, {
    ui.Image? paperTexture,
  }) async {
    final themeChanged = theme != _theme;
    final textureChanged = !identical(_paperTexture, paperTexture);
    if (!themeChanged && !textureChanged) {
      return;
    }

    _applyTheme(theme, paperTexture: paperTexture);

    if (_hasLayoutContent && themeChanged) {
      await _relayout(true);
      return;
    }

    onSnapshot(snapshot);
    onInvalidate();
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

  @override
  Future<void> resize(double width, double height) async {
    _width = math.max(1, width.floorToDouble());
    _height = math.max(1, height.floorToDouble());
    _updateSizes();

    if (_hasLayoutContent) {
      await _relayout(true);
    } else {
      onSnapshot(snapshot);
      onInvalidate();
    }
  }

  @override
  bool hitTest(double x, double y) {
    return _clickable.any((area) => area.hit(x, y));
  }

  void updateInteractionHandlers({
    required ValueChanged<String>? onExternalOpen,
    required ValueChanged<KumihanTapDetails>? onUnhandledTap,
    required KumihanTapHandler tapHandler,
  }) {
    this.onExternalOpen = onExternalOpen;
    this.onUnhandledTap = onUnhandledTap;
    this.tapHandler = tapHandler;
  }

  @override
  Future<void> tap(double x, double y) async {
    for (final area in _clickable) {
      if (!area.hit(x, y)) {
        continue;
      }

      if (area.type == 'リンク') {
        if (area.data.startsWith('#')) {
          final page = _anchorList[area.data];
          if (page != null) {
            _lastPageNo = _currentPageNo;
            _showPage(page);
          }
        } else {
          final index = int.tryParse(area.data);
          final url = index != null && index >= 0 && index < _links.length
              ? _links[index]
              : area.data;
          onExternalOpen?.call(url);
        }
        return;
      }
    }

    final details = KumihanTapDetails(
      canvasSize: Size(_width, _height),
      position: Offset(x, y),
      snapshot: snapshot,
    );
    onUnhandledTap?.call(details);
    await tapHandler(details, _tapActions);
  }

  @override
  bool isReadOutActive() => false;

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

  @override
  Future<void> toggleSpread() async {
    _currentState =
        '${_currentState[0]}${_currentState.endsWith('double') ? 'single' : 'double'}';
    await _relayout(true);
  }

  @override
  Future<void> toggleWritingMode() async {
    _currentState =
        '${_currentState.startsWith('v') ? 'h' : 'v'}${_currentState.endsWith('single') ? 'single' : 'double'}';
    _currentPosition.leftToRight = _currentState.startsWith('h');
    await _relayout(true);
  }

  @override
  Future<void> toggleShift1Page() async {
    _shift1page = !_shift1page;
    await _relayout(true);
  }

  @override
  Future<void> togglePaperColor() async {
    paperColor = paperColor.toARGB32() == paperColorValue
        ? const Color(0xffffffff)
        : const Color(paperColorValue);
    _theme = _theme.copyWith(paperColor: paperColor);
    onInvalidate();
  }

  @override
  Future<void> toggleForceIndent() async {
    _forceIndent = !_forceIndent;
    await _relayout(true);
  }

  int _step() => snapshot.spreadMode == KumihanSpreadMode.single ? 1 : 2;

  String _preprocessText(String text) {
    var source = text.replaceAll(RegExp(r'(\r\n|\r)'), '\n');
    source = source.replaceAllMapped(
      RegExp(r'(.)［＃地'),
      (match) => '${match[1]}\n‌［＃地',
    );
    source = source.replaceAll(RegExp('[\u2014\u2015]'), '─');
    source = source.replaceAllMapped(
      RegExp(r'─(─+)'),
      (match) => '─⁠${match[1]}',
    );
    source = source.replaceAllMapped(
      RegExp(r'…(…+)'),
      (match) => '…⁠${match[1]}',
    );
    source = source.replaceAll('\u3099', '゛');
    source = source.replaceAll('\u309a', '゜');
    source = source.replaceFirst(RegExp(r'\n$'), '');
    return source;
  }

  Future<void> _relayout(bool preservePosition) async {
    final token = ++_layoutToken;
    final position = preservePosition && _blocks.isNotEmpty
        ? _getPositionInfo(true)
        : _currentPosition;

    _updateSizes();
    await _ensureImagesLoaded(_sourceText, token);
    if (token != _layoutToken) {
      return;
    }

    _currentPosition = position;
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

  void _clearRenderedTables() {
    _renderedTables.clear();
  }

  Future<void> _ensureTablesPrepared(int token) async {
    _clearRenderedTables();
    for (var index = 0; index < _entries.length; index += 1) {
      final entry = _entries[index];
      if (entry is! CompiledKumihanTableEntry) {
        continue;
      }
      if (token != _layoutToken) {
        return;
      }

      _renderedTables[index] = await renderTableBlock(
        block: entry.table,
        fontColor: fontColor,
        fontSize: _fontSize,
        gothicFontFamilies: gothicFontFamilies,
        maxHeight: math.max(_pageHeight, _fontSize * 6),
        maxWidth: math.max(_pageWidth, _fontSize * 8),
        minchoFontFamilies: minchoFontFamilies,
      );
    }
  }

  Future<void> _ensureImagesLoaded(String text, int token) async {
    if (imageLoader == null) {
      return;
    }

    final paths = <String>{};
    for (final match in _imageAnnotationPattern.allMatches(text)) {
      final path = match.group(2);
      if (path != null && path.isNotEmpty) {
        paths.add(path);
      }
    }
    for (final match in _engineImageAnnotationPattern.allMatches(text)) {
      final path = match.group(1);
      if (path != null && path.isNotEmpty) {
        paths.add(path);
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
    final marginScale = layout.pageMarginScale;
    final minPageWidth = _fontSize * 6;
    final minPageHeight = _fontSize * 6;

    if (_currentState[1] == 'd') {
      final desiredSide = math.max(_width * 0.045, _fontSize) * marginScale;
      final maxSide = math.max((_width / 2 - minPageWidth) / 2.1, 0.0);
      _pageMarginSide = math.min(desiredSide, maxSide);
      _pageMarginCenter = 1.1 * _pageMarginSide;
      _pageWidth = _width / 2 - _pageMarginSide - _pageMarginCenter;
    } else {
      final desiredSide = math.max(_width * 0.08, _fontSize) * marginScale;
      final maxSide = math.max((_width - minPageWidth) / 2.1, 0.0);
      _pageMarginSide = math.min(desiredSide, maxSide);
      _pageMarginCenter = 1.1 * _pageMarginSide;
      _pageWidth = _width - _pageMarginSide - _pageMarginCenter;
    }

    if (_currentState.startsWith('v')) {
      _pageWidth -= (_pageWidth + _lineSpace) % (_fontSize + _lineSpace);
      if (_currentState[1] == 's') {
        _pageMarginSide = (_width - _pageWidth) / 2;
      }
      final desiredTop =
          math.max(_height * 0.07, math.max(1.85 * _fontSize + 20, 0)) *
          marginScale;
      final desiredBottom =
          math.max(_height * 0.07, math.max(2.07 * _fontSize, 44)) *
          marginScale;
      final maxMarginTotal = math.max(_height - minPageHeight, 0);
      final marginTotal = desiredTop + desiredBottom;
      final marginFactor = marginTotal > maxMarginTotal && marginTotal > 0
          ? maxMarginTotal / marginTotal
          : 1.0;
      _pageMarginTop = desiredTop * marginFactor;
      _pageMarginBottom = desiredBottom * marginFactor;
    } else {
      final desiredTop = math.max(_height * 0.07, 3 * _fontSize) * marginScale;
      final desiredBottom =
          math.max(_height * 0.07, 2.5 * _fontSize) * marginScale;
      final maxMarginTotal = math.max(_height - minPageHeight, 0);
      final marginTotal = desiredTop + desiredBottom;
      final marginFactor = marginTotal > maxMarginTotal && marginTotal > 0
          ? maxMarginTotal / marginTotal
          : 1.0;
      _pageMarginTop = desiredTop * marginFactor;
      _pageMarginBottom = desiredBottom * marginFactor;
    }

    _pageHeight = _height - _pageMarginTop - _pageMarginBottom;
  }

  void _layoutDocument() {
    _lines.clear();
    _pages
      ..clear()
      ..add(PageInfo())
      ..add(PageInfo());
    if (_shift1page) {
      _pages.add(PageInfo());
    }
    _blocks.clear();
    _indexes.clear();
    _chapterList.clear();
    _anchorList.clear();
    _links.clear();
    _clickable = <ClickableArea>[];
    _currentPageWidth = -_lineSpace;
    _currentPageNo = -1;
    _resetParagraphState();

    final pageInlineSize = _currentState.startsWith('v')
        ? _pageWidth
        : _pageHeight;
    final pageBlockSize = _currentState.startsWith('v')
        ? _pageHeight
        : _pageWidth;

    for (var entryIndex = 0; entryIndex < _entries.length; entryIndex += 1) {
      final entry = _entries[entryIndex];
      final paragraphNo = _blocks.length;

      if (entry is CompiledKumihanTableEntry) {
        final rendered = _renderedTables[entryIndex];
        if (rendered == null) {
          continue;
        }

        final extras = <LayoutExtra>[];
        if (_frameDrawing) {
          extras.add(LayoutExtra(type: '囲', ruby: '罫囲み中'));
        }

        final firstTopMargin = _firstTopMargin;
        final restTopMargin = _restTopMargin;
        final bottomMargin = _bottomMargin;
        final alignBottom = _alignBottom;
        final block = LayoutTextBlock(this)
          ..setText(
            '￼',
            _currentFontSize,
            _currentFontType,
            _currentFontBold,
            _currentFontItalic,
            _currentTextRotation,
          )
          ..userData = LayoutBlockUserData(extras: extras);
        final atom = block.atom.first;
        if (_currentState.startsWith('v')) {
          atom.width = rendered.width;
          atom.height = rendered.height;
        } else {
          atom.width = rendered.height;
          atom.height = rendered.width;
        }
        atom.picture = rendered.picture;
        _blocks.add(block);
        _layoutPreparedBlock(
          alignBottom: alignBottom,
          block: block,
          bottomMargin: bottomMargin,
          extras: extras,
          firstTopMargin: firstTopMargin,
          inserts: const <LayoutInsert>[],
          nonBreak: false,
          pageBlockSize: pageBlockSize,
          pageInlineSize: pageInlineSize,
          paragraphNo: paragraphNo,
          restTopMargin: restTopMargin,
          rubies: const <LayoutRuby>[],
        );
        continue;
      }

      if (entry is! CompiledKumihanTextEntry) {
        continue;
      }

      var paragraph = entry.text;
      var nonBreak = false;

      if (paragraph.isNotEmpty && paragraph.startsWith('‌')) {
        nonBreak = true;
        paragraph = paragraph.substring(1);
      }

      var firstTopMargin = _firstTopMargin;
      var restTopMargin = _restTopMargin;
      var bottomMargin = _bottomMargin;
      var alignBottom = _alignBottom;

      if (paragraph.startsWith('［＃')) {
        if (_handleBlockAnnotation(paragraph, pageBlockSize)) {
          continue;
        }

        final margins = ParagraphMargins(
          alignBottom: alignBottom,
          bottomMargin: bottomMargin,
          firstTopMargin: firstTopMargin,
          restTopMargin: restTopMargin,
        );
        paragraph = _applyLeadingParagraphAnnotation(
          paragraph,
          pageBlockSize,
          margins,
        );
        alignBottom = margins.alignBottom;
        bottomMargin = margins.bottomMargin;
        firstTopMargin = margins.firstTopMargin;
        restTopMargin = margins.restTopMargin;
      }

      var textStyles = <LayoutExtra>[];
      var inlineStyles = <LayoutExtra>[];
      var tcyEntries = <LayoutExtra>[];
      var inserts = <LayoutInsert>[];
      var rubies = <LayoutRuby>[];
      var extras = <LayoutExtra>[];

      if (paragraph == '［＃ここから罫囲み］') {
        _frameDrawing = true;
        _frameTop = math.min(_firstTopMargin, _restTopMargin);
        _frameBottom = pageBlockSize - _bottomMargin;
        _firstTopMargin += _fontSize;
        _restTopMargin += _fontSize;
        _bottomMargin += _fontSize;
        extras.add(LayoutExtra(type: '囲', ruby: '罫囲み始'));
        paragraph = '';
      } else if (paragraph == '［＃ここで罫囲み終わり］') {
        _firstTopMargin = math.max(_firstTopMargin - _fontSize, 0);
        _restTopMargin = math.max(_restTopMargin - _fontSize, 0);
        _bottomMargin = math.max(_bottomMargin - _fontSize, 0);
        _frameDrawing = false;
        extras.add(LayoutExtra(type: '囲', ruby: '罫囲み終'));
        paragraph = '';
      } else {
        if (_frameDrawing) {
          extras.add(LayoutExtra(type: '囲', ruby: '罫囲み中'));
        }

        paragraph = paragraph.replaceAll('［＃改行］', '');
        paragraph = _currentState.startsWith('v')
            ? paragraph.replaceAll('／＼', '〳〵').replaceAll('／″＼', '〴〵')
            : paragraph.replaceAll('／＼', '／⁠＼').replaceAll('／″＼', '／⁠"⁠＼');

        if (paragraph.contains('〔')) {
          paragraph = paragraph.replaceAllMapped(
            RegExp(r'〔(.+?)〕'),
            (match) => _accentsCallback(match[1] ?? ''),
          );
        }

        if (_currentState.startsWith('v') && _currentTextRotation != 'h') {
          paragraph = paragraph.replaceAll('“', '〝').replaceAll('”', '〟');
        }

        if (paragraph.contains('［＃アンカー：')) {
          paragraph = paragraph.replaceAllMapped(
            RegExp(r'［＃アンカー：(.+?)］'),
            (match) => '￹ア￺${match[1]}￻',
          );
        }
        if (paragraph.contains('［＃リンク：')) {
          paragraph = paragraph.replaceAllMapped(
            RegExp(r'［＃リンク：(.+?)］'),
            (match) => _linkCallback(match[1] ?? ''),
          );
        }
        if (paragraph.contains('http')) {
          paragraph = paragraph.replaceAllMapped(
            RegExp(
              r"([^\ufffa]|^)(https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:@&=+$,%#]+)",
            ),
            (match) => _link2Callback(match[1] ?? '', match[2] ?? ''),
          );
        }
        if (paragraph.contains('《')) {
          paragraph = _convertRubies(paragraph);
        }

        paragraph = paragraph.replaceAllMapped(
          RegExp(r'※［＃(.*?)］'),
          (match) => _gaijiCallback(match[1] ?? ''),
        );

        if (paragraph.contains('終わり］')) {
          paragraph = _convertSpanFormat(paragraph);
        }

        paragraph = paragraph.replaceAll('\u2010', '￹中￺―￻');

        while (RegExp(r'［＃[^［]*］').hasMatch(paragraph)) {
          paragraph = paragraph.replaceFirstMapped(
            RegExp(r'(.*?)(［＃[^［]*?］)'),
            (match) => _annotationCallback(match[1] ?? '', match[2] ?? ''),
          );
        }

        final extracted = _extractInlineAnnotations(
          paragraph,
          extras,
          inlineStyles,
          inserts,
          rubies,
          tcyEntries,
          textStyles,
          paragraphNo,
        );
        extras = extracted.extras;
        inlineStyles = extracted.inlineStyles;
        inserts = extracted.inserts;
        paragraph = extracted.paragraph;
        rubies = extracted.rubies;
        tcyEntries = extracted.tcyEntries;
        textStyles = extracted.textStyles;
      }

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
        ..userData = LayoutBlockUserData(
          extras: extras,
          inserts: inserts,
          rubies: rubies,
        );
      _blocks.add(block);

      for (final style in textStyles) {
        _applyStyle(
          block,
          style.startIndex ?? 0,
          style.endIndex ?? 0,
          style.style ?? '',
        );
      }

      for (final style in inlineStyles) {
        if (style.type == '外') {
          _insertImage(
            block,
            style.startIndex ?? 0,
            style.style ?? '',
            0,
            _currentFontSize,
          );
          continue;
        }
        if (style.type == '画') {
          _insertImage(
            block,
            style.startIndex ?? 0,
            style.style ?? '',
            double.tryParse(style.userData ?? '') ?? 0,
            double.tryParse(style.ruby ?? '') ?? 0,
          );
          continue;
        }
        if (style.type == 'リ') {
          _applyStyle(
            block,
            style.startIndex ?? 0,
            style.endIndex ?? 0,
            style.style ?? '',
            userData: style.userData ?? '',
          );
          continue;
        }
        _applyStyle(
          block,
          style.startIndex ?? 0,
          style.endIndex ?? 0,
          style.style ?? '',
        );
      }

      if (_inCaption) {
        _applyStyle(block, 0, block.rawtext.length, 'キャプション');
      }
      if (_inYokogumi) {
        _applyStyle(block, 0, block.rawtext.length, '横組み');
      }
      if (_currentState.startsWith('v') && _currentTextRotation == 'v') {
        for (final tcy in tcyEntries) {
          block.setTCY(tcy.startIndex ?? 0, tcy.endIndex ?? 0);
        }
      }

      _insertTextLine(block, inserts);
      _adjustRubies(block, rubies);
      _layoutPreparedBlock(
        alignBottom: alignBottom,
        block: block,
        bottomMargin: bottomMargin,
        extras: extras,
        firstTopMargin: firstTopMargin,
        inserts: inserts,
        nonBreak: nonBreak,
        pageBlockSize: pageBlockSize,
        pageInlineSize: pageInlineSize,
        paragraphNo: paragraphNo,
        restTopMargin: restTopMargin,
        rubies: rubies,
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
    required List<LayoutExtra> extras,
    required double firstTopMargin,
    required List<LayoutInsert> inserts,
    required bool nonBreak,
    required double pageBlockSize,
    required double pageInlineSize,
    required int paragraphNo,
    required double restTopMargin,
    required List<LayoutRuby> rubies,
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
    if (line.userData.isEmpty) {
      line.userData.add(_pages.length - 1);
    }
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
      line.userData.add(_pages.length - 1);
      _updateCurrentPageForPosition(paragraphNo, block, line);
      availableHeight = pageBlockSize - nextTop - bottomMargin;
    }

    _attachParagraphDecorations(block, inserts, rubies, extras, paragraphNo);
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
    _frameTop = 0;
    _frameBottom = 0;
  }

  bool _handleBlockAnnotation(String paragraph, double pageBlockSize) {
    final pageEmpty = _lines.length == _pages.last.line;

    if (paragraph.startsWith('［＃ここから')) {
      var matched = true;

      if (RegExp(r'［＃ここから[０-９]+字下げ').hasMatch(paragraph)) {
        var value = _getIntValue(paragraph);
        if (value > 5) {
          value = (value * (pageBlockSize / _currentFontSize)) / 40;
        }
        _firstTopMargin = value * _currentFontSize;
        _restTopMargin = _firstTopMargin;
      } else if (paragraph.startsWith('［＃ここから改行天付き')) {
        _firstTopMargin = 0;
        _restTopMargin = 0;
      } else if (RegExp(r'^［＃ここから地から[０-９]+字上げ').hasMatch(paragraph)) {
        var value = _getIntValue(paragraph);
        if (value > 5) {
          value = (value * (pageBlockSize / _currentFontSize)) / 40;
        }
        _bottomMargin = value * _currentFontSize;
        _alignBottom = true;
      } else if (paragraph.startsWith('［＃ここから地付き')) {
        _bottomMargin = 0;
        _alignBottom = true;
      } else if (paragraph.startsWith('［＃ここから') && paragraph.contains('字詰め')) {
        if (_alignBottom) {
          _firstTopMargin =
              pageBlockSize -
              _bottomMargin -
              _getIntValue(paragraph) * _currentFontSize;
          _firstTopMargin = math.max(_firstTopMargin, 0);
          _restTopMargin = _firstTopMargin;
        } else {
          _bottomMargin =
              pageBlockSize -
              _firstTopMargin -
              _getIntValue(paragraph) * _currentFontSize;
          _bottomMargin = math.max(_bottomMargin, 0);
        }
      } else {
        matched = false;
      }

      if (matched) {
        final wrapped = paragraph.indexOf('折り返して');
        if (wrapped > 0) {
          var value = _getIntValue(paragraph.substring(wrapped));
          if (value > 5) {
            value = (value * (pageBlockSize / _currentFontSize)) / 40;
          }
          _restTopMargin = value * _currentFontSize;
        }
        return true;
      }

      if (paragraph == '［＃ここから太字］') {
        _currentFontType = 2;
        return true;
      }
      if (paragraph == '［＃ここから斜体］') {
        _currentFontItalic = true;
        return true;
      }
      if (paragraph == '［＃ここからキャプション］') {
        _inCaption = true;
        return true;
      }
      if (paragraph == '［＃ここから横組み］') {
        _inYokogumi = true;
        _currentTextRotation = 'h';
        return true;
      }
      if (RegExp(r'^［＃ここから[大中小]見出し］$').hasMatch(paragraph)) {
        switch (charAt(paragraph, 6)) {
          case '大':
            _currentFontSize = _fontSize * _fontScaleL * _fontScaleL;
          case '中':
            _currentFontSize = _fontSize * _fontScaleL;
          default:
            _currentFontSize = _fontSize;
        }
        _currentFontType = 2;
        _indexes.add(
          IndexEntry(
            endIndex: 9007199254740991,
            paragraphNo: _blocks.length + 1,
            startIndex: 0,
            type: paragraph.substring(6, 10),
          ),
        );
        return true;
      }
      if (RegExp(r'［＃ここから[１-５]段階(大き|小さ)な文字').hasMatch(paragraph)) {
        var value = _getIntValue(paragraph);
        if (value > 5) {
          value = 5;
        }
        _currentFontSize = charAt(paragraph, 9) == '大'
            ? _fontSize * math.pow(_fontScaleL, value)
            : _fontSize * math.pow(_fontScaleS, value);
        return true;
      }
    }

    if (paragraph.startsWith('［＃ここで')) {
      if (RegExp(r'^［＃ここで[大中小]見出し終わり］$').hasMatch(paragraph)) {
        _currentFontSize = _fontSize;
        _currentFontType = 0;
        return true;
      }

      switch (paragraph) {
        case '［＃ここで字下げ終わり］':
          _firstTopMargin = 0;
          _restTopMargin = 0;
          return true;
        case '［＃ここで字上げ終わり］':
        case '［＃ここで地付き終わり］':
          _bottomMargin = 0;
          _alignBottom = false;
          return true;
        case '［＃ここで字詰め終わり］':
          if (_alignBottom) {
            _firstTopMargin = 0;
            _restTopMargin = 0;
          } else {
            _bottomMargin = 0;
          }
          return true;
        case '［＃ここで太字終わり］':
          _currentFontType = 0;
          return true;
        case '［＃ここで斜体終わり］':
          _currentFontType = 0;
          _currentFontItalic = false;
          return true;
        case '［＃ここでキャプション終わり］':
          _inCaption = false;
          return true;
        case '［＃ここで大きな文字終わり］':
        case '［＃ここで小さな文字終わり］':
          _currentFontSize = _fontSize;
          return true;
        case '［＃ここで横組み終わり］':
          _inYokogumi = false;
          _currentTextRotation = _currentState.startsWith('h') ? 'h' : 'v';
          return true;
      }
    }

    switch (paragraph) {
      case '［＃改ページ］':
      case '［＃改段］':
        if (!pageEmpty) {
          _pages.add(PageInfo(line: _lines.length));
        }
        _currentPageWidth = -_lineSpace;
        return true;
      case '［＃改丁］':
        if (_pages.length.isOdd) {
          _pages.add(PageInfo(line: _lines.length));
        } else if (!pageEmpty) {
          _pages.add(PageInfo(line: _lines.length));
          _pages.add(PageInfo(line: _lines.length));
        }
        _currentPageWidth = -_lineSpace;
        return true;
      case '［＃改見開き］':
        if (_pages.length.isEven) {
          _pages.add(PageInfo(line: _lines.length));
        } else if (!pageEmpty) {
          _pages.add(PageInfo(line: _lines.length));
          _pages.add(PageInfo(line: _lines.length));
        }
        _currentPageWidth = -_lineSpace;
        return true;
      case '［＃ページの左右中央］':
        if (pageEmpty) {
          _pages[_pages.length - 1] = PageInfo(
            line: _pages.last.line,
            centering: true,
          );
        } else {
          _pages.add(PageInfo(line: _lines.length, centering: true));
        }
        _currentPageWidth = -_lineSpace;
        return true;
    }

    return false;
  }

  String _applyLeadingParagraphAnnotation(
    String paragraph,
    double pageBlockSize,
    ParagraphMargins margins,
  ) {
    double resolveMarginValue() {
      var value = _getIntValue(paragraph);
      if (value > 5) {
        value = (value * (pageBlockSize / _currentFontSize)) / 40;
      }
      return value * _currentFontSize;
    }

    if (RegExp(r'^［＃(天から|)[０-９]+字下げ］').hasMatch(paragraph)) {
      final margin = resolveMarginValue();
      margins.firstTopMargin = margin;
      margins.restTopMargin = margin;
      return paragraph.replaceFirst(RegExp(r'(［.*?］)'), '');
    }

    if (RegExp(r'^［＃(地から|)[０-９]+字上げ］').hasMatch(paragraph)) {
      margins.bottomMargin = resolveMarginValue();
      margins.alignBottom = true;
      return paragraph.replaceFirst(RegExp(r'(［.*?］)'), '');
    }

    if (paragraph.startsWith('［＃地付き］')) {
      margins.bottomMargin = 0;
      margins.alignBottom = true;
      return paragraph.substring(6);
    }

    return paragraph;
  }

  ({
    List<LayoutExtra> extras,
    List<LayoutExtra> inlineStyles,
    List<LayoutInsert> inserts,
    String paragraph,
    List<LayoutRuby> rubies,
    List<LayoutExtra> tcyEntries,
    List<LayoutExtra> textStyles,
  })
  _extractInlineAnnotations(
    String paragraph,
    List<LayoutExtra> extras,
    List<LayoutExtra> inlineStyles,
    List<LayoutInsert> inserts,
    List<LayoutRuby> rubies,
    List<LayoutExtra> tcyEntries,
    List<LayoutExtra> textStyles,
    int paragraphNo,
  ) {
    var working = paragraph;
    var annotationStart = working.indexOf('￹');

    while (annotationStart >= 0) {
      final annotationType = charAt(working, annotationStart + 1);
      var bodyStart = working.indexOf('￺', annotationStart + 2);
      var nested = working.indexOf('￹', annotationStart + 2);
      while (nested >= 0 && nested < bodyStart) {
        bodyStart = working.indexOf('￺', bodyStart + 1);
        nested = working.indexOf('￹', nested + 1);
      }

      var annotationEnd = working.indexOf('￻', bodyStart + 1);
      nested = working.indexOf('￹', bodyStart + 1);
      while (nested >= 0 && nested < annotationEnd) {
        annotationEnd = working.indexOf('￻', annotationEnd + 1);
        nested = working.indexOf('￹', nested + 1);
      }

      final targetText = working.substring(annotationStart + 2, bodyStart);
      var annotationText = working.substring(bodyStart + 1, annotationEnd);
      var startIndex = annotationStart;
      var endIndex = bodyStart;
      var replacement = '';
      var replaceTargetText = false;

      if (targetText.isNotEmpty) {
        var normalizedTarget = targetText
            .replaceAll(RegExp('\ufff9.*\ufffb'), '')
            .replaceAll('⁠', '');
        startIndex = -1;
        endIndex = annotationStart;
        if (normalizedTarget.isNotEmpty) {
          final targetLength = normalizedTarget.length;
          for (var probe = annotationStart; probe > 0; probe -= 1) {
            var sourceIndex = probe - 1;
            var compareIndex = targetLength - 1;
            while (sourceIndex >= 0 && compareIndex >= 0) {
              final current = charAt(working, sourceIndex);
              sourceIndex -= 1;
              if ('​⁠'.contains(current)) {
                continue;
              }
              if (current != charAt(normalizedTarget, compareIndex)) {
                break;
              }
              compareIndex -= 1;
            }
            if (compareIndex < 0) {
              startIndex = sourceIndex + 1;
              break;
            }
            if (sourceIndex < 0) {
              break;
            }
          }
        }
      } else if (annotationType == '返' ||
          annotationType == '中' ||
          annotationType == '送') {
        if (working.substring(annotationStart - 1, annotationStart) == '￼') {
          startIndex -= 1;
        } else {
          replacement += '⁠￼';
          startIndex += 1;
        }
      } else if (annotationType == '注' || annotationType == 'ア') {
        endIndex = startIndex;
        if (startIndex > 0) {
          startIndex -= 1;
        }
      }

      if (startIndex >= 0) {
        switch (annotationType) {
          case '外':
          case '画':
            final parts = annotationText.split('\t');
            inlineStyles.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                style: parts.isNotEmpty ? parts[0] : '',
                ruby: parts.length > 2 ? parts[2] : '',
                type: annotationType,
                userData: parts.length > 1 ? parts[1] : '',
              ),
            );
            replacement += '￼';
          case 'リ':
            inlineStyles.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                style: 'リンク',
                type: annotationType,
                userData: annotationText,
              ),
            );
          case '罫':
            extras.add(
              LayoutExtra(
                endIndex: endIndex,
                ruby: annotationText,
                startIndex: startIndex,
                type: annotationType,
              ),
            );
          case '横':
            tcyEntries.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                type: annotationType,
              ),
            );
          case '字':
            textStyles.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                style: annotationText,
                type: annotationType,
              ),
            );
          case '割':
            final innerLength = (annotationText.length + 1) ~/ 2;
            replacement = '（${_warichuPlaceholder * innerLength}）';
            replaceTargetText = true;
            inlineStyles.add(
              LayoutExtra(
                endIndex: startIndex + 1,
                startIndex: startIndex,
                style: '割り注括弧',
                type: annotationType,
              ),
            );
            inlineStyles.add(
              LayoutExtra(
                endIndex: startIndex + replacement.length - 1,
                startIndex: startIndex + 1,
                style: '割り注占位',
                type: annotationType,
              ),
            );
            inlineStyles.add(
              LayoutExtra(
                endIndex: startIndex + replacement.length,
                startIndex: startIndex + replacement.length - 1,
                style: '割り注括弧',
                type: annotationType,
              ),
            );
            extras.add(
              LayoutExtra(
                endIndex: startIndex + replacement.length,
                ruby: annotationText,
                startIndex: startIndex,
                type: annotationType,
              ),
            );
          case '見':
            textStyles.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                style: annotationText,
                type: annotationType,
              ),
            );
            _indexes.add(
              IndexEntry(
                endIndex: endIndex,
                paragraphNo: paragraphNo,
                startIndex: startIndex,
                type: annotationText,
              ),
            );
          case 'ア':
            _indexes.add(
              IndexEntry(
                endIndex: endIndex,
                paragraphNo: paragraphNo,
                startIndex: startIndex,
                type: '#$annotationText',
              ),
            );
          case '回':
            for (var index = startIndex; index < bodyStart; index += 1) {
              final character = charAt(working, index);
              if (character == '〝') {
                working =
                    '${working.substring(0, index)}“${working.substring(index + 1)}';
              } else if (character == '〟') {
                working =
                    '${working.substring(0, index)}”${working.substring(index + 1)}';
              }
            }
            inlineStyles.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                style: annotationText,
                type: annotationType,
              ),
            );
          case '─':
          case '小':
          case '合':
            inlineStyles.add(
              LayoutExtra(
                endIndex: endIndex,
                startIndex: startIndex,
                style: annotationText,
                type: annotationType,
              ),
            );
          case '返':
          case '中':
          case '送':
            inserts.add(
              LayoutInsert(
                startIndex: startIndex,
                text: annotationText,
                type: annotationType,
              ),
            );
          case 'ル':
          case 'る':
            final spans = <LayoutInsert>[];
            var nestedStart = annotationText.indexOf('￹');
            while (nestedStart >= 0) {
              final nestedType = charAt(annotationText, nestedStart + 1);
              final nestedEnd = annotationText.indexOf('￻', nestedStart + 2);
              if (nestedEnd < 0) {
                break;
              }
              if (nestedType == '返' || nestedType == '送' || nestedType == '中') {
                final body = annotationText.substring(
                  nestedStart + 3,
                  nestedEnd,
                );
                if (nestedType != '中') {
                  spans.add(
                    LayoutInsert(
                      startIndex: nestedStart,
                      text: body,
                      type: nestedType,
                    ),
                  );
                }
                annotationText =
                    annotationText.substring(0, nestedStart) +
                    body +
                    annotationText.substring(nestedEnd + 1);
              } else {
                annotationText =
                    annotationText.substring(0, nestedStart) +
                    annotationText.substring(nestedEnd + 1);
              }
              nestedStart = annotationText.indexOf('￹');
            }
            rubies.add(
              LayoutRuby(
                endIndex: endIndex,
                ruby: annotationText,
                spans: spans
                    .map(
                      (span) => LayoutStyleSpan(
                        endIndex: span.startIndex + span.text.length,
                        startIndex: span.startIndex,
                        type: span.type,
                      ),
                    )
                    .toList(),
                startIndex: startIndex,
                type: annotationType,
              ),
            );
          default:
            extras.add(
              LayoutExtra(
                endIndex: endIndex,
                ruby: annotationText,
                startIndex: startIndex,
                type: annotationType,
              ),
            );
        }
      }

      if (replaceTargetText) {
        working =
            working.substring(0, startIndex) +
            replacement +
            working.substring(annotationEnd + 1);
        annotationStart = working.indexOf('￹', startIndex + replacement.length);
      } else {
        working =
            working.substring(0, annotationStart) +
            replacement +
            working.substring(annotationEnd + 1);
        annotationStart = working.indexOf('￹');
      }
    }

    return (
      extras: extras,
      inlineStyles: inlineStyles,
      inserts: inserts,
      paragraph: working,
      rubies: rubies,
      tcyEntries: tcyEntries,
      textStyles: textStyles,
    );
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
    List<LayoutInsert> inserts,
    List<LayoutRuby> rubies,
    List<LayoutExtra> extras,
    int paragraphNo,
  ) {
    for (final insert in inserts) {
      final line = block.getTextLineAtCharIndex(insert.startIndex);
      if (line == null || insert.tl == null) {
        continue;
      }
      final atomIndex = block.getAtomIndexAt(insert.startIndex);
      insert.tl!.y = line.y + line.getAtomY(atomIndex);
      line.userData.add(insert.tl!);
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
      var segmentHeight = endY - startY;
      final rubyBlock = ruby.tb!;
      var rubyLine = endAtom > line.end
          ? rubyBlock.createTextLine(null, segmentHeight + ruby.trackingStart)
          : rubyBlock.createTextLine();

      if (rubyLine == null) {
        continue;
      }

      rubyLine.userData
        ..clear()
        ..add(ruby.type);
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

      line.userData.add(rubyLine);
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
        rubyLine = endAtom > line.end
            ? rubyBlock.createTextLine(rubyLine, segmentHeight)
            : rubyBlock.createTextLine(rubyLine);
        if (rubyLine == null) {
          break;
        }

        rubyLine.userData
          ..clear()
          ..add(ruby.type);
        offset = (rubyLine.textWidth - segmentHeight) / 2;
        rubyLine.y = line.y - offset;
        line.userData.add(rubyLine);
        line.rubyBottom[ruby.type] = math.max(
          line.rubyBottom[ruby.type] ?? 0,
          rubyLine.y + rubyLine.textWidth,
        );
      }
    }

    for (final extra in extras) {
      if (extra.type == '割') {
        _attachWarichu(block, extra);
      } else if (extra.type == '※') {
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
        markerLine.userData.add(extra.type);
        markerLine.y =
            line.y +
            line.getAtomY(atomIndex) +
            block.getAtomHeight(atomIndex) -
            0.4 * line.width;
        line.userData.add(markerLine);
        line.userData.add(
          NoteMarker(
            annotation: extra.ruby ?? '',
            height: markerLine.textWidth,
            markType: '※',
            top: markerLine.y,
            width: markerLine.width,
          ),
        );
      } else if (extra.type == '線' || extra.type == '罫' || extra.type == 'リ') {
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
              includeTrailingTracking: extra.type == '罫',
            );
        final endAtom = block.getAtomIndexAt(endIndex);
        final bottom =
            endLine.y +
            endLine.getAtomY(
              endAtom,
              includeTrailingTracking: extra.type == '罫',
            ) +
            block.getAtomHeight(endAtom);

        if (extra.type == 'リ') {
          final linkEnd = block.getAtomIndexAt(extra.endIndex ?? 0);
          LayoutTextLine? currentLine = startLine;
          var currentStart = startAtom;
          while (currentLine != null) {
            currentLine.userData.add(
              LinkMarker(
                endAtom: math.min(linkEnd, currentLine.end),
                startAtom: currentStart,
                userData: extra.userData ?? '',
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
          currentLine.userData.add(
            SpanMarker(
              bottom: currentLine.y + currentLine.textWidth,
              isEnd: false,
              isStart: isStart,
              markType: extra.ruby ?? '',
              top: top,
            ),
          );
          isStart = false;
          currentLine = currentLine.nextLine;
          top = currentLine?.y ?? 0;
        }

        currentLine?.userData.add(
          SpanMarker(
            bottom: bottom,
            isEnd: true,
            isStart: isStart,
            markType: extra.ruby ?? '',
            top: top,
          ),
        );
      } else if (extra.type == '囲') {
        var line = block.textLine;
        while (line != null) {
          line.userData.add(
            SpanMarker(
              bottom: _frameBottom,
              markType: extra.ruby ?? '',
              top: _frameTop,
            ),
          );
          line = line.nextLine;
        }
      } else if (extra.type == '点') {
        final emphasisChar = charAt(extra.ruby ?? '', 1);
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
          markerLine.userData.add('${charAt(extra.ruby ?? '', 0)}点');
          markerLine.y =
              line.y +
              line.getAtomY(atomIndex) +
              (block.getAtomHeight(atomIndex) - markerLine.textWidth) / 2;
          line.userData.add(markerLine);
        }
      } else if (extra.type == '注') {
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
        markerLine.userData.add(extra.type);

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

        line.userData.add(markerLine);
        line.userData.add(
          NoteMarker(
            annotation: extra.ruby ?? '',
            height: markerLine.textWidth,
            markType: '注',
            top: markerLine.y,
            width: markerLine.width,
          ),
        );
      }
    }
  }

  String _gaijiCallback(String body) {
    final jisMatch = RegExp(
      r'^.*([12]-[0-9]{1,2}-[0-9]{1,2}).*$',
    ).firstMatch(body);
    if (jisMatch != null) {
      final jis = jisMatch.group(1)!;
      final character = kumihanGaijiTable[jis];
      if (character != null) {
        return character;
      }
    }

    final unicodeMatch = RegExp(r'^.*、U\+([0-9A-Fa-f]+)、.*$').firstMatch(body);
    if (unicodeMatch != null) {
      return String.fromCharCode(int.parse(unicodeMatch.group(1)!, radix: 16));
    }

    final dakuten = RegExp(r'^濁点付き(平|片)仮名(.).*$').firstMatch(body);
    if (dakuten != null) {
      return '${dakuten.group(2)}゛';
    }

    final handakuten = RegExp(r'^半濁点付き(平|片)仮名(.).*$').firstMatch(body);
    if (handakuten != null) {
      return '${handakuten.group(2)}゜';
    }

    return '※￹※※￺$body￻';
  }

  String _accentsCallback(String body) {
    final converted = body.replaceAllMapped(
      RegExp(r"(AE&|OE&|[!?ACEINOSUY][@`'^~:&,/_])", caseSensitive: false),
      (match) => accentsTable[match[0]!] ?? match[0]!,
    );
    return converted != body ? converted : '〔$body〕';
  }

  String _linkCallback(String link) {
    final glyph = _currentState.startsWith('v') ? '◀' : '▶';
    if (link.startsWith('#')) {
      return '$glyph￹リ$glyph￺$link￻';
    }
    final index = _links.length;
    _links.add(link);
    return '$glyph￹リ$glyph￺$index￻';
  }

  String _link2Callback(String prefix, String url) {
    final index = _links.length;
    _links.add(url);
    return '$prefix$url￹リ$url￺$index￻';
  }

  String _annotationCallback(String prefix, String annotation) {
    var extracted = '';
    var openSide = '右';
    final start = annotation.indexOf('「');

    if (start >= 0) {
      final end = _findEndBracket(annotation, start + 1);
      if (end >= 0) {
        extracted = annotation
            .substring(start + 1, end)
            .replaceAll(RegExp(r'［＃[^［]*?］'), '')
            .replaceAll(RegExp('\ufff9.*?\ufffb'), '')
            .replaceAll('\ufff7', '「')
            .replaceAll('\ufff8', '」');

        if (annotation.indexOf('の左', end + 1) >= 0) {
          openSide = '左';
        }

        String marker(String suffix, String body) =>
            '$prefix￹$suffix$extracted￺$body￻';

        if (annotation.indexOf('に傍点］', end + 1) >= 0) {
          return marker('点', '$openSide﹅');
        }
        if (annotation.indexOf('白ゴマ傍点］', end + 1) >= 0) {
          return marker('点', '$openSide﹆');
        }
        if (annotation.indexOf('に丸傍点］', end + 1) >= 0) {
          return marker('点', '$openSide⬤');
        }
        if (annotation.indexOf('白丸傍点］', end + 1) >= 0) {
          return marker('点', '$openSide○');
        }
        if (annotation.indexOf('黒三角傍点］', end + 1) >= 0) {
          return marker('点', '$openSide▲');
        }
        if (annotation.indexOf('白三角傍点］', end + 1) >= 0) {
          return marker('点', '$openSide△');
        }
        if (annotation.indexOf('二重丸傍点］', end + 1) >= 0) {
          return marker('点', '$openSide◎');
        }
        if (annotation.indexOf('蛇の目傍点］', end + 1) >= 0) {
          return marker('点', '$openSide◉');
        }
        if (annotation.indexOf('ばつ傍点］', end + 1) >= 0) {
          return marker('点', '$openSide❌');
        }
        if (annotation.indexOf('に傍線］', end + 1) >= 0) {
          return marker('線', '$openSide傍線');
        }
        if (annotation.indexOf('二重傍線］', end + 1) >= 0) {
          return marker('線', '$openSide二重傍線');
        }
        if (annotation.indexOf('鎖線］', end + 1) >= 0) {
          return marker('線', '$openSide鎖線');
        }
        if (annotation.indexOf('破線］', end + 1) >= 0) {
          return marker('線', '$openSide破線');
        }
        if (annotation.indexOf('波線］', end + 1) >= 0) {
          return marker('線', '$openSide波線');
        }
        if (annotation.indexOf('取消線］', end + 1) >= 0) {
          return '$prefix￹線$extracted￺取消線￻';
        }
        if (annotation.indexOf('縦中横］', end + 1) >= 0) {
          return '$prefix￹横$extracted￺縦中横￻';
        }
        if (annotation.indexOf('罫囲み］', end + 1) >= 0) {
          return '$prefix￹罫$extracted￺罫囲み￻';
        }

        if ((annotation.indexOf('」のルビ］', end + 1) >= 0 ||
                annotation.indexOf('」の注記］', end + 1) >= 0) &&
            annotation.lastIndexOf('」') > annotation.indexOf('「', end + 1)) {
          final rubyStart = annotation.indexOf('「', end + 1);
          final rubyEnd = annotation.lastIndexOf('」');
          final ruby = annotation.substring(rubyStart + 1, rubyEnd);
          return '${openSide == '左' ? _jointTargetString(prefix, extracted) : prefix}￹${openSide == '左' ? 'る' : 'ル'}$extracted￺$ruby￻';
        }

        if (annotation.indexOf('見出し］', end + 1) >= 0) {
          if (annotation.indexOf('大見出し］', end + 1) >= 0) {
            return '$prefix￹見$extracted￺大見出し￻';
          }
          if (annotation.indexOf('中見出し］', end + 1) >= 0) {
            return '$prefix￹見$extracted￺中見出し￻';
          }
          if (annotation.indexOf('小見出し］', end + 1) >= 0) {
            return '$prefix￹見$extracted￺小見出し￻';
          }
        }

        if (annotation.indexOf('段階大きな文字］', end + 1) >= 0 ||
            annotation.indexOf('段階小さな文字］', end + 1) >= 0) {
          return '$prefix￹字$extracted￺${annotation.substring(end + 2, end + 10)}￻';
        }

        if (annotation.indexOf('太字］', end + 1) >= 0) {
          return '$prefix￹字$extracted￺太字￻';
        }
        if (annotation.indexOf('斜体］', end + 1) >= 0) {
          return '$prefix￹字$extracted￺斜体￻';
        }
        if (annotation.indexOf('キャプション］', end + 1) >= 0) {
          return '$prefix￹字$extracted￺キャプション￻';
        }
        if (annotation.indexOf('横組み］', end + 1) >= 0) {
          return '$prefix￹回$extracted￺横組み￻';
        }
        if (annotation.indexOf('行右小書き］', end + 1) >= 0) {
          return '$prefix￹小$extracted￺行右小書き￻';
        }
        if (annotation.indexOf('行左小書き］', end + 1) >= 0) {
          return '$prefix￹小$extracted￺行左小書き￻';
        }
        if (annotation.indexOf('上付き小文字］', end + 1) >= 0) {
          return '$prefix￹小$extracted￺上付き小文字￻';
        }
        if (annotation.indexOf('下付き小文字］', end + 1) >= 0) {
          return '$prefix￹小$extracted￺下付き小文字￻';
        }
        if (annotation.indexOf('割り注］', end + 1) >= 0) {
          return '$prefix￹割$extracted￺$extracted￻';
        }
      }
    } else {
      if (RegExp(r'^［＃[レ一二三四五上中下甲乙丙丁天地人]{1,2}］$').hasMatch(annotation)) {
        final text = annotation.replaceFirstMapped(
          RegExp(r'^［＃([レ一二三四五上中下甲乙丙丁天地人]{1,2})］$'),
          (match) => '$prefix￹返￺${match[1]}￻',
        );
        return text;
      }
      if (RegExp(r'^［＃（(.*)）］$').hasMatch(annotation)) {
        return annotation.replaceFirstMapped(
          RegExp(r'^［＃（(.*)）］$'),
          (match) => '$prefix￹送￺${match[1]}￻',
        );
      }
    }

    final imageMatch = RegExp(
      r'^［＃外字（([^（、]*)(、横([0-9]+)×縦([0-9]+)|)）入る］$',
    ).firstMatch(annotation);
    if (imageMatch != null) {
      return '$prefix￼￹外￺${imageMatch[1]}\t${imageMatch[3] ?? ''}\t${imageMatch[4] ?? ''}￻';
    }
    final paintedImageMatch = RegExp(
      r'^［＃(.*?)（([^（、]*)(、横([0-9]+)×縦([0-9]+)|)）入る］$',
    ).firstMatch(annotation);
    if (paintedImageMatch != null) {
      return '$prefix￼￹画￺${paintedImageMatch[2]}\t${paintedImageMatch[4] ?? ''}\t${paintedImageMatch[5] ?? ''}￻';
    }
    return prefix +
        annotation.replaceFirstMapped(
          RegExp(r'^［＃(.*)］$'),
          (match) => '￹注￺${match[1]}￻',
        );
  }

  String _convertSpanFormat(String text) {
    var working = text;
    var style = working.replaceFirstMapped(
      RegExp(
        r'^.*［＃(左に|)(傍点|白ゴマ傍点|丸傍点|白丸傍点|黒三角傍点|白三角傍点|二重丸傍点|蛇の目傍点|ばつ傍点|傍線|二重傍線|鎖線|破線|波線|取消線|注記付き|ルビ付き)］.*$',
      ),
      (match) => '${match[1]}${match[2]}',
    );

    while (working != style) {
      final start = working.indexOf('［＃$style］');
      final startEnd = working.indexOf('］', start + 2);
      working = working.substring(0, start) + working.substring(startEnd + 1);
      var end = -1;
      var suffixEnd = -1;

      if (style.endsWith('注記付き')) {
        end = style.startsWith('左に')
            ? RegExp(r'［＃左に「[^［]*?」の注記付き終わり］').firstMatch(working)?.start ?? -1
            : RegExp(r'［＃「[^［]*?」の注記付き終わり］').firstMatch(working)?.start ?? -1;
        if (end < 0) {
          break;
        }
        suffixEnd = working.indexOf('」の注記付き終わり］', end + 2) + 9;
        style = '${working.substring(end + 2, suffixEnd - 7)}ルビ';
      } else if (style.endsWith('ルビ付き')) {
        end = style.startsWith('左に')
            ? RegExp(r'［＃左に「[^［]*?」のルビ付き終わり］').firstMatch(working)?.start ?? -1
            : RegExp(r'［＃「[^［]*?」のルビ付き終わり］').firstMatch(working)?.start ?? -1;
        if (end < 0) {
          break;
        }
        suffixEnd = working.indexOf('」のルビ付き終わり］', end + 2) + 9;
        style = '${working.substring(end + 2, suffixEnd - 7)}ルビ';
      } else {
        end = working.indexOf('［＃$style終わり］');
        if (end < 0) {
          break;
        }
        suffixEnd = end + style.length + 5;
      }

      var target = working
          .substring(start, end)
          .replaceAll(RegExp(r'［＃[^［]*?］'), '');
      target = target
          .replaceAll(RegExp('\ufff9.*?\ufffb'), '')
          .replaceAll('「', '￷')
          .replaceAll('」', '￸');
      if (target.isNotEmpty) {
        working = style.startsWith('左に')
            ? '${working.substring(0, end + 2)}「$target」の$style${working.substring(suffixEnd)}'
            : '${working.substring(0, end + 2)}「$target」に$style${working.substring(suffixEnd)}';
      }

      style = working.replaceFirstMapped(
        RegExp(
          r'^.*［＃(左に|)(傍点|白ゴマ傍点|丸傍点|白丸傍点|黒三角傍点|白三角傍点|二重丸傍点|蛇の目傍点|ばつ傍点|傍線|二重傍線|鎖線|破線|波線|取消線|注記付き|ルビ付き)］.*$',
        ),
        (match) => '${match[1]}${match[2]}',
      );
    }

    style = working.replaceFirstMapped(
      RegExp(
        r'^.*［＃(縦中横|大見出し|中見出し|小見出し|同行大見出し|同行中見出し|同行小見出し|窓大見出し|窓中見出し|窓小見出し|太字|斜体|キャプション|横組み|罫囲み|行右小書き|行左小書き|上付き小文字|下付き小文字|割り注)］.*$',
      ),
      (match) => '${match[1]}',
    );

    while (working != style) {
      final start = working.indexOf('［＃$style］');
      final startEnd = working.indexOf('］', start + 2);
      working = working.substring(0, start) + working.substring(startEnd + 1);
      final end = working.indexOf('［＃$style終わり］');
      if (end < 0) {
        break;
      }

      var target = working
          .substring(start, end)
          .replaceAll(RegExp(r'［＃[^［]*?］'), '');
      target = target
          .replaceAll(RegExp('\ufff9.*?\ufffb'), '')
          .replaceAll('「', '￷')
          .replaceAll('」', '￸');
      if (target.isNotEmpty) {
        working =
            '${working.substring(0, end + 2)}「$target」は$style${working.substring(end + style.length + 5)}';
      }

      style = working.replaceFirstMapped(
        RegExp(
          r'^.*［＃(縦中横|大見出し|中見出し|小見出し|同行大見出し|同行中見出し|同行小見出し|窓大見出し|窓中見出し|窓小見出し|太字|斜体|キャプション|横組み|罫囲み|行右小書き|行左小書き|上付き小文字|下付き小文字|割り注)］.*$',
        ),
        (match) => '${match[1]}',
      );
    }

    var match = RegExp(r'［＃[１-５]段階(大き|小さ)な文字］').firstMatch(working);
    while (match != null) {
      final start = match.start;
      final startEnd = working.indexOf('］', start + 2);
      final body = working.substring(start + 2, startEnd);
      working = working.substring(0, start) + working.substring(startEnd + 1);
      final end = working.indexOf('［＃${body.substring(3)}終わり］');
      if (end >= 0) {
        var target = working
            .substring(start, end)
            .replaceAll(RegExp(r'［＃[^［]*?］'), '');
        target = target
            .replaceAll(RegExp('\ufff9.*?\ufffb'), '')
            .replaceAll('「', '￷')
            .replaceAll('」', '￸');
        if (target.isNotEmpty) {
          working =
              '${working.substring(0, end + 2)}「$target」は$body${working.substring(end + body.length + 2)}';
        }
      }
      match = RegExp(r'［＃[１-５]段階(大き|小さ)な文字］').firstMatch(working);
    }

    return working;
  }

  String _convertRubies(String text) {
    return text
        .replaceAllMapped(RegExp(r'［＃(.+?)］'), (match) {
          var escaped = (match[1] ?? '').replaceAll('《', '※［＃始め二重山括弧、1-1-52］');
          escaped = escaped.replaceAll('》', '※［＃終わり二重山括弧、1-1-53］');
          escaped = escaped.replaceAll('｜', '※［＃縦線、1-1-35］');
          return '［＃$escaped］';
        })
        .replaceAllMapped(
          RegExp(r'｜(.+?)《(.+?)》'),
          (match) => '${match[1]}［＃「${match[1]}」に「${match[2]}」の注記］',
        )
        .replaceAllMapped(
          RegExp(r'(([⺀-⻳㐁-䶮一-龻豈-龎仝々〆〇ヶ]|※［＃[^］]*］)+?)《(.+?)》'),
          (match) => '${match[1]}［＃「${match[1]}」に「${match[3]}」の注記］',
        )
        .replaceAllMapped(
          RegExp(r'([ぁ-ゖゝゞゟ]+?)《(.+?)》'),
          (match) => '${match[1]}［＃「${match[1]}」に「${match[2]}」の注記］',
        )
        .replaceAllMapped(
          RegExp(r'([゠-ヿ]+?)《(.+?)》'),
          (match) => '${match[1]}［＃「${match[1]}」に「${match[2]}」の注記］',
        )
        .replaceAllMapped(
          RegExp(r'([！-～Α-Ωα-ωА-я]+?)《(.+?)》'),
          (match) => '${match[1]}［＃「${match[1]}」に「${match[2]}」の注記］',
        )
        .replaceAllMapped(
          RegExp(r'([\x21-\x7e¡¿-ž]+?)《(.+?)》'),
          (match) => '${match[1]}［＃「${match[1]}」に「${match[2]}」の注記］',
        );
  }

  double _getIntValue(String text) {
    final digits = text.replaceFirstMapped(
      RegExp(r'^(.*?)([０-９]+)(.*?)$'),
      (match) => '${match[2]}',
    );
    var value = 0;
    for (var index = 0; index < digits.length; index += 1) {
      value = value * 10 + (digits.codeUnitAt(index) - 65296);
    }
    return value.toDouble();
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

  void _insertTextLine(LayoutTextBlock block, List<LayoutInsert> inserts) {
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
      if (insert.type == '返') {
        if (insert.text == '一レ') {
          markerBlock.splitAtom(1);
          markerBlock.atom[1].tracking = -0.27 * fontSize;
        } else if (charAt(insert.text, 1) == 'レ') {
          markerBlock.atom[0].tracking = -0.1 * fontSize;
        }
      }
      final markerLine = markerBlock.createTextLine()!;
      markerLine.userData.add(insert.type);
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
    String style, {
    String? userData,
  }) {
    if (endIndex <= math.max(startIndex, 0)) {
      return;
    }

    final start = block.splitAtom(startIndex < 0 ? 0 : startIndex);
    final end = block.splitAtom(endIndex);
    final atoms = block.atom;

    switch (style) {
      case '大見出し':
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(_fontSize * _fontScaleL * _fontScaleL)
            ..setFontGothic();
        }
      case '中見出し':
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(_fontSize * _fontScaleL)
            ..setFontGothic();
        }
      case '小見出し':
      case '太字':
        for (var index = start; index < end; index += 1) {
          atoms[index].setFontGothic();
        }
      case '斜体':
        for (var index = start; index < end; index += 1) {
          atoms[index].setFontItalic();
        }
      case 'キャプション':
        for (var index = start; index < end; index += 1) {
          atoms[index].color = _theme.captionColor;
        }
      case '横組み':
        for (var index = start; index < end; index += 1) {
          atoms[index].setRotated();
        }
      case '返':
        for (var index = start; index < end; index += 1) {
          atoms[index].offsetX = -atoms[index].getFontSize() / 8;
        }
      case '送':
        for (var index = start; index < end; index += 1) {
          atoms[index].offsetX = atoms[index].getFontSize() / 8;
        }
      case '行右小書き':
      case '上付き小文字':
        final size = 0.6 * _currentFontSize;
        final offset = 0.2 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(size)
            ..offsetX = offset;
        }
      case '行左小書き':
      case '下付き小文字':
        final size = 0.6 * _currentFontSize;
        final offset = -0.2 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(size)
            ..offsetX = offset;
        }
      case '割り注占位':
        final size = 0.5 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          atoms[index]
            ..setFontSize(size)
            ..color = const Color(0x00000000);
        }
      case '割り注括弧':
        final advance = 0.5 * _currentFontSize;
        for (var index = start; index < end; index += 1) {
          final text = block.getAtomText(index);
          atoms[index]
            ..height = advance
            ..offsetY = openingBrackets.contains(text) ? -advance : 0;
        }
      case 'リンク':
        final color = (userData?.startsWith('#') ?? false)
            ? _theme.internalLinkColor
            : _theme.linkColor;
        for (var index = start; index < end; index += 1) {
          atoms[index].color = color;
        }
        block.userData.extras.add(
          LayoutExtra(
            endIndex: endIndex,
            startIndex: startIndex,
            type: 'リ',
            userData: userData ?? '',
          ),
        );
      default:
        if (RegExp(r'[１-５]段階(大き|小さ)な文字').hasMatch(style)) {
          var value = _getIntValue(style).toInt();
          if (value > 5) {
            value = 5;
          }
          final size = charAt(style, 3) == '大'
              ? _fontSize * math.pow(_fontScaleL, value)
              : _fontSize * math.pow(_fontScaleS, value);
          for (var index = start; index < end; index += 1) {
            atoms[index].setFontSize(size.toDouble());
          }
        }
    }
  }

  void _adjustRubies(LayoutTextBlock block, List<LayoutRuby> rubies) {
    final line = block.createTextLine();
    if (line == null) {
      return;
    }

    for (final ruby in rubies) {
      final start = block.splitAtom(ruby.startIndex);
      final end = block.splitAtom(ruby.endIndex);
      final startY = line.getAtomY(start, includeTrailingTracking: true);
      final segmentHeight = line.getAtomY(end) - startY;
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
        _applyStyle(rubyBlock, span.startIndex, span.endIndex, span.type);
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
          final tracking = overflow / (end - start + 1);
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

  void _attachWarichu(LayoutTextBlock block, LayoutExtra extra) {
    final body = extra.ruby ?? '';
    final startIndex = extra.startIndex ?? 0;
    final endIndex = extra.endIndex ?? startIndex;
    final innerStart = startIndex + 1;
    final innerEnd = math.max(innerStart, endIndex - 1);
    if (body.isEmpty || innerEnd <= innerStart) {
      return;
    }

    var consumed = 0;
    var line = block.getTextLineAtCharIndex(innerStart);
    while (line != null && consumed < body.length) {
      final lineStartOffset = block.atom[line.start].index;
      final lineEndOffset = _lineEndOffset(block, line);
      final segmentStart = math.max(innerStart, lineStartOffset);
      final segmentEnd = math.min(innerEnd, lineEndOffset);

      if (segmentEnd > segmentStart) {
        final segmentUnits = segmentEnd - segmentStart;
        final segmentChars = math.min(body.length - consumed, segmentUnits * 2);
        final segmentText = body.substring(consumed, consumed + segmentChars);
        consumed += segmentChars;

        final split = (segmentText.length + 1) ~/ 2;
        final upperLine = _buildWarichuLine(
          segmentText.substring(0, split),
          segmentUnits * _currentFontSize / 2,
        );
        final lowerLine = _buildWarichuLine(
          segmentText.substring(split),
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

        line.userData.add(
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
      final pageNo = _internalToDocumentPageNo(line.userData[0] as int);
      if (index.type.startsWith('#')) {
        _anchorList[index.type] = pageNo;
      } else {
        var label = block.rawtext.substring(index.startIndex, index.endIndex);
        if (index.type == '中見出し') {
          label = '　$label';
        } else if (index.type == '小見出し') {
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

    final single = _currentState.endsWith('single');
    final last = _lastDocumentPage;
    if (pageNo > last) {
      pageNo = last;
    }
    if (!single) {
      pageNo &= ~1;
    }

    _currentPageNo = pageNo;
    _clickable = <ClickableArea>[];
    onSnapshot(snapshot);
    onInvalidate();
  }

  void paint(ui.Canvas canvas) {
    if (_width <= 0 || _height <= 0 || _pageWidth <= 0 || _pageHeight <= 0) {
      return;
    }

    _clickable = <ClickableArea>[];
    _drawPaperSurface(canvas, Rect.fromLTWH(0, 0, _width, _height));

    final pageNo = _currentPageNo < 0 ? 0 : _currentPageNo;
    final single = _currentState.endsWith('single');
    final last = _lastDocumentPage;

    if (single) {
      if (_isCoverPage(pageNo)) {
        _showTopPage(canvas);
      } else {
        if (pageNo < last) {
          _showOnePage(
            canvas,
            _documentToInternalPageNo(pageNo + 1),
            true,
            backPage: true,
          );
        }
        _showOnePage(canvas, _documentToInternalPageNo(pageNo), true);
      }
    } else {
      canvas.save();
      canvas.drawLine(
        Offset(_width / 2, 0),
        Offset(_width / 2, _height),
        Paint()
          ..color = fontColor.withValues(alpha: 0.18)
          ..strokeWidth = 1,
      );
      canvas.restore();

      if (_currentState.startsWith('v')) {
        if (_isCoverPage(pageNo)) {
          _showTopPage(canvas);
        } else {
          if (pageNo > 0 && !_isCoverPage(pageNo - 1)) {
            _showOnePage(
              canvas,
              _documentToInternalPageNo(pageNo - 1),
              true,
              backPage: true,
            );
          }
          _showOnePage(canvas, _documentToInternalPageNo(pageNo), false);
        }
        if (pageNo < last - 1) {
          _showOnePage(
            canvas,
            _documentToInternalPageNo(pageNo + 2),
            false,
            backPage: true,
          );
        }
        if (pageNo < last) {
          _showOnePage(canvas, _documentToInternalPageNo(pageNo + 1), true);
        }
      } else {
        if (_isCoverPage(pageNo)) {
          _showTopPage(canvas);
        } else {
          if (pageNo > 0 && !_isCoverPage(pageNo - 1)) {
            _showOnePage(
              canvas,
              _documentToInternalPageNo(pageNo - 1),
              false,
              backPage: true,
            );
          }
          _showOnePage(canvas, _documentToInternalPageNo(pageNo), true);
        }
        if (pageNo < last - 1) {
          _showOnePage(
            canvas,
            _documentToInternalPageNo(pageNo + 2),
            true,
            backPage: true,
          );
        }
        if (pageNo < last) {
          _showOnePage(canvas, _documentToInternalPageNo(pageNo + 1), false);
        }
      }
    }

    _drawHeader(canvas);
  }

  void _drawPaperSurface(ui.Canvas canvas, Rect rect) {
    canvas.save();
    canvas.drawRect(rect, Paint()..color = paperColor);

    final texture = _paperTexture;
    final opacity = clampDouble(_theme.paperTextureOpacity, 0, 1);
    if (texture != null && opacity > 0) {
      final source = _coverImageSourceRect(texture, rect.size);
      canvas.clipRect(rect);
      canvas.drawImageRect(
        texture,
        source,
        rect,
        Paint()
          ..filterQuality = FilterQuality.medium
          ..colorFilter = ColorFilter.mode(
            paperColor.withValues(alpha: opacity),
            BlendMode.modulate,
          ),
      );
    }

    canvas.restore();
  }

  Rect _coverImageSourceRect(ui.Image image, Size outputSize) {
    final sourceSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.cover, sourceSize, outputSize);
    return Alignment.center.inscribe(fitted.source, Offset.zero & sourceSize);
  }

  void _drawHeader(ui.Canvas canvas) {
    if (_headerTitle.isEmpty || _isCoverPage(_currentPageNo)) {
      return;
    }

    var x = _pageMarginSide;
    final y = _pageMarginTop - 1.85 * _fontSize;
    var width = _currentState.endsWith('single')
        ? _width - _pageMarginSide - _fontSize
        : _currentState.startsWith('v')
        ? _pageWidth - _fontSize
        : _pageWidth;

    if (!_currentState.endsWith('single')) {
      x = _pageMarginSide + _fontSize;
    }

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(x, y, width, _pageMarginTop));
    final painter = TextPainter(
      text: TextSpan(
        text: _headerTitle,
        style: TextStyle(
          color: fontColor.withValues(alpha: _theme.isDark ? 0.64 : 0.5),
          fontFamily: gothicFontFamilies.first,
          fontFamilyFallback: gothicFontFamilies.sublist(1),
          package: bundledFontPackage,
          fontSize: 14,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout(maxWidth: width);
    painter.paint(canvas, Offset(x, y));
    canvas.restore();
  }

  void _showTopPage(ui.Canvas canvas) {
    if (_coverImage != null) {
      _showImageCoverPage(canvas, _coverImage!);
      return;
    }

    if (_cover == null) {
      return;
    }

    final center = _currentState.startsWith('v')
        ? (_width + (_currentState.endsWith('double') ? _width / 2 : 0)) / 2
        : _currentState.endsWith('double')
        ? _width / 4
        : _width / 2;

    final subtitle = _cover!.subtitle?.trim() ?? '';
    final credit = _cover!.credit?.trim() ?? '';

    final titlePainter = TextPainter(
      text: TextSpan(
        text: _cover!.title,
        style: TextStyle(
          color: _coverAccentColor.withValues(alpha: 0.82),
          fontFamily: gothicFontFamilies.first,
          fontFamilyFallback: gothicFontFamilies.sublist(1),
          package: bundledFontPackage,
          fontSize: _pageWidth * 0.16,
          fontWeight: FontWeight.w700,
          letterSpacing: _pageWidth * 0.02,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    titlePainter.paint(
      canvas,
      Offset(center - titlePainter.width / 2, _height * 0.18),
    );

    final subPainter = TextPainter(
      text: TextSpan(
        text: subtitle.isNotEmpty ? subtitle : credit,
        style: TextStyle(
          color: fontColor.withValues(alpha: _theme.isDark ? 0.68 : 0.55),
          fontFamily: gothicFontFamilies.first,
          fontFamilyFallback: gothicFontFamilies.sublist(1),
          package: bundledFontPackage,
          fontSize: _pageWidth * 0.035,
          letterSpacing: 1.5,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    if (subtitle.isNotEmpty || credit.isNotEmpty) {
      subPainter.paint(
        canvas,
        Offset(center - subPainter.width / 2, _height * 0.33),
      );
    }

    if (subtitle.isNotEmpty && credit.isNotEmpty) {
      final creditPainter = TextPainter(
        text: TextSpan(
          text: credit,
          style: TextStyle(
            color: _coverAccentColor.withValues(alpha: 0.58),
            fontFamily: gothicFontFamilies.first,
            fontFamilyFallback: gothicFontFamilies.sublist(1),
            package: bundledFontPackage,
            fontSize: _pageWidth * 0.04,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
      )..layout();
      creditPainter.paint(
        canvas,
        Offset(center - creditPainter.width / 2, _height * 0.9),
      );
    }
  }

  void _showImageCoverPage(ui.Canvas canvas, ui.Image image) {
    final destination = _coverPageRect();
    if (destination.width <= 0 || destination.height <= 0) {
      return;
    }

    final sourceSize = Size(image.width.toDouble(), image.height.toDouble());
    final fitted = applyBoxFit(BoxFit.contain, sourceSize, destination.size);
    final source = Alignment.center.inscribe(
      fitted.source,
      Offset.zero & sourceSize,
    );
    final output = Alignment.center.inscribe(fitted.destination, destination);

    canvas.save();
    canvas.clipRect(destination);
    canvas.drawImageRect(image, source, output, Paint());
    canvas.restore();
  }

  Rect _coverPageRect() {
    if (_currentState.startsWith('v')) {
      final x = _currentState.endsWith('double')
          ? _width - _pageMarginSide - _pageWidth
          : _pageMarginSide;
      return Rect.fromLTWH(x, _pageMarginTop, _pageWidth, _pageHeight);
    }

    return Rect.fromLTWH(
      _pageMarginSide,
      _pageMarginTop,
      _pageWidth,
      _pageHeight,
    );
  }

  void _showOnePage(
    ui.Canvas canvas,
    int pageNo,
    bool leftSide, {
    bool backPage = false,
  }) {
    final vertical = _currentState.startsWith('v');
    final pageStartLine = pageNo < _pages.length ? _pages[pageNo].line : 0;
    var cursor = vertical ? _pageWidth : 0.0;
    final endLine = pageNo + 1 < _pages.length
        ? _pages[pageNo + 1].line
        : _lines.length;

    canvas.save();
    if (backPage) {
      canvas.translate(_width, 0);
      canvas.scale(-1, 1);
    }

    if (backPage) {
      canvas.saveLayer(
        Rect.fromLTWH(0, 0, _width, _height),
        Paint()
          ..color =
              (_theme.isDark
                      ? const Color(0xff000000)
                      : const Color(0xffffffff))
                  .withValues(alpha: _settings.backPageAlpha),
      );
    }

    if (_pages[pageNo].centering) {
      var used = -_lineSpace;
      for (var lineIndex = pageStartLine; lineIndex < endLine; lineIndex += 1) {
        used += _lines[lineIndex].width + _lineSpace;
      }
      cursor = vertical
          ? _pageWidth - (_pageWidth - used) / 2
          : (_pageHeight - used) / 2;
    }

    for (var lineIndex = pageStartLine; lineIndex < endLine; lineIndex += 1) {
      final group = _lines[lineIndex];
      final lines = group.lines;

      for (final line in lines) {
        double x;
        double y;

        if (vertical) {
          x = leftSide
              ? cursor - line.width + _pageMarginSide
              : _width - _pageMarginSide - _pageWidth + cursor - line.width;
          y = _pageMarginTop;
          line.draw(canvas, x, y, backPage: backPage);
        } else {
          x = cursor + _pageMarginTop;
          y = leftSide
              ? _pageMarginSide
              : _width - _pageMarginSide - _pageWidth;
          line.drawYoko(canvas, y, x + line.width / 2, backPage: backPage);
        }

        line.x = x;

        for (var index = 1; index < line.userData.length; index += 1) {
          final item = line.userData[index];
          if (item is LayoutTextLine) {
            final kind = item.userData[0];
            final pointOffset = item.width == _fontSize ? _fontSize / 4 : 0;
            switch (kind) {
              case '右点':
                vertical
                    ? item.draw(canvas, x + line.width - pointOffset, y)
                    : item.drawYoko(
                        canvas,
                        y,
                        x - item.width / 2 + pointOffset,
                      );
              case '左点':
                vertical
                    ? item.draw(canvas, x - item.width + pointOffset, y)
                    : item.drawYoko(
                        canvas,
                        y,
                        x + line.width + item.width / 2 - pointOffset,
                      );
              case '※':
              case '注':
                vertical
                    ? item.draw(canvas, x - 0.45 * line.width, y)
                    : item.drawYoko(
                        canvas,
                        y,
                        x + 0.95 * line.width + item.width / 2,
                      );
              case 'る':
                item.color = _theme.rubyColor;
                vertical
                    ? item.draw(canvas, x - item.width, y)
                    : item.drawYoko(canvas, y, x + line.width + item.width / 2);
              case 'ル':
                item.color = _theme.rubyColor;
                vertical
                    ? item.draw(canvas, x + line.width, y)
                    : item.drawYoko(canvas, y, x - item.width / 2);
              case '返':
                final size = item.block.atom.first.getFontSize();
                vertical
                    ? item.draw(canvas, x - 0.2 * size, y)
                    : item.drawYoko(canvas, y, x + line.width - 0.3 * size);
              case '中':
                final size = item.block.atom.first.getFontSize();
                vertical
                    ? item.draw(canvas, x + line.width / 2 - size / 2, y)
                    : item.drawYoko(canvas, y, x + line.width / 2);
              case '送':
                final size = item.block.atom.first.getFontSize();
                vertical
                    ? item.draw(canvas, x + line.width - 0.8 * size, y)
                    : item.drawYoko(canvas, y, x + 0.3 * size);
            }
            continue;
          }

          if (item is WarichuMarker) {
            if (vertical) {
              item.upperLine?.draw(canvas, x + line.width / 2, y);
              item.lowerLine?.draw(
                canvas,
                x + line.width / 2 - (item.lowerLine?.width ?? 0),
                y,
              );
            } else {
              final upperCenter = x + (item.upperLine?.width ?? 0) / 2;
              final lowerCenter =
                  x + line.width - (item.lowerLine?.width ?? 0) / 2;
              item.upperLine?.drawYoko(canvas, y, upperCenter);
              item.lowerLine?.drawYoko(canvas, y, lowerCenter);
            }
            continue;
          }

          if (item is LinkMarker && !backPage) {
            final top = line.getAtomY(item.startAtom);
            final bottom = line.getAtomY(item.endAtom);
            _clickable.add(
              vertical
                  ? ClickableArea(
                      type: 'リンク',
                      x: x,
                      y: y + top + line.y,
                      width: line.width,
                      height: bottom - top,
                      data: item.userData,
                    )
                  : ClickableArea(
                      type: 'リンク',
                      x: y + top + line.y,
                      y: x,
                      width: bottom - top,
                      height: line.width,
                      data: item.userData,
                    ),
            );
            continue;
          }

          if (item is! SpanMarker && item is! NoteMarker) {
            continue;
          }

          canvas.save();
          final paint = Paint()
            ..color = fontColor
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke;

          if (item is SpanMarker) {
            switch (item.markType) {
              case '罫囲み始':
                if (vertical) {
                  final left = x;
                  final right = x + line.width / 2;
                  final top = item.top + y;
                  final bottom = item.bottom + y;
                  canvas.drawPath(
                    Path()
                      ..moveTo(left, top)
                      ..lineTo(right, top)
                      ..lineTo(right, bottom)
                      ..lineTo(left, bottom),
                    paint,
                  );
                } else {
                  final top = x + line.width;
                  final bottom = x + line.width / 2;
                  final left = item.top + y;
                  final right = item.bottom + y;
                  canvas.drawPath(
                    Path()
                      ..moveTo(left, top)
                      ..lineTo(left, bottom)
                      ..lineTo(right, bottom)
                      ..lineTo(right, top),
                    paint,
                  );
                }
              case '罫囲み終':
                if (vertical) {
                  var left = x + line.width;
                  if (lineIndex != pageStartLine) {
                    left += _lineSpace + 1;
                  }
                  final right = x + line.width / 2;
                  final top = item.top + y;
                  final bottom = item.bottom + y;
                  canvas.drawPath(
                    Path()
                      ..moveTo(left, top)
                      ..lineTo(right, top)
                      ..lineTo(right, bottom)
                      ..lineTo(left, bottom),
                    paint,
                  );
                } else {
                  var top = x;
                  if (lineIndex != pageStartLine) {
                    top -= _lineSpace + 1;
                  }
                  final bottom = x + line.width / 2;
                  final left = item.top + y;
                  final right = item.bottom + y;
                  canvas.drawPath(
                    Path()
                      ..moveTo(left, top)
                      ..lineTo(left, bottom)
                      ..lineTo(right, bottom)
                      ..lineTo(right, top),
                    paint,
                  );
                }
              case '罫囲み中':
                if (vertical) {
                  final left = x;
                  var right = x + line.width;
                  if (lineIndex != pageStartLine) {
                    right += _lineSpace + 1;
                  }
                  final top = item.top + y;
                  final bottom = item.bottom + y;
                  canvas.drawLine(Offset(left, top), Offset(right, top), paint);
                  canvas.drawLine(
                    Offset(left, bottom),
                    Offset(right, bottom),
                    paint,
                  );
                } else {
                  var top = x;
                  if (lineIndex != pageStartLine) {
                    top -= _lineSpace + 1;
                  }
                  final bottom = x + line.width;
                  final left = item.top + y;
                  final right = item.bottom + y;
                  canvas.drawLine(
                    Offset(left, top),
                    Offset(left, bottom),
                    paint,
                  );
                  canvas.drawLine(
                    Offset(right, top),
                    Offset(right, bottom),
                    paint,
                  );
                }
              case '罫囲み':
                if (vertical) {
                  final left = x - 1;
                  final right = x + line.width;
                  final top = item.top + y;
                  final bottom = item.bottom + y;
                  if (item.isStart ?? false) {
                    canvas.drawLine(
                      Offset(left, top),
                      Offset(right + 1, top),
                      paint,
                    );
                  }
                  if (item.isEnd ?? false) {
                    canvas.drawLine(
                      Offset(left, bottom),
                      Offset(right + 1, bottom),
                      paint,
                    );
                  }
                  canvas.drawLine(
                    Offset(left, top),
                    Offset(left, bottom + 1),
                    paint,
                  );
                  canvas.drawLine(
                    Offset(right, top),
                    Offset(right, bottom + 1),
                    paint,
                  );
                } else {
                  final top = x - 1;
                  final bottom = x + line.width;
                  final left = item.top + y;
                  final right = item.bottom + y;
                  if (item.isStart ?? false) {
                    canvas.drawLine(
                      Offset(left, top),
                      Offset(left, bottom),
                      paint,
                    );
                  }
                  if (item.isEnd ?? false) {
                    canvas.drawLine(
                      Offset(right, top),
                      Offset(right, bottom),
                      paint,
                    );
                  }
                  canvas.drawLine(Offset(left, top), Offset(right, top), paint);
                  canvas.drawLine(
                    Offset(left, bottom + 1),
                    Offset(right, bottom + 1),
                    paint,
                  );
                }
              case '右傍線':
              case '右二重傍線':
              case '右鎖線':
              case '右破線':
              case '右波線':
                final position = item.markType == '右波線'
                    ? x + line.width + 3
                    : x + line.width + 2;
                if (item.markType == '右鎖線') {
                  paint.strokeCap = StrokeCap.square;
                }
                if (vertical) {
                  if (item.markType == '右波線') {
                    _drawWavyLine(
                      canvas,
                      paint,
                      position,
                      item.top + y,
                      item.bottom + y,
                    );
                  } else {
                    canvas.drawLine(
                      Offset(position, item.top + y),
                      Offset(position, item.bottom + y),
                      paint,
                    );
                    if (item.markType == '右二重傍線') {
                      canvas.drawLine(
                        Offset(position + 3, item.top + y),
                        Offset(position + 3, item.bottom + y),
                        paint,
                      );
                    }
                  }
                } else if (item.markType == '右波線') {
                  _drawWavyLineYoko(
                    canvas,
                    paint,
                    position,
                    item.top + y,
                    item.bottom + y,
                  );
                } else {
                  canvas.drawLine(
                    Offset(item.top + y, position),
                    Offset(item.bottom + y, position),
                    paint,
                  );
                  if (item.markType == '右二重傍線') {
                    canvas.drawLine(
                      Offset(item.top + y, position + 3),
                      Offset(item.bottom + y, position + 3),
                      paint,
                    );
                  }
                }
              case '左傍線':
              case '左二重傍線':
              case '左鎖線':
              case '左破線':
              case '左波線':
                final position = item.markType == '左波線' ? x - 3 : x - 2;
                if (vertical) {
                  if (item.markType == '左波線') {
                    _drawWavyLine(
                      canvas,
                      paint,
                      position,
                      item.top + y,
                      item.bottom + y,
                    );
                  } else {
                    canvas.drawLine(
                      Offset(position, item.top + y),
                      Offset(position, item.bottom + y),
                      paint,
                    );
                    if (item.markType == '左二重傍線') {
                      canvas.drawLine(
                        Offset(position - 3, item.top + y),
                        Offset(position - 3, item.bottom + y),
                        paint,
                      );
                    }
                  }
                } else if (item.markType == '左波線') {
                  _drawWavyLineYoko(
                    canvas,
                    paint,
                    position,
                    item.top + y,
                    item.bottom + y,
                  );
                } else {
                  canvas.drawLine(
                    Offset(item.top + y, position),
                    Offset(item.bottom + y, position),
                    paint,
                  );
                  if (item.markType == '左二重傍線') {
                    canvas.drawLine(
                      Offset(item.top + y, position - 3),
                      Offset(item.bottom + y, position - 3),
                      paint,
                    );
                  }
                }
              case '取消線':
                final position = x + line.width / 2;
                if (vertical) {
                  canvas.drawLine(
                    Offset(position, item.top + y),
                    Offset(position, item.bottom + y),
                    paint,
                  );
                } else {
                  canvas.drawLine(
                    Offset(item.top + y, position),
                    Offset(item.bottom + y, position),
                    paint,
                  );
                }
            }
          }

          canvas.restore();
        }
      }

      cursor = vertical
          ? cursor - group.width - _lineSpace
          : cursor + group.width + _lineSpace;
    }

    if (pageNo > 0) {
      final label = '$pageNo/$_contentPageCount';
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
            color: fontColor,
            fontFamily: minchoFontFamilies.first,
            fontFamilyFallback: minchoFontFamilies.sublist(1),
            package: bundledFontPackage,
            fontSize: 0.9 * _fontSize,
          ),
        ),
        textAlign: TextAlign.left,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: TextScaler.noScaling,
      )..layout();

      if (_currentState.endsWith('single')) {
        painter.paint(
          canvas,
          Offset(
            _width / 2 - painter.width / 2,
            _height - _pageMarginBottom + _fontSize - painter.height / 2,
          ),
        );
      } else if (leftSide) {
        painter.paint(
          canvas,
          Offset(
            _pageMarginSide + _fontSize,
            _height - _pageMarginBottom + _fontSize - painter.height / 2,
          ),
        );
      } else {
        painter.paint(
          canvas,
          Offset(
            _width - _pageMarginSide - _fontSize - painter.width,
            _height - _pageMarginBottom + _fontSize - painter.height / 2,
          ),
        );
      }
    }

    if (backPage) {
      canvas.restore();
    }
    canvas.restore();
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
    final mask = _currentState.endsWith('double') ? ~1 : ~0;
    for (final chapter in _chapterList) {
      stops.add(chapter.pageNo & mask);
    }
    stops.sort();
    return stops;
  }

  PositionInfo _getPositionInfo([bool leftPage = false]) {
    var pageNo = _currentPageNo;
    if (leftPage && _currentState.endsWith('double')) {
      pageNo += 1;
    }
    if (_currentPageNo >= 0 && pageNo >= 0 && !_isCoverPage(pageNo)) {
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
        leftToRight: _currentState.startsWith('h'),
        length: 0,
        offset: line.block.atom[line.start].index,
        paragraphNo: _blocks.indexOf(line.block),
        shift1page: _shift1page,
      );
    }
    return _currentPosition;
  }
}
