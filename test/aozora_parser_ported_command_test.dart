import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

import 'support/aozora_test_utils.dart';

void main() {
  group('AozoraAstParser ported command cases', () {
    test('ported from test_command_parse.rb: test_parse_command1', () {
      final paragraph = onlyParagraph(
        parseDocument('デボルド―※［＃濁点付き片仮名ワ、1-7-82］ルモオル'),
      );

      expect(paragraph.children, hasLength(3));
      expectTextNode(paragraph.children[0], 'デボルド―');
      expectGaijiNode(
        paragraph.children[1],
        description: '濁点付き片仮名ワ、1-7-82',
        jisCode: '1-7-82',
      );
      expectTextNode(paragraph.children[2], 'ルモオル');
    });

    test('ported from test_aozora_accent_parser.rb: test_new', () {
      final paragraph = onlyParagraph(parseDocument('〔e\'tiquette〕'));

      expect(paragraph.children, hasLength(2));
      expectGaijiNode(
        paragraph.children.first,
        description: 'アキュートアクセント付きE小文字',
      );
      expectTextNode(paragraph.children.last, 'tiquette');
    });

    test('ported from test_command_parse.rb: test_parse_command3', () {
      final paragraph = onlyParagraph(
        parseDocument('〔Sito^t qu\'on le touche il re\'sonne.〕'),
      );

      expect(paragraph.children, hasLength(7));
      expectTextNode(paragraph.children[0], 'Sit');
      expectGaijiNode(
        paragraph.children[1],
        description: 'サーカムフレックスアクセント付きO小文字',
      );
      expectTextNode(paragraph.children[2], 't q');
      expectGaijiNode(paragraph.children[3], description: 'アキュートアクセント付きU小文字');
      expectTextNode(paragraph.children[4], 'on le touche il r');
      expectGaijiNode(paragraph.children[5], description: 'アキュートアクセント付きE小文字');
      expectTextNode(paragraph.children[6], 'sonne.');
    });

    test('ported from test_command_parse.rb: test_parse_command4', () {
      final paragraph = onlyParagraph(parseDocument('presqu\'〔i^le〕'));

      expect(paragraph.children, hasLength(3));
      expectTextNode(paragraph.children[0], 'presqu\'');
      expectGaijiNode(
        paragraph.children[1],
        description: 'サーカムフレックスアクセント付きI小文字',
      );
      expectTextNode(paragraph.children[2], 'le');
    });

    test('ported from test_command_parse.rb: test_parse_command5', () {
      final paragraph = onlyParagraph(parseDocument('［二十歳の 〔E\'tude〕］'));

      expect(paragraph.children, hasLength(4));
      expectTextNode(paragraph.children[0], '［二十歳の ');
      expectGaijiNode(paragraph.children[1], description: 'アキュートアクセント付きE');
      expectTextNode(paragraph.children[2], 'tude');
      expectTextNode(paragraph.children[3], '］');
    });

    test('ported from test_command_parse.rb: test_parse_command6', () {
      final paragraph = onlyParagraph(parseDocument('責［＃「責」に白ゴマ傍点］空文庫'));

      expect(paragraph.children, hasLength(2));
      final emphasis = expectInlineContainer(
        paragraph.children.first,
        kind: 'emphasis',
        variant: 'whiteSesameDot',
      );
      expectTextNode(paragraph.children.last, '空文庫');
      expectTextNode(emphasis.children.single, '責');
    });

    test('ported from test_command_parse.rb: test_parse_command7', () {
      final paragraph = onlyParagraph(
        parseDocument('［＃丸傍点］青空文庫で読書しよう［＃丸傍点終わり］。'),
      );

      expect(paragraph.children, hasLength(2));
      final emphasis = expectInlineContainer(
        paragraph.children.first,
        kind: 'emphasis',
        variant: 'blackCircle',
      );
      expectTextNode(emphasis.children.single, '青空文庫で読書しよう');
      expectTextNode(paragraph.children.last, '。');
    });

    test('ported from test_command_parse.rb: test_parse_command8', () {
      final paragraph = onlyParagraph(
        parseDocument('この形は傍線［＃「傍線」に傍線］と書いてください。'),
      );

      expect(paragraph.children, hasLength(3));
      final decoration = expectInlineContainer(
        paragraph.children[1],
        kind: 'decoration',
        variant: 'underlineSolid',
      );
      expectTextNode(decoration.children.single, '傍線');
    });

    test('ported from test_command_parse.rb: test_parse_command9', () {
      final paragraph = onlyParagraph(
        parseDocument('［＃左に鎖線］青空文庫で読書しよう［＃左に鎖線終わり］。'),
      );

      final decoration = expectInlineContainer(
        paragraph.children.first,
        kind: 'decoration',
        variant: 'underlineDotted',
      );
      expect(decoration.attributes['direction'], '左');
    });

    test('ported from test_command_parse.rb: test_parse_command10', () {
      final paragraph = onlyParagraph(
        parseDocument(
          '「クリス、宇宙航行委員会が選考［＃「選考」は太字］するんだ。きみは志願できない。待つ［＃「待つ」は太字］んだ」',
        ),
      );

      expect(paragraph.children, hasLength(5));
      expectTextNode(paragraph.children[0], '「クリス、宇宙航行委員会が');
      expectInlineContainer(
        paragraph.children[1],
        kind: 'style',
        variant: 'bold',
      );
      expectTextNode(paragraph.children[2], 'するんだ。きみは志願できない。');
      expectInlineContainer(
        paragraph.children[3],
        kind: 'style',
        variant: 'bold',
      );
      expectTextNode(paragraph.children[4], 'んだ」');
    });

    test('ported from test_command_parse.rb: test_parse_command11', () {
      final paragraph = onlyParagraph(
        parseDocument(
          'Which, teaching us, hath this exordium: Nothing from nothing ever yet was born.［＃「Nothing from nothing ever yet was born.」は斜体］',
        ),
      );

      expect(paragraph.children, hasLength(2));
      expectTextNode(
        paragraph.children.first,
        'Which, teaching us, hath this exordium: ',
      );
      final italic = expectInlineContainer(
        paragraph.children.last,
        kind: 'style',
        variant: 'italic',
      );
      expectTextNode(
        italic.children.single,
        'Nothing from nothing ever yet was born.',
      );
    });

    test('ported from test_command_parse.rb: test_parse_command_warichu', () {
      final paragraph = onlyParagraph(
        parseDocument('［＃割り注］価は四百円であった。［＃割り注終わり］'),
      );

      expect(paragraph.children, hasLength(1));
      final note = expectInlineContainer(
        paragraph.children.single,
        kind: 'note',
        variant: 'warichu',
      );
      expectTextNode(note.children.single, '価は四百円であった。');
    });

    test('ported from test_command_parse.rb: test_parse_command_warichu2', () {
      final paragraph = onlyParagraph(
        parseDocument('飽海郡南平田村大字飛鳥［＃割り注］東は字大林四三七［＃改行］西は字神内一一一ノ一［＃割り注終わり］'),
      );

      expect(paragraph.children, hasLength(2));
      expectTextNode(paragraph.children.first, '飽海郡南平田村大字飛鳥');
      final note = expectInlineContainer(
        paragraph.children.last,
        kind: 'note',
        variant: 'warichu',
      );
      expect(note.children, hasLength(3));
      expectTextNode(note.children.first, '東は字大林四三七');
      expect(note.children[1], isA<LineBreakNode>());
      expectTextNode(note.children.last, '西は字神内一一一ノ一');
    });

    for (final variant in <String>[
      'test_parse_command_unicode_class',
      'test_parse_command_unicode',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('※［＃「衄のへん＋卩」、U+5379、287-2］'),
        );

        expect(paragraph.children, hasLength(1));
        expectGaijiNode(
          paragraph.children.single,
          description: '「衄のへん＋卩」、U+5379、287-2',
          unicodeCodePoint: '5379',
        );
      });
    }

    for (final variant in <String>[
      'test_parse_command_teisei1_class',
      'test_parse_command_teisei1',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(parseDocument('吹喋［＃「喋」に「ママ」の注記］'));

        expect(paragraph.children, hasLength(2));
        expectTextNode(paragraph.children.first, '吹');
        final ruby = expectRubyNode(
          paragraph.children.last,
          kind: RubyKind.annotation,
          position: RubyPosition.over,
          text: 'ママ',
        );
        expectTextNode(ruby.base.single, '喋');
      });
    }

    for (final variant in <String>[
      'test_parse_command_teisei2_class',
      'test_parse_command_teisei2',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('紋附だとか［＃「紋附だとか」は底本では「絞附だとか」］'),
        );

        expect(paragraph.children, hasLength(2));
        expectTextNode(paragraph.children.first, '紋附だとか');
        expectInlineAnnotation(
          paragraph.children.last,
          kind: 'editorNote',
          text: '「紋附だとか」は底本では「絞附だとか」',
        );
      });
    }

    for (final variant in <String>[
      'test_parse_command_teisei3_class',
      'test_parse_command_teisei3',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('私は籠《ざる》［＃ルビの「ざる」は底本では「さる」］をさげ'),
        );

        expect(paragraph.children, hasLength(4));
        expectTextNode(paragraph.children.first, '私は');
        expectRubyNode(
          paragraph.children[1],
          kind: RubyKind.phonetic,
          position: RubyPosition.over,
          text: 'ざる',
        );
        expectInlineAnnotation(
          paragraph.children[2],
          kind: 'editorNote',
          text: 'ルビの「ざる」は底本では「さる」',
        );
        expectTextNode(paragraph.children[3], 'をさげ');
      });
    }

    for (final variant in <String>[
      'test_parse_command_teisei4_class',
      'test_parse_command_teisei4',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('広場へに［＃「広場へに」はママ］店でもだそう。'),
        );

        expect(paragraph.children, hasLength(3));
        expectTextNode(paragraph.children.first, '広場へに');
        expectInlineAnnotation(
          paragraph.children[1],
          kind: 'editorNote',
          text: '「広場へに」はママ',
        );
        expectTextNode(paragraph.children.last, '店でもだそう。');
      });
    }

    for (final variant in <String>[
      'test_parse_command_teisei5_class',
      'test_parse_command_teisei5',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(parseDocument('お湯《ゆう》［＃ルビの「ゆう」はママ］'));

        expect(paragraph.children, hasLength(3));
        expectTextNode(paragraph.children.first, 'お');
        expectRubyNode(
          paragraph.children[1],
          kind: RubyKind.phonetic,
          position: RubyPosition.over,
          text: 'ゆう',
        );
        expectInlineAnnotation(
          paragraph.children.last,
          kind: 'editorNote',
          text: 'ルビの「ゆう」はママ',
        );
      });
    }

    for (final variant in <String>[
      'test_parse_command_tcy_class',
      'test_parse_command_tcy',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(parseDocument('米機Ｂ29［＃「29」は縦中横］の編隊は、'));

        expect(paragraph.children, hasLength(3));
        expectTextNode(paragraph.children.first, '米機Ｂ');
        expectInlineContainer(
          paragraph.children[1],
          kind: 'direction',
          variant: 'tateChuYoko',
        );
        expectTextNode(paragraph.children.last, 'の編隊は、');
      });
    }

    for (final variant in <String>[
      'test_parse_command_tcy2_class',
      'test_parse_command_tcy2',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('［＃縦中横］（※［＃ローマ数字1、1-13-21］）［＃縦中横終わり］'),
        );

        expect(paragraph.children, hasLength(1));
        final container = expectInlineContainer(
          paragraph.children.single,
          kind: 'direction',
          variant: 'tateChuYoko',
        );
        expect(container.children, hasLength(3));
        expectTextNode(container.children[0], '（');
        expectGaijiNode(
          container.children[1],
          description: 'ローマ数字1、1-13-21',
          jisCode: '1-13-21',
        );
        expectTextNode(container.children[2], '）');
      });
    }

    for (final variant in <String>[
      'test_parse_command_kogaki_class',
      'test_parse_command_kogaki',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('それ以上である。（５）［＃「（５）」は行右小書き］'),
        );

        expect(paragraph.children, hasLength(2));
        expectTextNode(paragraph.children.first, 'それ以上である。');
        expectInlineAnnotation(
          paragraph.children.last,
          kind: 'superscript',
          text: '（５）',
        );
      });
    }

    for (final variant in <String>[
      'test_parse_command_uetsuki_class',
      'test_parse_command_uetsuki',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(parseDocument('22［＃「2」は上付き小文字］'));

        expect(paragraph.children, hasLength(2));
        expectTextNode(paragraph.children.first, '2');
        expectInlineAnnotation(
          paragraph.children.last,
          kind: 'superscript',
          text: '2',
        );
      });
    }

    for (final variant in <String>[
      'test_parse_command_bouki_class',
      'test_parse_command_bouki',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument('支部長の顔にさっと血が流れ［＃「血が流れ」に「×」の傍記］た'),
        );

        expect(paragraph.children, hasLength(3));
        expectTextNode(paragraph.children.first, '支部長の顔にさっと');
        final ruby = expectRubyNode(
          paragraph.children[1],
          kind: RubyKind.annotation,
          position: RubyPosition.over,
          text: '× × × ×',
        );
        expectTextNode(ruby.base.single, '血が流れ');
        expectTextNode(paragraph.children.last, 'た');
      });
    }

    test(
      'ported from test_command_parse.rb: test_parse_command_chuuki_with_tortoise_brackets',
      () {
        final paragraph = onlyParagraph(
          parseDocument('二万五千六百尺［＃「尺」に「〔呎〕」の注記］の雪峰'),
        );

        expect(paragraph.children, hasLength(3));
        expectTextNode(paragraph.children.first, '二万五千六百');
        final ruby = expectRubyNode(
          paragraph.children[1],
          kind: RubyKind.annotation,
          position: RubyPosition.over,
          text: '〔呎〕',
        );
        expectTextNode(ruby.base.single, '尺');
        expectTextNode(paragraph.children.last, 'の雪峰');
      },
    );

    test(
      'ported from test_command_parse.rb: test_parse_command_bouten_on_unembed_gaiji',
      () {
        final paragraph = onlyParagraph(
          parseDocument('※［＃「てへん＋夸」、37-下-12］［＃「※［＃「てへん＋夸」、37-下-12］」に傍点］門は崩れ'),
        );

        expect(paragraph.children, hasLength(2));
        final emphasis = expectInlineContainer(
          paragraph.children.first,
          kind: 'emphasis',
          variant: 'sesameDot',
        );
        expectInlineAnnotation(
          emphasis.children.single,
          kind: 'unresolvedGaiji',
          text: '「てへん＋夸」、37-下-12',
        );
        expectTextNode(paragraph.children.last, '門は崩れ');
      },
    );

    for (final variant in <String>[
      'test_parse_command_ruby_class',
      'test_parse_command_ruby',
    ]) {
      test('ported from test_command_parse.rb: $variant', () {
        final paragraph = onlyParagraph(
          parseDocument(
            'グリーンランドの中央部八千尺の氷河地帯にあるといわれる、［＃横組み］“Ser-mik-Suah《セルミク・シュアー》”［＃横組み終わり］の冥路《よみじ》の国。',
          ),
        );

        expect(paragraph.children, hasLength(5));
        expectTextNode(
          paragraph.children.first,
          'グリーンランドの中央部八千尺の氷河地帯にあるといわれる、',
        );
        final yokogumi = expectInlineContainer(
          paragraph.children[1],
          kind: 'flow',
          variant: 'yokogumi',
        );
        expect(yokogumi.children, hasLength(3));
        expectTextNode(yokogumi.children[0], '“');
        expectRubyNode(
          yokogumi.children[1],
          kind: RubyKind.phonetic,
          position: RubyPosition.over,
          text: 'セルミク・シュアー',
        );
        expectTextNode(yokogumi.children[2], '”');
        expectTextNode(paragraph.children[2], 'の');
        expectRubyNode(
          paragraph.children[3],
          kind: RubyKind.phonetic,
          position: RubyPosition.over,
          text: 'よみじ',
        );
        expectTextNode(paragraph.children[4], 'の国。');
      });
    }

    test('ported from test_tag_parser.rb: test_parse_gaiji_a', () {
      final paragraph = onlyParagraph(parseDocument('※［＃「口＋世」、ページ数-行数］…'));

      expect(paragraph.children, hasLength(2));
      expectInlineAnnotation(
        paragraph.children.first,
        kind: 'unresolvedGaiji',
        text: '「口＋世」、ページ数-行数',
      );
      expectTextNode(paragraph.children.last, '…');
    });

    test('ported from test_tag_parser.rb: test_parse_gaiji_kaeri', () {
      final paragraph = onlyParagraph(parseDocument('自［＃二］女王國［＃一］東度［＃レ］海千餘里。'));

      expect(paragraph.children, hasLength(7));
      expectInlineAnnotation(
        paragraph.children[1],
        kind: 'kaeriten',
        text: '二',
      );
      expectInlineAnnotation(
        paragraph.children[3],
        kind: 'kaeriten',
        text: '一',
      );
      expectInlineAnnotation(
        paragraph.children[5],
        kind: 'kaeriten',
        text: 'レ',
      );
    });
  });
}
