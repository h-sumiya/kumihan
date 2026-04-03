import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'document.dart';
import 'engine/kumihan_scroll_engine.dart';
import 'kumihan_scroll_controller.dart';
import 'kumihan_types.dart';
import 'parsers/aozora_parser.dart';
import 'parsers/html_parser.dart';
import 'parsers/markdown_parser.dart';

class KumihanScrollCanvas extends StatefulWidget {
  const KumihanScrollCanvas({
    super.key,
    required this.document,
    this.controller,
    this.imageLoader,
    this.layout = const KumihanLayoutData(),
    this.onSnapshotChanged,
  });

  factory KumihanScrollCanvas.aozora({
    Key? key,
    required String text,
    KumihanScrollController? controller,
    KumihanImageLoader? imageLoader,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanScrollSnapshot>? onSnapshotChanged,
  }) {
    return KumihanScrollCanvas(
      key: key,
      document: const AozoraParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  factory KumihanScrollCanvas.markdown({
    Key? key,
    required String text,
    KumihanScrollController? controller,
    KumihanImageLoader? imageLoader,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanScrollSnapshot>? onSnapshotChanged,
  }) {
    return KumihanScrollCanvas(
      key: key,
      document: const MarkdownParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  factory KumihanScrollCanvas.html({
    Key? key,
    required String text,
    KumihanScrollController? controller,
    KumihanImageLoader? imageLoader,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanScrollSnapshot>? onSnapshotChanged,
  }) {
    return KumihanScrollCanvas(
      key: key,
      document: const HtmlParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  final Document document;
  final KumihanScrollController? controller;
  final KumihanImageLoader? imageLoader;
  final KumihanLayoutData layout;
  final ValueChanged<KumihanScrollSnapshot>? onSnapshotChanged;

  @override
  State<KumihanScrollCanvas> createState() => _KumihanScrollCanvasState();
}

class _KumihanScrollCanvasState extends State<KumihanScrollCanvas>
    implements KumihanScrollViewport {
  late KumihanScrollEngine _engine;
  late ScrollController _scrollController;
  Size _lastSize = Size.zero;
  KumihanSelectableGlyph? _selectionAnchor;
  KumihanSelectableGlyph? _selectionFocus;
  bool _selectionMode = false;
  bool _showSelectionToolbar = false;
  Offset? _selectionEndPosition;
  bool _alignToEnd = true;
  double? _pendingScrollOffset;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScrollChanged);
    _engine = _createEngine();
    widget.controller?.attach(this);
    unawaited(_engine.open(widget.document));
  }

  @override
  void didUpdateWidget(covariant KumihanScrollCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }

    if (oldWidget.imageLoader != widget.imageLoader) {
      _clearSelection();
      oldWidget.controller?.detach(this);
      _engine = _createEngine();
      widget.controller?.attach(this);
      _alignToEnd = true;
      if (_lastSize != Size.zero) {
        unawaited(_engine.resize(_lastSize.width, _lastSize.height));
      }
      unawaited(_engine.open(widget.document));
      return;
    }

    if (oldWidget.layout != widget.layout) {
      _clearSelection();
      _alignToEnd = true;
      unawaited(_engine.updateLayout(widget.layout));
    }

    if (!identical(oldWidget.document, widget.document)) {
      _clearSelection();
      _alignToEnd = true;
      unawaited(_engine.open(widget.document));
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _scrollController
      ..removeListener(_handleScrollChanged)
      ..dispose();
    super.dispose();
  }

  KumihanScrollEngine _createEngine() {
    return KumihanScrollEngine(
      baseUri: null,
      imageLoader: widget.imageLoader,
      layout: widget.layout,
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
        widget.controller?.updateSnapshot(snapshot);
        widget.onSnapshotChanged?.call(snapshot);
        _scheduleScrollAlignment(snapshot);
      },
    );
  }

  void _scheduleResize(Size size) {
    if (_lastSize == size) {
      return;
    }
    _clearSelection();
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_engine.resize(size.width, size.height));
    });
  }

  void _handleScrollChanged() {
    if (!_scrollController.hasClients) {
      return;
    }
    unawaited(_engine.updateScrollOffset(_scrollController.offset));
  }

  void _scheduleScrollAlignment(KumihanScrollSnapshot snapshot) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final target = _pendingScrollOffset;
      if (target != null) {
        _pendingScrollOffset = null;
        _scrollController.jumpTo(target.clamp(0.0, snapshot.maxScrollOffset));
        return;
      }

      if (_alignToEnd) {
        _alignToEnd = false;
        _scrollController.jumpTo(snapshot.maxScrollOffset);
      }
    });
  }

  @override
  Future<void> open(Document document) async {
    _alignToEnd = true;
    await _engine.open(document);
  }

  @override
  Future<void> resize(double width, double height) async {
    await _engine.resize(width, height);
  }

  @override
  Future<void> jumpTo(double offset) async {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(
        offset.clamp(0.0, _scrollController.position.maxScrollExtent),
      );
      return;
    }
    _pendingScrollOffset = offset;
  }

  @override
  Future<void> scrollBy(double delta) async {
    final current = _scrollController.hasClients ? _scrollController.offset : 0;
    await jumpTo(current + delta);
  }

  @override
  KumihanScrollSnapshot get snapshot => _engine.snapshot;

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
                  color: const Color(0x1a1a73e8),
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
        final viewportSize = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        _scheduleResize(viewportSize);
        final contentSize = Size(
          math.max(viewportSize.width, _engine.snapshot.contentWidth),
          viewportSize.height,
        );

        return RawScrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: contentSize.width,
              height: contentSize.height,
              child: GestureDetector(
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
                onTapUp: (details) {
                  if (!_selectionMode) {
                    return;
                  }
                  final hit = _findSelectableGlyph(details.localPosition);
                  if (hit == null || !_isSelectedGlyph(hit)) {
                    _clearSelection();
                  }
                },
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    CustomPaint(
                      painter: _KumihanScrollPainter(_engine),
                      size: contentSize,
                    ),
                    _buildSelectionOverlay(contentSize),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _KumihanScrollPainter extends CustomPainter {
  const _KumihanScrollPainter(this.engine);

  final KumihanScrollEngine engine;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    engine.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _KumihanScrollPainter oldDelegate) {
    return true;
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
