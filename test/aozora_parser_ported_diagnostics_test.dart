import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan_v1/kumihan.dart';

import 'support/aozora_test_utils.dart';

void main() {
  group('AozoraAstParser ported diagnostics', () {
    test('ported from test_aozora_accent_parser.rb: test_invalid', () {
      final document = parseDocument('〔e\'tiquette');
      final paragraph = onlyParagraph(document);

      expect(paragraph.children, hasLength(1));
      expectTextNode(paragraph.children.single, '〔e\'tiquette');
      expect(document.diagnostics, hasLength(1));
      expect(document.diagnostics.single.code, 'unclosed_accent_bracket');
    });

    test('ported from test_font_size_tag.rb: test_to_s0', () {
      final document = parseDocument('［＃ここから0段階小さな文字］\nテスト\n［＃ここで0段階小さな文字終わり］');

      expect(document.children, hasLength(3));
      expect(document.children.first, isA<OpaqueBlockNode>());
      expect(document.diagnostics, hasLength(1));
      expect(document.diagnostics.single.code, 'invalid_font_size');
    });

    test(
      'ported from test_multiline_midashi_tag.rb: test_undeined_midashi',
      () {
        final document = parseDocument('［＃ここからあ見出し］\nテスト\n［＃ここであ見出し終わり］');

        expect(document.children, hasLength(3));
        expect(document.children.first, isA<OpaqueBlockNode>());
        expect(document.diagnostics, hasLength(1));
        expect(document.diagnostics.single.code, 'invalid_heading');
      },
    );

    test(
      'ported from test_multiline_midashi_tag.rb: test_undeined_midashi2',
      () {
        final document = parseDocument(
          '［＃ここから大見出しmadoo］\nテスト\n［＃ここで大見出しmadoo終わり］',
        );

        expect(document.children.first, isA<OpaqueBlockNode>());
        expect(document.diagnostics.single.code, 'invalid_heading');
      },
    );

    test('ported from test_midashi_tag.rb: test_undeined_midashi', () {
      final paragraph = onlyParagraph(parseDocument('テスト見出し［＃「テスト見出し」はあ見出し］'));

      expect(paragraph.children, hasLength(2));
      expect(paragraph.children.last, isA<EditorNoteNode>());
    });

    test('ported from test_aozora2html.rb: test_tcy', () {
      final document = parseDocument('［＃縦中横］（※［＃ローマ数字1、1-13-21］）\n');

      expect(document.children, hasLength(1));
      expect(document.diagnostics, isNotEmpty);
      expect(document.diagnostics.first.code, 'inline_container_crossed_line');
    });

    test('ported from test_aozora2html.rb: test_ensure_close', () {
      final document = parseDocument('［＃ここから５字下げ］\n底本： test\n');

      expect(document.children, hasLength(1));
      final container = document.children.single as IndentBlockNode;
      expect(container.isClosed, isFalse);
      expect(document.diagnostics, isNotEmpty);
      expect(document.diagnostics.first.code, 'unclosed_block_container');
    });

    test('ported from test_aozora2html.rb: test_invalid_closing', () {
      final document = parseDocument('［＃ここで太字終わり］');

      expect(document.children, hasLength(1));
      expect(document.children.single, isA<OpaqueBlockNode>());
      expect(document.diagnostics, hasLength(1));
      expect(document.diagnostics.single.code, 'orphan_block_close');
    });

    test('ported from test_aozora2html.rb: test_invalid_nest', () {
      final document = parseDocument('［＃太字］［＃傍線］あ［＃太字終わり］');
      final paragraph = onlyParagraph(document);

      expect(paragraph.children, hasLength(1));
      expect(paragraph.children.first, isA<StyledInlineNode>());
      expect(document.diagnostics, hasLength(1));
      expect(document.diagnostics.single.code, 'orphan_inline_close');
    });
  });
}
