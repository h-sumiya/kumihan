import 'package:flutter/foundation.dart';

import 'page_flip_types.dart';

abstract interface class PageFlipViewport {
  Future<void> nextSpread([int? amount]);
  Future<void> prevSpread([int? amount]);
  Future<void> showRightPage(int pageIndex);
  void cancelActiveTouch();
  PageFlipSnapshot get snapshot;
}

class PageFlipController extends ChangeNotifier {
  PageFlipViewport? _viewport;
  PageFlipSnapshot _snapshot = const PageFlipSnapshot(
    rightPageIndex: 0,
    pageCount: 0,
    isInteracting: false,
  );

  PageFlipSnapshot get snapshot => _snapshot;

  void attach(PageFlipViewport viewport) {
    _viewport = viewport;
    updateSnapshot(viewport.snapshot);
  }

  void detach(PageFlipViewport viewport) {
    if (identical(_viewport, viewport)) {
      _viewport = null;
    }
  }

  void updateSnapshot(PageFlipSnapshot snapshot) {
    if (_snapshot.rightPageIndex == snapshot.rightPageIndex &&
        _snapshot.pageCount == snapshot.pageCount &&
        _snapshot.isInteracting == snapshot.isInteracting) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> next([int? amount]) async => _viewport?.nextSpread(amount);

  Future<void> prev([int? amount]) async => _viewport?.prevSpread(amount);

  Future<void> showRightPage(int pageIndex) async =>
      _viewport?.showRightPage(pageIndex);

  void cancelActiveTouch() => _viewport?.cancelActiveTouch();
}
