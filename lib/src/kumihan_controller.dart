import 'package:flutter/foundation.dart';

import 'ast.dart';
import 'debug/render_trace.dart';
import 'kumihan_types.dart';

abstract interface class KumihanViewport {
  Future<void> nextPage([int? amount]);
  Future<void> nextStop();
  Future<void> open(AstData data);
  Future<void> prevPage([int? amount]);
  Future<void> prevStop();
  Future<void> resize(double width, double height);
  Future<void> showPage(int page);
  Future<void> showFirstPage();
  Future<void> showLastPage();
  KumihanRenderTrace? get renderTrace;
  KumihanSnapshot get snapshot;
}

class KumihanController extends ChangeNotifier {
  KumihanViewport? _viewport;
  KumihanSnapshot _snapshot = const KumihanSnapshot(
    currentPage: 0,
    totalPages: 0,
  );

  KumihanSnapshot get snapshot => _snapshot;

  KumihanRenderTrace? get renderTrace => _viewport?.renderTrace;

  void attach(KumihanViewport viewport) {
    _viewport = viewport;
    updateSnapshot(viewport.snapshot);
  }

  void detach(KumihanViewport viewport) {
    if (identical(_viewport, viewport)) {
      _viewport = null;
    }
  }

  void updateSnapshot(KumihanSnapshot snapshot) {
    if (_snapshot.currentPage == snapshot.currentPage &&
        _snapshot.totalPages == snapshot.totalPages) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> open(AstData data) async => _viewport?.open(data);

  Future<void> next([int? amount]) async => _viewport?.nextPage(amount);

  Future<void> prev([int? amount]) async => _viewport?.prevPage(amount);

  Future<void> nextStop() async => _viewport?.nextStop();

  Future<void> prevStop() async => _viewport?.prevStop();

  Future<void> showPage(int page) async => _viewport?.showPage(page);

  Future<void> showFirstPage() async => _viewport?.showFirstPage();

  Future<void> showLastPage() async => _viewport?.showLastPage();
}
