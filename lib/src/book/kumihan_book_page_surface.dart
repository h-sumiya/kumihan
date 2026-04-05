import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../engine/kumihan_engine.dart';
import '../kumihan_theme.dart';
import '../kumihan_types.dart';
import 'book_spread_renderer.dart';

class KumihanBookPageSurface extends StatelessWidget {
  const KumihanBookPageSurface({
    super.key,
    required this.engine,
    required this.layout,
    required this.pageIndex,
    required this.recordInteractiveRegions,
    required this.resetPaintState,
    required this.theme,
    required this.totalPages,
  });

  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final int pageIndex;
  final bool recordInteractiveRegions;
  final bool resetPaintState;
  final KumihanThemeData theme;
  final int totalPages;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _KumihanBookPageSurfacePainter(
        engine: engine,
        layout: layout,
        pageIndex: pageIndex,
        recordInteractiveRegions: recordInteractiveRegions,
        resetPaintState: resetPaintState,
        theme: theme,
        totalPages: totalPages,
      ),
      size: Size.infinite,
    );
  }
}

class _KumihanBookPageSurfacePainter extends CustomPainter {
  const _KumihanBookPageSurfacePainter({
    required this.engine,
    required this.layout,
    required this.pageIndex,
    required this.recordInteractiveRegions,
    required this.resetPaintState,
    required this.theme,
    required this.totalPages,
  });

  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final int pageIndex;
  final bool recordInteractiveRegions;
  final bool resetPaintState;
  final KumihanThemeData theme;
  final int totalPages;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final slot = pageIndex.isEven ? BookPageSlot.right : BookPageSlot.left;
    final currentPage = pageIndex.isEven ? pageIndex : pageIndex - 1;
    if (resetPaintState) {
      engine.resetPaintState();
    }
    final renderer = BookSpreadRenderer(
      engine: engine,
      layout: layout,
      theme: theme,
      spreadMode: KumihanSpreadMode.doublePage,
    );
    renderer.paintViewport(
      canvas,
      size,
      viewportSlot: slot,
      globalViewportOrigin: slot == BookPageSlot.right
          ? Offset(size.width, 0)
          : Offset.zero,
      currentPage: currentPage,
      totalPages: totalPages,
      recordInteractiveRegions: recordInteractiveRegions,
    );
  }

  @override
  bool shouldRepaint(covariant _KumihanBookPageSurfacePainter oldDelegate) {
    return oldDelegate.engine != engine ||
        oldDelegate.layout != layout ||
        oldDelegate.pageIndex != pageIndex ||
        oldDelegate.recordInteractiveRegions != recordInteractiveRegions ||
        oldDelegate.resetPaintState != resetPaintState ||
        oldDelegate.theme != theme ||
        oldDelegate.totalPages != totalPages;
  }
}
