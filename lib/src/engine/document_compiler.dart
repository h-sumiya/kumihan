import 'constants.dart';
import 'generated/gaiji_table.dart';
import 'layout_primitives.dart';
import 'warichu.dart';
import '../ast.dart';
import '../document.dart';

class AstCompiledDocument {
  const AstCompiledDocument({required this.entries});

  final List<AstCompiledEntry> entries;
}

sealed class AstCompiledEntry {
  const AstCompiledEntry();
}

class AstCompiledParagraphEntry extends AstCompiledEntry {
  const AstCompiledParagraphEntry({
    required this.text,
    this.alignBottom = false,
    this.bottomMargin = 0,
    this.chapterIndexes = const <AstChapterIndex>[],
    this.extras = const <AstParagraphExtra>[],
    this.firstTopMargin = 0,
    this.inserts = const <AstInlineInsert>[],
    this.nonBreak = false,
    this.restTopMargin = 0,
    this.rubies = const <AstRubySpan>[],
    this.styles = const <AstStyleSpan>[],
    this.tcyRanges = const <AstRange>[],
  });

  final String text;
  final bool nonBreak;
  final double firstTopMargin;
  final double restTopMargin;
  final double bottomMargin;
  final bool alignBottom;
  final List<AstStyleSpan> styles;
  final List<AstInlineInsert> inserts;
  final List<AstRubySpan> rubies;
  final List<AstParagraphExtra> extras;
  final List<AstRange> tcyRanges;
  final List<AstChapterIndex> chapterIndexes;
}

class AstCompiledTableEntry extends AstCompiledEntry {
  const AstCompiledTableEntry({
    required this.headerRowCount,
    required this.rows,
  });

  final List<List<AstCompiledTableCell>> rows;
  final int headerRowCount;
}

class AstCompiledTableCell {
  const AstCompiledTableCell({
    required this.alignment,
    required this.text,
  });

  final String text;
  final AstTableAlignment alignment;
}

enum AstCommandKind {
  indentStart,
  indentEnd,
  bottomAlignStart,
  bottomAlignEnd,
  jizumeStart,
  jizumeEnd,
  boldStart,
  boldEnd,
  italicStart,
  italicEnd,
  captionStart,
  captionEnd,
  yokogumiStart,
  yokogumiEnd,
  headingStart,
  headingEnd,
  fontScaleStart,
  fontScaleEnd,
  frameStart,
  frameEnd,
  pageBreak,
  pageCenter,
}

class AstCommandEntry extends AstCompiledEntry {
  const AstCommandEntry({
    required this.kind,
    this.bottomAlignKind,
    this.bottomAlignOffset = 0,
    this.fontScaleDirection,
    this.fontScaleSteps,
    this.headingLevel,
    this.indentHanging,
    this.indentLine = 0,
    this.pageBreakKind,
    this.jizumeWidth,
  });

  final AstCommandKind kind;
  final int indentLine;
  final int? indentHanging;
  final AstBottomAlignKind? bottomAlignKind;
  final int bottomAlignOffset;
  final AstHeadingLevel? headingLevel;
  final AstFontScaleDirection? fontScaleDirection;
  final int? fontScaleSteps;
  final int? jizumeWidth;
  final AstPageBreakKind? pageBreakKind;
}

enum AstStyleKind {
  headingLarge,
  headingMedium,
  headingSmall,
  bold,
  italic,
  textColor,
  caption,
  yokogumi,
  kaeri,
  okuri,
  lineRightSmall,
  lineLeftSmall,
  superscript,
  subscript,
  warichuPlaceholder,
  warichuBracket,
  fontScale,
}

class AstStyleSpan {
  const AstStyleSpan({
    required this.endIndex,
    required this.kind,
    required this.startIndex,
    this.colorValue,
    this.fontScaleDirection,
    this.fontScaleSteps,
  });

  final int startIndex;
  final int endIndex;
  final AstStyleKind kind;
  final int? colorValue;
  final AstFontScaleDirection? fontScaleDirection;
  final int? fontScaleSteps;
}

class AstRange {
  const AstRange({required this.startIndex, required this.endIndex});

  final int startIndex;
  final int endIndex;
}

class AstInlineInsert {
  AstInlineInsert({
    required this.startIndex,
    required this.text,
    required this.type,
  });

  final int startIndex;
  final String text;
  final LayoutInlineDecorationKind type;
  LayoutTextLine? tl;
}

class AstRubySpan {
  AstRubySpan({
    required this.endIndex,
    required this.ruby,
    required this.spans,
    required this.startIndex,
    required this.type,
  });

  final int startIndex;
  final int endIndex;
  final String ruby;
  final List<AstStyleSpan> spans;
  final LayoutInlineDecorationKind type;
  LayoutTextBlock? tb;
  double trackingStart = 0;
  double trackingEnd = 0;
}

enum AstParagraphExtraKind {
  outsideImage,
  inlineImage,
  ruledLine,
  warichu,
  noteReference,
  span,
  emphasis,
  note,
  link,
  frame,
  anchor,
}

enum AstRuledLineKind {
  solid,
  doubleLine,
  chain,
  dashed,
  wave,
  cancel,
  frameBox,
}

enum AstFrameKind { start, middle, end }

enum AstEmphasisKind {
  sesame,
  whiteSesame,
  blackCircle,
  whiteCircle,
  blackTriangle,
  whiteTriangle,
  bullseye,
  fisheye,
  saltire,
}

