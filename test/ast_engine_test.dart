import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  test('compiles aozora ast into structured paragraphs', () {
    const parser = AozoraAstParser();
    final ast = parser.parse(
      '青空文庫《あおぞらぶんこ》\n'
      '責［＃「責」に白丸傍点］\n'
      '［＃改ページ］\n'
      '終わり',
    );

    final compiled = compileAozoraAst(ast);

    expect(compiled.entries, hasLength(4));
    expect(compiled.entries[0], isA<AstCompiledParagraphEntry>());
    final first = compiled.entries[0] as AstCompiledParagraphEntry;
    expect(first.text, '青空文庫');
    expect(first.rubies, hasLength(1));
    expect(first.rubies.single.ruby, 'あおぞらぶんこ');

    final second = compiled.entries[1] as AstCompiledParagraphEntry;
    expect(second.extras.single.kind, AstParagraphExtraKind.emphasis);

    final third = compiled.entries[2] as AstCommandEntry;
    expect(third.kind, AstCommandKind.pageBreak);
  });

  testWidgets('ast engine opens parsed ast and paginates', (tester) async {
    final parser = const AozoraAstParser();
    final engine = KumihanAstEngine(
      baseUri: null,
      initialPage: 0,
      layout: const KumihanLayoutData(),
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(400, 600);
    await engine.openAst(
      parser.parse('［＃１字下げ］表示サンプルです。\n［＃改ページ］\n次のページです。'),
    );

    expect(engine.snapshot.totalPages, greaterThanOrEqualTo(2));
    expect(engine.snapshot.currentPage, 0);
  });
}
