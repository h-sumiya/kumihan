import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  group('LayoutResultBuilder', () {
    test('builds paragraph lines, annotations, and hit regions', () {
      final builder = LayoutResultBuilder(
        constraints: const LayoutConstraints(lineExtent: 4, lineGap: 0.5),
      );
      final document = LayoutDocument(
        span: _span(0),
        children: <LayoutBlock>[
          LayoutParagraph(
            span: _span(1),
            children: <LayoutInline>[
              LayoutTextInline(span: _span(2), text: '冒頭'),
              LayoutRubyInline(
                span: _span(3),
                base: <LayoutInline>[
                  LayoutTextInline(span: _span(4), text: '警視庁'),
                ],
                text: 'ヤード',
                kind: RubyKind.phonetic,
                position: RubyPosition.over,
              ),
              LayoutDirectionInline(
                span: _span(5),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(6), text: '29'),
                ],
                kind: DirectionKind.tateChuYoko,
              ),
              LayoutEmphasisInline(
                span: _span(7),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(8), text: '青空'),
                ],
                mark: EmphasisMark.blackCircle,
              ),
              LayoutDecorationInline(
                span: _span(9),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(10), text: '線'),
                ],
                kind: DecorationKind.underlineWave,
              ),
              LayoutNoteInline(
                span: _span(11),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(12), text: '東'),
                  LayoutLineBreakInline(span: _span(13)),
                  LayoutTextInline(span: _span(14), text: '西'),
                ],
                kind: NoteKind.warichu,
              ),
              LayoutGaijiInline(
                span: _span(15),
                rawNotation: '※［＃二の字点、1-2-22］',
                description: '二の字点、1-2-22',
                jisCode: '1-2-22',
              ),
              LayoutUnresolvedGaijiInline(
                span: _span(16),
                rawNotation: '※［＃未解決］',
                text: '未解決',
              ),
              LayoutImageInline(
                span: _span(17),
                source: 'foo.png',
                width: 20,
                height: 30,
              ),
              LayoutLinkInline(
                span: _span(23),
                target: '#foo',
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(24), text: '関連'),
                ],
              ),
              LayoutAnchorInline(span: _span(25), name: 'foo'),
              LayoutScriptInline(
                span: _span(18),
                kind: ScriptKind.superscript,
                text: '上',
              ),
              LayoutKaeritenInline(span: _span(19), text: 'レ'),
              LayoutOkuriganaInline(span: _span(20), text: 'かな'),
              LayoutEditorNoteInline(span: _span(21), text: '注'),
              LayoutUnsupportedInline(
                span: _span(22),
                directive: _directive('［＃未対応注記］', 22),
              ),
            ],
          ),
        ],
      );

      final result = builder.build(document);

      expect(result.blocks, hasLength(1));
      expect(result.hitRegions, hasLength(3));

      final paragraph = result.blocks.single as LayoutParagraphResult;
      expect(paragraph.lineGroup.lines.length, greaterThan(1));

      final fragments = paragraph.lineGroup.lines
          .expand((line) => line.fragments)
          .toList(growable: false);
      final markers = paragraph.lineGroup.lines
          .expand((line) => line.markers)
          .toList(growable: false);
      final rubies = paragraph.lineGroup.lines
          .expand((line) => line.rubies)
          .toList(growable: false);
      final notes = fragments.whereType<LayoutNoteFragment>().toList();

      expect(
        fragments.whereType<LayoutTextFragment>().any(
          (fragment) =>
              fragment.style.directionKind == DirectionKind.tateChuYoko,
        ),
        isTrue,
      );
      expect(
        fragments.whereType<LayoutTextFragment>().any(
          (fragment) => fragment.style.scriptKind == ScriptKind.superscript,
        ),
        isTrue,
      );
      expect(
        fragments.whereType<LayoutGaijiFragment>().any(
          (fragment) => fragment.resolved && fragment.displayText == '〻',
        ),
        isTrue,
      );
      expect(
        fragments.whereType<LayoutGaijiFragment>().any(
          (fragment) => !fragment.resolved,
        ),
        isTrue,
      );
      expect(fragments.whereType<LayoutImageFragment>(), hasLength(1));
      expect(notes, hasLength(1));
      expect(notes.single.upperText, '東');
      expect(notes.single.lowerText, '西');

      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.emphasis),
        isTrue,
      );
      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.decoration),
        isTrue,
      );
      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.note),
        isTrue,
      );
      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.kaeriten),
        isTrue,
      );
      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.okurigana),
        isTrue,
      );
      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.editorNote),
        isTrue,
      );
      expect(
        markers.any((marker) => marker.kind == LayoutMarkerKind.unsupported),
        isTrue,
      );
      expect(rubies, isNotEmpty);
      expect(rubies.any((ruby) => ruby.interCharacterSpacing != 0), isTrue);
      expect(
        result.hitRegions.map((region) => region.kind),
        containsAll(<LayoutHitRegionKind>[
          LayoutHitRegionKind.image,
          LayoutHitRegionKind.link,
          LayoutHitRegionKind.anchor,
        ]),
      );
    });

    test('uses unicode line breaking and keep-with-previous block spacing', () {
      final builder = LayoutResultBuilder(
        constraints: const LayoutConstraints(lineExtent: 2, blockGap: 1),
      );
      final document = LayoutDocument(
        span: _span(200),
        children: <LayoutBlock>[
          LayoutParagraph(
            span: _span(201),
            children: <LayoutInline>[
              LayoutTextInline(span: _span(202), text: '前'),
            ],
          ),
          LayoutParagraph(
            span: _span(203),
            keepWithPrevious: true,
            children: <LayoutInline>[
              LayoutTextInline(span: _span(204), text: '「あい」'),
            ],
          ),
        ],
      );

      final result = builder.build(document);
      final paragraphs = result.blocks
          .whereType<LayoutParagraphResult>()
          .toList();

      expect(paragraphs, hasLength(2));
      expect(paragraphs[1].inlineOffset, paragraphs[0].inlineExtent);
      expect(paragraphs[1].style.keepWithPrevious, isTrue);

      final secondLineTexts = paragraphs[1].lineGroup.lines
          .map(
            (line) => line.fragments
                .whereType<LayoutTextFragment>()
                .map((fragment) => fragment.text)
                .join(),
          )
          .toList(growable: false);
      expect(secondLineTexts.first, '「あ');
      expect(secondLineTexts.last, 'い」');
    });

    test('processes block containers and tables into leaf block results', () {
      final builder = LayoutResultBuilder(
        constraints: const LayoutConstraints(lineExtent: 6),
      );
      final document = LayoutDocument(
        span: _span(100),
        children: <LayoutBlock>[
          LayoutEmptyLine(span: _span(101)),
          LayoutUnsupportedBlock(
            span: _span(102),
            directive: _directive('［＃未対応ブロック］', 102),
          ),
          LayoutIndentBlock(
            span: _span(103),
            width: 2,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(104),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(105), text: '字下げ'),
                ],
              ),
            ],
          ),
          LayoutAlignmentBlock(
            span: _span(106),
            kind: BlockAlignmentKind.chitsuki,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(107),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(108), text: '地付き'),
                ],
              ),
            ],
          ),
          LayoutJizumeBlock(
            span: _span(109),
            width: 2,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(110),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(111), text: 'あいう'),
                ],
              ),
            ],
          ),
          LayoutFlowBlock(
            span: _span(112),
            kind: FlowKind.yokogumi,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(113),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(114), text: 'ABC'),
                ],
              ),
            ],
          ),
          LayoutCaptionBlock(
            span: _span(115),
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(116),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(117), text: 'caption'),
                ],
              ),
            ],
          ),
          LayoutFrameBlock(
            span: _span(118),
            kind: FrameKind.keigakomi,
            borderWidth: 2,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(119),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(120), text: '囲み'),
                ],
              ),
            ],
          ),
          LayoutStyledBlock(
            span: _span(121),
            style: TextStyleKind.bold,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(122),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(123), text: '太字'),
                ],
              ),
            ],
          ),
          LayoutFontSizeBlock(
            span: _span(124),
            kind: FontSizeKind.larger,
            steps: 1,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(125),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(126), text: '拡大'),
                ],
              ),
            ],
          ),
          LayoutHeadingBlock(
            span: _span(127),
            level: HeadingLevel.large,
            display: HeadingDisplay.dogyo,
            children: <LayoutBlock>[
              LayoutParagraph(
                span: _span(128),
                children: <LayoutInline>[
                  LayoutTextInline(span: _span(129), text: '見出し'),
                ],
              ),
            ],
          ),
          LayoutTableBlock(
            span: _span(130),
            rows: <LayoutTableRow>[
              LayoutTableRow(
                span: _span(131),
                cells: <LayoutTableCell>[
                  LayoutTableCell(
                    span: _span(132),
                    children: <LayoutBlock>[
                      LayoutParagraph(
                        span: _span(133),
                        children: <LayoutInline>[
                          LayoutTextInline(span: _span(134), text: 'A'),
                        ],
                      ),
                    ],
                  ),
                  LayoutTableCell(
                    span: _span(135),
                    children: <LayoutBlock>[
                      LayoutParagraph(
                        span: _span(136),
                        children: <LayoutInline>[
                          LayoutTextInline(span: _span(137), text: 'B'),
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

      final result = builder.build(document);
      final paragraphs = result.blocks
          .whereType<LayoutParagraphResult>()
          .toList();

      expect(result.blocks.whereType<LayoutEmptyLineResult>(), hasLength(1));
      expect(
        result.blocks.whereType<LayoutUnsupportedBlockResult>(),
        hasLength(1),
      );
      expect(paragraphs, hasLength(9));
      expect(result.blocks.whereType<LayoutTableResult>(), hasLength(1));

      expect(paragraphs[0].style.firstIndent, 2);
      expect(paragraphs[0].style.restIndent, 2);
      expect(paragraphs[1].style.alignToFarEdge, isTrue);
      expect(paragraphs[2].style.lineExtent, 2);
      expect(paragraphs[2].lineGroup.lines, hasLength(2));
      expect(paragraphs[3].style.flowKind, FlowKind.yokogumi);
      expect(paragraphs[4].style.caption, isTrue);
      expect(
        paragraphs[5].lineGroup.lines
            .expand((line) => line.markers)
            .any((marker) => marker.kind == LayoutMarkerKind.frame),
        isTrue,
      );
      expect(paragraphs[6].style.bold, isTrue);
      expect(paragraphs[7].style.fontScale, greaterThan(1));
      expect(paragraphs[8].style.headingLevel, HeadingLevel.large);
      expect(paragraphs[8].style.headingDisplay, HeadingDisplay.dogyo);
      expect(paragraphs[8].style.fontScale, greaterThan(1));

      final table = result.blocks.whereType<LayoutTableResult>().single;
      expect(table.rows, hasLength(1));
      expect(table.rows.single.cells, hasLength(2));
      expect(
        table.rows.single.cells.every((cell) => cell.blocks.isNotEmpty),
        isTrue,
      );
    });
  });
}

SourceSpan _span(int offset) {
  return SourceSpan(
    start: SourceLocation(offset: offset, line: 1, column: offset + 1),
    end: SourceLocation(offset: offset + 1, line: 1, column: offset + 2),
  );
}

SourceDirective _directive(String rawText, int offset) {
  return SourceDirective(
    format: 'aozora',
    rawText: rawText,
    body: rawText,
    span: _span(offset),
  );
}