class AstParagraphExtra {
  const AstParagraphExtra({
    required this.kind,
    this.emphasisKind,
    this.endIndex,
    this.frameKind,
    this.imageHeight,
    this.imagePath,
    this.imageWidth,
    this.linkTarget,
    this.noteText,
    this.rightSide,
    this.ruledLineKind,
    this.startIndex,
    this.warichuText,
  });

  final AstParagraphExtraKind kind;
  final int? startIndex;
  final int? endIndex;
  final AstFrameKind? frameKind;
  final String? imagePath;
  final double? imageWidth;
  final double? imageHeight;
  final String? linkTarget;
  final AstRuledLineKind? ruledLineKind;
  final AstEmphasisKind? emphasisKind;
  final bool? rightSide;
  final String? noteText;
  final String? warichuText;
}

enum AstChapterKind { large, medium, small, anchor }

class AstChapterIndex {
  const AstChapterIndex({
    required this.endIndex,
    required this.kind,
    required this.startIndex,
    this.anchorName,
  });

  final int startIndex;
  final int endIndex;
  final AstChapterKind kind;
  final String? anchorName;
}

AstCompiledDocument compileAst(Document document) {
  return _AstDocumentCompiler(document.ast).compile();
}

class _AstDocumentCompiler {
  _AstDocumentCompiler(this.data);

  final AstData data;
  final List<AstCompiledEntry> _entries = <AstCompiledEntry>[];

  AstCompiledDocument compile() {
    final lineTokens = <AstToken>[];
    var nonBreakNextLine = false;

    void flushLine() {
      if (lineTokens.isEmpty) {
        _entries.add(
          AstCompiledParagraphEntry(text: nonBreakNextLine ? ' ' : ' '),
        );
        nonBreakNextLine = false;
        return;
      }
      final lineEntries = _compileLine(lineTokens, nonBreak: nonBreakNextLine);
      _entries.addAll(lineEntries);
      lineTokens.clear();
      nonBreakNextLine = false;
    }

    for (final token in data) {
      if (token is AstNewLine) {
        flushLine();
        continue;
      }
      if (token is AstTable) {
        if (lineTokens.isNotEmpty) {
          flushLine();
        }
        _entries.add(_compileTable(token));
        continue;
      }
      if (token is AstDocumentRemark) {
        lineTokens.add(AstText(_remarkText(token)));
        continue;
      }
      if (token is AstBodyEnd) {
        lineTokens.add(AstUnsupportedAnnotation('［＃本文終わり］'));
        continue;
      }
      lineTokens.add(token);
    }
    if (lineTokens.isNotEmpty) {
      flushLine();
    }
    return AstCompiledDocument(
      entries: List<AstCompiledEntry>.unmodifiable(_entries),
    );
  }

  List<AstCompiledEntry> _compileLine(
    List<AstToken> sourceLine, {
    required bool nonBreak,
  }) {
    final line = List<AstToken>.from(sourceLine);
    final commands = <AstCompiledEntry>[];

    while (line.isNotEmpty) {
      final command = _consumeStandaloneCommand(line.first);
      if (command == null) {
        break;
      }
      commands.add(command);
      line.removeAt(0);
    }

    if (line.isEmpty) {
      if (commands.isNotEmpty) {
        final last = commands.last;
        if (last case AstCommandEntry(kind: AstCommandKind.frameStart)) {
          commands.add(
            const AstCompiledParagraphEntry(
              text: ' ',
              extras: <AstParagraphExtra>[
                AstParagraphExtra(
                  kind: AstParagraphExtraKind.frame,
                  frameKind: AstFrameKind.start,
                ),
              ],
            ),
          );
        } else if (last case AstCommandEntry(kind: AstCommandKind.frameEnd)) {
          commands.add(
            const AstCompiledParagraphEntry(
              text: ' ',
              extras: <AstParagraphExtra>[
                AstParagraphExtra(
                  kind: AstParagraphExtraKind.frame,
                  frameKind: AstFrameKind.end,
                ),
              ],
            ),
          );
        }
      }
      return commands;
    }

    final splitIndex = line.indexWhere(
      (token) =>
          token is AstBottomAlign &&
          token.scope == AstBottomAlignScope.inlineTail,
    );
    if (splitIndex >= 0) {
      final leadingTokens = line.sublist(0, splitIndex);
      final tailAlign = line[splitIndex] as AstBottomAlign;
      final tailTokens = line.sublist(splitIndex + 1);

      if (leadingTokens.isNotEmpty) {
        commands.add(_compileParagraph(leadingTokens, nonBreak: nonBreak));
      }
      if (tailTokens.isNotEmpty) {
        commands.add(
          _compileParagraph(
            tailTokens,
            nonBreak: true,
            forcedAlignBottom: true,
            forcedBottomMargin: tailAlign.kind == AstBottomAlignKind.bottom
                ? 0
                : tailAlign.offset.toDouble(),
          ),
        );
      }
      return commands;
    }

    commands.add(_compileParagraph(line, nonBreak: nonBreak));
    return commands;
  }

