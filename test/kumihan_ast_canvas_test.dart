import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  testWidgets('aozora ast text can be opened and paginated', (tester) async {
    final controller = KumihanController();

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          width: 400,
          height: 600,
          child: KumihanAstCanvas.aozora(
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
}
