import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'ast.dart';
import 'engine/kumihan_engine.dart';
import 'kumihan_controller.dart';
import 'kumihan_types.dart';
import 'parsers/aozora_parser.dart';

class KumihanCanvas extends StatefulWidget {
  const KumihanCanvas({
    super.key,
    required this.data,
    this.controller,
    this.imageLoader,
    this.initialPage = 0,
    this.layout = const KumihanLayoutData(),
    this.onSnapshotChanged,
  });

  factory KumihanCanvas.aozora({
    Key? key,
    required String text,
    KumihanController? controller,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanSnapshot>? onSnapshotChanged,
  }) {
    return KumihanCanvas(
      key: key,
      data: const AozoraParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      initialPage: initialPage,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  final AstData data;
  final KumihanController? controller;
  final KumihanImageLoader? imageLoader;
  final int initialPage;
  final KumihanLayoutData layout;
  final ValueChanged<KumihanSnapshot>? onSnapshotChanged;

  @override
  State<KumihanCanvas> createState() => _KumihanCanvasState();
}

class _KumihanCanvasState extends State<KumihanCanvas> {
  late KumihanEngine _engine;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _engine = _createEngine();
    widget.controller?.attach(_engine);
    unawaited(_engine.open(widget.data));
  }

  @override
  void didUpdateWidget(covariant KumihanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(_engine);
      widget.controller?.attach(_engine);
    }

    final settingsChanged =
        oldWidget.initialPage != widget.initialPage ||
        oldWidget.imageLoader != widget.imageLoader;

    if (settingsChanged) {
      oldWidget.controller?.detach(_engine);
      _engine = _createEngine();
      widget.controller?.attach(_engine);
      if (_lastSize != Size.zero) {
        unawaited(_engine.resize(_lastSize.width, _lastSize.height));
      }
      unawaited(_engine.open(widget.data));
      return;
    }

    if (oldWidget.layout != widget.layout) {
      unawaited(_engine.updateLayout(widget.layout));
    }

    if (!identical(oldWidget.data, widget.data)) {
      unawaited(_engine.open(widget.data));
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(_engine);
    super.dispose();
  }

  KumihanEngine _createEngine() {
    return KumihanEngine(
      baseUri: null,
      imageLoader: widget.imageLoader,
      initialPage: widget.initialPage,
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
      },
    );
  }

  void _scheduleResize(Size size) {
    if (_lastSize == size) {
      return;
    }
    _lastSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      unawaited(_engine.resize(size.width, size.height));
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        _scheduleResize(size);
        return CustomPaint(painter: _KumihanPainter(_engine), size: size);
      },
    );
  }
}

class _KumihanPainter extends CustomPainter {
  const _KumihanPainter(this.engine);

  final KumihanEngine engine;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    engine.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _KumihanPainter oldDelegate) {
    return true;
  }
}
