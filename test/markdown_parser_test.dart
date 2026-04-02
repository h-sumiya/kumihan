import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('MarkdownParser', () {
    test('parses headings, links, tables, and code blocks', () {
      const parser = MarkdownParser();

      final document = parser.parse(
        '# 見出し\n\n'
        '[青空文庫](https://www.aozora.gr.jp/)\n\n'
        '```dart\n'
        'final answer = 42;\n'
        '```\n\n'
        '| 列 | 値 |\n'
        '| :- | -: |\n'
        '| a | 1 |\n',
      );

      final compiled = compileAst(document);

      expect(
        compiled.entries.whereType<AstCompiledParagraphEntry>().first.text,
        '見出し',
      );

      final linkParagraph = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .firstWhere((entry) => entry.text.contains('青空文庫'));
      final link = linkParagraph.extras.singleWhere(
        (extra) => extra.kind == AstParagraphExtraKind.link,
      );
      expect(link.linkTarget, 'https://www.aozora.gr.jp/');

      final codeParagraph = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .firstWhere((entry) => entry.text.contains('final answer = 42;'));
      expect(codeParagraph.styles, isNotEmpty);
      expect(
        compiled.entries.whereType<AstCommandEntry>().any(
          (entry) => entry.kind == AstCommandKind.frameStart,
        ),
        isTrue,
      );
      expect(
        compiled.entries.whereType<AstCommandEntry>().any(
          (entry) => entry.kind == AstCommandKind.frameEnd,
        ),
        isTrue,
      );
      expect(
        compiled.entries
            .whereType<AstCompiledParagraphEntry>()
            .expand((entry) => entry.extras)
            .where((extra) => extra.kind == AstParagraphExtraKind.note),
        isEmpty,
      );

      final table = compiled.entries.whereType<AstCompiledTableEntry>().single;
      expect(table.headerRowCount, 1);
      expect(table.rows, hasLength(2));
      expect(table.rows.first.first.text, '列');
      expect(table.rows.first.last.alignment, AstTableAlignment.end);
    });

    test('list blocks do not emit unsupported note markers', () {
      final compiled = compileAst(
        const MarkdownParser().parse(
          '- 吾輩は猫である\n'
          '- 坊っちゃん\n'
          '1. 春はあけぼの\n'
          '2. 夏は夜\n',
        ),
      );

      expect(
        compiled.entries
            .whereType<AstCompiledParagraphEntry>()
            .expand((entry) => entry.extras)
            .where((extra) => extra.kind == AstParagraphExtraKind.note),
        isEmpty,
      );
    });

    testWidgets('opens markdown with a rendered table', (tester) async {
      final engine = KumihanEngine(
        baseUri: null,
        initialPage: 0,
        onInvalidate: () {},
        onSnapshot: (_) {},
      );

      await engine.resize(400, 600);
      await engine.open(
        const MarkdownParser().parse(
          '# 表\n\n'
          '| 作品名 | 発表年 |\n'
          '| :----- | -----: |\n'
          '| 羅生門 | 1915 |\n',
        ),
      );

      expect(engine.snapshot.totalPages, greaterThanOrEqualTo(1));
    });
  });
}
