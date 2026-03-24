import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'engine/kumihan_engine.dart';
import 'kumihan_controller.dart';
import 'kumihan_document.dart';
import 'kumihan_theme.dart';
import 'kumihan_types.dart';
import 'parsers/aozora_parser.dart';
import 'parsers/html_parser.dart';
import 'parsers/markdown_parser.dart';

class KumihanCanvas extends StatefulWidget {
  const KumihanCanvas({
    super.key,
    required this.document,
    this.controller,
    this.coverImage,
    this.imageLoader,
    this.initialPage = 0,
    this.initialSpread = KumihanSpreadMode.doublePage,
    this.initialWritingMode = KumihanWritingMode.vertical,
    this.layout = const KumihanLayoutData(),
    this.theme = const KumihanThemeData(),
    this.onExternalOpen,
    this.onSnapshotChanged,
  });

  factory KumihanCanvas.aozora({
    Key? key,
    required String text,
    String? title,
    String? author,
    KumihanController? controller,
    ImageProvider<Object>? coverImage,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanSpreadMode initialSpread = KumihanSpreadMode.doublePage,
    KumihanWritingMode initialWritingMode = KumihanWritingMode.vertical,
    KumihanLayoutData layout = const KumihanLayoutData(),
    KumihanThemeData theme = const KumihanThemeData(),
    ValueChanged<String>? onExternalOpen,
    ValueChanged<KumihanSnapshot>? onSnapshotChanged,
    bool includeCover = false,
  }) {
    return KumihanCanvas(
      key: key,
      document: KumihanAozoraParser(
        author: author,
        includeCover: includeCover,
        title: title,
      ).parse(text),
      controller: controller,
      coverImage: coverImage,
      imageLoader: imageLoader,
      initialPage: initialPage,
      initialSpread: initialSpread,
      initialWritingMode: initialWritingMode,
      layout: layout,
      theme: theme,
      onExternalOpen: onExternalOpen,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  factory KumihanCanvas.markdown({
    Key? key,
    required String text,
    String? title,
    String? author,
    KumihanController? controller,
    ImageProvider<Object>? coverImage,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanSpreadMode initialSpread = KumihanSpreadMode.doublePage,
    KumihanWritingMode initialWritingMode = KumihanWritingMode.vertical,
    KumihanLayoutData layout = const KumihanLayoutData(),
    KumihanThemeData theme = const KumihanThemeData(),
    ValueChanged<String>? onExternalOpen,
    ValueChanged<KumihanSnapshot>? onSnapshotChanged,
    bool includeCover = false,
  }) {
    return KumihanCanvas(
      key: key,
      document: KumihanMarkdownParser(
        author: author,
        includeCover: includeCover,
        title: title,
      ).parse(text),
      controller: controller,
      coverImage: coverImage,
      imageLoader: imageLoader,
      initialPage: initialPage,
      initialSpread: initialSpread,
      initialWritingMode: initialWritingMode,
      layout: layout,
      theme: theme,
      onExternalOpen: onExternalOpen,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  factory KumihanCanvas.html({
    Key? key,
    required String text,
    String? title,
    String? author,
    KumihanController? controller,
    ImageProvider<Object>? coverImage,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanSpreadMode initialSpread = KumihanSpreadMode.doublePage,
    KumihanWritingMode initialWritingMode = KumihanWritingMode.vertical,
    KumihanLayoutData layout = const KumihanLayoutData(),
    KumihanThemeData theme = const KumihanThemeData(),
    ValueChanged<String>? onExternalOpen,
    ValueChanged<KumihanSnapshot>? onSnapshotChanged,
    bool includeCover = false,
  }) {
    return KumihanCanvas(
      key: key,
      document: KumihanHtmlParser(
        author: author,
        includeCover: includeCover,
        title: title,
      ).parse(text),
      controller: controller,
      coverImage: coverImage,
      imageLoader: imageLoader,
      initialPage: initialPage,
      initialSpread: initialSpread,
      initialWritingMode: initialWritingMode,
      layout: layout,
      theme: theme,
      onExternalOpen: onExternalOpen,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  final KumihanDocument document;
  final KumihanController? controller;
  final ImageProvider<Object>? coverImage;
  final KumihanImageLoader? imageLoader;
  final int initialPage;
  final KumihanSpreadMode initialSpread;
  final KumihanWritingMode initialWritingMode;
  final KumihanLayoutData layout;
  final KumihanThemeData theme;
  final ValueChanged<String>? onExternalOpen;
  final ValueChanged<KumihanSnapshot>? onSnapshotChanged;

  @override
  State<KumihanCanvas> createState() => _KumihanCanvasState();
}

class _KumihanCanvasState extends State<KumihanCanvas> {
  late KumihanEngine _engine;
  ImageStream? _coverImageStream;
  ImageStreamListener? _coverImageListener;
  ui.Image? _resolvedCoverImage;
  ImageProvider<Object>? _resolvedCoverImageProvider;
  ImageStream? _paperTextureStream;
  ImageStreamListener? _paperTextureListener;
  ui.Image? _resolvedPaperTexture;
  ImageProvider<Object>? _resolvedPaperTextureProvider;
  Size _lastSize = Size.zero;

  @override
  void initState() {
    super.initState();
    _engine = _createEngine();
    widget.controller?.attach(_engine);
    unawaited(_engine.open(widget.document));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveCoverImage();
    _resolvePaperTexture();
  }

  @override
  void didUpdateWidget(covariant KumihanCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller?.detach(_engine);
      widget.controller?.attach(_engine);
    }

    if (oldWidget.coverImage != widget.coverImage) {
      _resolveCoverImage(force: true);
    }

    if (oldWidget.theme.paperTexture != widget.theme.paperTexture) {
      _resolvePaperTexture(force: true);
    }

    final settingsChanged =
        oldWidget.initialPage != widget.initialPage ||
        oldWidget.initialSpread != widget.initialSpread ||
        oldWidget.initialWritingMode != widget.initialWritingMode ||
        oldWidget.imageLoader != widget.imageLoader ||
        oldWidget.onExternalOpen != widget.onExternalOpen;

    if (settingsChanged) {
      oldWidget.controller?.detach(_engine);
      _engine = _createEngine();
      widget.controller?.attach(_engine);
      if (_lastSize != Size.zero) {
        unawaited(_engine.resize(_lastSize.width, _lastSize.height));
      }
      unawaited(_engine.open(widget.document));
      return;
    }

    if (oldWidget.theme != widget.theme) {
      unawaited(
        _engine.updateTheme(widget.theme, paperTexture: _resolvedPaperTexture),
      );
    }

    if (oldWidget.layout != widget.layout) {
      unawaited(_engine.updateLayout(widget.layout));
    }

    if (!identical(oldWidget.document, widget.document)) {
      unawaited(_engine.open(widget.document));
    }
  }

  @override
  void dispose() {
    _stopListeningToCoverImage();
    _stopListeningToPaperTexture();
    widget.controller?.detach(_engine);
    super.dispose();
  }

  KumihanEngine _createEngine() {
    return KumihanEngine(
      baseUri: null,
      coverImage: _resolvedCoverImage,
      imageLoader: widget.imageLoader,
      initialPage: widget.initialPage,
      initialSpread: widget.initialSpread,
      initialWritingMode: widget.initialWritingMode,
      layout: widget.layout,
      theme: widget.theme,
      paperTexture: _resolvedPaperTexture,
      onExternalOpen: widget.onExternalOpen,
      onInvalidate: () {
        if (!mounted) {
          return;
        }
        setState(() {});
      },
      onSnapshot: (snapshot) {
        widget.controller?.updateSnapshot(snapshot);
        widget.onSnapshotChanged?.call(snapshot);
      },
    );
  }

  void _resolveCoverImage({bool force = false}) {
    final provider = widget.coverImage;
    if (!force && _resolvedCoverImageProvider == provider) {
      return;
    }

    _resolvedCoverImageProvider = provider;
    _stopListeningToCoverImage();
    _updateResolvedCoverImage(null);

    if (provider == null) {
      return;
    }

    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (imageInfo, _) {
        if (!mounted) {
          return;
        }
        _updateResolvedCoverImage(imageInfo.image);
      },
      onError: (_, _) {
        if (!mounted) {
          return;
        }
        _updateResolvedCoverImage(null);
      },
    );

    _coverImageStream = stream;
    _coverImageListener = listener;
    stream.addListener(listener);
  }

  void _stopListeningToCoverImage() {
    if (_coverImageStream != null && _coverImageListener != null) {
      _coverImageStream!.removeListener(_coverImageListener!);
    }
    _coverImageStream = null;
    _coverImageListener = null;
  }

  void _resolvePaperTexture({bool force = false}) {
    final provider = widget.theme.paperTexture;
    if (!force && _resolvedPaperTextureProvider == provider) {
      return;
    }

    _resolvedPaperTextureProvider = provider;
    _stopListeningToPaperTexture();
    _updateResolvedPaperTexture(null);

    if (provider == null) {
      return;
    }

    final stream = provider.resolve(createLocalImageConfiguration(context));
    final listener = ImageStreamListener(
      (imageInfo, _) {
        if (!mounted) {
          return;
        }
        _updateResolvedPaperTexture(imageInfo.image);
      },
      onError: (_, _) {
        if (!mounted) {
          return;
        }
        _updateResolvedPaperTexture(null);
      },
    );

    _paperTextureStream = stream;
    _paperTextureListener = listener;
    stream.addListener(listener);
  }

  void _stopListeningToPaperTexture() {
    if (_paperTextureStream != null && _paperTextureListener != null) {
      _paperTextureStream!.removeListener(_paperTextureListener!);
    }
    _paperTextureStream = null;
    _paperTextureListener = null;
  }

  void _updateResolvedCoverImage(ui.Image? image) {
    if (identical(_resolvedCoverImage, image)) {
      return;
    }
    _resolvedCoverImage = image;
    unawaited(_engine.setCoverImage(image));
  }

  void _updateResolvedPaperTexture(ui.Image? image) {
    if (identical(_resolvedPaperTexture, image)) {
      return;
    }
    _resolvedPaperTexture = image;
    unawaited(_engine.updateTheme(widget.theme, paperTexture: image));
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

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            unawaited(
              _engine.tap(details.localPosition.dx, details.localPosition.dy),
            );
          },
          child: CustomPaint(painter: _KumihanPainter(_engine), size: size),
        );
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
