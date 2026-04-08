import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';
import 'package:kumihan/src/book/book_spread_renderer.dart';

void main() {
  testWidgets('aozora text can be opened and paginated', (tester) async {
    final controller = KumihanController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanPagedView(
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

  testWidgets('paged canvas maxPages truncates pagination', (tester) async {
    final controller = KumihanController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanPagedView(
            document: Document(<Object>[
              List<String>.filled(400, '本文です。').join(),
            ]),
            controller: controller,
            maxPages: 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.snapshot.totalPages, 1);
    expect(controller.snapshot.currentPage, 0);
  });

  testWidgets('single page canvas reports a single page snapshot', (
    tester,
  ) async {
    KumihanPagedSnapshot? snapshot;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanSinglePageView(
            document: Document(<Object>[
              List<String>.filled(400, '本文です。').join(),
            ]),
            onSnapshotChanged: (value) {
              snapshot = value;
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(snapshot, isNotNull);
    expect(snapshot!.totalPages, 1);
    expect(snapshot!.currentPage, 0);
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
          child: KumihanScrollView(
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

  testWidgets('paged canvas resolves relative image paths against baseUri', (
    tester,
  ) async {
    final loadedPaths = <String>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanPagedView(
            document: const MarkdownParser().parse('![image](cover.png)'),
            baseUri: Uri.parse('file:///books/sample.md'),
            imageLoader: (path) async {
              loadedPaths.add(path);
              return _createTestImage();
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(loadedPaths, contains('file:///books/cover.png'));
  });

  testWidgets('scroll canvas keeps absolute image URLs unchanged', (
    tester,
  ) async {
    final loadedPaths = <String>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanScrollView(
            document: const MarkdownParser().parse(
              '![image](https://example.com/cover.png)',
            ),
            baseUri: Uri.parse('file:///books/sample.md'),
            imageLoader: (path) async {
              loadedPaths.add(path);
              return _createTestImage();
            },
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(loadedPaths, contains('https://example.com/cover.png'));
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

  test('engine maxPages truncates extra pages', () async {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      maxPages: 1,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(400, 600);
    await engine.open(
      Document(<Object>[List<String>.filled(400, '本文です。').join()]),
    );

    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    engine.paint(canvas);
    recorder.endRecording();

    expect(engine.snapshot.totalPages, 1);
    expect(engine.selectableGlyphs, isNotEmpty);
  });

  test(
    'paged canvas keeps snapped width overflow on the left side for full pages by default',
    () async {
      final engine = KumihanEngine(
        baseUri: null,
        initialPage: 0,
        onInvalidate: () {},
        onSnapshot: (_) {},
      );

      await engine.resize(420, 600);
      await engine.open(
        Document(<Object>[List<String>.filled(400, '本文です。').join()]),
      );

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      engine.paint(canvas);
      recorder.endRecording();

      expect(engine.snapshot.totalPages, greaterThan(1));
      expect(engine.selectableGlyphs, isNotEmpty);
      final bounds = _glyphBounds(engine.selectableGlyphs);
      final rightGap = 420 - bounds.right;
      expect(bounds.left, greaterThan(rightGap + 5));
    },
  );

  test('paged canvas can align full pages left or center', () async {
    final document = Document(<Object>[
      List<String>.filled(400, '本文です。').join(),
    ]);
    const size = Size(420, 600);

    final rightBounds = await _pagedBounds(size: size, document: document);
    final centerBounds = await _pagedBounds(
      size: size,
      document: document,
      layout: const KumihanLayoutData(
        fullPageAlignment: KumihanFullPageAlignment.center,
      ),
    );
    final leftBounds = await _pagedBounds(
      size: size,
      document: document,
      layout: const KumihanLayoutData(
        fullPageAlignment: KumihanFullPageAlignment.left,
      ),
    );

    expect(leftBounds.left, lessThan(centerBounds.left));
    expect(centerBounds.left, lessThan(rightBounds.left));
    expect(
      rightBounds.left - centerBounds.left,
      closeTo((rightBounds.left - leftBounds.left) / 2, 2.0),
    );
  });

  test(
    'paged canvas keeps short pages right aligned even when full-page alignment changes',
    () async {
      const size = Size(420, 600);
      final document = Document(<Object>['本文です。']);

      final defaultBounds = await _pagedBounds(size: size, document: document);
      final leftBounds = await _pagedBounds(
        size: size,
        document: document,
        layout: const KumihanLayoutData(
          fullPageAlignment: KumihanFullPageAlignment.left,
        ),
      );

      expect(leftBounds.left, closeTo(defaultBounds.left, 0.001));
      expect(leftBounds.right, closeTo(defaultBounds.right, 0.001));
    },
  );

  test(
    'engine keeps fractional resize width for pagination thresholds',
    () async {
      Future<int> totalPagesForWidth(double width) async {
        final engine = KumihanEngine(
          baseUri: null,
          initialPage: 0,
          onInvalidate: () {},
          onSnapshot: (_) {},
        );

        await engine.resize(width, 600);
        await engine.open(
          Document(<Object>[List<String>.filled(93, '本文です。').join()]),
        );
        return engine.snapshot.totalPages;
      }

      final narrowPages = await totalPagesForWidth(399.0);
      final fractionalPages = await totalPagesForWidth(399.8);

      expect(fractionalPages, lessThanOrEqualTo(narrowPages));
    },
  );

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
          child: KumihanBookView(
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

  testWidgets('book canvas builds two independent page widgets', (
    tester,
  ) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: KumihanBookView(document: Document(<Object>['本文です。'])),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final paints = tester.widgetList<CustomPaint>(
      find.descendant(
        of: find.byType(KumihanBookView),
        matching: find.byType(CustomPaint),
      ),
    );
    for (final paint in paints) {
      final renderBox = tester.renderObject<RenderBox>(find.byWidget(paint));
      expect(renderBox.size.height, 600);
    }

    expect(
      find.descendant(
        of: find.byType(KumihanBookView),
        matching: find.byType(CustomPaint),
      ),
      findsNWidgets(2),
    );
  });

  test(
    'book renderer places the single right page toward the gutter by default',
    () async {
      const canvasSize = Size(420, 600);
      final document = Document(<Object>[
        List<String>.filled(400, '本文です。').join(),
      ]);

      final defaultBounds = await _bookBounds(
        size: canvasSize,
        document: document,
        spreadMode: KumihanSpreadMode.single,
      );
      final rightBounds = await _bookBounds(
        size: canvasSize,
        document: document,
        spreadMode: KumihanSpreadMode.single,
        layout: const KumihanBookLayoutData(
          rightPageFullPageAlignment: KumihanFullPageAlignment.right,
        ),
      );

      expect(defaultBounds.left, lessThanOrEqualTo(rightBounds.left));
    },
  );

  test('book renderer applies right-page alignment independently', () async {
    const size = Size(840, 600);
    final document = Document(<Object>[
      '右頁です。',
      const PageBreak(AstPageBreakKind.kaipage),
      '左頁です。',
    ]);
    final defaultGlyphs = await _bookGlyphs(
      size: size,
      document: document,
      spreadMode: KumihanSpreadMode.doublePage,
    );
    final rightOnlyGlyphs = await _bookGlyphs(
      size: size,
      document: document,
      layout: const KumihanBookLayoutData(
        rightPageFullPageAlignment: KumihanFullPageAlignment.right,
      ),
      spreadMode: KumihanSpreadMode.doublePage,
    );
    final bothOverrideGlyphs = await _bookGlyphs(
      size: size,
      document: document,
      layout: const KumihanBookLayoutData(
        rightPageFullPageAlignment: KumihanFullPageAlignment.right,
        leftPageFullPageAlignment: KumihanFullPageAlignment.left,
      ),
      spreadMode: KumihanSpreadMode.doublePage,
    );

    final defaultRightBounds = _glyphBounds(
      defaultGlyphs.where((item) => item.text == '右').toList(),
    );
    final rightOnlyRightBounds = _glyphBounds(
      rightOnlyGlyphs.where((item) => item.text == '右').toList(),
    );
    final bothRightBounds = _glyphBounds(
      bothOverrideGlyphs.where((item) => item.text == '右').toList(),
    );

    expect(
      defaultRightBounds.left,
      lessThanOrEqualTo(rightOnlyRightBounds.left),
    );
    expect(bothRightBounds.left, closeTo(rightOnlyRightBounds.left, 0.001));
  });

  test(
    'book renderer records selectable glyphs in right-to-left page order',
    () async {
      const size = Size(840, 600);
      final document = Document(<Object>[
        '右頁です。',
        const PageBreak(AstPageBreakKind.kaipage),
        '左頁です。',
      ]);

      final glyphs = await _bookGlyphs(
        size: size,
        document: document,
        spreadMode: KumihanSpreadMode.doublePage,
      );

      final rightGlyph = glyphs.firstWhere((item) => item.text == '右');
      final leftGlyph = glyphs.firstWhere((item) => item.text == '左');

      expect(rightGlyph.order, lessThan(leftGlyph.order));
    },
  );

  test('book renderer paints backside body text onto the spread', () async {
    const size = Size(840, 600);
    const layout = KumihanBookLayoutData(
      showTitle: false,
      showPageNumber: false,
    );
    const theme = KumihanThemeData(backPageOpacity: 1);
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );
    final renderer = BookSpreadRenderer(
      engine: engine,
      layout: layout,
      theme: theme,
      spreadMode: KumihanSpreadMode.doublePage,
    );
    final pageSize = renderer.resolvePageSize(size);

    Future<Uint8List> renderBytes(Document document) async {
      await engine.resize(pageSize.width, pageSize.height);
      await engine.open(document);
      expect(engine.snapshot.totalPages, greaterThanOrEqualTo(3));

      final recorder = PictureRecorder();
      final canvas = Canvas(recorder);
      renderer.paint(
        canvas,
        size,
        currentPage: 0,
        totalPages: engine.snapshot.totalPages,
      );
      final image = await recorder.endRecording().toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);
      return bytes!.buffer.asUint8List();
    }

    final withoutBack = await renderBytes(
      const AozoraParser().parse('表です。\n［＃改ページ］\n一\n［＃改ページ］\n一'),
    );
    final withBack = await renderBytes(
      const AozoraParser().parse(
        '表です。\n［＃改ページ］\n一\n［＃改ページ］\n'
        '裏写りです。裏写りです。裏写りです。裏写りです。'
        '裏写りです。裏写りです。裏写りです。裏写りです。'
        '裏写りです。裏写りです。裏写りです。裏写りです。'
        '裏写りです。裏写りです。裏写りです。裏写りです。'
        '裏写りです。裏写りです。裏写りです。裏写りです。'
        '裏写りです。裏写りです。裏写りです。裏写りです。',
      ),
    );

    final leftViewportWidth = (size.width / 2).toInt();
    var differingPixels = 0;

    for (var y = 0; y < size.height.toInt(); y += 1) {
      for (var x = 0; x < leftViewportWidth / 2; x += 1) {
        final index = (y * size.width.toInt() + x) * 4;
        if (withoutBack[index] != withBack[index] ||
            withoutBack[index + 1] != withBack[index + 1] ||
            withoutBack[index + 2] != withBack[index + 2] ||
            withoutBack[index + 3] != withBack[index + 3]) {
          differingPixels += 1;
        }
      }
    }

    expect(differingPixels, greaterThan(0));
  });

  test('book renderer resolves double-page width from body padding', () {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );
    const layout = KumihanBookLayoutData(
      fontSize: 18,
      bodyPadding: KumihanBookBodyPadding(inner: 14, outer: 30),
      showTitle: false,
      showPageNumber: false,
    );
    const canvasSize = Size(500, 600);
    final renderer = BookSpreadRenderer(
      engine: engine,
      layout: layout,
      theme: const KumihanThemeData(),
      spreadMode: KumihanSpreadMode.doublePage,
    );

    final pageSize = renderer.resolvePageSize(canvasSize);
    final expectedWidth = math.max(
      canvasSize.width / 2 -
          layout.bodyPadding.inner -
          layout.bodyPadding.outer,
      layout.fontSize,
    );

    expect(pageSize.width, closeTo(expectedWidth, 0.001));
  });

  test('book renderer reserves vertical body padding outside body area', () {
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      onInvalidate: () {},
      onSnapshot: (_) {},
    );
    const baseLayout = KumihanBookLayoutData(
      fontSize: 18,
      showTitle: false,
      showPageNumber: true,
    );
    const paddedLayout = KumihanBookLayoutData(
      fontSize: 18,
      bodyPadding: KumihanBookBodyPadding(bottom: 24),
      showTitle: false,
      showPageNumber: true,
    );
    const canvasSize = Size(420, 600);

    final baseRenderer = BookSpreadRenderer(
      engine: engine,
      layout: baseLayout,
      theme: const KumihanThemeData(),
      spreadMode: KumihanSpreadMode.doublePage,
    );
    final paddedRenderer = BookSpreadRenderer(
      engine: engine,
      layout: paddedLayout,
      theme: const KumihanThemeData(),
      spreadMode: KumihanSpreadMode.doublePage,
    );

    final basePageSize = baseRenderer.resolvePageSize(canvasSize);
    final paddedPageSize = paddedRenderer.resolvePageSize(canvasSize);

    expect(paddedPageSize.height, closeTo(basePageSize.height - 24, 0.001));
  });

  testWidgets('book canvas supports text selection', (tester) async {
    final document = Document(<Object>['本文です。']);
    const size = Size(800, 600);
    final point = await _firstBookGlyphCenter(size: size, document: document);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBookView(document: document),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanBookView),
      localPosition: point,
    );

    expect(find.text('コピー'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
  });

  testWidgets('book canvas supports text selection on the left page', (
    tester,
  ) async {
    final document = Document(<Object>[
      '右頁です。',
      const PageBreak(AstPageBreakKind.kaipage),
      '左頁です。',
    ]);
    const size = Size(800, 600);
    final point = await _bookGlyphCenterForText(
      size: size,
      document: document,
      text: '左',
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBookView(document: document),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanBookView),
      localPosition: point,
    );

    expect(find.text('コピー'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
    expect(_selectionHighlightFinder(), findsAtLeastNWidgets(1));
  });

  testWidgets('book canvas does not swallow plain taps', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: GestureDetector(
          onTap: () {
            tapped = true;
          },
          child: SizedBox(
            width: 800,
            height: 600,
            child: KumihanBookView(document: Document(<Object>['本文です。'])),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.byType(KumihanBookView));
    await tester.pumpAndSettle();

    expect(tapped, isTrue);
  });

  testWidgets('copy closes selection toolbar on book canvas', (tester) async {
    final document = Document(<Object>['本文です。']);
    const size = Size(800, 600);
    final point = await _firstBookGlyphCenter(size: size, document: document);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBookView(document: document),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanBookView),
      localPosition: point,
    );

    expect(find.text('コピー'), findsOneWidget);
    await tester.tap(find.text('コピー'));
    await tester.pumpAndSettle();

    expect(find.text('コピー'), findsNothing);
    expect(find.text('閉じる'), findsNothing);
  });

  testWidgets(
    'kumihan book shows selection highlight and closes toolbar after copy',
    (tester) async {
      final document = Document(<Object>['本文です。']);
      const size = Size(800, 600);
      final point = await _firstBookGlyphCenter(size: size, document: document);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: KumihanBook(document: document),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _longPressCanvas(
        tester,
        find.byType(KumihanBook),
        localPosition: point,
      );

      expect(_selectionHighlightFinder(), findsAtLeastNWidgets(1));
      expect(find.text('コピー'), findsOneWidget);
      await tester.tap(find.text('コピー'));
      await tester.pumpAndSettle();

      expect(find.text('コピー'), findsNothing);
      expect(find.text('閉じる'), findsNothing);
    },
  );

  testWidgets('kumihan book composes cover and blank pages in double spread', (
    tester,
  ) async {
    final document = const AozoraParser().parse(
      '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。',
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: KumihanBook(
            document: document,
            frontCover: const ColoredBox(
              color: Color(0xFF1F3B5C),
              child: SizedBox.expand(),
            ),
            backCover: const ColoredBox(
              color: Color(0xFF3B1F4A),
              child: SizedBox.expand(),
            ),
            blankPage: const ColoredBox(
              color: Color(0xFFEEE6D8),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final pageFlip = tester.widget<PageFlipBook>(find.byType(PageFlipBook));
    expect(pageFlip.displayMode, PageDisplayMode.doublePage);
    expect(pageFlip.pageCount, 8);
    expect(pageFlip.pageDensityBuilder?.call(0), PageDensity.soft);
    expect(pageFlip.pageDensityBuilder?.call(1), PageDensity.hard);
    expect(pageFlip.pageDensityBuilder?.call(6), PageDensity.hard);
    expect(pageFlip.pageDensityBuilder?.call(7), PageDensity.soft);
    expect(find.byType(KumihanDefaultBookDesk), findsOneWidget);
  });

  testWidgets('kumihan book maxPages truncates content pagination', (
    tester,
  ) async {
    final controller = KumihanPagedController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: KumihanBook(
            document: Document(<Object>[
              List<String>.filled(400, '本文です。').join(),
            ]),
            controller: controller,
            maxPages: 1,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(controller.snapshot.totalPages, 1);
    expect(controller.snapshot.currentPage, 0);
    final pageFlip = tester.widget<PageFlipBook>(find.byType(PageFlipBook));
    expect(pageFlip.pageCount, 2);
  });

  testWidgets(
    'kumihan book forwards book theme, tap flip duration, and animation flag',
    (tester) async {
      const bookTheme = KumihanBookThemeData(
        bookColor: Color(0xff6d4c32),
        pageBackgroundColor: Color(0xfff7efd9),
        borderColor: Color(0xff8a735c),
      );
      const autoPageFlipDuration = Duration(milliseconds: 420);
      const pageTurnAnimationEnabled = false;

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 800,
            height: 600,
            child: KumihanBook(
              document: Document(<Object>['本文です。']),
              bookTheme: bookTheme,
              autoPageFlipDuration: autoPageFlipDuration,
              pageTurnAnimationEnabled: pageTurnAnimationEnabled,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pageFlip = tester.widget<PageFlipBook>(find.byType(PageFlipBook));
      expect(pageFlip.bookColor, bookTheme.bookColor);
      expect(pageFlip.pageBackgroundColor, bookTheme.pageBackgroundColor);
      expect(pageFlip.borderColor, bookTheme.borderColor);
      expect(pageFlip.tapFlipTime, autoPageFlipDuration);
      expect(pageFlip.pageTurnAnimationEnabled, pageTurnAnimationEnabled);
    },
  );

  testWidgets('kumihan book starts from front-cover spread in double mode', (
    tester,
  ) async {
    final document = const AozoraParser().parse(
      '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。',
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: KumihanBook(
            document: document,
            frontCover: const ColoredBox(
              color: Color(0xFF1F3B5C),
              child: SizedBox.expand(),
            ),
            backCover: const ColoredBox(
              color: Color(0xFF3B1F4A),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final pageFlipState = tester.state(find.byType(PageFlipBook)) as dynamic;
    expect(pageFlipState.debugRightPageIndex, 0);
  });

  testWidgets('kumihan book can stay on trailing back-cover spread', (
    tester,
  ) async {
    final document = const AozoraParser().parse(
      '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。',
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 800,
          height: 600,
          child: KumihanBook(
            document: document,
            frontCover: const ColoredBox(
              color: Color(0xFF1F3B5C),
              child: SizedBox.expand(),
            ),
            backCover: const ColoredBox(
              color: Color(0xFF3B1F4A),
              child: SizedBox.expand(),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final pageFlipState = tester.state(find.byType(PageFlipBook)) as dynamic;
    await pageFlipState.showRightPage(6);
    await tester.pumpAndSettle();

    expect(pageFlipState.debugRightPageIndex, 6);
  });

  testWidgets(
    'kumihan book rebuild with new cover instances keeps current cover spread',
    (tester) async {
      final document = const AozoraParser().parse(
        '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。',
      );
      var frontColor = const Color(0xFF1F3B5C);

      Widget buildHost() {
        return Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 800,
            height: 600,
            child: KumihanBook(
              document: document,
              frontCover: ColoredBox(
                color: frontColor,
                child: const SizedBox.expand(),
              ),
              backCover: const ColoredBox(
                color: Color(0xFF3B1F4A),
                child: SizedBox.expand(),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      final pageFlipState = tester.state(find.byType(PageFlipBook)) as dynamic;
      expect(pageFlipState.debugRightPageIndex, 0);

      frontColor = const Color(0xFF314E6E);
      await tester.pumpWidget(buildHost());
      await tester.pumpAndSettle();

      expect(pageFlipState.debugRightPageIndex, 0);
    },
  );

  testWidgets(
    'kumihan book single spread enables edge overlay and skips blank',
    (tester) async {
      final document = const AozoraParser().parse(
        '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。',
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 800,
            height: 600,
            child: KumihanBook(
              document: document,
              spreadMode: KumihanSpreadMode.single,
              frontCover: const ColoredBox(color: Color(0xFF1F3B5C)),
              backCover: const ColoredBox(color: Color(0xFF3B1F4A)),
              blankPage: const ColoredBox(color: Color(0xFFEEE6D8)),
              singlePageEdge: const SizedBox(width: 8, height: 8),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final pageFlip = tester.widget<PageFlipBook>(find.byType(PageFlipBook));
      expect(pageFlip.displayMode, PageDisplayMode.singlePage);
      expect(pageFlip.pageCount, 5);
      expect(pageFlip.pageDensityBuilder?.call(0), PageDensity.hard);
      expect(pageFlip.pageDensityBuilder?.call(4), PageDensity.hard);
      expect(find.byType(KumihanSinglePageEdgeOverlay), findsOneWidget);
      expect(find.byType(KumihanDefaultBookDesk), findsNothing);
    },
  );

  testWidgets('kumihan book toolbar tap does not flip pages', (tester) async {
    final document = const AozoraParser().parse(
      '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。\n［＃改ページ］\n丁頁です。',
    );
    final controller = KumihanPagedController();
    const size = Size(800, 600);
    final point = await _firstBookGlyphCenter(size: size, document: document);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBook(document: document, controller: controller),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanBook),
      localPosition: point,
    );

    await tester.tap(find.text('コピー'));
    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 0);
    expect(find.text('コピー'), findsNothing);
  });

  testWidgets(
    'kumihan book dismisses selection without flipping when toolbar is visible',
    (tester) async {
      final document = const AozoraParser().parse(
        '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。\n［＃改ページ］\n丁頁です。',
      );
      final controller = KumihanPagedController();
      const size = Size(800, 600);
      final point = await _firstBookGlyphCenter(size: size, document: document);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: KumihanBook(document: document, controller: controller),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await _longPressCanvas(
        tester,
        find.byType(KumihanBook),
        localPosition: point,
      );

      final bookRect = tester.getRect(find.byType(KumihanBook));
      await tester.tapAt(
        bookRect.topLeft + Offset(size.width * 0.25, size.height * 0.85),
      );
      await tester.pumpAndSettle();

      expect(controller.snapshot.currentPage, 0);
      expect(find.text('コピー'), findsNothing);
      expect(_selectionHighlightFinder(), findsNothing);
    },
  );

  testWidgets('kumihan book tap on left-page text flips to the next spread', (
    tester,
  ) async {
    final document = const AozoraParser().parse(
      '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。\n［＃改ページ］\n丁頁です。',
    );
    final controller = KumihanPagedController();
    const size = Size(800, 600);
    final point = await _bookPageGlyphCenter(
      size: size,
      document: document,
      onLeftPage: true,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBook(document: document, controller: controller),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final bookRect = tester.getRect(find.byType(KumihanBook));
    await tester.tapAt(bookRect.topLeft + point);
    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 2);
  });

  testWidgets('kumihan book tap on blank area flips to the next spread', (
    tester,
  ) async {
    final document = const AozoraParser().parse(
      '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。\n［＃改ページ］\n丁頁です。',
    );
    final controller = KumihanPagedController();
    const size = Size(800, 600);
    final point = Offset(size.width * 0.25, size.height * 0.85);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBook(document: document, controller: controller),
        ),
      ),
    );

    await tester.pumpAndSettle();
    final bookRect = tester.getRect(find.byType(KumihanBook));
    await tester.tapAt(bookRect.topLeft + point);
    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 2);
  });

  testWidgets('kumihan book supports text selection on the left page', (
    tester,
  ) async {
    final document = const AozoraParser().parse('右頁です。\n［＃改ページ］\n左頁です。');
    const size = Size(800, 600);
    final point = await _bookPageGlyphCenter(
      size: size,
      document: document,
      onLeftPage: true,
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBook(document: document),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanBook),
      localPosition: point,
    );

    expect(find.text('コピー'), findsOneWidget);
    expect(find.text('閉じる'), findsOneWidget);
    expect(_selectionHighlightFinder(), findsAtLeastNWidgets(1));
  });

  testWidgets(
    'kumihan book horizontal swipe from blank area starts page drag',
    (tester) async {
      final document = const AozoraParser().parse(
        '甲頁です。\n［＃改ページ］\n乙頁です。\n［＃改ページ］\n丙頁です。\n［＃改ページ］\n丁頁です。',
      );
      const size = Size(800, 600);
      final point = Offset(size.width * 0.25, size.height * 0.85);

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: size.width,
            height: size.height,
            child: KumihanBook(document: document),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final bookRect = tester.getRect(find.byType(KumihanBook));
      final gesture = await tester.startGesture(bookRect.topLeft + point);
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();

      final state = tester.state(find.byType(PageFlipBook)) as dynamic;
      expect(state.debugIsDragging, isTrue);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('book canvas can disable text selection', (tester) async {
    final document = Document(<Object>['本文です。']);
    const size = Size(800, 600);
    final point = await _firstBookGlyphCenter(size: size, document: document);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanBookView(document: document, selectable: false),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanBookView),
      localPosition: point,
    );

    expect(find.text('コピー'), findsNothing);
  });

  testWidgets('paged canvas can disable text selection', (tester) async {
    final document = Document(<Object>['本文です。']);
    const size = Size(400, 600);
    final point = await _firstPagedGlyphCenter(size: size, document: document);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanPagedView(document: document, selectable: false),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanPagedView),
      localPosition: point,
    );

    expect(find.text('コピー'), findsNothing);
  });

  testWidgets('scroll canvas can disable text selection', (tester) async {
    final document = Document(<Object>['本文です。']);
    const size = Size(400, 600);
    final point = await _firstScrollGlyphCenter(size: size, document: document);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: KumihanScrollView(document: document, selectable: false),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await _longPressCanvas(
      tester,
      find.byType(KumihanScrollView),
      localPosition: point,
    );

    expect(find.text('コピー'), findsNothing);
  });
}

Future<ui.Image> _createTestImage() async {
  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, 1, 1),
    Paint()..color = const Color(0xffffffff),
  );
  return recorder.endRecording().toImage(1, 1);
}

Future<void> _longPressCanvas(
  WidgetTester tester,
  Finder finder, {
  required Offset localPosition,
}) async {
  await tester.longPressAt(tester.getTopLeft(finder) + localPosition);
  await tester.pumpAndSettle();
}

Future<Offset> _firstPagedGlyphCenter({
  required Size size,
  required Document document,
}) async {
  final engine = KumihanEngine(
    baseUri: null,
    initialPage: 0,
    onInvalidate: () {},
    onSnapshot: (_) {},
  );

  await engine.resize(size.width, size.height);
  await engine.open(document);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  engine.paint(canvas);
  recorder.endRecording();

  return _firstGlyphCenter(engine.selectableGlyphs);
}

Future<Rect> _pagedBounds({
  required Size size,
  required Document document,
  KumihanLayoutData layout = const KumihanLayoutData(),
}) async {
  final engine = KumihanEngine(
    baseUri: null,
    initialPage: 0,
    layout: layout,
    onInvalidate: () {},
    onSnapshot: (_) {},
  );

  await engine.resize(size.width, size.height);
  await engine.open(document);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  engine.paint(canvas);
  recorder.endRecording();

  return _glyphBounds(engine.selectableGlyphs);
}

Future<Offset> _firstScrollGlyphCenter({
  required Size size,
  required Document document,
}) async {
  final engine = KumihanScrollEngine(
    baseUri: null,
    onInvalidate: () {},
    onSnapshot: (_) {},
  );

  await engine.resize(size.width, size.height);
  await engine.open(document);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  engine.paint(canvas);
  recorder.endRecording();

  return _firstGlyphCenter(engine.selectableGlyphs);
}

Future<Offset> _firstBookGlyphCenter({
  required Size size,
  required Document document,
}) async {
  return _bookGlyphCenterForText(size: size, document: document, text: null);
}

Future<Offset> _bookGlyphCenterForText({
  required Size size,
  required Document document,
  required String? text,
}) async {
  const layout = KumihanBookLayoutData();
  final engine = KumihanEngine(
    baseUri: null,
    initialPage: 0,
    onInvalidate: () {},
    onSnapshot: (_) {},
  );
  const theme = KumihanThemeData();
  final renderer = BookSpreadRenderer(
    engine: engine,
    layout: layout,
    theme: theme,
    spreadMode: KumihanSpreadMode.doublePage,
  );
  final pageSize = renderer.resolvePageSize(size);

  await engine.resize(pageSize.width, pageSize.height);
  await engine.open(document);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  engine.resetPaintState();
  renderer.paint(
    canvas,
    size,
    currentPage: 0,
    totalPages: engine.snapshot.totalPages,
  );
  recorder.endRecording();

  final glyphs = engine.selectableGlyphs;
  if (text == null) {
    return _firstGlyphCenter(glyphs);
  }
  return glyphs.firstWhere((item) => item.text == text).rect.center;
}

Future<Offset> _bookPageGlyphCenter({
  required Size size,
  required Document document,
  required bool onLeftPage,
}) async {
  const layout = KumihanBookLayoutData();
  final engine = KumihanEngine(
    baseUri: null,
    initialPage: 0,
    onInvalidate: () {},
    onSnapshot: (_) {},
  );
  const theme = KumihanThemeData();
  final renderer = BookSpreadRenderer(
    engine: engine,
    layout: layout,
    theme: theme,
    spreadMode: KumihanSpreadMode.doublePage,
  );
  final enginePageSize = renderer.resolvePageSize(size);
  final viewportPageSize = Size(size.width / 2, size.height);

  await engine.resize(enginePageSize.width, enginePageSize.height);
  await engine.open(document);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  renderer.paintDocumentPageSurface(
    canvas,
    viewportPageSize,
    pageIndex: 0,
    totalPages: engine.snapshot.totalPages,
    slot: BookPageSlot.right,
    globalViewportOrigin: Offset(viewportPageSize.width, 0),
    resetPaintState: true,
    recordInteractiveRegions: true,
  );
  renderer.paintDocumentPageSurface(
    canvas,
    viewportPageSize,
    pageIndex: 1,
    totalPages: engine.snapshot.totalPages,
    slot: BookPageSlot.left,
    globalViewportOrigin: Offset.zero,
    resetPaintState: false,
    recordInteractiveRegions: true,
  );
  recorder.endRecording();

  final glyphs = List<KumihanSelectableGlyph>.of(engine.selectableGlyphs);
  final midpoint = size.width / 2;
  final candidates = glyphs
      .where(
        (glyph) => onLeftPage
            ? glyph.rect.center.dx < midpoint
            : glyph.rect.center.dx >= midpoint,
      )
      .toList(growable: false);
  if (candidates.isEmpty) {
    throw StateError('No selectable glyphs were recorded on the target page.');
  }
  candidates.sort((a, b) => b.rect.center.dy.compareTo(a.rect.center.dy));
  return candidates.first.rect.center;
}

Future<Rect> _bookBounds({
  required Size size,
  required Document document,
  KumihanBookLayoutData layout = const KumihanBookLayoutData(),
  KumihanSpreadMode spreadMode = KumihanSpreadMode.doublePage,
}) async {
  return _glyphBounds(
    await _bookGlyphs(
      size: size,
      document: document,
      layout: layout,
      spreadMode: spreadMode,
    ),
  );
}

Future<List<KumihanSelectableGlyph>> _bookGlyphs({
  required Size size,
  required Document document,
  KumihanBookLayoutData layout = const KumihanBookLayoutData(),
  KumihanSpreadMode spreadMode = KumihanSpreadMode.doublePage,
}) async {
  final engine = KumihanEngine(
    baseUri: null,
    initialPage: 0,
    onInvalidate: () {},
    onSnapshot: (_) {},
  );
  const theme = KumihanThemeData();
  final renderer = BookSpreadRenderer(
    engine: engine,
    layout: layout,
    theme: theme,
    spreadMode: spreadMode,
  );
  final pageSize = renderer.resolvePageSize(size);

  await engine.resize(pageSize.width, pageSize.height);
  await engine.open(document);

  final recorder = PictureRecorder();
  final canvas = Canvas(recorder);
  engine.resetPaintState();
  renderer.paint(
    canvas,
    size,
    currentPage: 0,
    totalPages: engine.snapshot.totalPages,
  );
  recorder.endRecording();

  return List<KumihanSelectableGlyph>.of(engine.selectableGlyphs);
}

Offset _firstGlyphCenter(List<KumihanSelectableGlyph> glyphs) {
  if (glyphs.isEmpty) {
    throw StateError('No selectable glyphs were recorded.');
  }
  return glyphs.first.rect.center;
}

Finder _selectionHighlightFinder() {
  return find.byWidgetPredicate((widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final decoration = widget.decoration;
    if (decoration is! BoxDecoration) {
      return false;
    }
    return decoration.color == const Color(0x331a73e8);
  });
}

Rect _glyphBounds(List<KumihanSelectableGlyph> glyphs) {
  if (glyphs.isEmpty) {
    throw StateError('No selectable glyphs were recorded.');
  }
  return glyphs
      .map((item) => item.rect)
      .reduce((value, element) => value.expandToInclude(element));
}
