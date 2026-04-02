import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('AozoraParser', () {
    test('parses ruby shorthand into attached text boundaries', () {
      const parser = AozoraParser();

      final tokens = parser.parse('青空文庫《あおぞらぶんこ》');

      expect(tokens, hasLength(3));
      expect(tokens[0], isA<AstAttachedText>());
      expect((tokens[0] as AstAttachedText).boundary, AstRangeBoundary.start);
      expect(tokens[1], isA<AstText>());
      expect((tokens[1] as AstText).text, '青空文庫');
      expect(tokens[2], isA<AstAttachedText>());
      final end = tokens[2] as AstAttachedText;
      expect(end.boundary, AstRangeBoundary.end);
      expect(end.role, AstAttachedTextRole.ruby);
      expect(end.side, AstTextSide.right);
      expect(end.content, hasLength(1));
      expect((end.content!.single as AstText).text, 'あおぞらぶんこ');
    });

    test('splits trailing ruby target like legacy engine', () {
      const parser = AozoraParser();

      final tokens = parser.parse('これは漢字《かんじ》');

      expect(tokens, hasLength(4));
      expect(tokens[0], isA<AstText>());
      expect((tokens[0] as AstText).text, 'これは');
      expect(tokens[1], isA<AstAttachedText>());
      expect(tokens[2], isA<AstText>());
      expect((tokens[2] as AstText).text, '漢字');
      expect(tokens[3], isA<AstAttachedText>());
    });

    test('supports explicit ruby marker without leaving splitter text', () {
      const parser = AozoraParser();

      final tokens = parser.parse('この度｜拠《よんどころ》なく');

      expect(tokens, hasLength(5));
      expect(tokens[0], isA<AstText>());
      expect((tokens[0] as AstText).text, 'この度');
      expect(tokens[1], isA<AstAttachedText>());
      expect(tokens[2], isA<AstText>());
      expect((tokens[2] as AstText).text, '拠');
      expect(tokens[3], isA<AstAttachedText>());
      expect(tokens[4], isA<AstText>());
      expect((tokens[4] as AstText).text, 'なく');
    });

    test('keeps full explicit ruby range until opening bracket', () {
      const parser = AozoraParser();

      final tokens = parser.parse('｜複雑な文《complex sentence》');

      expect(tokens, hasLength(3));
      expect(tokens[0], isA<AstAttachedText>());
      expect(tokens[1], isA<AstText>());
      expect((tokens[1] as AstText).text, '複雑な文');
      expect(tokens[2], isA<AstAttachedText>());
      final end = tokens[2] as AstAttachedText;
      expect((end.content!.single as AstText).text, 'complex sentence');
    });

    test('parses supported block and line annotations', () {
      const parser = AozoraParser();

      final tokens = parser.parse(
        '［＃ここから２字下げ、折り返して３字下げ］\n'
        '本文\n'
        '［＃ここで字下げ終わり］\n'
        '［＃地から２字上げ］署名\n'
        '［＃改ページ］',
      );

      expect(tokens[0], isA<AstIndent>());
      final indent = tokens[0] as AstIndent;
      expect(indent.kind, AstIndentKind.block);
      expect(indent.boundary, AstRangeBoundary.blockStart);
      expect(indent.lineIndent, 2);
      expect(indent.hangingIndent, 3);

      expect(tokens[4], isA<AstIndent>());
      expect((tokens[4] as AstIndent).boundary, AstRangeBoundary.blockEnd);

      expect(tokens[6], isA<AstBottomAlign>());
      final bottom = tokens[6] as AstBottomAlign;
      expect(bottom.kind, AstBottomAlignKind.raisedFromBottom);
      expect(bottom.scope, AstBottomAlignScope.singleLine);
      expect(bottom.offset, 2);

      expect(tokens.last, isA<AstPageBreak>());
      expect((tokens.last as AstPageBreak).kind, AstPageBreakKind.kaipage);
    });

    test('parses gaiji and unsupported annotations', () {
      const parser = AozoraParser();

      final tokens = parser.parse(
        '※［＃「てへん＋劣」、第3水準1-84-77］'
        '［＃未対応の独自注記］',
      );

      expect(tokens[0], isA<AstGaiji>());
      final gaiji = tokens[0] as AstGaiji;
      expect(gaiji.kind, AstGaijiKind.jisX0213);
      expect(gaiji.jisLevel, 3);
      expect(gaiji.jisCode?.plane, 1);
      expect(gaiji.jisCode?.row, 84);
      expect(gaiji.jisCode?.cell, 77);

      expect(tokens[1], isA<AstUnsupportedAnnotation>());
      expect((tokens[1] as AstUnsupportedAnnotation).raw, '［＃未対応の独自注記］');
    });

    test('parses document remarks and wraps single-target emphasis', () {
      const parser = AozoraParser();

      final tokens = parser.parse(
        '責［＃「責」に白丸傍点］\n'
        '※窓見出しは、３行どりです。',
      );

      expect(tokens[0], isA<AstStyledText>());
      final start = tokens[0] as AstStyledText;
      expect(start.boundary, AstRangeBoundary.start);
      expect(start.style, isA<AstBoutenStyle>());
      expect((start.style as AstBoutenStyle).kind, AstBoutenKind.whiteCircle);

      expect(tokens[1], isA<AstText>());
      expect((tokens[1] as AstText).text, '責');

      expect(tokens[2], isA<AstStyledText>());
      expect((tokens[2] as AstStyledText).boundary, AstRangeBoundary.end);

      expect(tokens.last, isA<AstDocumentRemark>());
      final remark = tokens.last as AstDocumentRemark;
      expect(remark.kind, AstDocumentRemarkKind.madoHeadingLineCount);
      expect(remark.value, 3);
    });

    test('parses cancel line as supported styled text', () {
      const parser = AozoraParser();

      final tokens = parser.parse('責［＃「責」に取消線］');

      expect(tokens[0], isA<AstStyledText>());
      final start = tokens[0] as AstStyledText;
      expect(start.style, isA<AstBosenStyle>());
      expect((start.style as AstBosenStyle).kind, AstBosenKind.cancel);
    });
  });
}
