import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('AozoraAstParser', () {
    test('parses ruby shorthand into attached text boundaries', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse('青空文庫《あおぞらぶんこ》');

      expect(tokens, hasLength(3));
      expect(tokens[0], isA<AozoraAttachedText>());
      expect(
        (tokens[0] as AozoraAttachedText).boundary,
        AozoraRangeBoundary.start,
      );
      expect(tokens[1], isA<AozoraText>());
      expect((tokens[1] as AozoraText).text, '青空文庫');
      expect(tokens[2], isA<AozoraAttachedText>());
      final end = tokens[2] as AozoraAttachedText;
      expect(end.boundary, AozoraRangeBoundary.end);
      expect(end.role, AozoraAttachedTextRole.ruby);
      expect(end.side, AozoraTextSide.right);
      expect(end.content, hasLength(1));
      expect((end.content!.single as AozoraText).text, 'あおぞらぶんこ');
    });

    test('splits trailing ruby target like legacy engine', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse('これは漢字《かんじ》');

      expect(tokens, hasLength(4));
      expect(tokens[0], isA<AozoraText>());
      expect((tokens[0] as AozoraText).text, 'これは');
      expect(tokens[1], isA<AozoraAttachedText>());
      expect(tokens[2], isA<AozoraText>());
      expect((tokens[2] as AozoraText).text, '漢字');
      expect(tokens[3], isA<AozoraAttachedText>());
    });

    test('supports explicit ruby marker without leaving splitter text', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse('この度｜拠《よんどころ》なく');

      expect(tokens, hasLength(5));
      expect(tokens[0], isA<AozoraText>());
      expect((tokens[0] as AozoraText).text, 'この度');
      expect(tokens[1], isA<AozoraAttachedText>());
      expect(tokens[2], isA<AozoraText>());
      expect((tokens[2] as AozoraText).text, '拠');
      expect(tokens[3], isA<AozoraAttachedText>());
      expect(tokens[4], isA<AozoraText>());
      expect((tokens[4] as AozoraText).text, 'なく');
    });

    test('parses supported block and line annotations', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse(
        '［＃ここから２字下げ、折り返して３字下げ］\n'
        '本文\n'
        '［＃ここで字下げ終わり］\n'
        '［＃地から２字上げ］署名\n'
        '［＃改ページ］',
      );

      expect(tokens[0], isA<AozoraIndent>());
      final indent = tokens[0] as AozoraIndent;
      expect(indent.kind, AozoraIndentKind.block);
      expect(indent.boundary, AozoraRangeBoundary.blockStart);
      expect(indent.lineIndent, 2);
      expect(indent.hangingIndent, 3);

      expect(tokens[4], isA<AozoraIndent>());
      expect(
        (tokens[4] as AozoraIndent).boundary,
        AozoraRangeBoundary.blockEnd,
      );

      expect(tokens[6], isA<AozoraBottomAlign>());
      final bottom = tokens[6] as AozoraBottomAlign;
      expect(bottom.kind, AozoraBottomAlignKind.raisedFromBottom);
      expect(bottom.scope, AozoraBottomAlignScope.singleLine);
      expect(bottom.offset, 2);

      expect(tokens.last, isA<AozoraPageBreak>());
      expect(
        (tokens.last as AozoraPageBreak).kind,
        AozoraPageBreakKind.kaipage,
      );
    });

    test('parses gaiji and unsupported annotations', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse(
        '※［＃「てへん＋劣」、第3水準1-84-77］'
        '［＃未対応の独自注記］',
      );

      expect(tokens[0], isA<AozoraGaiji>());
      final gaiji = tokens[0] as AozoraGaiji;
      expect(gaiji.kind, AozoraGaijiKind.jisX0213);
      expect(gaiji.jisLevel, 3);
      expect(gaiji.jisCode?.plane, 1);
      expect(gaiji.jisCode?.row, 84);
      expect(gaiji.jisCode?.cell, 77);

      expect(tokens[1], isA<AozoraUnsupportedAnnotation>());
      expect((tokens[1] as AozoraUnsupportedAnnotation).raw, '［＃未対応の独自注記］');
    });

    test('parses document remarks and wraps single-target emphasis', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse(
        '責［＃「責」に白丸傍点］\n'
        '※窓見出しは、３行どりです。',
      );

      expect(tokens[0], isA<AozoraStyledText>());
      final start = tokens[0] as AozoraStyledText;
      expect(start.boundary, AozoraRangeBoundary.start);
      expect(start.style, isA<AozoraBoutenStyle>());
      expect(
        (start.style as AozoraBoutenStyle).kind,
        AozoraBoutenKind.whiteCircle,
      );

      expect(tokens[1], isA<AozoraText>());
      expect((tokens[1] as AozoraText).text, '責');

      expect(tokens[2], isA<AozoraStyledText>());
      expect((tokens[2] as AozoraStyledText).boundary, AozoraRangeBoundary.end);

      expect(tokens.last, isA<AozoraDocumentRemark>());
      final remark = tokens.last as AozoraDocumentRemark;
      expect(remark.kind, AozoraDocumentRemarkKind.madoHeadingLineCount);
      expect(remark.value, 3);
    });

    test('parses cancel line as supported styled text', () {
      const parser = AozoraAstParser();

      final tokens = parser.parse('責［＃「責」に取消線］');

      expect(tokens[0], isA<AozoraStyledText>());
      final start = tokens[0] as AozoraStyledText;
      expect(start.style, isA<AozoraBosenStyle>());
      expect((start.style as AozoraBosenStyle).kind, AozoraBosenKind.cancel);
    });
  });
}
