import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

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
    this.imageLoader,
    this.initialPage = 0,
    this.spreadMode = KumihanSpreadMode.doublePage,
    this.layout = const KumihanBookLayoutData(),
    this.theme = const KumihanThemeData(),
    this.onSnapshotChanged,
  });

  final Document document;
  final KumihanPagedController? controller;
  final KumihanImageLoader? imageLoader;
  final int initialPage;
  final KumihanSpreadMode spreadMode;
  final KumihanBookLayoutData layout;
  final KumihanThemeData theme;
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

  @override
  void initState() {
    super.initState();
    _currentPage = _normalizePage(widget.initialPage, totalPages: 0);
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

    if (oldWidget.imageLoader != widget.imageLoader ||
        oldWidget.initialPage != widget.initialPage) {
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
      unawaited(_engine.updateLayout(_engineLayout(widget.layout)));
    }

    if (oldWidget.theme != widget.theme) {
      unawaited(_engine.updateTheme(widget.theme));
    }

    if (!identical(oldWidget.document, widget.document)) {
      _currentPage = _normalizePage(0, totalPages: _totalPages);
      unawaited(_engine.open(widget.document));
      return;
    }

    if (oldWidget.spreadMode != widget.spreadMode) {
      unawaited(showPage(_currentPage));
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(this);
    super.dispose();
  }

  KumihanEngine _createEngine() {
    return KumihanEngine(
      baseUri: null,
      imageLoader: widget.imageLoader,
      initialPage: _currentPage,
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
    return KumihanLayoutData(
      fontSize: layout.fontSize,
      pagePadding: layout.contentPadding,
    );
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
        return CustomPaint(
          painter: _KumihanBookPainter(
            currentPage: _currentPage,
            engine: _engine,
            layout: widget.layout,
            spreadMode: widget.spreadMode,
            theme: widget.theme,
            totalPages: _totalPages,
          ),
          size: size,
        );
      },
    );
  }
}

class _KumihanBookPainter extends CustomPainter {
  const _KumihanBookPainter({
    required this.currentPage,
    required this.engine,
    required this.layout,
    required this.spreadMode,
    required this.theme,
    required this.totalPages,
  });

  final int currentPage;
  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final KumihanSpreadMode spreadMode;
  final KumihanThemeData theme;
  final int totalPages;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    engine.resetPaintState();
    BookSpreadRenderer(
      engine: engine,
      layout: layout,
      theme: theme,
      spreadMode: spreadMode,
    ).paint(canvas, size, currentPage: currentPage, totalPages: totalPages);
  }

  @override
  bool shouldRepaint(covariant _KumihanBookPainter oldDelegate) {
    return oldDelegate.currentPage != currentPage ||
        oldDelegate.engine != engine ||
        oldDelegate.layout != layout ||
        oldDelegate.spreadMode != spreadMode ||
        oldDelegate.theme != theme ||
        oldDelegate.totalPages != totalPages;
  }
}
