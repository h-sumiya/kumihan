import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('HtmlParser', () {
    test('parses headings, ruby, lists, table, and code blocks', () {
      final compiled = compileAst(
        const HtmlParser().parse(
          '<h1>見出し</h1>'
          '<p><ruby>青空<rt>あおぞら</rt></ruby>文庫</p>'
          '<ol start="2"><li><strong>本文</strong></li></ol>'
          '<pre><code>final answer = 42;</code></pre>'
          '<table><tr><th>列</th><th align="right">値</th></tr><tr><td>a</td><td>1</td></tr></table>',
        ),
      );

      final paragraphs = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .toList();
      expect(paragraphs.first.text, '見出し');
      expect(paragraphs[1].text, '青空文庫');
      expect(paragraphs[1].rubies.single.ruby, 'あおぞら');
      expect(paragraphs[2].text, '二、本文');
      expect(
        paragraphs[2].styles.any((style) => style.kind == AstStyleKind.bold),
        isTrue,
      );

      final codeParagraph = paragraphs.firstWhere(
        (entry) => entry.text.contains('final answer = 42;'),
      );
      expect(
        codeParagraph.styles.any(
          (style) => style.kind == AstStyleKind.yokogumi,
        ),
        isTrue,
      );

      final table = compiled.entries.whereType<AstCompiledTableEntry>().single;
      expect(table.headerRowCount, 1);
      expect(table.rows.first.last.alignment, AstTableAlignment.end);
    });

    test('blockquote and section compile to quote and indent commands', () {
      final compiled = compileAst(
        const HtmlParser().parse(
          '<section><p>導入</p><blockquote><p>本文</p><p>作者：太郎</p></blockquote></section>',
        ),
      );

      expect(
        compiled.entries.first,
        isA<AstCommandEntry>().having(
          (entry) => entry.kind,
          'kind',
          AstCommandKind.indentStart,
        ),
      );
      expect(
        compiled.entries.any(
          (entry) =>
              entry is AstCommandEntry &&
              entry.kind == AstCommandKind.quoteStart,
        ),
        isTrue,
      );

      final paragraphs = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .toList();
      expect(paragraphs[0].text, '導入');
      expect(paragraphs[1].text, '本文');
      expect(paragraphs[2].text, '　');
      expect(paragraphs[3].text, '太郎');
      expect(paragraphs[3].alignBottom, isTrue);
      expect(paragraphs[3].suppressQuote, isTrue);
    });

    test('maps del and ins to ruled line spans', () {
      final compiled = compileAst(
        const HtmlParser().parse('<p><del>旧文</del>と<ins>新文</ins></p>'),
      );

      final paragraph = compiled.entries
          .whereType<AstCompiledParagraphEntry>()
          .single;
      expect(paragraph.text, '旧文と新文');
      expect(
        paragraph.extras.any(
          (extra) =>
              extra.kind == AstParagraphExtraKind.span &&
              extra.ruledLineKind == AstRuledLineKind.cancel,
        ),
        isTrue,
      );
      expect(
        paragraph.extras.any(
          (extra) =>
              extra.kind == AstParagraphExtraKind.span &&
              extra.ruledLineKind == AstRuledLineKind.solid,
        ),
        isTrue,
      );
    });

    testWidgets('opens html with rendered content', (tester) async {
      final controller = KumihanController();

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SizedBox(
            width: 400,
            height: 600,
            child: KumihanCanvas.html(
              text: '<section><h1>表題</h1><p>本文です。</p></section>',
              controller: controller,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(controller.snapshot.totalPages, greaterThanOrEqualTo(1));
    });
  });
}
