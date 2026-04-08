import 'package:flutter/foundation.dart';

import 'document.dart';
import 'kumihan_types.dart';

abstract interface class KumihanPagedViewport {
  Future<void> nextPage([int? amount]);
  Future<void> nextStop();
  Future<void> open(Document document);
  Future<void> prevPage([int? amount]);
  Future<void> prevStop();
  Future<void> resize(double width, double height);
  Future<void> showPage(int page);
  Future<void> showFirstPage();
  Future<void> showLastPage();
  KumihanPagedSnapshot get snapshot;
}

class KumihanPagedController extends ChangeNotifier {
  KumihanPagedViewport? _viewport;
  KumihanPagedSnapshot _snapshot = const KumihanPagedSnapshot(
    currentPage: 0,
    totalPages: 0,
  );

  KumihanPagedSnapshot get snapshot => _snapshot;

  void attach(KumihanPagedViewport viewport) {
    _viewport = viewport;
    updateSnapshot(viewport.snapshot);
  }

  void detach(KumihanPagedViewport viewport) {
    if (identical(_viewport, viewport)) {
      _viewport = null;
    }
  }

  void updateSnapshot(KumihanPagedSnapshot snapshot) {
    if (_snapshot.currentPage == snapshot.currentPage &&
        _snapshot.totalPages == snapshot.totalPages) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> open(Document document) async => _viewport?.open(document);

  Future<void> next([int? amount]) async => _viewport?.nextPage(amount);

  Future<void> prev([int? amount]) async => _viewport?.prevPage(amount);

  Future<void> nextStop() async => _viewport?.nextStop();

  Future<void> prevStop() async => _viewport?.prevStop();

  Future<void> showPage(int page) async => _viewport?.showPage(page);

  Future<void> showFirstPage() async => _viewport?.showFirstPage();

  Future<void> showLastPage() async => _viewport?.showLastPage();
}
