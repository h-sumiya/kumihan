import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'ast_engine/kumihan_ast_engine.dart' hide KumihanImageLoader;
import 'engine/kumihan_engine.dart' show KumihanImageLoader;
import 'kumihan_controller.dart';
import 'kumihan_types.dart';
import 'parsers/aozora/ast.dart';
import 'parsers/aozora/ast_parser.dart';

class KumihanAstCanvas extends StatefulWidget {
  const KumihanAstCanvas({
    super.key,
    required this.data,
    this.controller,
    this.imageLoader,
    this.initialPage = 0,
    this.layout = const KumihanLayoutData(),
    this.onSnapshotChanged,
  });

  factory KumihanAstCanvas.aozora({
    Key? key,
    required String text,
    KumihanController? controller,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanSnapshot>? onSnapshotChanged,
  }) {
    return KumihanAstCanvas(
      key: key,
      data: const AozoraAstParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      initialPage: initialPage,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  final AozoraData data;
  final KumihanController? controller;
  final KumihanImageLoader? imageLoader;
  final int initialPage;
  final KumihanLayoutData layout;
  final ValueChanged<KumihanSnapshot>? onSnapshotChanged;

  @override
  State<KumihanAstCanvas> createState() => _KumihanAstCanvasState();
}

class _KumihanAstCanvasState extends State<KumihanAstCanvas> {
  late KumihanAstEngine _engine;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _engine = _createEngine();
    widget.controller?.attach(_engine);
    unawaited(_engine.openAst(widget.data));
  }

  @override
  void didUpdateWidget(covariant KumihanAstCanvas oldWidget) {
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
      unawaited(_engine.openAst(widget.data));
      return;
    }

    if (oldWidget.layout != widget.layout) {
      unawaited(_engine.updateLayout(widget.layout));
    }

    if (!identical(oldWidget.data, widget.data)) {
      unawaited(_engine.openAst(widget.data));
    }
  }

  @override
  void dispose() {
    widget.controller?.detach(_engine);
    super.dispose();
  }

  KumihanAstEngine _createEngine() {
    return KumihanAstEngine(
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
        return CustomPaint(painter: _KumihanAstPainter(_engine), size: size);
      },
    );
  }
}

class _KumihanAstPainter extends CustomPainter {
  const _KumihanAstPainter(this.engine);

  final KumihanAstEngine engine;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    engine.paint(canvas);
  }

  @override
  bool shouldRepaint(covariant _KumihanAstPainter oldDelegate) {
    return true;
  }
}
