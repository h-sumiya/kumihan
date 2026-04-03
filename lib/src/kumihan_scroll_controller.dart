import 'dart:ui';

import 'package:flutter/foundation.dart';

import 'document.dart';
import 'kumihan_types.dart';

abstract interface class KumihanScrollViewport {
  Future<void> jumpTo(double offset);
  Future<void> open(Document document);
  Future<void> resize(double width, double height);
  Future<void> scrollBy(double delta);
  KumihanScrollSnapshot get snapshot;
}

class KumihanScrollController extends ChangeNotifier {
  KumihanScrollViewport? _viewport;
  KumihanScrollSnapshot _snapshot = const KumihanScrollSnapshot(
    viewportWidth: 0,
    viewportHeight: 0,
    scrollOffset: 0,
    maxScrollOffset: 0,
    contentWidth: 0,
    visibleRange: Rect.zero,
  );

  KumihanScrollSnapshot get snapshot => _snapshot;

  void attach(KumihanScrollViewport viewport) {
    _viewport = viewport;
    updateSnapshot(viewport.snapshot);
  }

  void detach(KumihanScrollViewport viewport) {
    if (identical(_viewport, viewport)) {
      _viewport = null;
    }
  }

  void updateSnapshot(KumihanScrollSnapshot snapshot) {
    if (_snapshot.viewportWidth == snapshot.viewportWidth &&
        _snapshot.viewportHeight == snapshot.viewportHeight &&
        _snapshot.scrollOffset == snapshot.scrollOffset &&
        _snapshot.maxScrollOffset == snapshot.maxScrollOffset &&
        _snapshot.contentWidth == snapshot.contentWidth &&
        _snapshot.visibleRange == snapshot.visibleRange) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> open(Document document) async => _viewport?.open(document);

  Future<void> resize(double width, double height) async =>
      _viewport?.resize(width, height);

  Future<void> jumpTo(double offset) async => _viewport?.jumpTo(offset);

  Future<void> scrollBy(double delta) async => _viewport?.scrollBy(delta);
}
