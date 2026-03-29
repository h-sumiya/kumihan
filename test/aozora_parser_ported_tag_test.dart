import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

import 'support/aozora_test_utils.dart';

void main() {
  group('AozoraAstParser ported tag cases', () {
    test('ported from test_ruby_tag.rb: test_ruby_new / test_to_s', () {
      final paragraph = onlyParagraph(parseDocument('テスト《てすと》'));

      expect(paragraph.children, hasLength(1));
      final ruby = expectRubyNode(
        paragraph.children.single,
        kind: RubyKind.phonetic,
        position: RubyPosition.over,
        text: 'てすと',
      );
      expect(ruby.base, hasLength(1));
      expect((ruby.base.single as TextNode).text, 'テスト');
    });

    test('ported from test_gaiji_tag.rb: test_gaiji_new', () {
      final paragraph = onlyParagraph(parseDocument('※［＃二の字点、1-2-22］'));

      expect(paragraph.children, hasLength(1));
      expectGaijiNode(
        paragraph.children.single,
        description: '二の字点、1-2-22',
        jisCode: '1-2-22',
      );
    });

    test('ported from test_gaiji_tag.rb: test_unembed_gaiji_new', () {
      final paragraph = onlyParagraph(parseDocument('※［＃「口＋世」、ページ数-行数］'));

      expect(paragraph.children, hasLength(1));
      expectInlineAnnotation(
        paragraph.children.single,
        kind: 'unresolvedGaiji',
        text: '「口＋世」、ページ数-行数',
      );
    });

    for (final variant in <String>['test_jisx0213_class', 'test_jisx0213']) {
      test('ported from test_gaiji_tag.rb: $variant', () {
        final paragraph = onlyParagraph(parseDocument('※［＃snowman、1-06-75］'));

        expect(paragraph.children, hasLength(1));
        expectGaijiNode(
          paragraph.children.single,
          description: 'snowman、1-06-75',
          jisCode: '1-06-75',
        );
      });
    }

    for (final variant in <String>[
      'test_use_unicode_class',
      'test_use_unicode',
    ]) {
      test('ported from test_gaiji_tag.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('※［＃snowman、U+2603、1-06-75］'),
        );

        expect(paragraph.children, hasLength(1));
        expectGaijiNode(
          paragraph.children.single,
          description: 'snowman、U+2603、1-06-75',
          jisCode: '1-06-75',
          unicodeCodePoint: '2603',
        );
      });
    }

    test(
      'ported from test_okurigana_tag.rb: test_okurigana_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('［＃（テスト）］'));

        expect(paragraph.children, hasLength(1));
        expectInlineAnnotation(
          paragraph.children.single,
          kind: 'okurigana',
          text: 'テスト',
        );
      },
    );

    test('ported from test_kaeriten_tag.rb: test_kaeriten_new / test_to_s', () {
      final paragraph = onlyParagraph(parseDocument('自［＃二］女王國'));

      expect(paragraph.children, hasLength(3));
      expectTextNode(paragraph.children.first, '自');
      expectInlineAnnotation(
        paragraph.children[1],
        kind: 'kaeriten',
        text: '二',
      );
      expectTextNode(paragraph.children.last, '女王國');
    });

    test('ported from test_dir_tag.rb: test_dir_new / test_to_s', () {
      final paragraph = onlyParagraph(parseDocument('米機Ｂ29［＃「29」は縦中横］'));

      expect(paragraph.children, hasLength(2));
      expectTextNode(paragraph.children.first, '米機Ｂ');
      final container = expectInlineContainer(
        paragraph.children.last,
        kind: 'direction',
        variant: 'tateChuYoko',
      );
      expect(container.children, hasLength(1));
      expectTextNode(container.children.single, '29');
    });

    test(
      'ported from test_inline_yokogumi_tag.rb: test_yokogumi_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」は横組み］'));

        expect(paragraph.children, hasLength(1));
        final container = expectInlineContainer(
          paragraph.children.single,
          kind: 'flow',
          variant: 'yokogumi',
        );
        expect(container.children, hasLength(1));
        expectTextNode(container.children.single, 'テスト');
      },
    );

    test(
      'ported from test_inline_caption_tag.rb: test_caption_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」はキャプション］'));

        expect(paragraph.children, hasLength(1));
        final container = expectInlineContainer(
          paragraph.children.single,
          kind: 'caption',
          variant: 'caption',
        );
        expect(container.children, hasLength(1));
        expectTextNode(container.children.single, 'テスト');
      },
    );

    test(
      'ported from test_inline_keigakomi_tag.rb: test_keigakomi_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」は罫囲み］'));

        expect(paragraph.children, hasLength(1));
        final container = expectInlineContainer(
          paragraph.children.single,
          kind: 'frame',
          variant: 'keigakomi',
        );
        expect(container.children, hasLength(1));
        expectTextNode(container.children.single, 'テスト');
      },
    );

    test(
      'ported from test_inline_font_size_tag.rb: test_font_size_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」は1段階大きな文字］'));

        expect(paragraph.children, hasLength(1));
        final container = expectInlineContainer(
          paragraph.children.single,
          kind: 'fontSize',
          variant: 'larger',
        );
        expect(container.attributes['steps'], '1');
        expectTextNode(container.children.single, 'テスト');
      },
    );

    test('ported from test_inline_font_size_tag.rb: test_to_s2', () {
      final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」は2段階小さな文字］'));

      final container = expectInlineContainer(
        paragraph.children.single,
        kind: 'fontSize',
        variant: 'smaller',
      );
      expect(container.attributes['steps'], '2');
      expectTextNode(container.children.single, 'テスト');
    });

    test('ported from test_inline_font_size_tag.rb: test_to_s3', () {
      final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」は3段階小さな文字］'));

      final container = expectInlineContainer(
        paragraph.children.single,
        kind: 'fontSize',
        variant: 'smaller',
      );
      expect(container.attributes['steps'], '3');
      expectTextNode(container.children.single, 'テスト');
    });

    test('ported from test_decorate_tag.rb: test_decorate_new / test_to_s', () {
      final paragraph = onlyParagraph(parseDocument('テスト［＃「テスト」に傍点］'));

      expect(paragraph.children, hasLength(1));
      final container = expectInlineContainer(
        paragraph.children.single,
        kind: 'emphasis',
        variant: 'sesameDot',
      );
      expectTextNode(container.children.single, 'テスト');
    });

    test(
      'ported from test_editor_note_tag.rb: test_editor_note_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('［＃注記のテスト］'));

        expect(paragraph.children, hasLength(1));
        expectInlineAnnotation(
          paragraph.children.single,
          kind: 'editorNote',
          text: '注記のテスト',
        );
      },
    );

    test('ported from test_img_tag.rb: test_img_new / test_to_s', () {
      final paragraph = onlyParagraph(
        parseDocument('［＃alt img1（foo.png、横40×縦50）入る］'),
      );

      expect(paragraph.children, hasLength(1));
      expectImageNode(
        paragraph.children.single,
        source: 'foo.png',
        alt: 'alt img1',
        className: 'img1',
        width: 40,
        height: 50,
      );
    });

    test(
      'ported from test_font_size_tag.rb: test_font_size_new / test_to_s',
      () {
        final document = parseDocument(
          '［＃ここから1段階大きな文字］\nテスト\n［＃ここで1段階大きな文字終わり］',
        );

        expect(document.children, hasLength(1));
        final container = expectBlockContainer(
          document.children.single,
          kind: 'fontSize',
          variant: 'larger',
        );
        expect(container.attributes['steps'], '1');
        expect(container.children, hasLength(1));
      },
    );

    test('ported from test_font_size_tag.rb: test_to_s2', () {
      final document = parseDocument('［＃ここから2段階大きな文字］\nテスト\n［＃ここで2段階大きな文字終わり］');

      final container = expectBlockContainer(
        document.children.single,
        kind: 'fontSize',
        variant: 'larger',
      );
      expect(container.attributes['steps'], '2');
    });

    test('ported from test_font_size_tag.rb: test_to_s3', () {
      final document = parseDocument('［＃ここから3段階小さな文字］\nテスト\n［＃ここで3段階小さな文字終わり］');

      final container = expectBlockContainer(
        document.children.single,
        kind: 'fontSize',
        variant: 'smaller',
      );
      expect(container.attributes['steps'], '3');
    });

    test(
      'ported from test_multiline_style_tag.rb: test_multiline_style_new / test_to_s',
      () {
        final document = parseDocument('［＃ここから太字］\nテスト\n［＃ここで太字終わり］');

        expect(document.children, hasLength(1));
        final container = expectBlockContainer(
          document.children.single,
          kind: 'style',
          variant: 'bold',
        );
        expect(container.isClosed, isTrue);
      },
    );

    test(
      'ported from test_multiline_yokogumi_tag.rb: test_multiline_yokogumi_new / test_to_s',
      () {
        final document = parseDocument('［＃ここから横組み］\nテスト\n［＃ここで横組み終わり］');

        final container = expectBlockContainer(
          document.children.single,
          kind: 'flow',
          variant: 'yokogumi',
        );
        expect(container.isClosed, isTrue);
      },
    );

    test(
      'ported from test_multiline_caption_tag.rb: test_multiline_caption_new / test_to_s',
      () {
        final document = parseDocument('［＃ここからキャプション］\nテスト\n［＃ここでキャプション終わり］');

        final container = expectBlockContainer(
          document.children.single,
          kind: 'caption',
          variant: 'caption',
        );
        expect(container.isClosed, isTrue);
      },
    );

    test(
      'ported from test_multiline_midashi_tag.rb: test_multiline_midashi_new / test_to_s',
      () {
        final document = parseDocument('［＃ここから小見出し］\nテスト見出し\n［＃ここで小見出し終わり］');

        final container = expectBlockContainer(
          document.children.single,
          kind: 'heading',
          variant: 'small',
        );
        expect(container.attributes['display'], 'normal');
      },
    );

    test('ported from test_multiline_midashi_tag.rb: test_to_s_chu', () {
      final document = parseDocument('［＃ここから同行中見出し］\nテスト見出し\n［＃ここで同行中見出し終わり］');

      final container = expectBlockContainer(
        document.children.single,
        kind: 'heading',
        variant: 'medium',
      );
      expect(container.attributes['display'], 'dogyo');
    });

    test('ported from test_multiline_midashi_tag.rb: test_to_s_dai', () {
      final document = parseDocument('［＃ここから窓大見出し］\nテスト見出し\n［＃ここで窓大見出し終わり］');

      final container = expectBlockContainer(
        document.children.single,
        kind: 'heading',
        variant: 'large',
      );
      expect(container.attributes['display'], 'mado');
    });

    test('ported from test_midashi_tag.rb: test_midashi_new / test_to_s', () {
      final paragraph = onlyParagraph(parseDocument('テスト見出し［＃「テスト見出し」は小見出し］'));

      final container = expectInlineContainer(
        paragraph.children.single,
        kind: 'heading',
        variant: 'small',
      );
      expect(container.attributes['display'], 'normal');
      expectTextNode(container.children.single, 'テスト見出し');
    });

    test('ported from test_midashi_tag.rb: test_to_s_mado', () {
      final paragraph = onlyParagraph(parseDocument('テスト見出し［＃「テスト見出し」は窓小見出し］'));

      final container = expectInlineContainer(
        paragraph.children.single,
        kind: 'heading',
        variant: 'small',
      );
      expect(container.attributes['display'], 'mado');
    });

    test('ported from test_jizume_tag.rb: test_jizume_new / test_to_s', () {
      final document = parseDocument('［＃ここから50字詰め］\nテスト\n［＃ここで字詰め終わり］');

      final container = expectBlockContainer(
        document.children.single,
        kind: 'measure',
        variant: 'jizume',
      );
      expect(container.attributes['width'], '50');
    });

    test(
      'ported from test_keigakomi_tag.rb: test_keigakomi_new / test_to_s',
      () {
        final document = parseDocument('［＃ここから罫囲み］\nテスト\n［＃ここで罫囲み終わり］');

        final container = expectBlockContainer(
          document.children.single,
          kind: 'frame',
          variant: 'keigakomi',
        );
        expect(container.attributes['borderWidth'] ?? '1', '1');
      },
    );

    test('ported from test_keigakomi_tag.rb: test_to_s2', () {
      final document = parseDocument('［＃ここから2重罫囲み］\nテスト\n［＃ここで2重罫囲み終わり］');

      final container = expectBlockContainer(
        document.children.single,
        kind: 'frame',
        variant: 'keigakomi',
      );
      expect(container.attributes['borderWidth'], '2');
    });

    test(
      'ported from test_dakuten_katakana_tag.rb: test_dakuten_katakana_new / test_to_s',
      () {
        final paragraph = onlyParagraph(parseDocument('ア※［＃濁点付き片仮名ア、1-7-81］'));

        expect(paragraph.children, hasLength(2));
        expectTextNode(paragraph.children.first, 'ア');
        expectGaijiNode(
          paragraph.children.last,
          description: '濁点付き片仮名ア、1-7-81',
          jisCode: '1-7-81',
        );
      },
    );
  });
}
