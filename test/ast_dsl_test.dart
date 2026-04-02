import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/painting.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('AST DSL', () {
    test('builds attached text and styled spans from Dart wrappers', () {
      final tokens = ast([
        Ruby.text('青空文庫', 'あおぞらぶんこ'),
        const LineBreak(),
        const Bold(children: ['強調']),
      ]);

      expect(tokens[0], isA<AstAttachedText>());
      expect((tokens[0] as AstAttachedText).boundary, AstRangeBoundary.start);
      expect(tokens[1], isA<AstText>());
      expect((tokens[1] as AstText).text, '青空文庫');

      final rubyEnd = tokens[2] as AstAttachedText;
      expect(rubyEnd.boundary, AstRangeBoundary.end);
      expect(rubyEnd.role, AstAttachedTextRole.ruby);
      expect((rubyEnd.content!.single as AstText).text, 'あおぞらぶんこ');

      expect(tokens[3], isA<AstNewLine>());

      final boldStart = tokens[4] as AstStyledText;
      expect(boldStart.boundary, AstRangeBoundary.start);
      expect(
        (boldStart.style as AstFontStyleAnnotation).style,
        AstFontStyle.bold,
      );
      expect((tokens[5] as AstText).text, '強調');
      expect((tokens[6] as AstStyledText).boundary, AstRangeBoundary.end);
    });

    test('builds text wrappers with common inline properties', () {
      final compiled = compileAst(
        ast([
          const Text(
            value: '春',
            color: Color(0xffe53935),
            bold: true,
            italic: true,
            size: 2,
            ruby: <Object>['はる'],
            border: AstBosenKind.wave,
            bouten: AstBoutenKind.sesame,
          ),
          const Text(value: '2026', tatechuyoko: true),
        ]),
      );

      final paragraph = compiled.entries.single as AstCompiledParagraphEntry;
      expect(paragraph.text, '春2026');

      final colorSpan = paragraph.styles.singleWhere(
        (span) => span.kind == AstStyleKind.textColor,
      );
      expect(colorSpan.startIndex, 0);
      expect(colorSpan.endIndex, 1);
      expect(colorSpan.colorValue, const Color(0xffe53935).toARGB32());

      final boldSpan = paragraph.styles.singleWhere(
        (span) => span.kind == AstStyleKind.bold,
      );
      expect(boldSpan.startIndex, 0);
      expect(boldSpan.endIndex, 1);

      final italicSpan = paragraph.styles.singleWhere(
        (span) => span.kind == AstStyleKind.italic,
      );
      expect(italicSpan.startIndex, 0);
      expect(italicSpan.endIndex, 1);

      final fontScaleSpan = paragraph.styles.singleWhere(
        (span) => span.kind == AstStyleKind.fontScale,
      );
      expect(fontScaleSpan.startIndex, 0);
      expect(fontScaleSpan.endIndex, 1);
      expect(fontScaleSpan.fontScaleDirection, AstFontScaleDirection.larger);
      expect(fontScaleSpan.fontScaleSteps, 2);

      final waveLine = paragraph.extras.singleWhere(
        (extra) =>
            extra.kind == AstParagraphExtraKind.span &&
            extra.ruledLineKind == AstRuledLineKind.wave,
      );
      expect(waveLine.startIndex, 0);
      expect(waveLine.endIndex, 1);

      final sesame = paragraph.extras.singleWhere(
        (extra) =>
            extra.kind == AstParagraphExtraKind.emphasis &&
            extra.emphasisKind == AstEmphasisKind.sesame,
      );
      expect(sesame.startIndex, 0);
      expect(sesame.endIndex, 1);

      expect(paragraph.rubies, hasLength(1));
      expect(paragraph.rubies.single.startIndex, 0);
      expect(paragraph.rubies.single.endIndex, 1);
      expect(paragraph.rubies.single.ruby, 'はる');

      expect(paragraph.tcyRanges, hasLength(1));
      expect(paragraph.tcyRanges.single.startIndex, 1);
      expect(paragraph.tcyRanges.single.endIndex, 5);
    });

    test('builds heading and page break with wrapper nodes', () {
      final tokens = ast([
        const Heading(level: AstHeadingLevel.large, children: ['第一章']),
        const LineBreak(),
        const PageBreak(AstPageBreakKind.kaipage),
      ]);

      final start = tokens[0] as AstHeading;
      expect(start.boundary, AstRangeBoundary.start);
      expect(start.level, AstHeadingLevel.large);
      expect((tokens[1] as AstText).text, '第一章');
      expect((tokens[2] as AstHeading).boundary, AstRangeBoundary.end);
      expect(tokens[3], isA<AstNewLine>());
      expect((tokens[4] as AstPageBreak).kind, AstPageBreakKind.kaipage);
    });

    test('maps line breaks correctly inside and outside warichu', () {
      final tokens = ast([
        const Text(value: '一行目\n二行目'),
        const Br(),
        Warichu(text: '上段\n下段'),
      ]);

      expect((tokens[0] as AstText).text, '一行目');
      expect(tokens[1], isA<AstNewLine>());
      expect((tokens[2] as AstText).text, '二行目');
      expect(tokens[3], isA<AstNewLine>());
      expect(tokens[4], isA<AstInlineDecoration>());
      expect((tokens[5] as AstText).text, '上段');
      expect(tokens[6], isA<AstWarichuNewLine>());
      expect((tokens[7] as AstText).text, '下段');
      expect(tokens[8], isA<AstInlineDecoration>());
    });

    test('compiles warichu built from DSL', () {
      final dslCompiled = compileAst(
        ast([
          const Text(value: '本文'),
          Warichu(children: ['東は字大林四三七', const WarichuBreak(), '西は字神内一一一ノ一']),
        ]),
      );
      final parsedCompiled = compileAst(
        const AozoraParser().parse('本文［＃割り注］東は字大林四三七［＃改行］西は字神内一一一ノ一［＃割り注終わり］'),
      );

      final dslParagraph =
          dslCompiled.entries.single as AstCompiledParagraphEntry;
      final parsedParagraph =
          parsedCompiled.entries.single as AstCompiledParagraphEntry;
      final warichu = dslParagraph.extras.singleWhere(
        (extra) => extra.kind == AstParagraphExtraKind.warichu,
      );
      final parsedWarichu = parsedParagraph.extras.singleWhere(
        (extra) => extra.kind == AstParagraphExtraKind.warichu,
      );

      expect(dslParagraph.text, parsedParagraph.text);
      expect(warichu.warichuText, parsedWarichu.warichuText);
    });

    test('builds text color spans from Dart wrappers', () {
      final compiled = compileAst(
        ast([
          TextColor(
            color: const Color(0xffe53935),
            children: [
              const Text(value: '赤'),
              const Text(value: '太', bold: true),
            ],
          ),
        ]),
      );

      final paragraph = compiled.entries.single as AstCompiledParagraphEntry;
      expect(paragraph.text, '赤太');

      final colorSpan = paragraph.styles.singleWhere(
        (span) => span.kind == AstStyleKind.textColor,
      );
      expect(colorSpan.startIndex, 0);
      expect(colorSpan.endIndex, 2);
      expect(colorSpan.colorValue, const Color(0xffe53935).toARGB32());

      final boldSpan = paragraph.styles.singleWhere(
        (span) => span.kind == AstStyleKind.bold,
      );
      expect(boldSpan.startIndex, 1);
      expect(boldSpan.endIndex, 2);
    });
  });
}
