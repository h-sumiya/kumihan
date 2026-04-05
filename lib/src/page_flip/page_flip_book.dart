import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'flip_calculation.dart';
import 'page_flip_controller.dart';
import 'page_flip_gutter_shadow.dart';
import 'page_flip_painter.dart';
import 'page_flip_types.dart';

class PageFlipActionRegion extends StatelessWidget {
  const PageFlipActionRegion({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: _pageFlipActionRegionMarker,
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}

const _pageFlipActionRegionMarker = _PageFlipActionRegionMarker();

final class _PageFlipActionRegionMarker {
  const _PageFlipActionRegionMarker();
}

class PageFlipBook extends StatefulWidget {
  const PageFlipBook({
    super.key,
    required this.pageCount,
    required this.pageBuilder,
    required this.pageSize,
    this.snapshotPageBuilder,
    this.controller,
    this.initialRightPageIndex = 0,
    this.flippingTime = const Duration(milliseconds: 1000),
    this.drawShadow = true,
    this.maxShadowOpacity = 0.35,
    this.bookColor = const Color(0xFFD7C8AE),
    this.pageBackgroundColor = const Color(0xFFFCFBF7),
    this.borderColor = const Color(0xFFBDB7AA),
    this.pageDensityBuilder,
    this.onSnapshotChanged,
    this.overlay,
  });

  final int pageCount;
  final IndexedWidgetBuilder pageBuilder;
  final IndexedWidgetBuilder? snapshotPageBuilder;
  final Size pageSize;
  final PageFlipController? controller;
  final int initialRightPageIndex;
  final Duration flippingTime;
  final bool drawShadow;
  final double maxShadowOpacity;
  final Color bookColor;
  final Color pageBackgroundColor;
  final Color borderColor;
  final PageDensity Function(int pageIndex)? pageDensityBuilder;
  final ValueChanged<PageFlipSnapshot>? onSnapshotChanged;
  final Widget? overlay;

  @override
  State<PageFlipBook> createState() => _PageFlipBookState();
}

class _PageFlipBookState extends State<PageFlipBook>
    with SingleTickerProviderStateMixin
    implements PageFlipViewport {
  static const Duration _tapMaxDuration = Duration(milliseconds: 250);
  static const double _tapSlop = 8;
  static const double _swipeGrabThreshold = 24;
  static const double _horizontalSwipeBias = 1.2;
  static const double _edgeGrabWidthRatio = 0.18;
  static const double _edgeGrabInsetRatio = 0.12;

  late final AnimationController _animationController;

  final Map<int, GlobalKey> _snapshotKeys = <int, GlobalKey>{};
  final Map<int, ui.Image> _pageImages = <int, ui.Image>{};
  final Set<int> _capturingPages = <int>{};

  int _rightPageIndex = 0;
  int _pageImageVersion = 0;
  int? _blockedPointer;
  int? _blockedPageIndex;
  FlipCalculation? _calculation;
  FlipDirection? _activeDirection;
  FlipCorner? _activeCorner;
  FlipScene? _scene;
  Offset? _touchStartPosition;
  Duration? _touchStartTimestamp;
  bool _isUserTouch = false;
  bool _isDragging = false;

  Offset? _animationStart;
  Offset? _animationEnd;
  bool _animationTurnsPage = false;

  @override
  void initState() {
    super.initState();
    _rightPageIndex = _normalizeRightPageIndex(widget.initialRightPageIndex);
    _animationController = AnimationController(vsync: this)
      ..addListener(_handleAnimationTick)
      ..addStatusListener(_handleAnimationStatus);
    widget.controller?.attach(this);
    _notifySnapshotChanged();
  }

  @override
  void didUpdateWidget(covariant PageFlipBook oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(this);
      widget.controller?.attach(this);
    }
    if (oldWidget.pageCount != widget.pageCount ||
        oldWidget.pageSize != widget.pageSize) {
      _disposeSnapshots();
      _rightPageIndex = _normalizeRightPageIndex(_rightPageIndex);
      _resetFlipState();
      _notifySnapshotChanged();
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    _animationController.dispose();
    _disposeSnapshots();
    super.dispose();
  }

  int get _renderPageCount {
    if (widget.pageCount.isEven) {
      return widget.pageCount;
    }
    return widget.pageCount + 1;
  }

  List<int> get _requiredSnapshotIndices {
    final candidates = <int>{
      _rightPageIndex - 2,
      _rightPageIndex - 1,
      _rightPageIndex,
      _rightPageIndex + 1,
      _rightPageIndex + 2,
      _rightPageIndex + 3,
    };
    return candidates
        .where((index) => index >= 0 && index < _renderPageCount)
        .toList()
      ..sort();
  }

  Set<int> get _livePageIndices {
    if (_scene != null) {
      return const <int>{};
    }
    return <int>{
      if (_rightPageIndex >= 0 && _rightPageIndex < _renderPageCount)
        _rightPageIndex,
      if (_rightPageIndex + 1 >= 0 && _rightPageIndex + 1 < _renderPageCount)
        _rightPageIndex + 1,
    };
  }

  PageDensity _gutterDensityForSpread(int rightPageIndex) {
    final visibleIndices = <int>[rightPageIndex, rightPageIndex + 1];
    for (final pageIndex in visibleIndices) {
      if (_densityForPage(pageIndex) == PageDensity.hard) {
        return PageDensity.hard;
      }
    }
    return PageDensity.soft;
  }

  bool _canFlipFrom(int rightPageIndex, FlipDirection direction) {
    if (direction == FlipDirection.back) {
      return rightPageIndex + 2 < _renderPageCount;
    }
    return rightPageIndex >= 2;
  }

  int _targetRightPageIndexFor(int rightPageIndex, FlipDirection direction) {
    final maxRightPageIndex = math.max(0, _renderPageCount - 2);
    return switch (direction) {
      FlipDirection.back => (rightPageIndex + 2).clamp(0, maxRightPageIndex),
      FlipDirection.forward => (rightPageIndex - 2).clamp(0, maxRightPageIndex),
    };
  }

  PageDensity _staticGutterDensityFor(int rightPageIndex) {
    if (_gutterDensityForSpread(rightPageIndex) == PageDensity.hard) {
      return PageDensity.hard;
    }

    if (_canFlipFrom(rightPageIndex, FlipDirection.back) &&
        _gutterDensityForSpread(
              _targetRightPageIndexFor(rightPageIndex, FlipDirection.back),
            ) ==
            PageDensity.hard) {
      return PageDensity.hard;
    }

    return PageDensity.soft;
  }

  PageDensity get _staticGutterDensity =>
      _staticGutterDensityFor(_rightPageIndex);

  PageDensity _animationGutterDensityFor(FlipDirection direction) {
    final targetRightPageIndex = _targetRightPageIndexFor(
      _rightPageIndex,
      direction,
    );
    return _staticGutterDensityFor(targetRightPageIndex);
  }

  PageDensity get _currentGutterDensity {
    final direction = _activeDirection;
    if (_scene != null && direction != null) {
      final sourceDensity = _staticGutterDensity;
      final targetDensity = _animationGutterDensityFor(direction);
      return _scene!.progress < 90 ? sourceDensity : targetDensity;
    }
    return _staticGutterDensity;
  }

  int _normalizeRightPageIndex(int pageIndex) {
    if (_renderPageCount <= 0) {
      return 0;
    }
    final maxRightPageIndex = math.max(0, _renderPageCount - 2);
    return pageIndex.clamp(0, maxRightPageIndex).toInt() & ~1;
  }

  PageFlipSnapshot _currentSnapshot() {
    return PageFlipSnapshot(
      rightPageIndex: _rightPageIndex,
      pageCount: widget.pageCount,
      isInteracting:
          _scene != null || _animationController.isAnimating || _isDragging,
    );
  }

  void _notifySnapshotChanged() {
    final snapshot = _currentSnapshot();
    widget.controller?.updateSnapshot(snapshot);
    widget.onSnapshotChanged?.call(snapshot);
  }

  @override
  Widget build(BuildContext context) {
    _scheduleSnapshotCapture();

    return SizedBox(
      width: widget.pageSize.width * 2,
      height: widget.pageSize.height,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        onPointerMove: _handlePointerMove,
        onPointerUp: _handlePointerUp,
        onPointerCancel: _handlePointerCancel,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            RepaintBoundary(
              child: CustomPaint(
                size: Size(widget.pageSize.width * 2, widget.pageSize.height),
                painter: PageFlipPainter(
                  pageImages: _pageImages,
                  pageImageVersion: _pageImageVersion,
                  rightPageIndex: _rightPageIndex,
                  pageCount: _renderPageCount,
                  pageSize: widget.pageSize,
                  scene: _scene,
                  staticGutterDensity: _currentGutterDensity,
                  bookColor: widget.bookColor,
                  pageBackgroundColor: widget.pageBackgroundColor,
                  borderColor: widget.borderColor,
                ),
              ),
            ),
            ..._buildLivePages(),
            if (_scene == null)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BookGutterShadowPainter(
                      pageWidth: widget.pageSize.width,
                      density: _currentGutterDensity,
                    ),
                  ),
                ),
              ),
            if (widget.overlay != null) Positioned.fill(child: widget.overlay!),
            Positioned(
              left: -widget.pageSize.width * 8,
              top: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: 0.01,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _requiredSnapshotIndices
                        .where(
                          (pageIndex) => !_livePageIndices.contains(pageIndex),
                        )
                        .map(_buildSnapshotHost)
                        .toList(growable: false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Future<void> nextSpread([int? amount]) async {
    await showRightPage(_rightPageIndex + 2 * (amount ?? 1));
  }

  @override
  Future<void> prevSpread([int? amount]) async {
    await showRightPage(_rightPageIndex - 2 * (amount ?? 1));
  }

  @override
  Future<void> showRightPage(int pageIndex) async {
    final normalized = _normalizeRightPageIndex(pageIndex);
    if (normalized == _rightPageIndex) {
      return;
    }
    _animationController.stop();
    _clearFlipSceneState();
    _clearTouchTracking();
    setState(() {
      _rightPageIndex = normalized;
    });
    _notifySnapshotChanged();
  }

  @override
  void cancelActiveTouch() {
    _clearBlockedInteraction();

    if (_scene != null || _isDragging) {
      _resetFlipState();
      _notifySnapshotChanged();
      return;
    }

    if (!_isUserTouch) {
      return;
    }

    _clearTouchTracking();
    _notifySnapshotChanged();
  }

  @override
  PageFlipSnapshot get snapshot => _currentSnapshot();

  List<Widget> _buildLivePages() {
    if (_scene != null) {
      return const <Widget>[];
    }

    return <Widget>[
      if (_rightPageIndex < _renderPageCount)
        _buildVisiblePage(
          pageIndex: _rightPageIndex,
          left: widget.pageSize.width,
        ),
      if (_rightPageIndex + 1 < _renderPageCount)
        _buildVisiblePage(pageIndex: _rightPageIndex + 1, left: 0),
    ];
  }

  Widget _buildVisiblePage({required int pageIndex, required double left}) {
    final key = _snapshotKeys.putIfAbsent(pageIndex, GlobalKey.new);
    return Positioned(
      left: left,
      top: 0,
      width: widget.pageSize.width,
      height: widget.pageSize.height,
      child: RepaintBoundary(key: key, child: _pageWidgetForIndex(pageIndex)),
    );
  }

  Widget _buildSnapshotHost(int pageIndex) {
    final key = _snapshotKeys.putIfAbsent(pageIndex, GlobalKey.new);
    return SizedBox(
      width: widget.pageSize.width,
      height: widget.pageSize.height,
      child: RepaintBoundary(
        key: key,
        child: _snapshotWidgetForIndex(pageIndex),
      ),
    );
  }

  Widget _pageWidgetForIndex(int pageIndex) {
    if (pageIndex >= widget.pageCount) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: widget.pageBackgroundColor,
          border: Border.all(color: widget.borderColor, width: 1.2),
        ),
      );
    }
    return widget.pageBuilder(context, pageIndex);
  }

