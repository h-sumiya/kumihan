import 'package:flutter/foundation.dart';

import 'kumihan_document.dart';
import 'kumihan_types.dart';

abstract interface class KumihanViewport {
  bool hitTest(double x, double y);
  bool isReadOutActive();
  Future<void> nextPage([int? amount]);
  Future<void> nextStop();
  Future<void> open(KumihanDocument document);
  Future<void> prevPage([int? amount]);
  Future<void> prevStop();
  Future<void> resize(double width, double height);
  Future<void> showFirstPage();
  Future<void> showLastPage();
  Future<void> tap(double x, double y);
  Future<void> toggleForceIndent();
  Future<void> togglePaperColor();
  Future<void> toggleShift1Page();
  Future<void> toggleSpread();
  Future<void> toggleWritingMode();
  KumihanSnapshot get snapshot;
}

class KumihanController extends ChangeNotifier {
  KumihanViewport? _viewport;
  KumihanSnapshot _snapshot = const KumihanSnapshot(
    currentPage: 0,
    spreadMode: KumihanSpreadMode.doublePage,
    totalPages: 0,
    writingMode: KumihanWritingMode.vertical,
  );

  KumihanSnapshot get snapshot => _snapshot;

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
        _snapshot.spreadMode == snapshot.spreadMode &&
        _snapshot.totalPages == snapshot.totalPages &&
        _snapshot.writingMode == snapshot.writingMode) {
      return;
    }
    _snapshot = snapshot;
    notifyListeners();
  }

  Future<void> open(KumihanDocument document) async =>
      _viewport?.open(document);

  Future<void> next([int? amount]) async => _viewport?.nextPage(amount);

  Future<void> prev([int? amount]) async => _viewport?.prevPage(amount);

  Future<void> nextStop() async => _viewport?.nextStop();

  Future<void> prevStop() async => _viewport?.prevStop();

  Future<void> showFirstPage() async => _viewport?.showFirstPage();

  Future<void> showLastPage() async => _viewport?.showLastPage();

  Future<void> toggleSpread() async => _viewport?.toggleSpread();

  Future<void> toggleWritingMode() async => _viewport?.toggleWritingMode();

  Future<void> togglePaperColor() async => _viewport?.togglePaperColor();

  Future<void> toggleShift1Page() async => _viewport?.toggleShift1Page();

  Future<void> toggleForceIndent() async => _viewport?.toggleForceIndent();
}
