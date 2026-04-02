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

    test('ordered lists keep inline styles on the same paragraph', () {
      final compiled = compileAst(
        const MarkdownParser().parse(
          '1. **春**は`あけぼの`\n'
          '2. 夏は夜\n'
          '3. 秋は夕暮れ\n'
          '4. *冬*はつとめて\n',
        ),
      );

      final paragraphs = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .toList();
      expect(paragraphs, hasLength(4));
      expect(paragraphs[0].text, '一、春はあけぼの');
      expect(
        paragraphs[0].styles.any((style) => style.kind == AstStyleKind.bold),
        isTrue,
      );
      expect(
        paragraphs[0].styles.any(
          (style) => style.kind == AstStyleKind.yokogumi,
        ),
        isTrue,
      );
      expect(paragraphs[3].text, '四、冬はつとめて');
      expect(
        paragraphs[3].styles.any((style) => style.kind == AstStyleKind.italic),
        isTrue,
      );
    });

    test('blockquote compiles to quoted paragraph with indentation', () {
      final compiled = compileAst(
        const MarkdownParser().parse('> 雨ニモマケズ\n>\n> 風ニモマケズ\n'),
      );

      expect(
        compiled.entries.first,
        isA<AstCommandEntry>().having(
          (entry) => entry.kind,
          'kind',
          AstCommandKind.quoteStart,
        ),
      );

      final paragraphs = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .toList();
      expect(paragraphs, hasLength(2));
      expect(paragraphs[0].text, '雨ニモマケズ');
      expect(paragraphs[0].firstTopMargin, 0);
      expect(paragraphs[0].restTopMargin, 0);
      expect(paragraphs[1].text, '風ニモマケズ');
      expect(
        compiled.entries.whereType<AstCommandEntry>().any(
          (entry) => entry.kind == AstCommandKind.quoteEnd,
        ),
        isTrue,
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
