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

  test(
    'compiles frame and cancel annotations into legacy-equivalent markers',
    () {
      const parser = AozoraAstParser();
      final ast = parser.parse(
        '［＃ここから罫囲み］\n'
        '囲み\n'
        '［＃ここで罫囲み終わり］\n'
        '責［＃「責」に取消線］\n'
        '語［＃「語」は罫囲み］',
      );

      final compiled = compileAozoraAst(ast);
      final commands = compiled.entries.whereType<AstCommandEntry>().toList();
      final paragraphs = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .toList();

      expect(
        commands.any((entry) => entry.kind == AstCommandKind.frameStart),
        isTrue,
      );
      expect(
        commands.any((entry) => entry.kind == AstCommandKind.frameEnd),
        isTrue,
      );
      expect(
        paragraphs.any(
          (entry) => entry.extras.any(
            (extra) =>
                extra.kind == AstParagraphExtraKind.frame &&
                extra.frameKind == AstFrameKind.start,
          ),
        ),
        isTrue,
      );
      expect(
        paragraphs.any(
          (entry) => entry.extras.any(
            (extra) =>
                extra.kind == AstParagraphExtraKind.frame &&
                extra.frameKind == AstFrameKind.end,
          ),
        ),
        isTrue,
      );
      expect(
        paragraphs.any(
          (entry) => entry.extras.any(
            (extra) => extra.ruledLineKind == AstRuledLineKind.cancel,
          ),
        ),
        isTrue,
      );
      expect(
        paragraphs.any(
          (entry) => entry.extras.any(
            (extra) => extra.ruledLineKind == AstRuledLineKind.frameBox,
          ),
        ),
        isTrue,
      );
    },
  );

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
    await engine.openAst(parser.parse('［＃１字下げ］表示サンプルです。\n［＃改ページ］\n次のページです。'));

    expect(engine.snapshot.totalPages, greaterThanOrEqualTo(2));
    expect(engine.snapshot.currentPage, 0);
  });
}
