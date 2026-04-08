import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart' hide Text;
import 'package:kumihan/src/page_flip/page_flip_painter.dart';

void main() {
  testWidgets('page flip action region blocks page turning', (tester) async {
    var tapped = 0;

    final pages = List<Widget>.generate(4, (index) {
      return Center(
        child: PageFlipActionRegion(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              tapped += 1;
            },
            child: SizedBox(
              width: 80,
              height: 48,
              child: Center(
                child: Text(
                  'Button ${index + 1}',
                  textDirection: TextDirection.ltr,
                ),
              ),
            ),
          ),
        ),
      );
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageFlipBook(
            pageCount: pages.length,
            pageSize: const Size(240, 360),
            pageBuilder: (context, index) => pages[index],
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final book = find.byType(PageFlipBook);
    expect(book, findsOneWidget);

    await tester.tap(find.text('Button 2'));
    await tester.pump();

    final state = tester.state(book) as dynamic;
    expect(tapped, 1);
    expect(state.debugRightPageIndex, 0);
    expect(state.debugIsDragging, isFalse);
  });

  testWidgets('kumihan book long press selection does not flip pages', (
    tester,
  ) async {
    final controller = KumihanPagedController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 720,
          height: 560,
          child: KumihanBook(
            controller: controller,
            layout: const KumihanBookLayoutData(
              topUiPadding: EdgeInsets.fromLTRB(24, 40, 24, 0),
              bodyPadding: KumihanBookBodyPadding(
                top: 16,
                inner: 20,
                outer: 20,
                bottom: 28,
              ),
              bottomUiPadding: EdgeInsets.fromLTRB(24, 0, 24, 12),
            ),
            document: const AozoraParser().parse(
              '一頁目です。十分な文字量を入れておきます。'
              '\n［＃改ページ］\n二頁目です。'
              '\n［＃改ページ］\n三頁目です。'
              '\n［＃改ページ］\n四頁目です。',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final book = find.byType(PageFlipBook);
    final rect = tester.getRect(book);
    final bodyPoint = Offset(
      rect.center.dx + rect.width / 4 - 24,
      rect.center.dy,
    );

    final gesture = await tester.startGesture(bodyPoint);
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.moveBy(const Offset(-120, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 0);
  });

  testWidgets('page snapshots are refreshed when source pages repaint', (
    tester,
  ) async {
    final highlight = ValueNotifier<bool>(false);

    Widget page(int index) {
      return ValueListenableBuilder<bool>(
        valueListenable: highlight,
        builder: (context, highlighted, child) {
          final isDynamicPage = index == 2;
          final color = isDynamicPage && highlighted
              ? const Color(0xFF2255FF)
              : const Color(0xFFCC3344);
          return ColoredBox(
            color: color,
            child: Center(
              child: Text(
                'Page ${index + 1}',
                textDirection: TextDirection.ltr,
              ),
            ),
          );
        },
      );
    }

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageFlipBook(
            pageCount: 4,
            pageSize: const Size(240, 360),
            pageBuilder: (context, index) => page(index),
            snapshotPageBuilder: (context, index) => page(index),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final state = tester.state(find.byType(PageFlipBook)) as dynamic;
    final initialVersion = state.debugPageImageVersion as int;
    expect(initialVersion, greaterThan(0));

    highlight.value = true;
    await tester.pump();
    await tester.pumpAndSettle();

    expect(state.debugPageImageVersion, greaterThan(initialVersion));
  });

  testWidgets('single page mode advances one page per turn', (tester) async {
    final pages = List<Widget>.generate(
      5,
      (index) => Center(
        child: Text('Page ${index + 1}', textDirection: TextDirection.ltr),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageFlipBook(
            pageCount: pages.length,
            pageSize: const Size(240, 360),
            displayMode: PageDisplayMode.singlePage,
            pageBuilder: (context, index) => pages[index],
          ),
        ),
      ),
    );

    final book = find.byType(PageFlipBook);
    final state = tester.state(book) as dynamic;

    await tester.tapAt(tester.getCenter(book) + const Offset(-40, 0));
    await tester.pumpAndSettle();

    expect(state.debugRightPageIndex, 1);
  });

  testWidgets('custom tap action resolver can swap tap directions', (
    tester,
  ) async {
    final pages = List<Widget>.generate(
      5,
      (index) => Center(
        child: Text('Page ${index + 1}', textDirection: TextDirection.ltr),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageFlipBook(
            pageCount: pages.length,
            pageSize: const Size(240, 360),
            displayMode: PageDisplayMode.singlePage,
            tapActionResolver: (width, height, x, y) {
              return x < width / 2
                  ? PageFlipTapAction.back
                  : PageFlipTapAction.next;
            },
            pageBuilder: (context, index) => pages[index],
          ),
        ),
      ),
    );

    final book = find.byType(PageFlipBook);
    final state = tester.state(book) as dynamic;

    await tester.tapAt(tester.getCenter(book) + const Offset(40, 0));
    await tester.pumpAndSettle();

    expect(state.debugRightPageIndex, 1);
  });

  testWidgets('custom tap action resolver can disable tap flipping', (
    tester,
  ) async {
    final pages = List<Widget>.generate(
      5,
      (index) => Center(
        child: Text('Page ${index + 1}', textDirection: TextDirection.ltr),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageFlipBook(
            pageCount: pages.length,
            pageSize: const Size(240, 360),
            displayMode: PageDisplayMode.singlePage,
            tapActionResolver: (width, height, x, y) => null,
            pageBuilder: (context, index) => pages[index],
          ),
        ),
      ),
    );

    final book = find.byType(PageFlipBook);
    final state = tester.state(book) as dynamic;

    await tester.tapAt(tester.getCenter(book) + const Offset(-40, 0));
    await tester.pumpAndSettle();

    expect(state.debugRightPageIndex, 0);
  });

  testWidgets('single page backward grip flips to previous page', (
    tester,
  ) async {
    final pages = List<Widget>.generate(
      6,
      (index) => Center(
        child: Text('Page ${index + 1}', textDirection: TextDirection.ltr),
      ),
    );

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: PageFlipBook(
            pageCount: pages.length,
            pageSize: const Size(240, 360),
            displayMode: PageDisplayMode.singlePage,
            pageBuilder: (context, index) => pages[index],
          ),
        ),
      ),
    );

    final book = find.byType(PageFlipBook);
    final state = tester.state(book) as dynamic;

    for (var i = 0; i < 3; i += 1) {
      await tester.tapAt(tester.getCenter(book) + const Offset(-40, 0));
      await tester.pumpAndSettle();
    }

    expect(state.debugRightPageIndex, 3);

    final gesture = await tester.startGesture(
      tester.getTopLeft(book) + const Offset(228, 40),
    );
    await tester.pump();

    expect(state.debugIsDragging, isTrue);

    await gesture.up();
    await tester.pump();
  });

  testWidgets('kumihan book forwards tap action resolver to page flip book', (
    tester,
  ) async {
    final controller = KumihanPagedController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 720,
          height: 560,
          child: KumihanBook(
            controller: controller,
            spreadMode: KumihanSpreadMode.single,
            tapActionResolver: (width, height, x, y) {
              return x < width / 2
                  ? PageFlipTapAction.back
                  : PageFlipTapAction.next;
            },
            document: const AozoraParser().parse(
              '一頁目です。'
              '\n［＃改ページ］\n二頁目です。'
              '\n［＃改ページ］\n三頁目です。',
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final book = find.byType(PageFlipBook);
    final rect = tester.getRect(book);

    await tester.tapAt(Offset(rect.center.dx + rect.width / 4, rect.center.dy));
    await tester.pumpAndSettle();

    expect(controller.snapshot.currentPage, 1);
  });

  testWidgets(
    'single mode keeps double-width paint layout and clips viewport',
    (tester) async {
      final pages = List<Widget>.generate(
        3,
        (index) => Center(
          child: Text('Page ${index + 1}', textDirection: TextDirection.ltr),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: PageFlipBook(
              pageCount: pages.length,
              pageSize: const Size(240, 360),
              displayMode: PageDisplayMode.singlePage,
              pageBuilder: (context, index) => pages[index],
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(tester.getSize(find.byType(PageFlipBook)), const Size(240, 360));

      final paintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is PageFlipPainter,
      );
      expect(paintFinder, findsOneWidget);
      expect(tester.getSize(paintFinder), const Size(480, 360));
    },
  );
}
