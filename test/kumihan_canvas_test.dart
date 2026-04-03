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
          child: KumihanPagedCanvas(
            document: const AozoraParser().parse(
              '［＃１字下げ］表示サンプルです。\n［＃改ページ］\n次のページです。',
            ),
            controller: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.snapshot.totalPages, greaterThanOrEqualTo(2));
    expect(controller.snapshot.currentPage, 0);
  });

  testWidgets('scroll canvas exposes continuous offset and scrollbar', (
    tester,
  ) async {
    final controller = KumihanScrollController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanScrollCanvas(
            document: const AozoraParser().parse('最初の本文です。\n［＃改ページ］\n次の本文です。'),
            controller: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.byType(RawScrollbar), findsOneWidget);
    expect(controller.snapshot.contentWidth, greaterThan(400));
    expect(controller.snapshot.maxScrollOffset, greaterThan(0));
    expect(
      controller.snapshot.scrollOffset,
      closeTo(controller.snapshot.maxScrollOffset, 1),
    );
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
      engine.selectableGlyphs
          .map((item) => item.text)
          .join()
          .contains('青空文庫です。'),
      isTrue,
    );
    expect(
      engine.selectableGlyphs.any((item) => item.text.contains('あおぞらぶんこ')),
      isFalse,
    );
  });

  test('page padding shifts content rect for painting', () async {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      layout: const KumihanLayoutData(
        pagePadding: EdgeInsets.only(left: 24, top: 32, right: 16, bottom: 20),
      ),
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(400, 600);
    await engine.open(Document(<Object>['本文です。']));

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    engine.paint(canvas);
    recorder.endRecording();

    expect(engine.selectableGlyphs, isNotEmpty);
    final bounds = engine.selectableGlyphs
        .map((item) => item.rect)
        .reduce((value, element) => value.expandToInclude(element));
    expect(bounds.left, greaterThanOrEqualTo(24));
    expect(bounds.top, greaterThanOrEqualTo(32));
    expect(bounds.right, lessThanOrEqualTo(400 - 16 + 0.001));
    expect(bounds.bottom, lessThanOrEqualTo(600 - 20 + 0.001));
  });

  test('theme update changes engine text color', () async {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    expect(engine.fontColor, defaultKumihanTextColor);

    const theme = KumihanThemeData(
      textColor: Color(0xff112233),
      captionColor: Color(0xff445566),
      rubyColor: Color(0xff778899),
      linkColor: Color(0xff2244aa),
      internalLinkColor: Color(0xff228844),
    );
    await engine.updateTheme(theme);

    expect(engine.theme, theme);
    expect(engine.fontColor, const Color(0xff112233));
    expect(engine.paperColor, defaultKumihanPaperColor);
  });

  test('paintPage offsets selectable glyphs into the supplied rect', () async {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(240, 360);
    await engine.open(Document(<Object>['本文です。']));

    final offsetRect = const Rect.fromLTWH(40, 56, 240, 360);
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    engine.resetPaintState();
    engine.paintPage(canvas, 0, PagePaintContext(contentRect: offsetRect));
    recorder.endRecording();

    expect(engine.selectableGlyphs, isNotEmpty);
    final bounds = engine.selectableGlyphs
        .map((item) => item.rect)
        .reduce((value, element) => value.expandToInclude(element));
    expect(bounds.left, greaterThanOrEqualTo(offsetRect.left));
    expect(bounds.top, greaterThanOrEqualTo(offsetRect.top));
  });

  test('paintPage can skip interactive region recording', () async {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(240, 360);
    await engine.open(Document(<Object>['本文です。']));

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    engine.resetPaintState();
    engine.paintPage(
      canvas,
      0,
      const PagePaintContext(
        contentRect: Rect.fromLTWH(0, 0, 240, 360),
        recordInteractiveRegions: false,
      ),
    );
    recorder.endRecording();

    expect(engine.selectableGlyphs, isEmpty);
  });

  test(
    'scroll engine keeps first vertical line inside padded canvas',
    () async {
      final engine = KumihanScrollEngine(
        baseUri: null,
        layout: const KumihanLayoutData(
          pagePadding: EdgeInsets.only(
            left: 24,
            top: 32,
            right: 16,
            bottom: 20,
          ),
        ),
        onInvalidate: () {},
        onSnapshot: (_) {},
      );

      await engine.resize(400, 600);
      await engine.open(Document(<Object>['先頭の行です。次の行です。']));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      engine.paint(canvas);
      recorder.endRecording();

      expect(engine.selectableGlyphs, isNotEmpty);
      final bounds = engine.selectableGlyphs
          .map((item) => item.rect)
          .reduce((value, element) => value.expandToInclude(element));
      expect(bounds.left, greaterThanOrEqualTo(24));
      expect(bounds.top, greaterThanOrEqualTo(32));
      expect(
        bounds.right,
        lessThanOrEqualTo(engine.snapshot.contentWidth - 16),
      );
      expect(bounds.bottom, lessThanOrEqualTo(600 - 20 + 0.001));
    },
  );

  testWidgets('book canvas advances by spreads in double-page mode', (
    tester,
  ) async {
    final controller = KumihanPagedController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: KumihanBookCanvas(
            document: const AozoraParser().parse(
              '一頁目です。\n［＃改ページ］\n二頁目です。\n［＃改ページ］\n三頁目です。\n［＃改ページ］\n四頁目です。',
            ),
            controller: controller,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 0);
    expect(controller.snapshot.totalPages, greaterThanOrEqualTo(4));

    await controller.next();
    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 2);
  });
}
