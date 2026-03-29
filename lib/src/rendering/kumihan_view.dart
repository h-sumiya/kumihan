import 'package:flutter/widgets.dart';

import '../aozora/aozora_parser.dart';
import '../layout_ir/ast_to_layout_ir.dart';
import '../layout_ir/layout_ir.dart';
import '../layout_result/layout_result.dart';
import '../layout_result/layout_result_builder.dart';
import 'kumihan_layout_painter.dart';
import 'kumihan_render_theme.dart';

class KumihanView extends StatefulWidget {
  const KumihanView({
    super.key,
    required this.layoutDocument,
    this.theme = const KumihanRenderThemeData(),
  });

  factory KumihanView.aozora({
    Key? key,
    required String text,
    KumihanRenderThemeData theme = const KumihanRenderThemeData(),
  }) {
    final ast = AozoraAstParser().parse(text);
    final document = AstToLayoutIrConverter().convert(ast);
    return KumihanView(key: key, layoutDocument: document, theme: theme);
  }

  final LayoutDocument layoutDocument;
  final KumihanRenderThemeData theme;

  @override
  State<KumihanView> createState() => _KumihanViewState();
}

class _KumihanViewState extends State<KumihanView> {
  Size? _lastSize;
  KumihanRenderThemeData? _lastTheme;
  LayoutResult? _cachedResult;

  @override
  void didUpdateWidget(covariant KumihanView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.layoutDocument, widget.layoutDocument) ||
        oldWidget.theme != widget.theme) {
      _cachedResult = null;
      _lastSize = null;
      _lastTheme = null;
    }
  }

  LayoutResult _resolveLayout(Size size) {
    if (_cachedResult != null &&
        _lastSize == size &&
        identical(_lastTheme, widget.theme)) {
      return _cachedResult!;
    }
    final builder = LayoutResultBuilder(
      constraints: widget.theme.constraintsFor(size),
    );
    final result = builder.build(widget.layoutDocument);
    _cachedResult = result;
    _lastSize = size;
    _lastTheme = widget.theme;
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          constraints.maxWidth.isFinite ? constraints.maxWidth : 1,
          constraints.maxHeight.isFinite ? constraints.maxHeight : 1,
        );
        final result = _resolveLayout(size);
        return CustomPaint(
          size: size,
          painter: KumihanLayoutPainter(result: result, theme: widget.theme),
        );
      },
    );
  }
}
