import 'dart:async';

import 'package:flutter/widgets.dart';

import 'kumihan_controller.dart';
import 'kumihan_types.dart';

typedef KumihanUnhandledTapCallback = void Function(KumihanTapDetails details);
typedef KumihanTapHandler =
    FutureOr<void> Function(
      KumihanTapDetails details,
      KumihanTapActions actions,
    );

enum KumihanTapSide { left, right }

@immutable
class KumihanTapDetails {
  const KumihanTapDetails({
    required this.canvasSize,
    required this.position,
    required this.snapshot,
  });

  final Size canvasSize;
  final Offset position;
  final KumihanSnapshot snapshot;

  double get normalizedX => _normalize(position.dx, canvasSize.width);

  double get normalizedY => _normalize(position.dy, canvasSize.height);

  Offset get normalizedPosition => Offset(normalizedX, normalizedY);

  static double _normalize(double value, double size) {
    if (size <= 0) {
      return 0;
    }
    final normalized = value / size;
    if (normalized < 0) {
      return 0;
    }
    if (normalized > 1) {
      return 1;
    }
    return normalized;
  }
}

class KumihanTapActions {
  const KumihanTapActions(this._viewport);

  final KumihanViewport _viewport;

  Future<void> next([int? amount]) => _viewport.nextPage(amount);

  Future<void> prev([int? amount]) => _viewport.prevPage(amount);

  Future<void> nextStop() => _viewport.nextStop();

  Future<void> prevStop() => _viewport.prevStop();

  Future<void> showPage(int page) => _viewport.showPage(page);

  Future<void> showFirstPage() => _viewport.showFirstPage();

  Future<void> showLastPage() => _viewport.showLastPage();

  Future<void> toggleSpread() => _viewport.toggleSpread();

  Future<void> toggleWritingMode() => _viewport.toggleWritingMode();

  Future<void> togglePaperColor() => _viewport.togglePaperColor();

  Future<void> toggleShift1Page() => _viewport.toggleShift1Page();

  Future<void> toggleForceIndent() => _viewport.toggleForceIndent();

  Future<void> pageTurnFromSide(
    KumihanTapSide side,
    KumihanSnapshot snapshot,
  ) async {
    final amount = snapshot.spreadMode == KumihanSpreadMode.single ? 1 : 2;
    final forward = switch (snapshot.writingMode) {
      KumihanWritingMode.vertical => side == KumihanTapSide.left,
      KumihanWritingMode.horizontal => side == KumihanTapSide.right,
    };

    if (forward) {
      await next(amount);
      return;
    }

    await prev(amount);
  }
}

class KumihanTapHandlers {
  const KumihanTapHandlers._();

  static Future<void> pageTurnByHorizontalPosition(
    KumihanTapDetails details,
    KumihanTapActions actions,
  ) async {
    if (details.normalizedX >= 0.5) {
      await actions.pageTurnFromSide(KumihanTapSide.right, details.snapshot);
      return;
    }

    await actions.pageTurnFromSide(KumihanTapSide.left, details.snapshot);
  }
}
