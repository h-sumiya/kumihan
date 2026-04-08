import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'book/book_spread_renderer.dart';
import 'document.dart';
import 'engine/kumihan_engine.dart';
import 'kumihan_paged_controller.dart';
import 'kumihan_theme.dart';
import 'kumihan_types.dart';

class KumihanBookCanvas extends StatefulWidget {
  const KumihanBookCanvas({
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
    this.onSnapshotChanged,
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
  final ValueChanged<KumihanPagedSnapshot>? onSnapshotChanged;

  @override
  State<KumihanBookCanvas> createState() => _KumihanBookCanvasState();
}

class _KumihanBookCanvasState extends State<KumihanBookCanvas>
    implements KumihanPagedViewport {
  late KumihanEngine _engine;
  Size _lastPageSize = Size.zero;
  int _currentPage = 0;
  int _totalPages = 0;
  int _lastSnapshotPage = 0;
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
  void didUpdateWidget(covariant KumihanBookCanvas oldWidget) {
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

    if (oldWidget.spreadMode != widget.spreadMode) {
      _clearSelection();
      unawaited(showPage(_currentPage));
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
        if (normalized != snapshot.currentPage) {
          unawaited(_engine.showPage(normalized));
        }
      },
    );
  }

  KumihanLayoutData _engineLayout(KumihanBookLayoutData layout) {
    return KumihanLayoutData(fontSize: layout.fontSize);
  }

  int get _step => widget.spreadMode == KumihanSpreadMode.doublePage ? 2 : 1;

  int _normalizePage(int page, {required int totalPages}) {
    if (totalPages <= 0) {
      return 0;
    }
    final lastPage = math.max(totalPages - 1, 0);
    final clamped = page.clamp(0, lastPage).toInt();
    if (widget.spreadMode == KumihanSpreadMode.doublePage) {
      return clamped & ~1;
    }
    return clamped;
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
    await showPage(_currentPage + (amount ?? _step));
  }

  @override
  Future<void> prevPage([int? amount]) async {
    await showPage(math.max(_currentPage - (amount ?? _step), 0));
  }

  @override
  Future<void> showPage(int page) async {
    final normalized = _normalizePage(page, totalPages: _totalPages);
    _currentPage = normalized;
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
      await _engine.showPage(normalized);
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
      await _engine.showPage(normalized);
    }
  }

  @override
  Future<void> resize(double width, double height) async {
    await _engine.resize(width, height);
  }

  @override
  KumihanPagedSnapshot get snapshot =>
      KumihanPagedSnapshot(currentPage: _currentPage, totalPages: _totalPages);

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

  Offset _globalToLocal(Offset globalPosition) {
    final renderObject = context.findRenderObject();
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

  Widget _buildSelectionOverlay(Size size) {
    final rects = _selectionRects;
    if (!_selectionMode || rects.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: <Widget>[
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
      child: _SelectionToolbar(
        onCopy: _copySelection,
        onClose: _clearSelection,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final renderer = BookSpreadRenderer(
          engine: _engine,
          layout: widget.layout,
          theme: widget.theme,
          spreadMode: widget.spreadMode,
        );
        _scheduleResize(renderer.resolvePageSize(size));
        final paint = SizedBox.expand(
          child: widget.spreadMode == KumihanSpreadMode.doublePage
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  textDirection: TextDirection.rtl,
                  children: <Widget>[
                    Expanded(
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: _KumihanBookPagePainter(
                            currentPage: _currentPage,
                            engine: _engine,
                            globalViewportOrigin: Offset(size.width / 2, 0),
                            layout: widget.layout,
                            resetPaintState: true,
                            slot: BookPageSlot.right,
                            spreadMode: widget.spreadMode,
                            theme: widget.theme,
                            totalPages: _totalPages,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: SizedBox.expand(
                        child: CustomPaint(
                          painter: _KumihanBookPagePainter(
                            currentPage: _currentPage,
                            engine: _engine,
                            globalViewportOrigin: Offset.zero,
                            layout: widget.layout,
                            resetPaintState: false,
                            slot: BookPageSlot.left,
                            spreadMode: widget.spreadMode,
                            theme: widget.theme,
                            totalPages: _totalPages,
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : CustomPaint(
                  painter: _KumihanBookPagePainter(
                    currentPage: _currentPage,
                    engine: _engine,
                    globalViewportOrigin: Offset.zero,
                    layout: widget.layout,
                    resetPaintState: true,
                    slot: BookPageSlot.single,
                    spreadMode: widget.spreadMode,
                    theme: widget.theme,
                    totalPages: _totalPages,
                  ),
                ),
        );
        if (!widget.selectable) {
          return paint;
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onLongPressStart: (details) {
            _startSelection(details.localPosition);
          },
          onLongPressMoveUpdate: (details) {
            _updateSelection(
              _globalToLocal(details.globalPosition),
              allowNearest: true,
            );
          },
          onLongPressEnd: (details) {
            _finishSelection(_globalToLocal(details.globalPosition));
          },
          onTapUp: _selectionMode
              ? (details) {
                  final hit = _findSelectableGlyph(details.localPosition);
                  if (hit == null || !_isSelectedGlyph(hit)) {
                    _clearSelection();
                  }
                }
              : null,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[paint, _buildSelectionOverlay(size)],
          ),
        );
      },
    );
  }
}

class _KumihanBookPagePainter extends CustomPainter {
  const _KumihanBookPagePainter({
    required this.currentPage,
    required this.engine,
    required this.globalViewportOrigin,
    required this.layout,
    required this.resetPaintState,
    required this.slot,
    required this.spreadMode,
    required this.theme,
    required this.totalPages,
  });

  final int currentPage;
  final KumihanEngine engine;
  final Offset globalViewportOrigin;
  final KumihanBookLayoutData layout;
  final bool resetPaintState;
  final BookPageSlot slot;
  final KumihanSpreadMode spreadMode;
  final KumihanThemeData theme;
  final int totalPages;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    if (resetPaintState) {
      engine.resetPaintState();
    }
    final renderer = BookSpreadRenderer(
      engine: engine,
      layout: layout,
      theme: theme,
      spreadMode: spreadMode,
    );
    renderer.paintViewport(
      canvas,
      size,
      viewportSlot: slot,
      globalViewportOrigin: globalViewportOrigin,
      currentPage: currentPage,
      totalPages: totalPages,
    );
  }

  @override
  bool shouldRepaint(covariant _KumihanBookPagePainter oldDelegate) {
    return oldDelegate.currentPage != currentPage ||
        oldDelegate.engine != engine ||
        oldDelegate.globalViewportOrigin != globalViewportOrigin ||
        oldDelegate.layout != layout ||
        oldDelegate.resetPaintState != resetPaintState ||
        oldDelegate.slot != slot ||
        oldDelegate.spreadMode != spreadMode ||
        oldDelegate.theme != theme ||
        oldDelegate.totalPages != totalPages;
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
