import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('AozoraAstParser', () {
    late AozoraAstParser parser;

    setUp(() {
      parser = AozoraAstParser();
    });

    test('parses implicit and explicit ruby bases', () {
      final document = parser.parse('霧の｜ロンドン警視庁《スコットランドヤード》');
      final paragraph = _onlyParagraph(document);

      expect(paragraph.children, hasLength(2));

      final leading = paragraph.children.first as TextNode;
      expect(leading.text, '霧の');

      final ruby = paragraph.children.last as RubyNode;
      expect(ruby.kind, RubyKind.phonetic);
      expect(ruby.position, RubyPosition.over);
      expect(ruby.text, 'スコットランドヤード');
      expect(ruby.base, hasLength(1));
      expect((ruby.base.first as TextNode).text, 'ロンドン警視庁');
    });

    test('parses front-reference directives into inline containers', () {
      final document = parser.parse('米機Ｂ29［＃「29」は縦中横］の編隊は、');
      final paragraph = _onlyParagraph(document);

      expect(paragraph.children, hasLength(3));
      expect((paragraph.children.first as TextNode).text, '米機Ｂ');

      final container = paragraph.children[1] as DirectionInlineNode;
      expect(container.kind, DirectionKind.tateChuYoko);
      expect(
        container.openDirective.category,
        SourceDirectiveCategory.inlineReference,
      );
      expect(container.children, hasLength(1));
      expect((container.children.first as TextNode).text, '29');

      expect((paragraph.children.last as TextNode).text, 'の編隊は、');
    });

    test('parses note-attached gaiji into annotation ruby nodes', () {
      final document = parser.parse('［＃注記付き］名※［＃二の字点、1-2-22］［＃「（銘々）」の注記付き終わり］');
      final paragraph = _onlyParagraph(document);

      expect(paragraph.children, hasLength(1));

      final ruby = paragraph.children.single as RubyNode;
      expect(ruby.kind, RubyKind.annotation);
      expect(ruby.position, RubyPosition.over);
      expect(ruby.text, '（銘々）');
      expect(ruby.base, hasLength(2));
      expect((ruby.base.first as TextNode).text, '名');

      final gaiji = ruby.base.last as GaijiNode;
      expect(gaiji.description, '二の字点、1-2-22');
      expect(gaiji.jisCode, '1-2-22');
    });

    test('parses multiline block directives as structured containers', () {
      final document = parser.parse('［＃ここから太字］\nテスト。\n［＃ここで太字終わり］');

      expect(document.children, hasLength(1));

      final container = document.children.single as StyledBlockNode;
      expect(container.style, TextStyleKind.bold);
      expect(container.isClosed, isTrue);
      expect(container.children, hasLength(1));

      final paragraph = container.children.single as ParagraphNode;
      expect(paragraph.children, hasLength(1));
      expect((paragraph.children.single as TextNode).text, 'テスト。');
    });

    test('preserves explicit line-break directives inside inline scopes', () {
      final document = parser.parse('［＃割り注］東は［＃改行］西は［＃割り注終わり］');
      final paragraph = _onlyParagraph(document);
      final container = paragraph.children.single as NoteInlineNode;

      expect(container.kind, NoteKind.warichu);
      expect(container.children, hasLength(3));
      expect((container.children.first as TextNode).text, '東は');
      expect(container.children[1], isA<LineBreakNode>());
      expect((container.children.last as TextNode).text, '西は');
    });

    test('preserves unknown directives and reports unclosed blocks', () {
      final document = parser.parse('未知［＃未対応注記］です\n［＃ここから太字］\n未閉鎖');

      expect(document.children, hasLength(2));

      final paragraph = document.children.first as ParagraphNode;
      expect(paragraph.children, hasLength(3));
      expect(
        (paragraph.children[1] as OpaqueInlineNode).directive.rawText,
        '［＃未対応注記］',
      );

      final container = document.children.last as StyledBlockNode;
      expect(container.style, TextStyleKind.bold);
      expect(container.isClosed, isFalse);

      expect(document.diagnostics, hasLength(1));
      expect(document.diagnostics.single.code, 'unclosed_block_container');
    });
  });
}

ParagraphNode _onlyParagraph(DocumentNode document) {
  expect(document.children, hasLength(1));
  return document.children.single as ParagraphNode;
}
