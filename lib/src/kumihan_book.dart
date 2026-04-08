import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'book/book_spread_renderer.dart';
import 'book/kumihan_book_defaults.dart';
import 'book/kumihan_book_page_surface.dart';
import 'document.dart';
import 'engine/kumihan_engine.dart';
import 'kumihan_paged_controller.dart';
import 'kumihan_theme.dart';
import 'kumihan_types.dart';
import 'page_flip/page_flip_book.dart';
import 'page_flip/page_flip_controller.dart';
import 'page_flip/page_flip_types.dart';

enum _BookRenderPageKind { desk, frontCover, content, blank, backCover }

final class _BookRenderPage {
  const _BookRenderPage.content(this.documentPageIndex)
    : kind = _BookRenderPageKind.content;

  const _BookRenderPage.frontCover()
    : kind = _BookRenderPageKind.frontCover,
      documentPageIndex = null;

  const _BookRenderPage.desk()
    : kind = _BookRenderPageKind.desk,
      documentPageIndex = null;

  const _BookRenderPage.blank()
    : kind = _BookRenderPageKind.blank,
      documentPageIndex = null;

  const _BookRenderPage.backCover()
    : kind = _BookRenderPageKind.backCover,
      documentPageIndex = null;

  final _BookRenderPageKind kind;
  final int? documentPageIndex;

  bool get isHard =>
      kind == _BookRenderPageKind.frontCover ||
      kind == _BookRenderPageKind.backCover;
}

class KumihanBook extends StatefulWidget {
  const KumihanBook({
    super.key,
    required this.document,
    this.controller,
    this.baseUri,
    this.imageLoader,
    this.initialPage = 0,
    this.maxPages,
    this.spreadMode = KumihanSpreadMode.doublePage,
    this.layout = const KumihanBookLayoutData(),
    this.theme = const KumihanThemeData(),
    this.selectable = true,
    this.onLinkTap,
    this.onSnapshotChanged,
    this.frontCover,
    this.backCover,
    this.desk,
    this.blankPage,
    this.singlePageEdge,
  }) : assert(maxPages == null || maxPages > 0);

  final Document document;
  final KumihanPagedController? controller;
  final Uri? baseUri;
  final KumihanImageLoader? imageLoader;
  final int initialPage;
  final int? maxPages;
  final KumihanSpreadMode spreadMode;
  final KumihanBookLayoutData layout;
  final KumihanThemeData theme;
  final bool selectable;
  final ValueChanged<String>? onLinkTap;
  final ValueChanged<KumihanPagedSnapshot>? onSnapshotChanged;
  final Widget? frontCover;
  final Widget? backCover;
  final Widget? desk;
  final Widget? blankPage;
  final Widget? singlePageEdge;

  @override
  State<KumihanBook> createState() => _KumihanBookState();
}

