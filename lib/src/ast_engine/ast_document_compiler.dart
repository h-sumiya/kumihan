import '../engine/constants.dart';
import '../engine/generated/gaiji_table.dart';
import '../engine/layout_primitives.dart';
import '../parsers/aozora/ast.dart';

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
  final AozoraBottomAlignKind? bottomAlignKind;
  final int bottomAlignOffset;
  final AozoraHeadingLevel? headingLevel;
  final AozoraFontScaleDirection? fontScaleDirection;
  final int? fontScaleSteps;
  final int? jizumeWidth;
  final AozoraPageBreakKind? pageBreakKind;
}

enum AstStyleKind {
  headingLarge,
  headingMedium,
  headingSmall,
  bold,
  italic,
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
    this.fontScaleDirection,
    this.fontScaleSteps,
  });

  final int startIndex;
  final int endIndex;
  final AstStyleKind kind;
  final AozoraFontScaleDirection? fontScaleDirection;
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

AstCompiledDocument compileAozoraAst(AozoraData data) {
  return _AstDocumentCompiler(data).compile();
}

class _AstDocumentCompiler {
  _AstDocumentCompiler(this.data);

  final AozoraData data;
  final List<AstCompiledEntry> _entries = <AstCompiledEntry>[];

  AstCompiledDocument compile() {
    final lineTokens = <AozoraToken>[];
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
      if (token is AozoraNewLine) {
        flushLine();
        continue;
      }
      if (token is AozoraDocumentRemark) {
        lineTokens.add(AozoraText(_remarkText(token)));
        continue;
      }
      if (token is AozoraBodyEnd) {
        lineTokens.add(AozoraUnsupportedAnnotation('［＃本文終わり］'));
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
    List<AozoraToken> sourceLine, {
    required bool nonBreak,
  }) {
    final line = List<AozoraToken>.from(sourceLine);
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
          token is AozoraBottomAlign &&
          token.scope == AozoraBottomAlignScope.inlineTail,
    );
    if (splitIndex >= 0) {
      final leadingTokens = line.sublist(0, splitIndex);
      final tailAlign = line[splitIndex] as AozoraBottomAlign;
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
            forcedBottomMargin: tailAlign.kind == AozoraBottomAlignKind.bottom
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
    List<AozoraToken> sourceLine, {
    required bool nonBreak,
    bool forcedAlignBottom = false,
    double forcedBottomMargin = 0,
  }) {
    final line = List<AozoraToken>.from(sourceLine);
    var firstTopMargin = 0.0;
    var restTopMargin = 0.0;
    var bottomMargin = forcedBottomMargin;
    var alignBottom = forcedAlignBottom;

    while (line.isNotEmpty) {
      final token = line.first;
      if (token case AozoraIndent(kind: AozoraIndentKind.singleLine)) {
        final margin = token.lineIndent.toDouble();
        firstTopMargin = margin;
        restTopMargin = token.hangingIndent?.toDouble() ?? margin;
        line.removeAt(0);
        continue;
      }
      if (!forcedAlignBottom &&
          token is AozoraBottomAlign &&
          token.scope == AozoraBottomAlignScope.singleLine) {
        final kind = token.kind;
        final offset = token.offset;
        alignBottom = true;
        bottomMargin = kind == AozoraBottomAlignKind.bottom
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

  AstCompiledEntry? _consumeStandaloneCommand(AozoraToken token) {
    return switch (token) {
      AozoraIndent(
        kind: AozoraIndentKind.block,
        boundary: AozoraRangeBoundary.blockStart,
        lineIndent: final lineIndent,
        hangingIndent: final hangingIndent,
      ) =>
        AstCommandEntry(
          kind: AstCommandKind.indentStart,
          indentLine: lineIndent,
          indentHanging: hangingIndent,
        ),
      AozoraIndent(
        kind: AozoraIndentKind.block,
        boundary: AozoraRangeBoundary.blockEnd,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.indentEnd),
      AozoraBottomAlign(
        scope: AozoraBottomAlignScope.block,
        boundary: AozoraRangeBoundary.blockStart,
        kind: final kind,
        offset: final offset,
      ) =>
        AstCommandEntry(
          kind: AstCommandKind.bottomAlignStart,
          bottomAlignKind: kind,
          bottomAlignOffset: offset,
        ),
      AozoraBottomAlign(
        scope: AozoraBottomAlignScope.block,
        boundary: AozoraRangeBoundary.blockEnd,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.bottomAlignEnd),
      AozoraJizume(
        boundary: AozoraRangeBoundary.blockStart,
        width: final width,
      ) =>
        AstCommandEntry(kind: AstCommandKind.jizumeStart, jizumeWidth: width),
      AozoraJizume(boundary: AozoraRangeBoundary.blockEnd) =>
        const AstCommandEntry(kind: AstCommandKind.jizumeEnd),
      AozoraStyledText(
        boundary: AozoraRangeBoundary.blockStart,
        style: AozoraFontStyleAnnotation(style: AozoraFontStyle.bold),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.boldStart),
      AozoraStyledText(
        boundary: AozoraRangeBoundary.blockEnd,
        style: AozoraFontStyleAnnotation(style: AozoraFontStyle.bold),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.boldEnd),
      AozoraStyledText(
        boundary: AozoraRangeBoundary.blockStart,
        style: AozoraFontStyleAnnotation(style: AozoraFontStyle.italic),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.italicStart),
      AozoraStyledText(
        boundary: AozoraRangeBoundary.blockEnd,
        style: AozoraFontStyleAnnotation(style: AozoraFontStyle.italic),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.italicEnd),
      AozoraStyledText(
        boundary: AozoraRangeBoundary.blockStart,
        style: AozoraFontScaleStyle(
          direction: final direction,
          steps: final steps,
        ),
      ) =>
        AstCommandEntry(
          kind: AstCommandKind.fontScaleStart,
          fontScaleDirection: direction,
          fontScaleSteps: steps,
        ),
      AozoraStyledText(
        boundary: AozoraRangeBoundary.blockEnd,
        style: AozoraFontScaleStyle(),
      ) =>
        const AstCommandEntry(kind: AstCommandKind.fontScaleEnd),
      AozoraHeading(
        boundary: AozoraRangeBoundary.blockStart,
        level: final level,
      ) =>
        AstCommandEntry(kind: AstCommandKind.headingStart, headingLevel: level),
      AozoraHeading(boundary: AozoraRangeBoundary.blockEnd) =>
        const AstCommandEntry(kind: AstCommandKind.headingEnd),
      AozoraCaption(boundary: AozoraRangeBoundary.blockStart) =>
        const AstCommandEntry(kind: AstCommandKind.captionStart),
      AozoraCaption(boundary: AozoraRangeBoundary.blockEnd) =>
        const AstCommandEntry(kind: AstCommandKind.captionEnd),
      AozoraInlineDecoration(
        boundary: AozoraRangeBoundary.blockStart,
        kind: AozoraInlineDecorationKind.yokogumi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.yokogumiStart),
      AozoraInlineDecoration(
        boundary: AozoraRangeBoundary.blockEnd,
        kind: AozoraInlineDecorationKind.yokogumi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.yokogumiEnd),
      AozoraInlineDecoration(
        boundary: AozoraRangeBoundary.blockStart,
        kind: AozoraInlineDecorationKind.keigakomi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.frameStart),
      AozoraInlineDecoration(
        boundary: AozoraRangeBoundary.blockEnd,
        kind: AozoraInlineDecorationKind.keigakomi,
      ) =>
        const AstCommandEntry(kind: AstCommandKind.frameEnd),
      AozoraPageBreak(kind: final kind) => AstCommandEntry(
        kind: AstCommandKind.pageBreak,
        pageBreakKind: kind,
      ),
      AozoraPageCenter() => const AstCommandEntry(
        kind: AstCommandKind.pageCenter,
      ),
      _ => null,
    };
  }

  void _emitToken(_ParagraphBuilder builder, AozoraToken token) {
    switch (token) {
      case AozoraText():
        builder.appendText(_normalizePlainText(token.text));
      case AozoraAccentDecomposition():
        builder.appendText(_convertAccent(token.text));
      case AozoraGaiji():
        _emitGaiji(builder, token);
      case AozoraTateTen():
        builder.appendInlineMarker('―', LayoutInlineDecorationKind.naka);
      case AozoraKaeriten():
        builder.appendInlineMarker(
          _kaeritenText(token),
          LayoutInlineDecorationKind.kaeri,
        );
      case AozoraKuntenOkurigana():
        builder.appendInlineMarker(
          _compileInlineContent(token.content).text,
          LayoutInlineDecorationKind.okuri,
        );
      case AozoraAttachedText():
        builder.handleAttachedText(token, _compileInlineContent(token.content));
      case AozoraStyledText():
        builder.handleStyledText(token);
      case AozoraHeading():
        builder.handleHeading(token);
      case AozoraCaption():
        builder.handleCaption(token);
      case AozoraInlineDecoration():
        builder.handleInlineDecoration(token);
      case AozoraImage():
        builder.appendImage(token);
      case AozoraUnsupportedAnnotation():
        builder.handleUnsupported(token.raw);
      case AozoraWarichuNewLine():
        builder.appendWarichuNewLine();
      case AozoraIndent():
      case AozoraBottomAlign():
      case AozoraJizume():
      case AozoraPageBreak():
      case AozoraPageCenter():
      case AozoraBodyEnd():
      case AozoraDocumentRemark():
      case AozoraNewLine():
        builder.handleUnsupported(_rawForToken(token));
    }
  }

  void _emitGaiji(_ParagraphBuilder builder, AozoraGaiji gaiji) {
    switch (gaiji.kind) {
      case AozoraGaijiKind.jisX0213:
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
      case AozoraGaijiKind.unicode:
        final codePoint = gaiji.unicodeCodePoint;
        if (codePoint != null) {
          builder.appendText(String.fromCharCode(codePoint));
          return;
        }
      case AozoraGaijiKind.missingUnicode:
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

  _CompiledInlineContent _compileInlineContent(AozoraInlineContent? content) {
    if (content == null || content.isEmpty) {
      return const _CompiledInlineContent(text: '', spans: <AstStyleSpan>[]);
    }
    final builder = _ParagraphBuilder();
    for (final node in content) {
      switch (node) {
        case AozoraText():
          builder.appendText(_normalizePlainText(node.text));
        case AozoraAccentDecomposition():
          builder.appendText(_convertAccent(node.text));
        case AozoraGaiji():
          _emitGaiji(builder, node);
        case AozoraTateTen():
          builder.appendInlineMarker('―', LayoutInlineDecorationKind.naka);
        case AozoraKaeriten():
          builder.appendInlineMarker(
            _kaeritenText(node),
            LayoutInlineDecorationKind.kaeri,
          );
        case AozoraKuntenOkurigana():
          builder.appendInlineMarker(
            _compileInlineContent(node.content).text,
            LayoutInlineDecorationKind.okuri,
          );
        case AozoraWarichuNewLine():
          builder.appendText('［＃改行］');
        case AozoraAttachedText():
        case AozoraStyledText():
        case AozoraHeading():
        case AozoraCaption():
        case AozoraInlineDecoration():
        case AozoraUnsupportedAnnotation():
        case AozoraImage():
        case AozoraNewLine():
        case AozoraBodyEnd():
        case AozoraDocumentRemark():
        case AozoraIndent():
        case AozoraBottomAlign():
        case AozoraJizume():
        case AozoraPageBreak():
        case AozoraPageCenter():
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

  String _kaeritenText(AozoraKaeriten token) {
    const map = <AozoraKaeritenPrimary, String>{
      AozoraKaeritenPrimary.ichi: '一',
      AozoraKaeritenPrimary.ni: '二',
      AozoraKaeritenPrimary.san: '三',
      AozoraKaeritenPrimary.yon: '四',
      AozoraKaeritenPrimary.jou: '上',
      AozoraKaeritenPrimary.chuu: '中',
      AozoraKaeritenPrimary.ge: '下',
      AozoraKaeritenPrimary.kou: '甲',
      AozoraKaeritenPrimary.otsu: '乙',
      AozoraKaeritenPrimary.hei: '丙',
      AozoraKaeritenPrimary.ten: '天',
      AozoraKaeritenPrimary.chi: '地',
      AozoraKaeritenPrimary.jin: '人',
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

  String _gaijiBody(AozoraGaiji gaiji) {
    switch (gaiji.kind) {
      case AozoraGaijiKind.jisX0213:
        return '「${gaiji.description}」、第${gaiji.jisLevel}水準'
            '${gaiji.jisCode?.plane}-${gaiji.jisCode?.row}-${gaiji.jisCode?.cell}';
      case AozoraGaijiKind.unicode:
        return '「${gaiji.description}」、U+${gaiji.unicodeCodePoint?.toRadixString(16).toUpperCase()}'
            '、${gaiji.printPosition?.page}-${gaiji.printPosition?.line}';
      case AozoraGaijiKind.missingUnicode:
        return '「${gaiji.description}」、${gaiji.printPosition?.page}-${gaiji.printPosition?.line}';
    }
  }

  String _remarkText(AozoraDocumentRemark remark) {
    return switch (remark.kind) {
      AozoraDocumentRemarkKind.baseTextIsHorizontal => '※底本は横組みです。',
      AozoraDocumentRemarkKind.omittedLowerHeadingLevels =>
        '※小見出しよりもさらに下位の見出しには、注記しませんでした。',
      AozoraDocumentRemarkKind.madoHeadingLineCount =>
        '※窓見出しは、${remark.value}行どりです。',
      AozoraDocumentRemarkKind.replacedOuterKikkouWithSquareBrackets =>
        '※底本の「〔〕」を「［］」に置き換えました。',
    };
  }

  String _rawForToken(AozoraToken token) {
    return switch (token) {
      AozoraIndent(
        kind: AozoraIndentKind.singleLine,
        lineIndent: final lineIndent,
      ) =>
        '［＃$lineIndent字下げ］',
      AozoraBottomAlign(
        kind: AozoraBottomAlignKind.bottom,
        scope: AozoraBottomAlignScope.inlineTail,
      ) =>
        '［＃地付き］',
      AozoraBottomAlign(
        kind: AozoraBottomAlignKind.raisedFromBottom,
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

  final List<_OpenSpan<AozoraAttachedText>> _attached =
      <_OpenSpan<AozoraAttachedText>>[];
  final List<_OpenSpan<AozoraTextStyle>> _styled =
      <_OpenSpan<AozoraTextStyle>>[];
  final List<_OpenSpan<AozoraHeading>> _headings = <_OpenSpan<AozoraHeading>>[];
  final List<_OpenSpan<AozoraCaption>> _captions = <_OpenSpan<AozoraCaption>>[];
  final List<_OpenSpan<AozoraInlineDecoration>> _decorations =
      <_OpenSpan<AozoraInlineDecoration>>[];

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

  void appendImage(AozoraImage image) {
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
    AozoraAttachedText token,
    _CompiledInlineContent compiled,
  ) {
    if (token.boundary == AozoraRangeBoundary.start) {
      _attached.add(_OpenSpan<AozoraAttachedText>(text.length, token));
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
        type: token.side == AozoraTextSide.left
            ? LayoutInlineDecorationKind.leftRuby
            : LayoutInlineDecorationKind.rightRuby,
      ),
    );
  }

  void handleStyledText(AozoraStyledText token) {
    if (token.boundary == AozoraRangeBoundary.start) {
      _styled.add(_OpenSpan<AozoraTextStyle>(text.length, token.style));
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

  void handleHeading(AozoraHeading token) {
    if (token.boundary == AozoraRangeBoundary.start) {
      _headings.add(_OpenSpan<AozoraHeading>(text.length, token));
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
      AozoraHeadingLevel.large => AstStyleKind.headingLarge,
      AozoraHeadingLevel.medium => AstStyleKind.headingMedium,
      AozoraHeadingLevel.small => AstStyleKind.headingSmall,
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
          AozoraHeadingLevel.large => AstChapterKind.large,
          AozoraHeadingLevel.medium => AstChapterKind.medium,
          AozoraHeadingLevel.small => AstChapterKind.small,
        },
      ),
    );
  }

  void handleCaption(AozoraCaption token) {
    if (token.boundary == AozoraRangeBoundary.start) {
      _captions.add(_OpenSpan<AozoraCaption>(text.length, token));
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

  void handleInlineDecoration(AozoraInlineDecoration token) {
    if (token.boundary == AozoraRangeBoundary.start) {
      _decorations.add(_OpenSpan<AozoraInlineDecoration>(text.length, token));
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
      case AozoraInlineDecorationKind.tatechuyoko:
        tcyRanges.add(
          AstRange(startIndex: open.startIndex, endIndex: text.length),
        );
      case AozoraInlineDecorationKind.lineRightSmall:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.lineRightSmall,
          ),
        );
      case AozoraInlineDecorationKind.lineLeftSmall:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.lineLeftSmall,
          ),
        );
      case AozoraInlineDecorationKind.superscript:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.superscript,
          ),
        );
      case AozoraInlineDecorationKind.subscript:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.subscript,
          ),
        );
      case AozoraInlineDecorationKind.keigakomi:
        extras.add(
          AstParagraphExtra(
            kind: AstParagraphExtraKind.span,
            startIndex: open.startIndex,
            endIndex: text.length,
            ruledLineKind: AstRuledLineKind.frameBox,
          ),
        );
      case AozoraInlineDecorationKind.yokogumi:
        styles.add(
          AstStyleSpan(
            startIndex: open.startIndex,
            endIndex: text.length,
            kind: AstStyleKind.yokogumi,
          ),
        );
      case AozoraInlineDecorationKind.warichu:
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

  void _closeStyled(int startIndex, int endIndex, AozoraTextStyle style) {
    switch (style) {
      case AozoraBoutenStyle(kind: final kind, side: final side):
        extras.add(
          AstParagraphExtra(
            kind: AstParagraphExtraKind.emphasis,
            startIndex: startIndex,
            endIndex: endIndex,
            emphasisKind: switch (kind) {
              AozoraBoutenKind.sesame => AstEmphasisKind.sesame,
              AozoraBoutenKind.whiteSesame => AstEmphasisKind.whiteSesame,
              AozoraBoutenKind.blackCircle => AstEmphasisKind.blackCircle,
              AozoraBoutenKind.whiteCircle => AstEmphasisKind.whiteCircle,
              AozoraBoutenKind.blackTriangle => AstEmphasisKind.blackTriangle,
              AozoraBoutenKind.whiteTriangle => AstEmphasisKind.whiteTriangle,
              AozoraBoutenKind.bullseye => AstEmphasisKind.bullseye,
              AozoraBoutenKind.fisheye => AstEmphasisKind.fisheye,
              AozoraBoutenKind.saltire => AstEmphasisKind.saltire,
            },
            rightSide: side == AozoraTextSide.right,
          ),
        );
      case AozoraBosenStyle(kind: final kind, side: final side):
        extras.add(
          AstParagraphExtra(
            kind: AstParagraphExtraKind.span,
            startIndex: startIndex,
            endIndex: endIndex,
            ruledLineKind: switch (kind) {
              AozoraBosenKind.solid => AstRuledLineKind.solid,
              AozoraBosenKind.doubleLine => AstRuledLineKind.doubleLine,
              AozoraBosenKind.chain => AstRuledLineKind.chain,
              AozoraBosenKind.dashed => AstRuledLineKind.dashed,
              AozoraBosenKind.wave => AstRuledLineKind.wave,
              AozoraBosenKind.cancel => AstRuledLineKind.cancel,
            },
            rightSide: side == AozoraTextSide.right,
          ),
        );
      case AozoraFontStyleAnnotation(style: final fontStyle):
        styles.add(
          AstStyleSpan(
            startIndex: startIndex,
            endIndex: endIndex,
            kind: fontStyle == AozoraFontStyle.bold
                ? AstStyleKind.bold
                : AstStyleKind.italic,
          ),
        );
      case AozoraFontScaleStyle(direction: final direction, steps: final steps):
        styles.add(
          AstStyleSpan(
            startIndex: startIndex,
            endIndex: endIndex,
            kind: AstStyleKind.fontScale,
            fontScaleDirection: direction,
            fontScaleSteps: steps,
          ),
        );
    }
  }

  void _replaceWithWarichu(int startIndex, int endIndex) {
    if (endIndex <= startIndex) {
      return;
    }
    final original = text.substring(startIndex, endIndex);
    final placeholderLength = (original.length + 1) ~/ 2;
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
