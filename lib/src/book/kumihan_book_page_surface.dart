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
    required this.spreadMode,
  });

  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final int pageIndex;
  final bool recordInteractiveRegions;
  final bool resetPaintState;
  final KumihanThemeData theme;
  final int totalPages;
  final KumihanSpreadMode spreadMode;

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
        spreadMode: spreadMode,
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
    required this.spreadMode,
  });

  final KumihanEngine engine;
  final KumihanBookLayoutData layout;
  final int pageIndex;
  final bool recordInteractiveRegions;
  final bool resetPaintState;
  final KumihanThemeData theme;
  final int totalPages;
  final KumihanSpreadMode spreadMode;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final slot = spreadMode == KumihanSpreadMode.single
        ? BookPageSlot.single
        : (pageIndex.isEven ? BookPageSlot.right : BookPageSlot.left);
    final currentPage = spreadMode == KumihanSpreadMode.single
        ? pageIndex
        : (pageIndex.isEven ? pageIndex : pageIndex - 1);
    if (resetPaintState) {
      engine.resetPaintState();
    }
    final layoutForPainting = spreadMode == KumihanSpreadMode.single
        ? layout.copyWith(
            singlePageNumberPosition: KumihanSinglePageNumberPosition.right,
          )
        : layout;
    final renderer = BookSpreadRenderer(
      engine: engine,
      layout: layoutForPainting,
      theme: theme,
      spreadMode: spreadMode,
      drawGutterShadow: false,
    );
    renderer.paintViewport(
      canvas,
      size,
      viewportSlot: slot,
      globalViewportOrigin:
          spreadMode == KumihanSpreadMode.doublePage &&
              slot == BookPageSlot.right
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
        oldDelegate.totalPages != totalPages ||
        oldDelegate.spreadMode != spreadMode;
  }
}