class _KumihanBookState extends State<KumihanBook>
    implements KumihanPagedViewport {
  final PageFlipController _pageFlipController = PageFlipController();
  final GlobalKey _spreadKey = GlobalKey();

  late KumihanEngine _engine;
  Size _lastPageSize = Size.zero;
  int _currentPage = 0;
  int _totalPages = 0;
  int _lastSnapshotPage = 0;
  bool _isFlipping = false;
  KumihanSelectableGlyph? _selectionAnchor;
  KumihanSelectableGlyph? _selectionFocus;
  bool _selectionMode = false;
  bool _showSelectionToolbar = false;
  Offset? _selectionEndPosition;

  @override
  void initState() {
    super.initState();
    _currentPage = _normalizePage(widget.initialPage, totalPages: 0);
    _lastSnapshotPage = _currentPage;
    _engine = _createEngine();
    widget.controller?.attach(this);
    unawaited(_engine.open(widget.document));
  }

  @override
  void didUpdateWidget(covariant KumihanBook oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }

    if (oldWidget.baseUri != widget.baseUri ||
        oldWidget.imageLoader != widget.imageLoader ||
        oldWidget.initialPage != widget.initialPage ||
        oldWidget.maxPages != widget.maxPages) {
      _clearSelection();
      oldWidget.controller?.detach(this);
      _currentPage = _normalizePage(
        widget.initialPage,
        totalPages: _totalPages,
      );
      _engine = _createEngine();
      widget.controller?.attach(this);
      if (_lastPageSize != Size.zero) {
        unawaited(_engine.resize(_lastPageSize.width, _lastPageSize.height));
      }
      unawaited(_engine.open(widget.document));
      return;
    }

    if (oldWidget.layout != widget.layout) {
      _clearSelection();
      unawaited(_engine.updateLayout(_engineLayout(widget.layout)));
    }

    if (oldWidget.theme != widget.theme) {
      _clearSelection();
      unawaited(_engine.updateTheme(widget.theme));
    }

    if (!identical(oldWidget.document, widget.document)) {
      _clearSelection();
      _currentPage = _normalizePage(0, totalPages: _totalPages);
      unawaited(_engine.open(widget.document));
      return;
    }

    final compositionChanged =
        oldWidget.spreadMode != widget.spreadMode ||
        (oldWidget.frontCover == null) != (widget.frontCover == null) ||
        (oldWidget.backCover == null) != (widget.backCover == null) ||
        (oldWidget.blankPage == null) != (widget.blankPage == null);
    if (compositionChanged) {
      _clearSelection();
      _currentPage = _normalizePage(_currentPage, totalPages: _totalPages);
      unawaited(
        _pageFlipController.showRightPage(
          _renderIndexForDocumentPage(_currentPage),
        ),
      );
    }

    if (oldWidget.selectable && !widget.selectable) {
      _clearSelection(notify: false);
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    super.dispose();
  }

  KumihanEngine _createEngine() {
    return KumihanEngine(
      baseUri: widget.baseUri,
      imageLoader: widget.imageLoader,
      initialPage: _currentPage,
      maxPages: widget.maxPages,
      layout: _engineLayout(widget.layout),
      theme: widget.theme,
      onInvalidate: () {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
      onSnapshot: (snapshot) {
        if (!mounted) {
          return;
        }
        final normalized = _normalizePage(
          snapshot.currentPage,
          totalPages: snapshot.totalPages,
        );
        if (_lastSnapshotPage != normalized) {
          _clearSelection(notify: false);
        }
        _lastSnapshotPage = normalized;
        _currentPage = normalized;
        _totalPages = snapshot.totalPages;
        final pagedSnapshot = KumihanPagedSnapshot(
          currentPage: normalized,
          totalPages: snapshot.totalPages,
        );
        widget.controller?.updateSnapshot(pagedSnapshot);
        widget.onSnapshotChanged?.call(pagedSnapshot);
        final activeRenderPage = _pageFlipController.snapshot.rightPageIndex;
        if (_isContentVisibleAtSpread(activeRenderPage)) {
          final targetRenderPage = _renderIndexForDocumentPage(normalized);
          if (activeRenderPage != targetRenderPage) {
            unawaited(_pageFlipController.showRightPage(targetRenderPage));
          }
        }
      },
    );
  }

  KumihanLayoutData _engineLayout(KumihanBookLayoutData layout) {
    return KumihanLayoutData(fontSize: layout.fontSize);
  }

  bool get _isSingleSpread => widget.spreadMode == KumihanSpreadMode.single;

  int get _pageStep => _isSingleSpread ? 1 : 2;

  bool get _useDeskBoards =>
      !_isSingleSpread &&
      (widget.frontCover != null || widget.backCover != null);

  int get _contentRenderStartIndex {
    var index = 0;
    if (_useDeskBoards) {
      index += 1;
    }
    if (widget.frontCover != null) {
      index += 1;
    }
    return index;
  }

  bool get _needsBlankRenderPage => !_isSingleSpread && _totalPages.isOdd;

  int get _blankRenderPageIndex =>
      _needsBlankRenderPage ? _contentRenderStartIndex + _totalPages : -1;

  int get _backCoverRenderPageIndex {
    if (widget.backCover == null) {
      return -1;
    }
    return _contentRenderStartIndex +
        _totalPages +
        (_needsBlankRenderPage ? 1 : 0);
  }

  int get _trailingDeskRenderPageIndex {
    if (!_useDeskBoards) {
      return -1;
    }
    return _contentRenderStartIndex +
        _totalPages +
        (_needsBlankRenderPage ? 1 : 0) +
        (widget.backCover == null ? 0 : 1);
  }

  List<_BookRenderPage> get _renderPages {
    final pages = <_BookRenderPage>[];
    if (_useDeskBoards) {
      pages.add(const _BookRenderPage.desk());
    }
    if (widget.frontCover != null) {
      pages.add(const _BookRenderPage.frontCover());
    }
    for (var pageIndex = 0; pageIndex < _totalPages; pageIndex += 1) {
      pages.add(_BookRenderPage.content(pageIndex));
    }
    if (_needsBlankRenderPage) {
      pages.add(const _BookRenderPage.blank());
    }
    if (widget.backCover != null) {
      pages.add(const _BookRenderPage.backCover());
    }
    if (_useDeskBoards) {
      pages.add(const _BookRenderPage.desk());
    }
    return pages;
  }

  int get _composedPageCount => _renderPages.length;

  int? _documentPageAtRenderIndex(int renderPageIndex) {
    final documentPageIndex = renderPageIndex - _contentRenderStartIndex;
    if (documentPageIndex < 0 || documentPageIndex >= _totalPages) {
      return null;
    }
    return documentPageIndex;
  }

  int _renderIndexForDocumentPage(int documentPageIndex) {
    if (_totalPages <= 0) {
      return 0;
    }
    final normalizedDocumentPage = documentPageIndex
        .clamp(0, _totalPages - 1)
        .toInt();
    final rawRenderIndex = _contentRenderStartIndex + normalizedDocumentPage;
    final spreadIndex = _isSingleSpread ? rawRenderIndex : rawRenderIndex & ~1;
    final lastRenderIndex = math.max(_composedPageCount - 1, 0);
    return spreadIndex.clamp(0, lastRenderIndex).toInt();
  }

  int _documentPageForRenderSpreadIndex(int renderSpreadIndex) {
    if (_totalPages <= 0) {
      return 0;
    }

    final rightDocumentPage = _documentPageAtRenderIndex(renderSpreadIndex);
    final leftDocumentPage = _isSingleSpread
        ? null
        : _documentPageAtRenderIndex(renderSpreadIndex + 1);

    if (_isSingleSpread) {
      if (rightDocumentPage != null) {
        return rightDocumentPage;
      }
    } else {
      if (rightDocumentPage != null && rightDocumentPage.isEven) {
        return rightDocumentPage;
      }
      if (leftDocumentPage != null && leftDocumentPage.isEven) {
        return leftDocumentPage;
      }
      if (rightDocumentPage != null) {
        return _normalizePage(rightDocumentPage, totalPages: _totalPages);
      }
      if (leftDocumentPage != null) {
        return _normalizePage(leftDocumentPage, totalPages: _totalPages);
      }
    }

    if (renderSpreadIndex < _contentRenderStartIndex) {
      return 0;
    }
    return _totalPages - 1;
  }

  bool _isContentVisibleAtSpread(int renderSpreadIndex) {
    if (_documentPageAtRenderIndex(renderSpreadIndex) != null) {
      return true;
    }
    if (!_isSingleSpread &&
        _documentPageAtRenderIndex(renderSpreadIndex + 1) != null) {
      return true;
    }
    return false;
  }

  Widget _buildDefaultBlankPage() {
    return KumihanDefaultBlankBookPage(
      title: _engine.headerTitle,
      theme: widget.theme,
    );
  }

  Widget _buildRenderPageWidget(
    BuildContext context,
    int renderPageIndex, {
    required bool recordInteractiveRegions,
    required bool resetPaintState,
  }) {
    if (renderPageIndex == 0 && _useDeskBoards) {
      return KeyedSubtree(
        key: const ValueKey<String>('kumihan-book-desk-front'),
        child: widget.desk ?? const KumihanDefaultBookDesk(),
      );
    }
    if (renderPageIndex == _contentRenderStartIndex - 1 &&
        widget.frontCover != null) {
      return widget.frontCover!;
    }
    if (renderPageIndex == _blankRenderPageIndex) {
      return widget.blankPage ?? _buildDefaultBlankPage();
    }
    if (renderPageIndex == _backCoverRenderPageIndex &&
        widget.backCover != null) {
      return widget.backCover!;
    }
    if (renderPageIndex == _trailingDeskRenderPageIndex && _useDeskBoards) {
      return KeyedSubtree(
        key: const ValueKey<String>('kumihan-book-desk-back'),
        child: widget.desk ?? const KumihanDefaultBookDesk(),
      );
    }

    final documentPageIndex = _documentPageAtRenderIndex(renderPageIndex);
    if (documentPageIndex == null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: widget.theme.paperColor,
          border: Border.all(color: const Color(0xFFBDB7AA), width: 1.2),
        ),
      );
    }

    return KumihanBookPageSurface(
      engine: _engine,
      layout: widget.layout,
      pageIndex: documentPageIndex,
      recordInteractiveRegions: recordInteractiveRegions,
      resetPaintState: resetPaintState,
      theme: widget.theme,
      totalPages: _totalPages,
      spreadMode: widget.spreadMode,
    );
  }

  PageDensity _densityForRenderPage(int renderPageIndex) {
    final pages = _renderPages;
    if (renderPageIndex < 0 || renderPageIndex >= pages.length) {
      return PageDensity.soft;
    }
    return pages[renderPageIndex].isHard ? PageDensity.hard : PageDensity.soft;
  }

  int _normalizePage(int page, {required int totalPages}) {
    if (totalPages <= 0) {
      return 0;
    }
    final lastPage = math.max(totalPages - 1, 0);
    final clamped = page.clamp(0, lastPage).toInt();
    if (_isSingleSpread) {
      return clamped;
    }
    return clamped & ~1;
  }

  void _scheduleResize(Size pageSize) {
    if (_lastPageSize == pageSize) {
      return;
    }
    _clearSelection();
    _lastPageSize = pageSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_engine.resize(pageSize.width, pageSize.height));
    });
  }

  @override
  Future<void> open(Document document) async {
    _currentPage = _normalizePage(0, totalPages: _totalPages);
    await _engine.open(document);
  }

  @override
  Future<void> nextPage([int? amount]) async {
    await showPage(_currentPage + _pageStep * (amount ?? 1));
  }

  @override
  Future<void> prevPage([int? amount]) async {
    await showPage(_currentPage - _pageStep * (amount ?? 1));
  }

  @override
  Future<void> showPage(int page) async {
    final normalized = _normalizePage(page, totalPages: _totalPages);
    _currentPage = normalized;
    await _pageFlipController.showRightPage(
      _renderIndexForDocumentPage(normalized),
    );
    await _engine.showPage(normalized);
  }

  @override
  Future<void> showFirstPage() async {
    await showPage(0);
  }

  @override
  Future<void> showLastPage() async {
    await showPage(math.max(_totalPages - 1, 0));
  }

  @override
  Future<void> nextStop() async {
    await _engine.nextStop();
    final normalized = _normalizePage(
      _engine.snapshot.currentPage,
      totalPages: _totalPages,
    );
    if (normalized != _engine.snapshot.currentPage) {
      await showPage(normalized);
    }
  }

  @override
  Future<void> prevStop() async {
    await _engine.prevStop();
    final normalized = _normalizePage(
      _engine.snapshot.currentPage,
      totalPages: _totalPages,
    );
    if (normalized != _engine.snapshot.currentPage) {
      await showPage(normalized);
    }
  }

  @override
  Future<void> resize(double width, double height) async {
    await _engine.resize(width, height);
  }

  @override
  KumihanPagedSnapshot get snapshot =>
      KumihanPagedSnapshot(currentPage: _currentPage, totalPages: _totalPages);

  void _handlePageFlipSnapshotChanged(PageFlipSnapshot snapshot) {
    if (_isFlipping != snapshot.isInteracting) {
      setState(() {
        _isFlipping = snapshot.isInteracting;
      });
    }
    if (!_isContentVisibleAtSpread(snapshot.rightPageIndex)) {
      _clearSelection(notify: false);
    }

    final documentPage = _documentPageForRenderSpreadIndex(
      snapshot.rightPageIndex,
    );
    if (documentPage == _currentPage) {
      return;
    }
    _currentPage = documentPage;
    unawaited(_engine.showPage(documentPage));
  }

  void _clearSelection({bool notify = true}) {
    if (!_selectionMode &&
        _selectionAnchor == null &&
        _selectionFocus == null) {
      return;
    }
    if (!notify) {
      _selectionMode = false;
      _showSelectionToolbar = false;
      _selectionEndPosition = null;
      _selectionAnchor = null;
      _selectionFocus = null;
      return;
    }
    setState(() {
      _selectionMode = false;
      _showSelectionToolbar = false;
      _selectionEndPosition = null;
      _selectionAnchor = null;
      _selectionFocus = null;
    });
  }

  KumihanSelectableGlyph? _findSelectableGlyph(
    Offset position, {
    bool allowNearest = false,
  }) {
    final glyphs = _engine.selectableGlyphs;
    if (glyphs.isEmpty) {
      return null;
    }

    KumihanSelectableGlyph? nearest;
    var nearestDistance = double.infinity;
    for (final glyph in glyphs) {
      if (glyph.hitTest(position)) {
        return glyph;
      }

      if (!allowNearest) {
        continue;
      }

      final dx = position.dx < glyph.rect.left
          ? glyph.rect.left - position.dx
          : position.dx > glyph.rect.right
          ? position.dx - glyph.rect.right
          : 0.0;
      final dy = position.dy < glyph.rect.top
          ? glyph.rect.top - position.dy
          : position.dy > glyph.rect.bottom
          ? position.dy - glyph.rect.bottom
          : 0.0;
      final distance = dx * dx + dy * dy;
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = glyph;
      }
    }

    return nearest;
  }

  void _startSelection(Offset position) {
    final next = _findSelectableGlyph(position);
    if (next == null) {
      return;
    }
    setState(() {
      _selectionMode = true;
      _showSelectionToolbar = false;
      _selectionEndPosition = position;
      _selectionAnchor = next;
      _selectionFocus = next;
    });
  }

  void _updateSelection(Offset position, {bool allowNearest = false}) {
    final next = _findSelectableGlyph(position, allowNearest: allowNearest);
    if (next == null || identical(next, _selectionFocus)) {
      if (next != null) {
        setState(() {
          _selectionEndPosition = position;
        });
      }
      return;
    }
    setState(() {
      _selectionMode = true;
      _showSelectionToolbar = false;
      _selectionEndPosition = position;
      _selectionFocus = next;
    });
  }

  void _finishSelection(Offset position) {
    if (!_selectionMode || _selectionFocus == null) {
      return;
    }
    setState(() {
      _selectionEndPosition = position;
      _showSelectionToolbar = true;
    });
  }

  Offset _globalToSpreadLocal(Offset globalPosition) {
    final renderObject = _spreadKey.currentContext?.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(globalPosition);
    }
    return globalPosition;
  }

  bool _isSelectedGlyph(KumihanSelectableGlyph glyph) {
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (anchor == null || focus == null) {
      return false;
    }

    final start = math.min(anchor.order, focus.order);
    final end = math.max(anchor.order, focus.order);
    return glyph.order >= start && glyph.order <= end;
  }

  List<KumihanSelectableGlyph> get _selectedGlyphs {
    final anchor = _selectionAnchor;
    final focus = _selectionFocus;
    if (anchor == null || focus == null) {
      return const <KumihanSelectableGlyph>[];
    }

    final glyphs = _engine.selectableGlyphs;
    final start = math.min(anchor.order, focus.order);
    final end = math.max(anchor.order, focus.order);
    return glyphs
        .where((glyph) => glyph.order >= start && glyph.order <= end)
        .toList(growable: false);
  }

  List<Rect> get _selectionRects {
    final glyphs = _selectedGlyphs;
    if (glyphs.isEmpty) {
      return const <Rect>[];
    }

    final rects = <Rect>[];
    Rect? current;
    for (final glyph in glyphs) {
      final rect = glyph.rect;
      if (current == null) {
        current = rect;
        continue;
      }

      if (_shouldMergeSelectionRects(current, rect)) {
        current = current.expandToInclude(rect);
        continue;
      }

      rects.add(current);
      current = rect;
    }

    if (current != null) {
      rects.add(current);
    }
    return rects;
  }

  bool _shouldMergeSelectionRects(Rect current, Rect next) {
    final sameColumn =
        (current.left - next.left).abs() < 1.0 &&
        (current.width - next.width).abs() < 1.0;
    final sameRow =
        (current.top - next.top).abs() < 1.0 &&
        (current.height - next.height).abs() < 1.0;

    final verticalGap = next.top - current.bottom;
    final horizontalGap = next.left - current.right;
    final verticalMergeThreshold = math.max(
      4.0,
      math.min(current.height, next.height) * 0.9,
    );
    final horizontalMergeThreshold = math.max(
      4.0,
      math.min(current.width, next.width) * 0.9,
    );

    final verticalOverlap =
        math.min(current.bottom, next.bottom) - math.max(current.top, next.top);
    final horizontalOverlap =
        math.min(current.right, next.right) - math.max(current.left, next.left);

    final verticallyContinuous =
        verticalGap <= verticalMergeThreshold && horizontalOverlap > 0;
    final horizontallyContinuous =
        horizontalGap <= horizontalMergeThreshold && verticalOverlap > 0;

    return (sameColumn && verticallyContinuous) ||
        (sameRow && horizontallyContinuous);
  }

  Future<void> _copySelection() async {
    final text = _selectedGlyphs.map((glyph) => glyph.text).join();
    if (text.isEmpty) {
      return;
    }
    if (mounted) {
      _clearSelection();
    }
    await Clipboard.setData(ClipboardData(text: text));
  }

  Future<void> _handleClickableAreaTap(ClickableArea clickable) async {
    _clearSelection();
    final target = clickable.data;
    if (target.startsWith('#')) {
      final page = _engine.resolveAnchorPage(target);
      if (page != null) {
        await showPage(page);
      }
      return;
    }
    widget.onLinkTap?.call(target);
  }

  Widget _buildSelectionOverlay(Size size) {
    final rects = _selectionRects;
    if (!_selectionMode || rects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: <Widget>[
        if (_showSelectionToolbar)
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (_) {
                _pageFlipController.cancelActiveTouch();
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clearSelection,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        for (final rect in rects)
          Positioned.fromRect(
            rect: rect.inflate(2),
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0x331a73e8),
                  border: Border.all(color: const Color(0xff1a73e8), width: 2),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        if (_showSelectionToolbar) ...[_buildSelectionToolbar(size)],
      ],
    );
  }

  Widget _buildSelectionToolbar(Size size) {
    final focus = _selectionFocus;
    if (focus == null) {
      return const SizedBox.shrink();
    }

    const toolbarWidth = 116.0;
    const toolbarHeight = 36.0;
    final anchor = _selectionEndPosition ?? focus.rect.center;
    final left = (anchor.dx - toolbarWidth / 2)
        .clamp(8.0, math.max(8.0, size.width - toolbarWidth - 8))
        .toDouble();

    final preferredTop = anchor.dy - toolbarHeight - 12;
    final fallbackTop = focus.rect.bottom + 8;
    final top = preferredTop >= 8 ? preferredTop : fallbackTop;
    final toolbarTop = top
        .clamp(8.0, math.max(8.0, size.height - toolbarHeight - 8))
        .toDouble();

    return Positioned(
      left: left,
      top: toolbarTop,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) {
          _pageFlipController.cancelActiveTouch();
        },
        child: _SelectionToolbar(
          onCopy: _copySelection,
          onClose: _clearSelection,
        ),
      ),
    );
  }

  List<Rect> _bodyRectsFor(Size pageSize) {
    if (_isSingleSpread) {
      final renderer = BookSpreadRenderer(
        engine: _engine,
        layout: widget.layout,
        theme: widget.theme,
        spreadMode: KumihanSpreadMode.single,
      );
      return <Rect>[renderer.resolveBodyRect(pageSize, BookPageSlot.single)];
    }

    final renderer = BookSpreadRenderer(
      engine: _engine,
      layout: widget.layout,
      theme: widget.theme,
      spreadMode: KumihanSpreadMode.doublePage,
    );
    final leftRect = renderer.resolveBodyRect(pageSize, BookPageSlot.left);
    final rightRect = renderer
        .resolveBodyRect(pageSize, BookPageSlot.right)
        .shift(Offset(pageSize.width, 0));
    return <Rect>[leftRect, rightRect];
  }

  Widget _buildSelectionRegion(Rect rect) {
    return Positioned.fromRect(
      rect: rect,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPressStart: (details) {
          _pageFlipController.cancelActiveTouch();
          _startSelection(details.localPosition + rect.topLeft);
        },
        onLongPressMoveUpdate: (details) {
          _updateSelection(
            _globalToSpreadLocal(details.globalPosition),
            allowNearest: true,
          );
        },
        onLongPressEnd: (details) {
          _finishSelection(_globalToSpreadLocal(details.globalPosition));
        },
        onTapUp: (details) {
          if (!_selectionMode) {
            return;
          }
          final position = details.localPosition + rect.topLeft;
          final hit = _findSelectableGlyph(position);
          if (hit == null || !_isSelectedGlyph(hit)) {
            _clearSelection();
          }
        },
        child: const SizedBox.expand(),
      ),
    );
  }

  Size _interactiveOverlaySizeFor(Size pageSize) {
    return _isSingleSpread
        ? Size(pageSize.width, pageSize.height)
        : Size(pageSize.width * 2, pageSize.height);
  }

  Widget _buildInteractiveLayer(Size pageSize) {
    final bodyRects = _bodyRectsFor(pageSize);
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _selectionMode
          ? (_) {
              _pageFlipController.cancelActiveTouch();
            }
          : null,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (widget.selectable)
            for (final rect in bodyRects) _buildSelectionRegion(rect),
          for (final clickable in _engine.clickableAreas)
            Positioned.fromRect(
              rect: Rect.fromLTWH(
                clickable.x,
                clickable.y,
                clickable.width,
                clickable.height,
              ),
              child: Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (_) {
                  _pageFlipController.cancelActiveTouch();
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => unawaited(_handleClickableAreaTap(clickable)),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          _buildSelectionOverlay(_interactiveOverlaySizeFor(pageSize)),
        ],
      ),
    );
  }

  Widget? _buildPageFlipOverlay(Size pageSize) {
    final interactiveLayer = !_isFlipping
        ? _buildInteractiveLayer(pageSize)
        : null;
    final edgeOverlay = _isSingleSpread && widget.singlePageEdge != null
        ? KumihanSinglePageEdgeOverlay(edge: widget.singlePageEdge!)
        : null;

    if (interactiveLayer == null && edgeOverlay == null) {
      return null;
    }
    if (interactiveLayer == null) {
      return edgeOverlay;
    }
    if (edgeOverlay == null) {
      return interactiveLayer;
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[interactiveLayer, edgeOverlay],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final renderer = BookSpreadRenderer(
          engine: _engine,
          layout: widget.layout,
          theme: widget.theme,
          spreadMode: widget.spreadMode,
        );
        final enginePageSize = renderer.resolvePageSize(availableSize);
        _scheduleResize(enginePageSize);
        final pageSize = _isSingleSpread
            ? availableSize
            : Size(availableSize.width / 2, availableSize.height);
        final spreadSize = _isSingleSpread
            ? pageSize
            : Size(pageSize.width * 2, pageSize.height);

        return SizedBox.expand(
          child: Center(
            child: SizedBox(
              key: _spreadKey,
              width: spreadSize.width,
              height: spreadSize.height,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  PageFlipBook(
                    controller: _pageFlipController,
                    pageCount: _composedPageCount,
                    pageSize: pageSize,
                    displayMode: _isSingleSpread
                        ? PageDisplayMode.singlePage
                        : PageDisplayMode.doublePage,
                    pageDensityBuilder: _densityForRenderPage,
                    onSnapshotChanged: _handlePageFlipSnapshotChanged,
                    snapshotPageBuilder: (context, pageIndex) {
                      return _buildRenderPageWidget(
                        context,
                        pageIndex,
                        recordInteractiveRegions: false,
                        resetPaintState: false,
                      );
                    },
                    pageBuilder: (context, pageIndex) {
                      final documentPage = _documentPageAtRenderIndex(
                        pageIndex,
                      );
                      return _buildRenderPageWidget(
                        context,
                        pageIndex,
                        recordInteractiveRegions: true,
                        resetPaintState: documentPage == _currentPage,
                      );
                    },
                    overlay: _buildPageFlipOverlay(pageSize),
                    interactionEnabled: !_showSelectionToolbar,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  const _SelectionToolbar({required this.onCopy, required this.onClose});

  final Future<void> Function() onCopy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: const TextStyle(
        color: Color(0xffffffff),
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xe6000000),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ToolbarButton(label: 'コピー', onTap: () => unawaited(onCopy())),
              const SizedBox(width: 4),
              _ToolbarButton(label: '閉じる', onTap: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({required this.label, required this.onTap});

  final String label;
  final GestureTapCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(label),
      ),
    );
  }
}