  AstCompiledParagraphEntry _compileParagraph(
    List<AstToken> sourceLine, {
    required bool nonBreak,
    bool forcedAlignBottom = false,
    double forcedBottomMargin = 0,
  }) {
    final line = List<AstToken>.from(sourceLine);
    var firstTopMargin = 0.0;
    var restTopMargin = 0.0;
    var bottomMargin = forcedBottomMargin;
    var alignBottom = forcedAlignBottom;

    while (line.isNotEmpty) {
      final token = line.first;
      if (token case AstIndent(kind: AstIndentKind.singleLine)) {
        final margin = token.lineIndent.toDouble();
        firstTopMargin = margin;
        restTopMargin = token.hangingIndent?.toDouble() ?? margin;
        line.removeAt(0);
        continue;
      }
      if (!forcedAlignBottom &&
          token is AstBottomAlign &&
          token.scope == AstBottomAlignScope.singleLine) {
        final kind = token.kind;
        final offset = token.offset;
        alignBottom = true;
        bottomMargin = kind == AstBottomAlignKind.bottom
            ? 0
            : offset.toDouble();
        line.removeAt(0);
        continue;
      }
      break;
    }

    final builder = _ParagraphBuilder();
    for (final token in line) {
      _emitToken(builder, token);
    }
    builder.applyAutoLinks();

    return AstCompiledParagraphEntry(
      text: builder.text.isEmpty ? ' ' : builder.text,
      nonBreak: nonBreak,
      firstTopMargin: firstTopMargin,
      restTopMargin: restTopMargin,
      bottomMargin: bottomMargin,
      alignBottom: alignBottom,
      styles: List<AstStyleSpan>.unmodifiable(builder.styles),
      inserts: List<AstInlineInsert>.unmodifiable(builder.inserts),
      rubies: List<AstRubySpan>.unmodifiable(builder.rubies),
      extras: List<AstParagraphExtra>.unmodifiable(builder.extras),
      tcyRanges: List<AstRange>.unmodifiable(builder.tcyRanges),
      chapterIndexes: List<AstChapterIndex>.unmodifiable(
        builder.chapterIndexes,
      ),
    );
  }

