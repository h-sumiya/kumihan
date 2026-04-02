import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  test('compiles aozora ast into structured paragraphs', () {
    const parser = AozoraParser();
    final ast = parser.parse(
      '青空文庫《あおぞらぶんこ》\n'
      '責［＃「責」に白丸傍点］\n'
      '［＃改ページ］\n'
      '終わり',
    );

    final compiled = compileAst(ast);

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
      const parser = AozoraParser();
      final ast = parser.parse(
        '［＃ここから罫囲み］\n'
        '囲み\n'
        '［＃ここで罫囲み終わり］\n'
        '責［＃「責」に取消線］\n'
        '語［＃「語」は罫囲み］',
      );

      final compiled = compileAst(ast);
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

  test(
    'compiles inline tail bottom alignment into a non-breaking tail block',
    () {
      const parser = AozoraParser();
      final ast = parser.parse('行の最後の部分だけ、地付き［＃地付き］地付き');

      final compiled = compileAst(ast);
      final paragraphs = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .toList();

      expect(paragraphs, hasLength(2));
      expect(paragraphs[0].text, '行の最後の部分だけ、地付き');
      expect(paragraphs[0].alignBottom, isFalse);
      expect(paragraphs[1].text, '地付き');
      expect(paragraphs[1].alignBottom, isTrue);
      expect(paragraphs[1].bottomMargin, 0);
      expect(paragraphs[1].nonBreak, isTrue);
      expect(
        paragraphs.expand((entry) => entry.extras),
        isNot(
          contains(
            isA<AstParagraphExtra>().having(
              (extra) => extra.kind,
              'kind',
              AstParagraphExtraKind.note,
            ),
          ),
        ),
      );
    },
  );

  testWidgets('ast engine opens parsed ast and paginates', (tester) async {
    final parser = const AozoraParser();
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      layout: const KumihanLayoutData(),
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(400, 600);
    await engine.open(parser.parse('［＃１字下げ］表示サンプルです。\n［＃改ページ］\n次のページです。'));

    expect(engine.snapshot.totalPages, greaterThanOrEqualTo(2));
    expect(engine.snapshot.currentPage, 0);
  });

  testWidgets('ast engine emits start middle end markers for block frames', (
    tester,
  ) async {
    final parser = const AozoraParser();
    final engine = KumihanEngine(
      baseUri: null,
      initialPage: 0,
      layout: const KumihanLayoutData(),
      onInvalidate: () {},
      onSnapshot: (_) {},
    );

    await engine.resize(400, 600);
    await engine.open(
      parser.parse(
        '［＃ここから罫囲み］\n'
        '囲み本文\n'
        '［＃ここで罫囲み終わり］',
      ),
    );

    final roles =
        engine.renderTrace?.commands
            .where((command) => command.kind == 'marker')
            .map((command) => command.role)
            .whereType<String>()
            .toList() ??
        const <String>[];

    expect(roles, contains('frameStart'));
    expect(roles, contains('frameMiddle'));
    expect(roles, contains('frameEnd'));
  });
}
