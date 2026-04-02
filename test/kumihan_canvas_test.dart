import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  testWidgets('aozora text can be opened and paginated', (tester) async {
    final controller = KumihanController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanCanvas.aozora(
            text: '［＃１字下げ］表示サンプルです。\n［＃改ページ］\n次のページです。',
            controller: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.snapshot.totalPages, greaterThanOrEqualTo(2));
    expect(controller.snapshot.currentPage, 0);
  });

  test('selectable text contains only body text without ruby', () async {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(400, 600);
    await engine.open(const AozoraParser().parse('青空文庫《あおぞらぶんこ》です。'));

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    engine.paint(canvas);
    recorder.endRecording();

    expect(engine.selectableGlyphs, isNotEmpty);
    expect(
      engine.selectableGlyphs.map((item) => item.text).join().contains('青空文庫です。'),
      isTrue,
    );
    expect(
      engine.selectableGlyphs.any((item) => item.text.contains('あおぞらぶんこ')),
      isFalse,
    );
  });
}
