import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan_v1/kumihan.dart';

void main() {
  group('AstToLayoutIrConverter', () {
    late AstToLayoutIrConverter converter;

    setUp(() {
      converter = AstToLayoutIrConverter();
    });

    test(
      'converts v0-compatible parser output without compatibility issues',
      () {
        final document = AozoraAstParser().parse(
          '霧の｜ロンドン警視庁《スコットランドヤード》'
          '米機Ｂ29［＃「29」は縦中横］'
          '［＃丸傍点］青空［＃丸傍点終わり］'
          '［＃割り注］東［＃改行］西［＃割り注終わり］',
        );

        final ir = converter.convert(document);

        expect(ir.children, hasLength(1));
        expect(ir.compatibilityIssues, isEmpty);

        final paragraph = ir.children.single as LayoutParagraph;
        expect(paragraph.children[0], isA<LayoutTextInline>());
        expect(paragraph.children[1], isA<LayoutRubyInline>());
        expect(paragraph.children[2], isA<LayoutTextInline>());
        expect(paragraph.children[3], isA<LayoutDirectionInline>());
        expect(paragraph.children[4], isA<LayoutEmphasisInline>());
        expect(paragraph.children[5], isA<LayoutNoteInline>());
      },
    );

    test('preserves keep-with-previous and link/anchor inline nodes', () {
      final document = DocumentNode(
        span: _span(0),
        children: <BlockNode>[
          ParagraphNode(
            span: _span(1),
            keepWithPrevious: true,
            children: <InlineNode>[
              LinkNode(
                span: _span(2),
                target: '#chapter-1',
                children: <InlineNode>[TextNode(span: _span(3), text: '参照')],
              ),
              AnchorNode(span: _span(4), name: 'chapter-1'),
            ],
          ),
        ],
      );

      final ir = converter.convert(document);

      final paragraph = ir.children.single as LayoutParagraph;
      expect(paragraph.keepWithPrevious, isTrue);
      expect(paragraph.children.first, isA<LayoutLinkInline>());
      expect(paragraph.children.last, isA<LayoutAnchorInline>());

      final link = paragraph.children.first as LayoutLinkInline;
      final anchor = paragraph.children.last as LayoutAnchorInline;
      expect(link.target, '#chapter-1');
      expect(anchor.name, 'chapter-1');
    });

    test('converts all AST node kinds and records unsupported v0 patterns', () {
      final textSpan = _span(0);
      final inlineParagraph = ParagraphNode(
        span: _span(1),
        children: <InlineNode>[
          TextNode(span: _span(2), text: '本文'),
          GaijiNode(
            span: _span(3),
            rawNotation: '※［＃二の字点、1-2-22］',
            description: '二の字点、1-2-22',
            jisCode: '1-2-22',
          ),
          UnresolvedGaijiNode(
            span: _span(4),
            rawNotation: '※［＃「口＋世」、ページ数-行数］',
            text: '「口＋世」、ページ数-行数',
          ),
          ImageNode(
            span: _span(5),
            source: 'foo.png',
            alt: 'img',
            className: 'img1',
            width: 40,
            height: 50,
          ),
          RubyNode(
            span: _span(6),
            base: <InlineNode>[TextNode(span: _span(7), text: '注記')],
            text: 'した',
            kind: RubyKind.annotation,
            position: RubyPosition.under,
          ),
          DirectionInlineNode(
            span: _span(8),
            children: <InlineNode>[TextNode(span: _span(9), text: '29')],
            openDirective: _directive('［＃縦中横］', 8),
            kind: DirectionKind.tateChuYoko,
          ),
          FlowInlineNode(
            span: _span(10),
            children: <InlineNode>[TextNode(span: _span(11), text: 'ABC')],
            openDirective: _directive('［＃横組み］', 10),
            kind: FlowKind.yokogumi,
          ),
          CaptionInlineNode(
            span: _span(12),
            children: <InlineNode>[TextNode(span: _span(13), text: 'caption')],
            openDirective: _directive('［＃キャプション］', 12),
          ),
          FrameInlineNode(
            span: _span(14),
            children: <InlineNode>[TextNode(span: _span(15), text: '枠')],
            openDirective: _directive('［＃罫囲み］', 14),
            kind: FrameKind.keigakomi,
          ),
          NoteInlineNode(
            span: _span(16),
            children: <InlineNode>[TextNode(span: _span(17), text: '割書')],
            openDirective: _directive('［＃割書］', 16),
            kind: NoteKind.warigaki,
          ),
          StyledInlineNode(
            span: _span(18),
            children: <InlineNode>[TextNode(span: _span(19), text: '太字')],
            openDirective: _directive('［＃太字］', 18),
            style: TextStyleKind.bold,
          ),
          FontSizeInlineNode(
            span: _span(20),
            children: <InlineNode>[TextNode(span: _span(21), text: '大')],
            openDirective: _directive('［＃1段階大きな文字］', 20),
            kind: FontSizeKind.larger,
            steps: 1,
          ),
          HeadingInlineNode(
            span: _span(22),
            children: <InlineNode>[TextNode(span: _span(23), text: '同行')],
            openDirective: _directive('［＃同行中見出し］', 22),
            level: HeadingLevel.medium,
            display: HeadingDisplay.dogyo,
          ),
          EmphasisInlineNode(
            span: _span(24),
            children: <InlineNode>[TextNode(span: _span(25), text: '傍点')],
            openDirective: _directive('［＃右に傍点］', 24),
            mark: EmphasisMark.sesameDot,
            side: EmphasisSide.right,
          ),
          DecorationInlineNode(
            span: _span(26),
            children: <InlineNode>[TextNode(span: _span(27), text: '傍線')],
            openDirective: _directive('［＃下に傍線］', 26),
            kind: DecorationKind.underlineSolid,
            side: DecorationSide.under,
          ),
          ScriptInlineNode(
            span: _span(28),
            kind: ScriptKind.superscript,
            text: '上付き',
          ),
          KaeritenNode(span: _span(29), text: '二'),
          OkuriganaNode(span: _span(30), text: 'テスト'),
          EditorNoteNode(span: _span(31), text: '注記'),
          LineBreakNode(span: _span(32)),
          OpaqueInlineNode(
            span: _span(33),
            directive: _directive('［＃未対応注記］', 33),
          ),
        ],
      );

      final document = DocumentNode(
        span: textSpan,
        children: <BlockNode>[
          inlineParagraph,
          EmptyLineNode(span: _span(34)),
          OpaqueBlockNode(
            span: _span(36),
            directive: _directive('［＃未対応ブロック］', 36),
          ),
          IndentBlockNode(
            span: _span(37),
            children: <BlockNode>[
              ParagraphNode(span: _span(38), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから3字下げ］', 37),
            width: 3,
            isClosed: false,
          ),
          AlignmentBlockNode(
            span: _span(39),
            children: <BlockNode>[
              ParagraphNode(span: _span(40), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから地付き］', 39),
            kind: BlockAlignmentKind.chitsuki,
          ),
          JizumeBlockNode(
            span: _span(41),
            children: <BlockNode>[
              ParagraphNode(span: _span(42), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから3字詰め］', 41),
            width: 3,
          ),
          FlowBlockNode(
            span: _span(43),
            children: <BlockNode>[
              ParagraphNode(span: _span(44), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから横組み］', 43),
            kind: FlowKind.yokogumi,
          ),
          CaptionBlockNode(
            span: _span(45),
            children: <BlockNode>[
              ParagraphNode(span: _span(46), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここからキャプション］', 45),
          ),
          FrameBlockNode(
            span: _span(47),
            children: <BlockNode>[
              ParagraphNode(span: _span(48), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから罫囲み］', 47),
            kind: FrameKind.keigakomi,
          ),
          StyledBlockNode(
            span: _span(49),
            children: <BlockNode>[
              ParagraphNode(span: _span(50), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから太字］', 49),
            style: TextStyleKind.bold,
          ),
          FontSizeBlockNode(
            span: _span(51),
            children: <BlockNode>[
              ParagraphNode(span: _span(52), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから1段階大きな文字］', 51),
            kind: FontSizeKind.larger,
            steps: 1,
          ),
          HeadingBlockNode(
            span: _span(53),
            children: <BlockNode>[
              ParagraphNode(span: _span(54), children: const <InlineNode>[]),
            ],
            openDirective: _directive('［＃ここから窓小見出し］', 53),
            level: HeadingLevel.small,
            display: HeadingDisplay.mado,
          ),
          TableBlockNode(
            span: _span(55),
            attributes: const <String, String>{'class': 'wide'},
            rows: <TableRowNode>[
              TableRowNode(
                span: _span(56),
                attributes: const <String, String>{'role': 'header'},
                cells: <TableCellNode>[
                  TableCellNode(
                    span: _span(57),
                    attributes: const <String, String>{'align': 'center'},
                    children: <BlockNode>[
                      ParagraphNode(
                        span: _span(58),
                        children: <InlineNode>[
                          TextNode(span: _span(59), text: '見出し'),
                          StyledInlineNode(
                            span: _span(60),
                            children: <InlineNode>[
                              TextNode(span: _span(61), text: '強調'),
                            ],
                            openDirective: _directive('［＃太字］', 60),
                            style: TextStyleKind.bold,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      );

      final ir = converter.convert(document);

      expect(ir.children, hasLength(13));
      expect(ir.children.first, isA<LayoutParagraph>());
      expect(ir.children[1], isA<LayoutEmptyLine>());
      expect(ir.children[2], isA<LayoutUnsupportedBlock>());
      expect(ir.children.last, isA<LayoutTableBlock>());

      expect(
        ir.compatibilityIssues.map((issue) => issue.code),
        containsAll(<String>[
          'unresolved_gaiji_not_supported_by_v0',
          'ruby_position_not_supported_by_v0',
          'warigaki_not_supported_by_v0',
          'heading_display_not_supported_by_v0',
          'emphasis_side_not_supported_by_v0',
          'decoration_side_not_supported_by_v0',
          'opaque_inline_directive',
          'opaque_block_directive',
          'table_attributes_not_supported_by_v0',
          'table_row_attributes_not_supported_by_v0',
          'table_cell_attributes_not_supported_by_v0',
          'rich_table_cell_content_not_supported_by_v0',
        ]),
      );
    });
  });
}

SourceDirective _directive(String rawText, int offset) {
  return SourceDirective(
    format: 'aozora',
    rawText: rawText,
    body: rawText,
    span: _span(offset),
  );
}

SourceSpan _span(int offset) {
  return SourceSpan(start: _loc(offset), end: _loc(offset + 1));
}

SourceLocation _loc(int offset) {
  return SourceLocation(offset: offset, line: 1, column: offset + 1);
}