  AstCompiledTableEntry _compileTable(AstTable table) {
    return AstCompiledTableEntry(
      headerRowCount: table.headerRowCount,
      rows: List<List<AstCompiledTableCell>>.unmodifiable(
        table.rows.map(
          (row) => List<AstCompiledTableCell>.unmodifiable(
            row.map(
              (cell) => AstCompiledTableCell(
                alignment: cell.alignment,
                text: _compileInlineContent(cell.content).text.trim(),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AstCompiledEntry? _consumeStandaloneCommand(AstToken token) {
    return switch (token) {
      AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockStart,
        lineIndent: final lineIndent,
        hangingIndent: final hangingIndent,
      ) =>
        AstCommandEntry(
          kind: AstCommandKind.indentStart,
          indentLine: lineIndent,
          indentHanging: hangingIndent,
        ),
      AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockEnd,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.indentEnd),
      AstBottomAlign(
        scope: AstBottomAlignScope.block,
        boundary: AstRangeBoundary.blockStart,
        kind: final kind,
        offset: final offset,
      ) =>
        AstCommandEntry(
          kind: AstCommandKind.bottomAlignStart,
          bottomAlignKind: kind,
          bottomAlignOffset: offset,
        ),
      AstBottomAlign(
        scope: AstBottomAlignScope.block,
        boundary: AstRangeBoundary.blockEnd,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.bottomAlignEnd),
      AstJizume(boundary: AstRangeBoundary.blockStart, width: final width) =>
        AstCommandEntry(kind: AstCommandKind.jizumeStart, jizumeWidth: width),
      AstJizume(boundary: AstRangeBoundary.blockEnd) => const AstCommandEntry(
        kind: AstCommandKind.jizumeEnd,
      ),
      AstStyledText(
        boundary: AstRangeBoundary.blockStart,
        style: AstFontStyleAnnotation(style: AstFontStyle.bold),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.boldStart),
      AstStyledText(
        boundary: AstRangeBoundary.blockEnd,
        style: AstFontStyleAnnotation(style: AstFontStyle.bold),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.boldEnd),
      AstStyledText(
        boundary: AstRangeBoundary.blockStart,
        style: AstFontStyleAnnotation(style: AstFontStyle.italic),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.italicStart),
      AstStyledText(
        boundary: AstRangeBoundary.blockEnd,
        style: AstFontStyleAnnotation(style: AstFontStyle.italic),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.italicEnd),
      AstStyledText(
        boundary: AstRangeBoundary.blockStart,
        style: AstFontScaleStyle(
          direction: final direction,
          steps: final steps,
        ),
      ) =>
        AstCommandEntry(
          kind: AstCommandKind.fontScaleStart,
          fontScaleDirection: direction,
          fontScaleSteps: steps,
        ),
      AstStyledText(
        boundary: AstRangeBoundary.blockEnd,
        style: AstFontScaleStyle(),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.fontScaleEnd),
      AstHeading(boundary: AstRangeBoundary.blockStart, level: final level) =>
        AstCommandEntry(kind: AstCommandKind.headingStart, headingLevel: level),
      AstHeading(boundary: AstRangeBoundary.blockEnd) => const AstCommandEntry(
        kind: AstCommandKind.headingEnd,
      ),
      AstCaption(boundary: AstRangeBoundary.blockStart) =>
        const AstCommandEntry(kind: AstCommandKind.captionStart),
      AstCaption(boundary: AstRangeBoundary.blockEnd) => const AstCommandEntry(
        kind: AstCommandKind.captionEnd,
      ),
      AstInlineDecoration(
        boundary: AstRangeBoundary.blockStart,
        kind: AstInlineDecorationKind.yokogumi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.yokogumiStart),
      AstInlineDecoration(
        boundary: AstRangeBoundary.blockEnd,
        kind: AstInlineDecorationKind.yokogumi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.yokogumiEnd),
      AstInlineDecoration(
        boundary: AstRangeBoundary.blockStart,
        kind: AstInlineDecorationKind.keigakomi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.frameStart),
      AstInlineDecoration(
        boundary: AstRangeBoundary.blockEnd,
        kind: AstInlineDecorationKind.keigakomi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.frameEnd),
      AstPageBreak(kind: final kind) => AstCommandEntry(
        kind: AstCommandKind.pageBreak,
        pageBreakKind: kind,
      ),
      AstPageCenter() => const AstCommandEntry(kind: AstCommandKind.pageCenter),
      _ => null,
    };
  }

  void _emitToken(_ParagraphBuilder builder, AstToken token) {
    switch (token) {
      case AstText():
        builder.appendText(_normalizePlainText(token.text));
      case AstAccentDecomposition():
        builder.appendText(_convertAccent(token.text));
      case AstGaiji():
        _emitGaiji(builder, token);
      case AstTateTen():
        builder.appendInlineMarker('―', LayoutInlineDecorationKind.naka);
      case AstKaeriten():
        builder.appendInlineMarker(
          _kaeritenText(token),
          LayoutInlineDecorationKind.kaeri,
        );
      case AstKuntenOkurigana():
        builder.appendInlineMarker(
          _compileInlineContent(token.content).text,
          LayoutInlineDecorationKind.okuri,
        );
      case AstAttachedText():
        builder.handleAttachedText(token, _compileInlineContent(token.content));
      case AstStyledText():
        builder.handleStyledText(token);
      case AstHeading():
        builder.handleHeading(token);
      case AstCaption():
        builder.handleCaption(token);
      case AstLink():
        builder.handleLink(token);
      case AstInlineDecoration():
        builder.handleInlineDecoration(token);
      case AstImage():
        builder.appendImage(token);
      case AstTable():
        builder.handleUnsupported('［＃未対応の表］');
      case AstUnsupportedAnnotation():
        builder.handleUnsupported(token.raw);
      case AstWarichuNewLine():
        builder.appendWarichuNewLine();
      case AstIndent():
      case AstBottomAlign():
      case AstJizume():
      case AstPageBreak():
      case AstPageCenter():
      case AstBodyEnd():
      case AstDocumentRemark():
      case AstNewLine():
        builder.handleUnsupported(_rawForToken(token));
    }
  }

  void _emitGaiji(_ParagraphBuilder builder, AstGaiji gaiji) {
    switch (gaiji.kind) {
      case AstGaijiKind.jisX0213:
        final jis = [
          gaiji.jisCode?.plane,
          gaiji.jisCode?.row,
          gaiji.jisCode?.cell,
        ].join('-');
        final character = kumihanGaijiTable[jis];
        if (character != null) {
          builder.appendText(character);
          return;
        }
      case AstGaijiKind.unicode:
        final codePoint = gaiji.unicodeCodePoint;
        if (codePoint != null) {
          builder.appendText(String.fromCharCode(codePoint));
          return;
        }
      case AstGaijiKind.missingUnicode:
        break;
    }
    final start = builder.text.length;
    builder.appendText('※');
    builder.extras.add(
      AstParagraphExtra(
        kind: AstParagraphExtraKind.noteReference,
        noteText: _gaijiBody(gaiji),
        startIndex: start,
        endIndex: start + 1,
      ),
    );
  }

  _CompiledInlineContent _compileInlineContent(AstInlineContent? content) {
    if (content == null || content.isEmpty) {
      return const _CompiledInlineContent(text: '', spans: <AstStyleSpan>[]);
    }
    final builder = _ParagraphBuilder();
    for (final node in content) {
      switch (node) {
        case AstText():
          builder.appendText(_normalizePlainText(node.text));
        case AstAccentDecomposition():
          builder.appendText(_convertAccent(node.text));
        case AstGaiji():
          _emitGaiji(builder, node);
        case AstTateTen():
          builder.appendInlineMarker('―', LayoutInlineDecorationKind.naka);
        case AstKaeriten():
          builder.appendInlineMarker(
            _kaeritenText(node),
            LayoutInlineDecorationKind.kaeri,
          );
        case AstKuntenOkurigana():
          builder.appendInlineMarker(
            _compileInlineContent(node.content).text,
            LayoutInlineDecorationKind.okuri,
          );
        case AstWarichuNewLine():
          builder.appendText('［＃改行］');
        case AstAttachedText():
        case AstStyledText():
        case AstHeading():
        case AstCaption():
        case AstLink():
        case AstInlineDecoration():
        case AstUnsupportedAnnotation():
        case AstImage():
        case AstTable():
        case AstNewLine():
        case AstBodyEnd():
        case AstDocumentRemark():
        case AstIndent():
        case AstBottomAlign():
        case AstJizume():
        case AstPageBreak():
        case AstPageCenter():
          break;
      }
    }
    final spans = <AstStyleSpan>[
      for (final insert in builder.inserts)
        if (insert.type != LayoutInlineDecorationKind.naka)
          AstStyleSpan(
            startIndex: insert.startIndex,
            endIndex: insert.startIndex + insert.text.length,
            kind: insert.type == LayoutInlineDecorationKind.kaeri
                ? AstStyleKind.kaeri
                : AstStyleKind.okuri,
          ),
    ];
    return _CompiledInlineContent(
      text: builder.text.replaceAll('⁠￼', ''),
      spans: spans,
    );
  }

  String _convertAccent(String source) {
    final converted = source.replaceAllMapped(
      RegExp(r"(AE&|OE&|[!?ACEINOSUY][@`'^~:&,/_])", caseSensitive: false),
      (match) => accentsTable[match[0]!] ?? match[0]!,
    );
    return converted != source ? converted : '〔$source〕';
  }

  String _normalizePlainText(String text) {
    final buffer = StringBuffer();
    String? previous;
    for (final rune in text.runes) {
      var char = String.fromCharCode(rune);
      if (char == '\u2014' || char == '\u2015') {
        char = '─';
      } else if (char == '\u3099') {
        char = '゛';
      } else if (char == '\u309a') {
        char = '゜';
      }
      if ((char == '─' || char == '…') && previous == char) {
        buffer.write('⁠');
      }
      buffer.write(char);
      previous = char;
    }
    return buffer.toString();
  }

  String _kaeritenText(AstKaeriten token) {
    const map = <AstKaeritenPrimary, String>{
      AstKaeritenPrimary.ichi: '一',
      AstKaeritenPrimary.ni: '二',
      AstKaeritenPrimary.san: '三',
      AstKaeritenPrimary.yon: '四',
      AstKaeritenPrimary.jou: '上',
      AstKaeritenPrimary.chuu: '中',
      AstKaeritenPrimary.ge: '下',
      AstKaeritenPrimary.kou: '甲',
      AstKaeritenPrimary.otsu: '乙',
      AstKaeritenPrimary.hei: '丙',
      AstKaeritenPrimary.ten: '天',
      AstKaeritenPrimary.chi: '地',
      AstKaeritenPrimary.jin: '人',
    };
    final buffer = StringBuffer();
    final primary = token.primary;
    if (primary != null) {
      buffer.write(map[primary]);
    }
    if (token.hasRe) {
      buffer.write('レ');
    }
    return buffer.toString();
  }

  String _gaijiBody(AstGaiji gaiji) {
    switch (gaiji.kind) {
      case AstGaijiKind.jisX0213:
        return '「${gaiji.description}」、第${gaiji.jisLevel}水準'
            '${gaiji.jisCode?.plane}-${gaiji.jisCode?.row}-${gaiji.jisCode?.cell}';
      case AstGaijiKind.unicode:
        return '「${gaiji.description}」、U+${gaiji.unicodeCodePoint?.toRadixString(16).toUpperCase()}'
            '、${gaiji.printPosition?.page}-${gaiji.printPosition?.line}';
      case AstGaijiKind.missingUnicode:
        return '「${gaiji.description}」、${gaiji.printPosition?.page}-${gaiji.printPosition?.line}';
    }
  }

  String _remarkText(AstDocumentRemark remark) {
    return switch (remark.kind) {
      AstDocumentRemarkKind.baseTextIsHorizontal => '※底本は横組みです。',
      AstDocumentRemarkKind.omittedLowerHeadingLevels =>
        '※小見出しよりもさらに下位の見出しには、注記しませんでした。',
      AstDocumentRemarkKind.madoHeadingLineCount =>
        '※窓見出しは、${remark.value}行どりです。',
      AstDocumentRemarkKind.replacedOuterKikkouWithSquareBrackets =>
        '※底本の「〔〕」を「［］」に置き換えました。',
    };
  }

  String _rawForToken(AstToken token) {
    return switch (token) {
      AstIndent(kind: AstIndentKind.singleLine, lineIndent: final lineIndent) =>
        '［＃$lineIndent字下げ］',
      AstBottomAlign(
        kind: AstBottomAlignKind.bottom,
        scope: AstBottomAlignScope.inlineTail,
      ) =>
        '［＃地付き］',
      AstBottomAlign(
        kind: AstBottomAlignKind.raisedFromBottom,
        offset: final offset,
      ) =>
        '［＃地から$offset字上げ］',
      _ => '［＃未対応］',
    };
  }
}

class _CompiledInlineContent {
  const _CompiledInlineContent({required this.text, required this.spans});

  final String text;
  final List<AstStyleSpan> spans;
}

class _OpenSpan<T> {
  const _OpenSpan(this.startIndex, this.value);

  final int startIndex;
  final T value;
}

class _ParagraphBuilder {
  final StringBuffer _buffer = StringBuffer();
  final List<AstStyleSpan> styles = <AstStyleSpan>[];
  final List<AstInlineInsert> inserts = <AstInlineInsert>[];
  final List<AstRubySpan> rubies = <AstRubySpan>[];
  final List<AstParagraphExtra> extras = <AstParagraphExtra>[];
  final List<AstRange> tcyRanges = <AstRange>[];
  final List<AstChapterIndex> chapterIndexes = <AstChapterIndex>[];

  final List<_OpenSpan<AstAttachedText>> _attached =
      <_OpenSpan<AstAttachedText>>[];
  final List<_OpenSpan<AstTextStyle>> _styled = <_OpenSpan<AstTextStyle>>[];
  final List<_OpenSpan<AstHeading>> _headings = <_OpenSpan<AstHeading>>[];
  final List<_OpenSpan<AstCaption>> _captions = <_OpenSpan<AstCaption>>[];
  final List<_OpenSpan<AstLink>> _links = <_OpenSpan<AstLink>>[];
  final List<_OpenSpan<AstInlineDecoration>> _decorations =
      <_OpenSpan<AstInlineDecoration>>[];

  String get text => _buffer.toString();

  void appendText(String text) {
    _buffer.write(text);
  }

  void appendWarichuNewLine() {
    _buffer.write('［＃改行］');
  }

  void appendInlineMarker(String text, LayoutInlineDecorationKind kind) {
    final currentLength = this.text.length;
    final previous = currentLength > 0 ? this.text[currentLength - 1] : null;
    var startIndex = currentLength;
    if (previous == '￼') {
      startIndex = currentLength - 1;
    } else {
      _buffer.write('⁠￼');
      startIndex = currentLength + 1;
    }
    inserts.add(
      AstInlineInsert(startIndex: startIndex, text: text, type: kind),
    );
  }

  void appendImage(AstImage image) {
    final start = text.length;
    _buffer.write('￼');
    extras.add(
      AstParagraphExtra(
        kind: image.description == '外字'
            ? AstParagraphExtraKind.outsideImage
            : AstParagraphExtraKind.inlineImage,
        startIndex: start,
        endIndex: start + 1,
        imagePath: image.fileName,
        imageWidth: image.size?.width.toDouble(),
        imageHeight: image.size?.height.toDouble(),
      ),
    );
  }

  void handleAttachedText(
    AstAttachedText token,
    _CompiledInlineContent compiled,
  ) {
    if (token.boundary == AstRangeBoundary.start) {
      _attached.add(_OpenSpan<AstAttachedText>(text.length, token));
      return;
    }
    final index = _attached.lastIndexWhere(
      (entry) =>
          entry.value.role == token.role && entry.value.side == token.side,
    );
    if (index < 0) {
      return;
    }
    final open = _attached.removeAt(index);
    rubies.add(
      AstRubySpan(
        startIndex: open.startIndex,
        endIndex: text.length,
        ruby: compiled.text,
        spans: compiled.spans,
        type: token.side == AstTextSide.left
            ? LayoutInlineDecorationKind.leftRuby
            : LayoutInlineDecorationKind.rightRuby,
      ),
    );
  }

  void handleStyledText(AstStyledText token) {
    if (token.boundary == AstRangeBoundary.start) {
      _styled.add(_OpenSpan<AstTextStyle>(text.length, token.style));
      return;
    }
    final index = _styled.lastIndexWhere(
      (entry) => entry.value.runtimeType == token.style.runtimeType,
    );
    if (index < 0) {
      return;
    }
    final open = _styled.removeAt(index);
    _closeStyled(open.startIndex, text.length, token.style);
  }

  void handleHeading(AstHeading token) {
    if (token.boundary == AstRangeBoundary.start) {
      _headings.add(_OpenSpan<AstHeading>(text.length, token));
      return;
    }
    final index = _headings.lastIndexWhere(
      (entry) => entry.value.level == token.level,
    );
    if (index < 0) {
      return;
    }
    final open = _headings.removeAt(index);
    final kind = switch (token.level) {
      AstHeadingLevel.large => AstStyleKind.headingLarge,
      AstHeadingLevel.medium => AstStyleKind.headingMedium,
      AstHeadingLevel.small => AstStyleKind.headingSmall,
    };
    styles.add(
      AstStyleSpan(
        startIndex: open.startIndex,
        endIndex: text.length,
        kind: kind,
      ),
    );
    chapterIndexes.add(
      AstChapterIndex(
        startIndex: open.startIndex,
        endIndex: text.length,
        kind: switch (token.level) {
          AstHeadingLevel.large => AstChapterKind.large,
          AstHeadingLevel.medium => AstChapterKind.medium,
          AstHeadingLevel.small => AstChapterKind.small,
        },
      ),
    );
  }

  void handleCaption(AstCaption token) {
    if (token.boundary == AstRangeBoundary.start) {
      _captions.add(_OpenSpan<AstCaption>(text.length, token));
      return;
    }
    if (_captions.isEmpty) {
      return;
    }
    final open = _captions.removeLast();
    styles.add(
      AstStyleSpan(
        startIndex: open.startIndex,
        endIndex: text.length,
        kind: AstStyleKind.caption,
      ),
    );
  }

  void handleLink(AstLink token) {
    if (token.boundary == AstRangeBoundary.start) {
      _links.add(_OpenSpan<AstLink>(text.length, token));
      return;
    }
    if (_links.isEmpty) {
      return;
    }
    final open = _links.removeLast();
    final target = token.target ?? open.value.target;
    if (target == null || target.isEmpty || open.startIndex >= text.length) {
      return;
    }
    extras.add(
      AstParagraphExtra(
        kind: AstParagraphExtraKind.link,
        startIndex: open.startIndex,
        endIndex: text.length,
        linkTarget: target,
      ),
    );
  }

  void handleInlineDecoration(AstInlineDecoration token) {
    if (token.boundary == AstRangeBoundary.start) {
      _decorations.add(_OpenSpan<AstInlineDecoration>(text.length, token));
      return;
    }
    final index = _decorations.lastIndexWhere(
      (entry) => entry.value.kind == token.kind,
    );
    if (index < 0) {
      return;
    }
    final open = _decorations.removeAt(index);
    switch (token.kind) {
      case AstInlineDecorationKind.tatechuyoko:
        tcyRanges.add(
          AstRange(startIndex: open.startIndex, endIndex: text.length),
        );
      case AstInlineDecorationKind.lineRightSmall:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.lineRightSmall,
          ),
        );
      case AstInlineDecorationKind.lineLeftSmall:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.lineLeftSmall,
          ),
        );
      case AstInlineDecorationKind.superscript:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.superscript,
          ),
        );
      case AstInlineDecorationKind.subscript:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.subscript,
          ),
        );
      case AstInlineDecorationKind.keigakomi:
        extras.add(
          AstParagraphExtra(
            kind: AstParagraphExtraKind.span,
            startIndex: open.startIndex,
            endIndex: text.length,
            ruledLineKind: AstRuledLineKind.frameBox,
          ),
        );
      case AstInlineDecorationKind.yokogumi:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.yokogumi,
          ),
        );
      case AstInlineDecorationKind.warichu:
        _replaceWithWarichu(open.startIndex, text.length);
    }
  }

  void handleUnsupported(String raw) {
    final bodyMatch = RegExp(r'^［＃(.*)］$').firstMatch(raw);
    final body = bodyMatch?[1] ?? raw;

    final anchor = RegExp(r'^アンカー：(.+)$').firstMatch(body);
    if (anchor != null) {
      chapterIndexes.add(
        AstChapterIndex(
          startIndex: text.isEmpty ? 0 : text.length - 1,
          endIndex: text.length,
          kind: AstChapterKind.anchor,
          anchorName: anchor[1]!,
        ),
      );
      return;
    }

    final link = RegExp(r'^リンク：(.+)$').firstMatch(body);
    if (link != null) {
      final start = text.length;
      _buffer.write('◀');
      extras.add(
        AstParagraphExtra(
          kind: AstParagraphExtraKind.link,
          startIndex: start,
          endIndex: start + 1,
          linkTarget: link[1]!,
        ),
      );
      return;
    }

    extras.add(
      AstParagraphExtra(
        kind: AstParagraphExtraKind.note,
        startIndex: text.isEmpty ? 0 : text.length - 1,
        endIndex: text.length,
        noteText: body,
      ),
    );
  }

  void applyAutoLinks() {
    final matches = RegExp(
      r"https?:\/\/[-_.!~*'()a-zA-Z0-9;\/?:@&=+$,%#]+",
    ).allMatches(text);
    for (final match in matches) {
      extras.add(
        AstParagraphExtra(
          kind: AstParagraphExtraKind.link,
          startIndex: match.start,
          endIndex: match.end,
          linkTarget: match.group(0),
        ),
      );
    }
  }

  void _closeStyled(int startIndex, int endIndex, AstTextStyle style) {
    switch (style) {
      case AstBoutenStyle(kind: final kind, side: final side):
        extras.add(
          AstParagraphExtra(
            kind: AstParagraphExtraKind.emphasis,
            startIndex: startIndex,
            endIndex: endIndex,
            emphasisKind: switch (kind) {
              AstBoutenKind.sesame => AstEmphasisKind.sesame,
              AstBoutenKind.whiteSesame => AstEmphasisKind.whiteSesame,
              AstBoutenKind.blackCircle => AstEmphasisKind.blackCircle,
              AstBoutenKind.whiteCircle => AstEmphasisKind.whiteCircle,
              AstBoutenKind.blackTriangle => AstEmphasisKind.blackTriangle,
              AstBoutenKind.whiteTriangle => AstEmphasisKind.whiteTriangle,
              AstBoutenKind.bullseye => AstEmphasisKind.bullseye,
              AstBoutenKind.fisheye => AstEmphasisKind.fisheye,
              AstBoutenKind.saltire => AstEmphasisKind.saltire,
            },
            rightSide: side == AstTextSide.right,
          ),
        );
      case AstBosenStyle(kind: final kind, side: final side):
        extras.add(
          AstParagraphExtra(
            kind: AstParagraphExtraKind.span,
            startIndex: startIndex,
            endIndex: endIndex,
            ruledLineKind: switch (kind) {
              AstBosenKind.solid => AstRuledLineKind.solid,
              AstBosenKind.doubleLine => AstRuledLineKind.doubleLine,
              AstBosenKind.chain => AstRuledLineKind.chain,
              AstBosenKind.dashed => AstRuledLineKind.dashed,
              AstBosenKind.wave => AstRuledLineKind.wave,
              AstBosenKind.cancel => AstRuledLineKind.cancel,
            },
            rightSide: side == AstTextSide.right,
          ),
        );
      case AstFontStyleAnnotation(style: final fontStyle):
        styles.add(
          AstStyleSpan(
            startIndex: startIndex,
            endIndex: endIndex,
            kind: fontStyle == AstFontStyle.bold
                ? AstStyleKind.bold
                : AstStyleKind.italic,
          ),
        );
      case AstFontScaleStyle(direction: final direction, steps: final steps):
        styles.add(
          AstStyleSpan(
            startIndex: startIndex,
            endIndex: endIndex,
            kind: AstStyleKind.fontScale,
            fontScaleDirection: direction,
            fontScaleSteps: steps,
          ),
        );
      case AstTextColorStyle(colorValue: final colorValue):
        styles.add(
          AstStyleSpan(
            startIndex: startIndex,
            endIndex: endIndex,
            kind: AstStyleKind.textColor,
            colorValue: colorValue,
          ),
        );
    }
  }

  void _replaceWithWarichu(int startIndex, int endIndex) {
    if (endIndex <= startIndex) {
      return;
    }
    final original = text.substring(startIndex, endIndex);
    final placeholderLength = splitWarichuText(original).placeholderLength;
    final replacement = '（${'　' * placeholderLength}）';
    final delta = replacement.length - (endIndex - startIndex);

    final before = text.substring(0, startIndex);
    final after = text.substring(endIndex);
    _buffer
      ..clear()
      ..write(before)
      ..write(replacement)
      ..write(after);

    _shiftRanges(startIndex, delta);
    styles.add(
      AstStyleSpan(
        startIndex: startIndex,
        endIndex: startIndex + 1,
        kind: AstStyleKind.warichuBracket,
      ),
    );
    styles.add(
      AstStyleSpan(
        startIndex: startIndex + 1,
        endIndex: startIndex + replacement.length - 1,
        kind: AstStyleKind.warichuPlaceholder,
      ),
    );
    styles.add(
      AstStyleSpan(
        startIndex: startIndex + replacement.length - 1,
        endIndex: startIndex + replacement.length,
        kind: AstStyleKind.warichuBracket,
      ),
    );
    extras.add(
      AstParagraphExtra(
        kind: AstParagraphExtraKind.warichu,
        startIndex: startIndex,
        endIndex: startIndex + replacement.length,
        warichuText: original,
      ),
    );
  }

  void _shiftRanges(int pivot, int delta) {
    if (delta == 0) {
      return;
    }
    void shiftStyle(AstStyleSpan style) {
      if (style.startIndex >= pivot) {
        // ignore, rebuilt by caller when needed
      }
    }

    for (var index = 0; index < styles.length; index += 1) {
      final span = styles[index];
      styles[index] = AstStyleSpan(
        startIndex: span.startIndex >= pivot
            ? span.startIndex + delta
            : span.startIndex,
        endIndex: span.endIndex >= pivot
            ? span.endIndex + delta
            : span.endIndex,
        kind: span.kind,
        colorValue: span.colorValue,
        fontScaleDirection: span.fontScaleDirection,
        fontScaleSteps: span.fontScaleSteps,
      );
      shiftStyle(styles[index]);
    }

    for (var index = 0; index < inserts.length; index += 1) {
      final insert = inserts[index];
      inserts[index] = AstInlineInsert(
        startIndex: insert.startIndex >= pivot
            ? insert.startIndex + delta
            : insert.startIndex,
        text: insert.text,
        type: insert.type,
      );
    }

    for (var index = 0; index < rubies.length; index += 1) {
      final ruby = rubies[index];
      rubies[index] = AstRubySpan(
        startIndex: ruby.startIndex >= pivot
            ? ruby.startIndex + delta
            : ruby.startIndex,
        endIndex: ruby.endIndex >= pivot
            ? ruby.endIndex + delta
            : ruby.endIndex,
        ruby: ruby.ruby,
        spans: ruby.spans
            .map(
              (span) => AstStyleSpan(
                startIndex: span.startIndex >= pivot
                    ? span.startIndex + delta
                    : span.startIndex,
                endIndex: span.endIndex >= pivot
                    ? span.endIndex + delta
                    : span.endIndex,
                kind: span.kind,
                colorValue: span.colorValue,
                fontScaleDirection: span.fontScaleDirection,
                fontScaleSteps: span.fontScaleSteps,
              ),
            )
            .toList(growable: false),
        type: ruby.type,
      );
    }

    for (var index = 0; index < extras.length; index += 1) {
      final extra = extras[index];
      extras[index] = AstParagraphExtra(
        kind: extra.kind,
        startIndex: extra.startIndex != null && extra.startIndex! >= pivot
            ? extra.startIndex! + delta
            : extra.startIndex,
        endIndex: extra.endIndex != null && extra.endIndex! >= pivot
            ? extra.endIndex! + delta
            : extra.endIndex,
        frameKind: extra.frameKind,
        imagePath: extra.imagePath,
        imageWidth: extra.imageWidth,
        imageHeight: extra.imageHeight,
        linkTarget: extra.linkTarget,
        ruledLineKind: extra.ruledLineKind,
        emphasisKind: extra.emphasisKind,
        rightSide: extra.rightSide,
        noteText: extra.noteText,
        warichuText: extra.warichuText,
      );
    }

    for (var index = 0; index < tcyRanges.length; index += 1) {
      final range = tcyRanges[index];
      tcyRanges[index] = AstRange(
        startIndex: range.startIndex >= pivot
            ? range.startIndex + delta
            : range.startIndex,
        endIndex: range.endIndex >= pivot
            ? range.endIndex + delta
            : range.endIndex,
      );
    }

    for (var index = 0; index < chapterIndexes.length; index += 1) {
      final chapter = chapterIndexes[index];
      chapterIndexes[index] = AstChapterIndex(
        startIndex: chapter.startIndex >= pivot
            ? chapter.startIndex + delta
            : chapter.startIndex,
        endIndex: chapter.endIndex >= pivot
            ? chapter.endIndex + delta
            : chapter.endIndex,
        kind: chapter.kind,
        anchorName: chapter.anchorName,
      );
    }
  }
}