  Widget _snapshotWidgetForIndex(int pageIndex) {
    if (pageIndex >= widget.pageCount) {
      return _pageWidgetForIndex(pageIndex);
    }
    final builder = widget.snapshotPageBuilder;
    if (builder == null) {
      return widget.pageBuilder(context, pageIndex);
    }
    return builder(context, pageIndex);
  }

  void _scheduleSnapshotCapture() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_captureRequiredSnapshots());
    });
  }

  Future<void> _captureRequiredSnapshots() async {
    final pixelRatio = View.of(context).devicePixelRatio;

    for (final pageIndex in _requiredSnapshotIndices) {
      if (_pageImages.containsKey(pageIndex) ||
          _capturingPages.contains(pageIndex)) {
        continue;
      }

      final boundary =
          _snapshotKeys[pageIndex]?.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null || boundary.debugNeedsPaint) {
        continue;
      }

      _capturingPages.add(pageIndex);
      try {
        final image = await boundary.toImage(pixelRatio: pixelRatio);
        if (!mounted) {
          image.dispose();
          return;
        }
        final oldImage = _pageImages[pageIndex];
        setState(() {
          _pageImages[pageIndex] = image;
          _pageImageVersion += 1;
        });
        oldImage?.dispose();
      } finally {
        _capturingPages.remove(pageIndex);
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_blockedPointer == event.pointer) {
      return;
    }
    if (_animationController.isAnimating) {
      return;
    }

    final bookPosition = _clampToBook(event.localPosition);
    final blockedPageIndex = _interactivePageIndexAt(bookPosition);
    if (blockedPageIndex != null) {
      _blockedPointer = event.pointer;
      _blockedPageIndex = blockedPageIndex;
      return;
    }

    _touchStartPosition = bookPosition;
    _touchStartTimestamp = event.timeStamp;
    _isUserTouch = true;
    _isDragging = false;
    _notifySnapshotChanged();

    if (!_isInEdgeGrabZone(bookPosition)) {
      return;
    }

    final grabPosition = _edgeGrabPositionFor(bookPosition);
    if (!_startFlip(grabPosition)) {
      _clearTouchTracking();
      _notifySnapshotChanged();
      return;
    }

    _isDragging = true;
    _notifySnapshotChanged();
    _updateFlip(grabPosition);
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (_blockedPointer == event.pointer) {
      return;
    }
    if (!_isUserTouch) {
      return;
    }

    final bookPosition = _clampToBook(event.localPosition);
    final touchStartPosition = _touchStartPosition;
    if (!_isDragging) {
      if (touchStartPosition == null ||
          !_shouldGrabFromSwipe(bookPosition - touchStartPosition)) {
        return;
      }
      if (!_startFlip(bookPosition)) {
        _clearTouchTracking();
        _notifySnapshotChanged();
        return;
      }
      _isDragging = true;
      _notifySnapshotChanged();
    }

    _updateFlip(bookPosition);
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (_blockedPointer == event.pointer) {
      _refreshBlockedPageSnapshot();
      return;
    }
    if (!_isUserTouch) {
      return;
    }

    final wasDragging = _isDragging;
    final touchStartPosition = _touchStartPosition;
    final touchStartTimestamp = _touchStartTimestamp;
    final bookPosition = _clampToBook(event.localPosition);

    _clearTouchTracking();
    _notifySnapshotChanged();

    if (wasDragging) {
      _settleFlip();
      return;
    }

    if (touchStartPosition == null || touchStartTimestamp == null) {
      return;
    }

    final isQuickTap =
        event.timeStamp - touchStartTimestamp <= _tapMaxDuration &&
        (bookPosition - touchStartPosition).distance <= _tapSlop;
    if (!isQuickTap || _isInEdgeGrabZone(touchStartPosition)) {
      return;
    }

    _handleTap(bookPosition);
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    if (_blockedPointer == event.pointer) {
      _clearBlockedInteraction();
      return;
    }
    if (!_isUserTouch && _scene == null) {
      return;
    }

    final wasDragging = _isDragging;
    _clearTouchTracking();
    _notifySnapshotChanged();
    if (!wasDragging) {
      return;
    }
    _resetFlipState();
  }

  void _handleTap(Offset position) {
    if (_animationController.isAnimating || _isDragging) {
      return;
    }

    if (!_startFlip(position)) {
      return;
    }

    final topMargin = widget.pageSize.height / 10;
    final yStart = _activeCorner == FlipCorner.bottom
        ? widget.pageSize.height - topMargin
        : topMargin;
    final yDest = _activeCorner == FlipCorner.bottom
        ? widget.pageSize.height
        : 0.0;

    final start = Offset(widget.pageSize.width - topMargin, yStart);
    _updateFromPagePosition(start);
    _animateFlipTo(
      start: start,
      destination: Offset(-widget.pageSize.width, yDest),
      turnsPage: true,
    );
  }

  bool _startFlip(Offset bookPosition) {
    _clearFlipSceneState();

    final direction = _directionForPoint(bookPosition);
    if (!_canFlip(direction)) {
      return false;
    }

    _activeDirection = direction;
    _activeCorner = bookPosition.dy >= widget.pageSize.height / 2
        ? FlipCorner.bottom
        : FlipCorner.top;
    _calculation = FlipCalculation(
      direction: direction,
      corner: _activeCorner!,
      pageWidth: widget.pageSize.width,
      pageHeight: widget.pageSize.height,
    );
    _notifySnapshotChanged();
    return true;
  }

  void _updateFlip(Offset bookPosition) {
    if (_activeDirection == null) {
      return;
    }
    final pagePosition = _convertToPage(bookPosition, _activeDirection!);
    _updateFromPagePosition(pagePosition);
  }

  void _updateFromPagePosition(Offset pagePosition) {
    final calculation = _calculation;
    final direction = _activeDirection;
    final corner = _activeCorner;
    if (calculation == null || direction == null || corner == null) {
      return;
    }

    if (!calculation.calc(pagePosition)) {
      return;
    }

    final progress = calculation.getFlippingProgress();
    final density = _drawingDensityFor(direction);
    final hardAngle = switch (direction) {
      FlipDirection.forward => 90 * (200 - progress * 2) / 100,
      FlipDirection.back => -90 * (200 - progress * 2) / 100,
    };

    ShadowData? shadow;
    if (widget.drawShadow) {
      try {
        shadow = ShadowData(
          position: calculation.getShadowStartPoint(),
          angle: calculation.getShadowAngle(),
          width: ((widget.pageSize.width * 3) / 4) * progress / 100,
          opacity:
              ((100 - progress) * (100 * widget.maxShadowOpacity)) / 100 / 100,
          direction: direction,
          progress: progress * 2,
        );
      } catch (_) {
        shadow = null;
      }
    }

    try {
      final nextScene = FlipScene(
        direction: direction,
        corner: corner,
        density: density,
        pageRect: calculation.getRect(),
        bottomClipArea: calculation.getBottomClipArea(),
        flippingClipArea: calculation.getFlippingClipArea(),
        bottomPagePosition: calculation.getBottomPagePosition(),
        activeCorner: calculation.getActiveCorner(),
        pagePosition: calculation.getPosition(),
        angle: calculation.getAngle(),
        hardAngle: hardAngle,
        progress: progress,
        shadow: shadow,
      );

      setState(() {
        _scene = nextScene;
      });
      _notifySnapshotChanged();
    } catch (_) {
      // Ignore intermediate invalid geometries near hard bounds.
    }
  }

  void _settleFlip() {
    final scene = _scene;
    if (scene == null) {
      _resetFlipState();
      return;
    }

    final y = scene.corner == FlipCorner.bottom ? widget.pageSize.height : 0.0;
    if (scene.pagePosition.dx <= 0) {
      _animateFlipTo(
        start: scene.pagePosition,
        destination: Offset(-widget.pageSize.width, y),
        turnsPage: true,
      );
    } else {
      _animateFlipTo(
        start: scene.pagePosition,
        destination: Offset(widget.pageSize.width, y),
        turnsPage: false,
      );
    }
  }

  void _animateFlipTo({
    required Offset start,
    required Offset destination,
    required bool turnsPage,
  }) {
    _animationController.stop();
    _animationStart = start;
    _animationEnd = destination;
    _animationTurnsPage = turnsPage;

    final pathLength = math.max(
      (start.dx - destination.dx).abs(),
      (start.dy - destination.dy).abs(),
    );
    final duration = pathLength >= 1000
        ? widget.flippingTime
        : widget.flippingTime * (pathLength / 1000);

    _animationController.duration = duration;
    _animationController.forward(from: 0);
    _notifySnapshotChanged();
  }

  void _handleAnimationTick() {
    final start = _animationStart;
    final end = _animationEnd;
    if (start == null || end == null) {
      return;
    }
    final position = Offset.lerp(start, end, _animationController.value);
    if (position != null) {
      _updateFromPagePosition(position);
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }

    if (_animationTurnsPage && _activeDirection != null) {
      setState(() {
        if (_activeDirection == FlipDirection.back) {
          _rightPageIndex = (_rightPageIndex + 2).clamp(
            0,
            _renderPageCount - 2,
          );
        } else {
          _rightPageIndex = (_rightPageIndex - 2).clamp(
            0,
            _renderPageCount - 2,
          );
        }
      });
    }

    _resetFlipState();
    _notifySnapshotChanged();
  }

  Offset _convertToPage(Offset bookPosition, FlipDirection direction) {
    final x = direction == FlipDirection.forward
        ? bookPosition.dx - widget.pageSize.width
        : widget.pageSize.width - bookPosition.dx;
    return Offset(x, bookPosition.dy);
  }

  Offset _clampToBook(Offset point) {
    const epsilon = 0.001;
    return Offset(
      point.dx.clamp(epsilon, widget.pageSize.width * 2 - epsilon),
      point.dy.clamp(epsilon, widget.pageSize.height - epsilon),
    );
  }

  bool _isInEdgeGrabZone(Offset bookPosition) {
    final edgeWidth = (widget.pageSize.width * _edgeGrabWidthRatio).clamp(
      24.0,
      64.0,
    );
    return bookPosition.dx <= edgeWidth ||
        bookPosition.dx >= widget.pageSize.width * 2 - edgeWidth;
  }

  bool _shouldGrabFromSwipe(Offset delta) {
    return delta.dx.abs() >= _swipeGrabThreshold &&
        delta.dx.abs() >= delta.dy.abs() * _horizontalSwipeBias;
  }

  Offset _edgeGrabPositionFor(Offset bookPosition) {
    final edgeInset = math.min(
      widget.pageSize.width * _edgeGrabInsetRatio,
      32.0,
    );
    final x = bookPosition.dx < widget.pageSize.width
        ? edgeInset
        : widget.pageSize.width * 2 - edgeInset;
    return Offset(x, bookPosition.dy);
  }

  FlipDirection _directionForPoint(Offset bookPosition) {
    if (bookPosition.dx < widget.pageSize.width) {
      return FlipDirection.back;
    }
    return FlipDirection.forward;
  }

  bool _canFlip(FlipDirection direction) {
    if (direction == FlipDirection.back) {
      return _rightPageIndex + 2 < _renderPageCount;
    }
    return _rightPageIndex >= 2;
  }

  int _flippingPageIndexFor(FlipDirection direction) {
    return direction == FlipDirection.back
        ? _rightPageIndex + 2
        : _rightPageIndex - 1;
  }

  PageDensity _densityForPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex >= _renderPageCount) {
      return PageDensity.soft;
    }
    return widget.pageDensityBuilder?.call(pageIndex) ?? PageDensity.soft;
  }

  PageDensity _drawingDensityFor(FlipDirection direction) {
    final flippingPageIndex = _flippingPageIndexFor(direction);
    final flippingDensity = _densityForPage(flippingPageIndex);
    final neighborIndex = direction == FlipDirection.back
        ? flippingPageIndex - 1
        : flippingPageIndex + 1;
    if (_densityForPage(neighborIndex) != flippingDensity) {
      return PageDensity.hard;
    }
    return flippingDensity;
  }

  void _resetFlipState() {
    _clearFlipSceneState();
    _clearTouchTracking();
    if (mounted) {
      setState(() {});
    }
  }

  void _clearTouchTracking() {
    _touchStartPosition = null;
    _touchStartTimestamp = null;
    _isUserTouch = false;
    _isDragging = false;
  }

  void _clearFlipSceneState() {
    _animationStart = null;
    _animationEnd = null;
    _animationTurnsPage = false;
    _calculation = null;
    _activeDirection = null;
    _activeCorner = null;
    _scene = null;
  }

  int? _interactivePageIndexAt(Offset bookPosition) {
    if (_scene != null) {
      return null;
    }

    final pageIndex = _pageIndexForBookPosition(bookPosition);
    if (pageIndex == null || !_livePageIndices.contains(pageIndex)) {
      return null;
    }

    final boundary =
        _snapshotKeys[pageIndex]?.currentContext?.findRenderObject()
            as RenderBox?;
    if (boundary == null) {
      return null;
    }

    final result = BoxHitTestResult();
    if (!boundary.hitTest(result, position: _localPagePosition(bookPosition))) {
      return null;
    }

    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData &&
          identical(target.metaData, _pageFlipActionRegionMarker)) {
        return pageIndex;
      }
    }

    return null;
  }

  int? _pageIndexForBookPosition(Offset bookPosition) {
    if (bookPosition.dx < widget.pageSize.width) {
      final leftPageIndex = _rightPageIndex + 1;
      return leftPageIndex < _renderPageCount ? leftPageIndex : null;
    }
    return _rightPageIndex < _renderPageCount ? _rightPageIndex : null;
  }

  Offset _localPagePosition(Offset bookPosition) {
    if (bookPosition.dx < widget.pageSize.width) {
      return bookPosition;
    }
    return Offset(bookPosition.dx - widget.pageSize.width, bookPosition.dy);
  }

  void _refreshBlockedPageSnapshot() {
    final pageIndex = _blockedPageIndex;
    _clearBlockedInteraction();
    if (pageIndex == null) {
      return;
    }
    _scheduleSnapshotRefresh(pageIndex);
  }

  void _clearBlockedInteraction() {
    _blockedPointer = null;
    _blockedPageIndex = null;
  }

  void _scheduleSnapshotRefresh(int pageIndex) {
    final oldImage = _pageImages.remove(pageIndex);
    oldImage?.dispose();
    _capturingPages.remove(pageIndex);
    _pageImageVersion += oldImage == null ? 0 : 1;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_captureSnapshotFor(pageIndex));
    });
  }

  Future<void> _captureSnapshotFor(int pageIndex) async {
    final boundary =
        _snapshotKeys[pageIndex]?.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null || boundary.debugNeedsPaint) {
      return;
    }
    if (_capturingPages.contains(pageIndex)) {
      return;
    }

    final pixelRatio = View.of(context).devicePixelRatio;
    _capturingPages.add(pageIndex);
    try {
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      if (!mounted) {
        image.dispose();
        return;
      }
      final oldImage = _pageImages[pageIndex];
      setState(() {
        _pageImages[pageIndex] = image;
        _pageImageVersion += 1;
      });
      oldImage?.dispose();
    } finally {
      _capturingPages.remove(pageIndex);
    }
  }

  void _disposeSnapshots() {
    for (final image in _pageImages.values) {
      image.dispose();
    }
    _pageImages.clear();
    _snapshotKeys.clear();
    _capturingPages.clear();
    _pageImageVersion = 0;
  }

  int get debugRightPageIndex => _rightPageIndex;

  bool get debugIsDragging => _isDragging;

  PageDensity get debugStaticGutterDensity => _staticGutterDensity;

  PageDensity get debugCurrentGutterDensity => _currentGutterDensity;
}

final class _BookGutterShadowPainter extends CustomPainter {
  const _BookGutterShadowPainter({
    required this.pageWidth,
    required this.density,
  });

  final double pageWidth;
  final PageDensity density;

  @override
  void paint(Canvas canvas, Size size) {
    paintBookGutterShadow(
      canvas,
      size: size,
      pageWidth: pageWidth,
      density: density,
    );
  }

  @override
  bool shouldRepaint(covariant _BookGutterShadowPainter oldDelegate) {
    return oldDelegate.pageWidth != pageWidth || oldDelegate.density != density;
  }
}
