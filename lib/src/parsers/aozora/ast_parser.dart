import 'ast.dart';

class AozoraAstParser {
  const AozoraAstParser();

  AozoraData parse(String input) {
    return _AozoraInlineParser(
      input.replaceAll(RegExp(r'(\r\n|\r)'), '\n'),
    ).parse();
  }
}

class _AozoraInlineParser {
  _AozoraInlineParser(this.source);

  final String source;
  final List<_OpenStyleEntry> _openStyles = <_OpenStyleEntry>[];
  static final RegExp _rubyBaseIgnorablePattern = RegExp(
    r'[\s、。，．,.「」『』（）()［］【】〈〉《》!?！？…―ー]',
  );
  static final RegExp _rubyHiraganaPattern = RegExp(r'[ぁ-んゝゞ]');
  static final RegExp _rubyKatakanaPattern = RegExp(r'[ァ-ンーヽヾヴ]');
  static final RegExp _rubyKanjiPattern = RegExp(
    r'[\u3400-\u9FFF\uF900-\uFAFF々〆〇ヶ]',
  );
  static final RegExp _rubyLatinPattern = RegExp(
    r"[A-Za-z0-9０-９Ａ-Ｚａ-ｚΑ-Ωα-ωА-Яа-я]",
  );

  AozoraData parse() {
    final tokens = <AozoraToken>[];
    var index = 0;
    var explicitRubyStartIndex = -1;

    while (index < source.length) {
      if (_isAtLineStart(tokens)) {
        explicitRubyStartIndex = -1;
        final remark = _tryParseDocumentRemark(index);
        if (remark != null) {
          tokens.add(remark.token);
          index = remark.nextIndex;
          continue;
        }
      }

      if (source.startsWith('※［＃', index)) {
        final annotationEnd = _findAnnotationEnd(index + 1);
        if (annotationEnd != null) {
          final raw = source.substring(index + 1, annotationEnd + 1);
          final gaiji = _parseGaiji(raw);
          if (gaiji != null) {
            tokens.add(gaiji);
            index = annotationEnd + 1;
            continue;
          }
        }
      }

      if (source.startsWith('［＃', index)) {
        final annotationEnd = _findAnnotationEnd(index);
        if (annotationEnd == null) {
          tokens.add(AozoraText(source.substring(index)));
          break;
        }
        final raw = source.substring(index, annotationEnd + 1);
        final nextIndex = annotationEnd + 1;
        _parseAnnotation(raw, tokens);
        index = nextIndex;
        continue;
      }

      final char = source[index];
      if (char == '\n') {
        tokens.add(const AozoraNewLine());
        explicitRubyStartIndex = -1;
        index += 1;
        continue;
      }
      if (char == '｜') {
        explicitRubyStartIndex = tokens.length;
        index += 1;
        continue;
      }
      if (char == '《') {
        final rubyEnd = source.indexOf('》', index + 1);
        if (rubyEnd > index) {
          final ruby = source.substring(index + 1, rubyEnd);
          _attachRuby(tokens, ruby, explicitStartIndex: explicitRubyStartIndex);
          explicitRubyStartIndex = -1;
          index = rubyEnd + 1;
          continue;
        }
      }
      if (char == '〔') {
        final accentEnd = source.indexOf('〕', index + 1);
        if (accentEnd > index) {
          tokens.add(
            AozoraAccentDecomposition(source.substring(index + 1, accentEnd)),
          );
          index = accentEnd + 1;
          continue;
        }
      }
      if (char == '‐') {
        tokens.add(const AozoraTateTen());
        index += 1;
        continue;
      }

      final next = _findNextSpecial(index);
      tokens.add(AozoraText(source.substring(index, next)));
      index = next;
    }

    return _mergeAdjacentText(tokens);
  }

  bool _isAtLineStart(List<AozoraToken> tokens) {
    if (tokens.isEmpty) {
      return true;
    }
    return tokens.last is AozoraNewLine;
  }

  int _findNextSpecial(int start) {
    var index = start;
    while (index < source.length) {
      final char = source[index];
      if (char == '\n' ||
          char == '｜' ||
          char == '《' ||
          char == '〔' ||
          char == '‐' ||
          source.startsWith('［＃', index) ||
          source.startsWith('※［＃', index)) {
        return index;
      }
      index += 1;
    }
    return source.length;
  }

  int? _findAnnotationEnd(int start) {
    if (!source.startsWith('［＃', start)) {
      return null;
    }

    var depth = 0;
    for (var index = start; index < source.length; index += 1) {
      if (source.startsWith('［＃', index)) {
        depth += 1;
        index += 1;
        continue;
      }
      if (source[index] == '］') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }
    return null;
  }

  _RemarkResult? _tryParseDocumentRemark(int index) {
    final lineEnd = source.indexOf('\n', index);
    final end = lineEnd >= 0 ? lineEnd : source.length;
    final line = source.substring(index, end);

    if (line == '※底本は横組みです。') {
      return _RemarkResult(
        const AozoraDocumentRemark(
          kind: AozoraDocumentRemarkKind.baseTextIsHorizontal,
        ),
        end,
      );
    }
    if (line == '※小見出しよりもさらに下位の見出しには、注記しませんでした。') {
      return _RemarkResult(
        const AozoraDocumentRemark(
          kind: AozoraDocumentRemarkKind.omittedLowerHeadingLevels,
        ),
        end,
      );
    }

    final madoMatch = RegExp(r'^※窓見出しは、([０-９]+)行どりです。$').firstMatch(line);
    if (madoMatch != null) {
      return _RemarkResult(
        AozoraDocumentRemark(
          kind: AozoraDocumentRemarkKind.madoHeadingLineCount,
          value: _parseZenkakuInt(madoMatch[1]!),
        ),
        end,
      );
    }

    if (line == '※底本の「〔〕」を「［］」に置き換えました。') {
      return _RemarkResult(
        const AozoraDocumentRemark(
          kind: AozoraDocumentRemarkKind.replacedOuterKikkouWithSquareBrackets,
        ),
        end,
      );
    }

    return null;
  }

  AozoraGaiji? _parseGaiji(String raw) {
    final body = _annotationBody(raw);

    final jisMatch = RegExp(
      r'^「(.+)」、第([34])水準([0-9]+)-([0-9]+)-([0-9]+)$',
    ).firstMatch(body);
    if (jisMatch != null) {
      return AozoraGaiji(
        description: jisMatch[1]!,
        kind: AozoraGaijiKind.jisX0213,
        jisLevel: int.parse(jisMatch[2]!),
        jisCode: AozoraJisCode(
          plane: int.parse(jisMatch[3]!),
          row: int.parse(jisMatch[4]!),
          cell: int.parse(jisMatch[5]!),
        ),
      );
    }

    final unicodeMatch = RegExp(
      r'^「(.+)」、U\+([0-9A-Fa-f]+)、([0-9]+)-([0-9]+)$',
    ).firstMatch(body);
    if (unicodeMatch != null) {
      return AozoraGaiji(
        description: unicodeMatch[1]!,
        kind: AozoraGaijiKind.unicode,
        unicodeCodePoint: int.parse(unicodeMatch[2]!, radix: 16),
        printPosition: AozoraPrintPosition(
          page: int.parse(unicodeMatch[3]!),
          line: int.parse(unicodeMatch[4]!),
        ),
      );
    }

    final missingUnicode = RegExp(
      r'^「(.+)」、([0-9]+)-([0-9]+)$',
    ).firstMatch(body);
    if (missingUnicode != null) {
      return AozoraGaiji(
        description: missingUnicode[1]!,
        kind: AozoraGaijiKind.missingUnicode,
        printPosition: AozoraPrintPosition(
          page: int.parse(missingUnicode[2]!),
          line: int.parse(missingUnicode[3]!),
        ),
      );
    }

    return null;
  }

  void _parseAnnotation(String raw, List<AozoraToken> tokens) {
    final body = _annotationBody(raw);

    final kaeriten = _parseKaeriten(body);
    if (kaeriten != null) {
      tokens.add(kaeriten);
      return;
    }

    final okurigana = RegExp(r'^（(.*)）$').firstMatch(body);
    if (okurigana != null) {
      tokens.add(
        AozoraKuntenOkurigana(
          _parseNestedInlineContent(okurigana[1]!, inWarichu: true),
        ),
      );
      return;
    }

    if (body == '改行') {
      tokens.add(const AozoraWarichuNewLine());
      return;
    }

    final attachedTarget = RegExp(
      r'^「(.+)」(の左)?に「(.*)」の(ルビ|注記)$',
    ).firstMatch(body);
    if (attachedTarget != null) {
      final content = _parseNestedInlineContent(attachedTarget[3]!);
      final role = attachedTarget[4] == 'ルビ'
          ? AozoraAttachedTextRole.ruby
          : AozoraAttachedTextRole.note;
      final side = attachedTarget[2] == null
          ? AozoraTextSide.right
          : AozoraTextSide.left;
      final applied = _wrapLastMatchingText(
        tokens,
        attachedTarget[1]!,
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.start,
          role: role,
          side: side,
        ),
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.end,
          role: role,
          side: side,
          content: content,
        ),
      );
      if (!applied) {
        tokens.add(AozoraUnsupportedAnnotation(raw));
      }
      return;
    }

    final correctionNote = _parseCorrectionNote(body, tokens, raw);
    if (correctionNote) {
      return;
    }

    final startAttached = _parseAttachedTextSpanStart(body);
    if (startAttached != null) {
      tokens.add(startAttached);
      return;
    }

    final endAttached = _parseAttachedTextSpanEnd(body);
    if (endAttached != null) {
      tokens.add(endAttached);
      return;
    }

    final singleStyle = _parseSingleTargetStyle(body);
    if (singleStyle != null) {
      final applied = _wrapLastMatchingText(
        tokens,
        singleStyle.target,
        singleStyle.startToken,
        singleStyle.endToken,
      );
      if (!applied) {
        tokens.add(AozoraUnsupportedAnnotation(raw));
      }
      return;
    }

    final openStyle = _parseSpanStart(body);
    if (openStyle != null) {
      tokens.add(openStyle.token);
      _openStyles.add(openStyle.entry);
      return;
    }

    final closeStyle = _parseSpanEnd(body);
    if (closeStyle != null) {
      tokens.add(closeStyle);
      return;
    }

    final pageBreaks = <String, AozoraPageBreakKind>{
      '改丁': AozoraPageBreakKind.kaicho,
      '改ページ': AozoraPageBreakKind.kaipage,
      '改見開き': AozoraPageBreakKind.kaimihiraki,
      '改段': AozoraPageBreakKind.kaidan,
    };
    final pageBreakKind = pageBreaks[body];
    if (pageBreakKind != null) {
      tokens.add(AozoraPageBreak(pageBreakKind));
      return;
    }

    if (body == 'ページの左右中央') {
      tokens.add(const AozoraPageCenter());
      return;
    }

    final indent = _parseIndent(body, _isAtLineStart(tokens));
    if (indent != null) {
      tokens.add(indent);
      return;
    }

    final bottomAlign = _parseBottomAlign(body, _isAtLineStart(tokens));
    if (bottomAlign != null) {
      tokens.add(bottomAlign);
      return;
    }

    final jizume = _parseJizume(body);
    if (jizume != null) {
      tokens.add(jizume);
      return;
    }

    final image = _parseImage(body);
    if (image != null) {
      tokens.add(image);
      return;
    }

    if (body == '本文終わり') {
      tokens.add(const AozoraBodyEnd());
      return;
    }

    tokens.add(AozoraUnsupportedAnnotation(raw));
  }

  AozoraKaeriten? _parseKaeriten(String body) {
    final match = RegExp(
      r'^(?:([一二三四上下中甲乙丙丁天地人])?(レ)|([一二三四上下中甲乙丙丁天地人]))$',
    ).firstMatch(body);
    if (match == null) {
      return null;
    }

    final primaryText = match[1] ?? match[3];
    return AozoraKaeriten(
      primary: _kaeritenPrimaryFrom(primaryText),
      hasRe: body.contains('レ'),
    );
  }

  bool _parseCorrectionNote(String body, List<AozoraToken> tokens, String raw) {
    final mamaMatch = RegExp(r'^「(.+)」はママ$').firstMatch(body);
    if (mamaMatch != null) {
      return _wrapLastMatchingText(
        tokens,
        mamaMatch[1]!,
        const AozoraAttachedText(
          boundary: AozoraRangeBoundary.start,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
        ),
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.end,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
          content: const <AozoraInlineNode>[AozoraText('ママ')],
        ),
      );
    }

    final rubyMama = RegExp(r'^ルビの「(.+)」はママ$').firstMatch(body);
    if (rubyMama != null) {
      tokens.add(
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.start,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
        ),
      );
      tokens.add(
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.end,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
          content: const <AozoraInlineNode>[AozoraText('ママ')],
        ),
      );
      return true;
    }

    final correction = RegExp(r'^「(.+)」は底本では「(.+)」$').firstMatch(body);
    if (correction != null) {
      return _wrapLastMatchingText(
        tokens,
        correction[1]!,
        const AozoraAttachedText(
          boundary: AozoraRangeBoundary.start,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
        ),
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.end,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
          content: _parseNestedInlineContent('底本では「${correction[2]!}」'),
        ),
      );
    }

    final rubyCorrection = RegExp(r'^ルビの「(.+)」は底本では「(.+)」$').firstMatch(body);
    if (rubyCorrection != null) {
      tokens.add(
        const AozoraAttachedText(
          boundary: AozoraRangeBoundary.start,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
        ),
      );
      tokens.add(
        AozoraAttachedText(
          boundary: AozoraRangeBoundary.end,
          role: AozoraAttachedTextRole.note,
          side: AozoraTextSide.right,
          content: _parseNestedInlineContent('底本では「${rubyCorrection[2]!}」'),
        ),
      );
      return true;
    }

    return false;
  }

  AozoraAttachedText? _parseAttachedTextSpanStart(String body) {
    if (body == '注記付き') {
      return const AozoraAttachedText(
        boundary: AozoraRangeBoundary.start,
        role: AozoraAttachedTextRole.note,
        side: AozoraTextSide.right,
      );
    }
    if (body == '左に注記付き') {
      return const AozoraAttachedText(
        boundary: AozoraRangeBoundary.start,
        role: AozoraAttachedTextRole.note,
        side: AozoraTextSide.left,
      );
    }
    if (body == '左にルビ付き') {
      return const AozoraAttachedText(
        boundary: AozoraRangeBoundary.start,
        role: AozoraAttachedTextRole.ruby,
        side: AozoraTextSide.left,
      );
    }
    return null;
  }

  AozoraAttachedText? _parseAttachedTextSpanEnd(String body) {
    final match = RegExp(r'^(左に)?「(.*)」の(注記付き|ルビ付き)終わり$').firstMatch(body);
    if (match == null) {
      return null;
    }
    return AozoraAttachedText(
      boundary: AozoraRangeBoundary.end,
      role: match[3] == 'ルビ付き'
          ? AozoraAttachedTextRole.ruby
          : AozoraAttachedTextRole.note,
      side: match[1] == null ? AozoraTextSide.right : AozoraTextSide.left,
      content: _parseNestedInlineContent(match[2]!),
    );
  }

  _SingleTargetStyle? _parseSingleTargetStyle(String body) {
    final decorationMatch = RegExp(
      r'^「(.+)」(の左)?に(傍点|白ゴマ傍点|丸傍点|白丸傍点|黒三角傍点|白三角傍点|二重丸傍点|蛇の目傍点|ばつ傍点|傍線|二重傍線|鎖線|破線|波線|取消線)$',
    ).firstMatch(body);
    if (decorationMatch != null) {
      final side = decorationMatch[2] == null
          ? AozoraTextSide.right
          : AozoraTextSide.left;
      final style = _parseTextStyle(decorationMatch[3]!, side);
      if (style != null) {
        return _SingleTargetStyle(
          target: decorationMatch[1]!,
          startToken: AozoraStyledText(
            boundary: AozoraRangeBoundary.start,
            style: style,
          ),
          endToken: AozoraStyledText(
            boundary: AozoraRangeBoundary.end,
            style: style,
          ),
        );
      }
    }

    final headingMatch = RegExp(r'^「(.+)」は(同行|窓)?(大|中|小)見出し$').firstMatch(body);
    if (headingMatch != null) {
      return _SingleTargetStyle(
        target: headingMatch[1]!,
        startToken: AozoraHeading(
          boundary: AozoraRangeBoundary.start,
          form: _headingFormFrom(headingMatch[2]),
          level: _headingLevelFrom(headingMatch[3]!),
        ),
        endToken: AozoraHeading(
          boundary: AozoraRangeBoundary.end,
          form: _headingFormFrom(headingMatch[2]),
          level: _headingLevelFrom(headingMatch[3]!),
        ),
      );
    }

    final fontMatch = RegExp(r'^「(.+)」は([０-９]+)段階(大き|小さ)な文字$').firstMatch(body);
    if (fontMatch != null) {
      final style = AozoraFontScaleStyle(
        direction: fontMatch[3] == '大き'
            ? AozoraFontScaleDirection.larger
            : AozoraFontScaleDirection.smaller,
        steps: _parseZenkakuInt(fontMatch[2]!),
      );
      return _SingleTargetStyle(
        target: fontMatch[1]!,
        startToken: AozoraStyledText(
          boundary: AozoraRangeBoundary.start,
          style: style,
        ),
        endToken: AozoraStyledText(
          boundary: AozoraRangeBoundary.end,
          style: style,
        ),
      );
    }

    final simpleStyleMatch = RegExp(
      r'^「(.+)」は(太字|斜体|キャプション|縦中横|行右小書き|行左小書き|上付き小文字|下付き小文字|罫囲み|横組み)$',
    ).firstMatch(body);
    if (simpleStyleMatch != null) {
      final target = simpleStyleMatch[1]!;
      final kind = simpleStyleMatch[2]!;
      if (kind == '太字' || kind == '斜体') {
        final style = AozoraFontStyleAnnotation(
          kind == '太字' ? AozoraFontStyle.bold : AozoraFontStyle.italic,
        );
        return _SingleTargetStyle(
          target: target,
          startToken: AozoraStyledText(
            boundary: AozoraRangeBoundary.start,
            style: style,
          ),
          endToken: AozoraStyledText(
            boundary: AozoraRangeBoundary.end,
            style: style,
          ),
        );
      }
      if (kind == 'キャプション') {
        return _SingleTargetStyle(
          target: target,
          startToken: const AozoraCaption(AozoraRangeBoundary.start),
          endToken: const AozoraCaption(AozoraRangeBoundary.end),
        );
      }
      return _SingleTargetStyle(
        target: target,
        startToken: AozoraInlineDecoration(
          boundary: AozoraRangeBoundary.start,
          kind: _inlineDecorationKindFrom(kind)!,
        ),
        endToken: AozoraInlineDecoration(
          boundary: AozoraRangeBoundary.end,
          kind: _inlineDecorationKindFrom(kind)!,
        ),
      );
    }

    return null;
  }

  _OpenSpan? _parseSpanStart(String body) {
    final inlineKind = _inlineDecorationKindFrom(body);
    if (inlineKind != null) {
      return _OpenSpan(
        token: AozoraInlineDecoration(
          boundary: AozoraRangeBoundary.start,
          kind: inlineKind,
        ),
        entry: _OpenStyleEntry.inlineDecoration(inlineKind),
      );
    }

    final headingMatch = RegExp(r'^(同行|窓)?(大|中|小)見出し$').firstMatch(body);
    if (headingMatch != null) {
      final form = _headingFormFrom(headingMatch[1]);
      final level = _headingLevelFrom(headingMatch[2]!);
      return _OpenSpan(
        token: AozoraHeading(
          boundary: AozoraRangeBoundary.start,
          form: form,
          level: level,
        ),
        entry: _OpenStyleEntry.heading(form, level),
      );
    }

    final blockHeading = RegExp(r'^ここから(同行|窓)?(大|中|小)見出し$').firstMatch(body);
    if (blockHeading != null) {
      final form = _headingFormFrom(blockHeading[1]);
      final level = _headingLevelFrom(blockHeading[2]!);
      return _OpenSpan(
        token: AozoraHeading(
          boundary: AozoraRangeBoundary.blockStart,
          form: form,
          level: level,
        ),
        entry: _OpenStyleEntry.blockHeading(form, level),
      );
    }

    if (body == 'キャプション') {
      return _OpenSpan(
        token: const AozoraCaption(AozoraRangeBoundary.start),
        entry: _OpenStyleEntry.caption(false),
      );
    }
    if (body == 'ここからキャプション') {
      return _OpenSpan(
        token: const AozoraCaption(AozoraRangeBoundary.blockStart),
        entry: _OpenStyleEntry.caption(true),
      );
    }

    final textStyle = _parseTextStyle(body, AozoraTextSide.right);
    if (textStyle != null) {
      return _OpenSpan(
        token: AozoraStyledText(
          boundary: AozoraRangeBoundary.start,
          style: textStyle,
        ),
        entry: _OpenStyleEntry.styled(textStyle, false),
      );
    }

    final blockStyleMatch = RegExp(
      r'^ここから([０-９]+段階[大小]きな文字|太字|斜体)$',
    ).firstMatch(body);
    if (blockStyleMatch != null) {
      final style = _parseTextStyle(blockStyleMatch[1]!, AozoraTextSide.right)!;
      return _OpenSpan(
        token: AozoraStyledText(
          boundary: AozoraRangeBoundary.blockStart,
          style: style,
        ),
        entry: _OpenStyleEntry.styled(style, true),
      );
    }

    final blockInline = RegExp(r'^ここから(横組み|罫囲み)$').firstMatch(body);
    if (blockInline != null) {
      final kind = _inlineDecorationKindFrom(blockInline[1]!)!;
      return _OpenSpan(
        token: AozoraInlineDecoration(
          boundary: AozoraRangeBoundary.blockStart,
          kind: kind,
        ),
        entry: _OpenStyleEntry.blockInlineDecoration(kind),
      );
    }

    return null;
  }

  AozoraToken? _parseSpanEnd(String body) {
    final inlineKindBody = body.replaceFirst('ここで', '').replaceFirst('終わり', '');
    final inlineKind = _inlineDecorationKindFrom(inlineKindBody);
    if (inlineKind != null && body.endsWith('終わり')) {
      final boundary = body.startsWith('ここで')
          ? AozoraRangeBoundary.blockEnd
          : AozoraRangeBoundary.end;
      _popOpenStyle((entry) {
        return entry.inlineDecorationKind == inlineKind &&
            entry.boundary ==
                (boundary == AozoraRangeBoundary.blockEnd
                    ? AozoraRangeBoundary.blockStart
                    : AozoraRangeBoundary.start);
      });
      return AozoraInlineDecoration(boundary: boundary, kind: inlineKind);
    }

    final headingEnd = RegExp(r'^(ここで)?(同行|窓)?(大|中|小)見出し終わり$').firstMatch(body);
    if (headingEnd != null) {
      final isBlock = headingEnd[1] != null;
      final form = _headingFormFrom(headingEnd[2]);
      final level = _headingLevelFrom(headingEnd[3]!);
      _popOpenStyle((entry) {
        return entry.headingForm == form &&
            entry.headingLevel == level &&
            entry.boundary ==
                (isBlock
                    ? AozoraRangeBoundary.blockStart
                    : AozoraRangeBoundary.start);
      });
      return AozoraHeading(
        boundary: isBlock
            ? AozoraRangeBoundary.blockEnd
            : AozoraRangeBoundary.end,
        form: form,
        level: level,
      );
    }

    if (body == 'キャプション終わり' || body == 'ここでキャプション終わり') {
      final isBlock = body.startsWith('ここで');
      _popOpenStyle((entry) {
        return entry.isCaption &&
            entry.boundary ==
                (isBlock
                    ? AozoraRangeBoundary.blockStart
                    : AozoraRangeBoundary.start);
      });
      return AozoraCaption(
        isBlock ? AozoraRangeBoundary.blockEnd : AozoraRangeBoundary.end,
      );
    }

    final fontEnd = RegExp(r'^(ここで)?(大き|小さ)な文字終わり$').firstMatch(body);
    if (fontEnd != null) {
      final isBlock = fontEnd[1] != null;
      final direction = fontEnd[2] == '大き'
          ? AozoraFontScaleDirection.larger
          : AozoraFontScaleDirection.smaller;
      final entry = _popOpenStyle((candidate) {
        final style = candidate.textStyle;
        return style is AozoraFontScaleStyle &&
            style.direction == direction &&
            candidate.boundary ==
                (isBlock
                    ? AozoraRangeBoundary.blockStart
                    : AozoraRangeBoundary.start);
      });
      final style =
          entry?.textStyle as AozoraFontScaleStyle? ??
          AozoraFontScaleStyle(direction: direction, steps: 1);
      return AozoraStyledText(
        boundary: isBlock
            ? AozoraRangeBoundary.blockEnd
            : AozoraRangeBoundary.end,
        style: style,
      );
    }

    final styleEnd = RegExp(r'^(ここで)?(太字|斜体)終わり$').firstMatch(body);
    if (styleEnd != null) {
      final isBlock = styleEnd[1] != null;
      final style = AozoraFontStyleAnnotation(
        styleEnd[2] == '太字' ? AozoraFontStyle.bold : AozoraFontStyle.italic,
      );
      _popOpenStyle((entry) {
        final candidate = entry.textStyle;
        return candidate is AozoraFontStyleAnnotation &&
            candidate.style == style.style &&
            entry.boundary ==
                (isBlock
                    ? AozoraRangeBoundary.blockStart
                    : AozoraRangeBoundary.start);
      });
      return AozoraStyledText(
        boundary: isBlock
            ? AozoraRangeBoundary.blockEnd
            : AozoraRangeBoundary.end,
        style: style,
      );
    }

    return null;
  }

  AozoraTextStyle? _parseTextStyle(String body, AozoraTextSide defaultSide) {
    final fontScale = RegExp(r'^([０-９]+)段階(大き|小さ)な文字$').firstMatch(body);
    if (fontScale != null) {
      return AozoraFontScaleStyle(
        direction: fontScale[2] == '大き'
            ? AozoraFontScaleDirection.larger
            : AozoraFontScaleDirection.smaller,
        steps: _parseZenkakuInt(fontScale[1]!),
      );
    }

    if (body == '太字') {
      return const AozoraFontStyleAnnotation(AozoraFontStyle.bold);
    }
    if (body == '斜体') {
      return const AozoraFontStyleAnnotation(AozoraFontStyle.italic);
    }

    const boutenMap = <String, AozoraBoutenKind>{
      '傍点': AozoraBoutenKind.sesame,
      '白ゴマ傍点': AozoraBoutenKind.whiteSesame,
      '丸傍点': AozoraBoutenKind.blackCircle,
      '白丸傍点': AozoraBoutenKind.whiteCircle,
      '黒三角傍点': AozoraBoutenKind.blackTriangle,
      '白三角傍点': AozoraBoutenKind.whiteTriangle,
      '二重丸傍点': AozoraBoutenKind.bullseye,
      '蛇の目傍点': AozoraBoutenKind.fisheye,
      'ばつ傍点': AozoraBoutenKind.saltire,
    };
    const bosenMap = <String, AozoraBosenKind>{
      '傍線': AozoraBosenKind.solid,
      '二重傍線': AozoraBosenKind.doubleLine,
      '鎖線': AozoraBosenKind.chain,
      '破線': AozoraBosenKind.dashed,
      '波線': AozoraBosenKind.wave,
      '取消線': AozoraBosenKind.cancel,
    };

    final side = body.startsWith('左に') ? AozoraTextSide.left : defaultSide;
    final name = body.startsWith('左に') ? body.substring(2) : body;

    final bouten = boutenMap[name];
    if (bouten != null) {
      return AozoraBoutenStyle(kind: bouten, side: side);
    }
    final bosen = bosenMap[name];
    if (bosen != null) {
      return AozoraBosenStyle(kind: bosen, side: side);
    }
    return null;
  }

  AozoraInlineDecorationKind? _inlineDecorationKindFrom(String body) {
    const map = <String, AozoraInlineDecorationKind>{
      '縦中横': AozoraInlineDecorationKind.tatechuyoko,
      '割り注': AozoraInlineDecorationKind.warichu,
      '行右小書き': AozoraInlineDecorationKind.lineRightSmall,
      '行左小書き': AozoraInlineDecorationKind.lineLeftSmall,
      '上付き小文字': AozoraInlineDecorationKind.superscript,
      '下付き小文字': AozoraInlineDecorationKind.subscript,
      '罫囲み': AozoraInlineDecorationKind.keigakomi,
      '横組み': AozoraInlineDecorationKind.yokogumi,
    };
    return map[body];
  }

  AozoraHeadingForm _headingFormFrom(String? name) {
    switch (name) {
      case '同行':
        return AozoraHeadingForm.runIn;
      case '窓':
        return AozoraHeadingForm.window;
      default:
        return AozoraHeadingForm.standalone;
    }
  }

  AozoraHeadingLevel _headingLevelFrom(String level) {
    switch (level) {
      case '大':
        return AozoraHeadingLevel.large;
      case '中':
        return AozoraHeadingLevel.medium;
      case '小':
        return AozoraHeadingLevel.small;
      default:
        throw ArgumentError.value(level, 'level');
    }
  }

  AozoraIndent? _parseIndent(String body, bool atLineStart) {
    final single = RegExp(r'^([０-９]+)字下げ$').firstMatch(body);
    if (single != null) {
      return AozoraIndent(
        kind: AozoraIndentKind.singleLine,
        lineIndent: _parseZenkakuInt(single[1]!),
      );
    }

    final hanging = RegExp(
      r'^ここから([０-９]+)字下げ、折り返して([０-９]+)字下げ$',
    ).firstMatch(body);
    if (hanging != null) {
      return AozoraIndent(
        kind: AozoraIndentKind.block,
        boundary: AozoraRangeBoundary.blockStart,
        lineIndent: _parseZenkakuInt(hanging[1]!),
        hangingIndent: _parseZenkakuInt(hanging[2]!),
      );
    }

    final hangingFlush = RegExp(
      r'^ここから改行天付き、折り返して([０-９]+)字下げ$',
    ).firstMatch(body);
    if (hangingFlush != null) {
      return AozoraIndent(
        kind: AozoraIndentKind.block,
        boundary: AozoraRangeBoundary.blockStart,
        lineIndent: 0,
        hangingIndent: _parseZenkakuInt(hangingFlush[1]!),
      );
    }

    final blockStart = RegExp(r'^ここから([０-９]+)字下げ$').firstMatch(body);
    if (blockStart != null) {
      return AozoraIndent(
        kind: AozoraIndentKind.block,
        boundary: AozoraRangeBoundary.blockStart,
        lineIndent: _parseZenkakuInt(blockStart[1]!),
      );
    }

    if (body == 'ここで字下げ終わり') {
      return const AozoraIndent(
        kind: AozoraIndentKind.block,
        boundary: AozoraRangeBoundary.blockEnd,
        lineIndent: 0,
      );
    }

    if (!atLineStart) {
      return null;
    }
    return null;
  }

  AozoraBottomAlign? _parseBottomAlign(String body, bool atLineStart) {
    if (body == '地付き') {
      return AozoraBottomAlign(
        kind: AozoraBottomAlignKind.bottom,
        scope: atLineStart
            ? AozoraBottomAlignScope.singleLine
            : AozoraBottomAlignScope.inlineTail,
      );
    }
    if (body == 'ここから地付き') {
      return const AozoraBottomAlign(
        kind: AozoraBottomAlignKind.bottom,
        scope: AozoraBottomAlignScope.block,
        boundary: AozoraRangeBoundary.blockStart,
      );
    }
    if (body == 'ここで地付き終わり') {
      return const AozoraBottomAlign(
        kind: AozoraBottomAlignKind.bottom,
        scope: AozoraBottomAlignScope.block,
        boundary: AozoraRangeBoundary.blockEnd,
      );
    }

    final single = RegExp(r'^地から([０-９]+)字上げ$').firstMatch(body);
    if (single != null) {
      return AozoraBottomAlign(
        kind: AozoraBottomAlignKind.raisedFromBottom,
        scope: atLineStart
            ? AozoraBottomAlignScope.singleLine
            : AozoraBottomAlignScope.inlineTail,
        offset: _parseZenkakuInt(single[1]!),
      );
    }

    final blockStart = RegExp(r'^ここから地から([０-９]+)字上げ$').firstMatch(body);
    if (blockStart != null) {
      return AozoraBottomAlign(
        kind: AozoraBottomAlignKind.raisedFromBottom,
        scope: AozoraBottomAlignScope.block,
        boundary: AozoraRangeBoundary.blockStart,
        offset: _parseZenkakuInt(blockStart[1]!),
      );
    }
    if (body == 'ここで字上げ終わり') {
      return const AozoraBottomAlign(
        kind: AozoraBottomAlignKind.raisedFromBottom,
        scope: AozoraBottomAlignScope.block,
        boundary: AozoraRangeBoundary.blockEnd,
      );
    }

    return null;
  }

  AozoraJizume? _parseJizume(String body) {
    final start = RegExp(r'^ここから([０-９]+)字詰め$').firstMatch(body);
    if (start != null) {
      return AozoraJizume(
        boundary: AozoraRangeBoundary.blockStart,
        width: _parseZenkakuInt(start[1]!),
      );
    }
    if (body == 'ここで字詰め終わり') {
      return const AozoraJizume(boundary: AozoraRangeBoundary.blockEnd);
    }
    return null;
  }

  AozoraImage? _parseImage(String body) {
    final imageMatch = RegExp(
      r'^(.*?)（([^（、]*)(、横([0-9]+)×縦([0-9]+))?）入る$',
    ).firstMatch(body);
    if (imageMatch == null) {
      return null;
    }

    return AozoraImage(
      description: imageMatch[1]!,
      fileName: imageMatch[2]!,
      size: imageMatch[4] == null || imageMatch[5] == null
          ? null
          : AozoraImageSize(
              width: int.parse(imageMatch[4]!),
              height: int.parse(imageMatch[5]!),
            ),
      hasCaption: imageMatch[1]!.contains('キャプション付き'),
    );
  }

  String _annotationBody(String raw) => raw.substring(2, raw.length - 1);

  int _parseZenkakuInt(String text) {
    const zenkaku = '０１２３４５６７８９';
    final buffer = StringBuffer();
    for (final codePoint in text.runes) {
      final char = String.fromCharCode(codePoint);
      final index = zenkaku.indexOf(char);
      buffer.write(index >= 0 ? index : char);
    }
    return int.parse(buffer.toString());
  }

  AozoraKaeritenPrimary? _kaeritenPrimaryFrom(String? text) {
    switch (text) {
      case '一':
        return AozoraKaeritenPrimary.ichi;
      case '二':
        return AozoraKaeritenPrimary.ni;
      case '三':
        return AozoraKaeritenPrimary.san;
      case '四':
        return AozoraKaeritenPrimary.yon;
      case '上':
        return AozoraKaeritenPrimary.jou;
      case '中':
        return AozoraKaeritenPrimary.chuu;
      case '下':
        return AozoraKaeritenPrimary.ge;
      case '甲':
        return AozoraKaeritenPrimary.kou;
      case '乙':
        return AozoraKaeritenPrimary.otsu;
      case '丙':
        return AozoraKaeritenPrimary.hei;
      case '天':
        return AozoraKaeritenPrimary.ten;
      case '地':
        return AozoraKaeritenPrimary.chi;
      case '人':
        return AozoraKaeritenPrimary.jin;
      default:
        return null;
    }
  }

  AozoraInlineContent _parseNestedInlineContent(
    String text, {
    bool inWarichu = false,
  }) {
    final nested = _AozoraInlineParser(text).parse();
    return nested
        .whereType<AozoraInlineNode>()
        .map((token) {
          if (inWarichu && token is AozoraNewLine && text.contains('［＃改行］')) {
            return const AozoraWarichuNewLine();
          }
          return token;
        })
        .toList(growable: false);
  }

  void _attachRuby(
    List<AozoraToken> tokens,
    String rubyText, {
    int explicitStartIndex = -1,
  }) {
    final startIndex = _findRubyTargetStart(
      tokens,
      explicitStartIndex: explicitStartIndex,
    );
    if (startIndex == null) {
      tokens.add(AozoraText('《$rubyText》'));
      return;
    }
    tokens.insert(
      startIndex,
      const AozoraAttachedText(
        boundary: AozoraRangeBoundary.start,
        role: AozoraAttachedTextRole.ruby,
        side: AozoraTextSide.right,
      ),
    );
    tokens.add(
      AozoraAttachedText(
        boundary: AozoraRangeBoundary.end,
        role: AozoraAttachedTextRole.ruby,
        side: AozoraTextSide.right,
        content: _parseNestedInlineContent(rubyText),
      ),
    );
  }

  int? _findRubyTargetStart(
    List<AozoraToken> tokens, {
    int explicitStartIndex = -1,
  }) {
    if (tokens.isEmpty) {
      return null;
    }
    if (explicitStartIndex >= 0 && explicitStartIndex < tokens.length) {
      return explicitStartIndex;
    }

    var index = tokens.length - 1;
    while (index >= 0) {
      final token = tokens[index];
      if (token is AozoraText) {
        final split = _splitTrailingRubyText(token.text);
        if (split == null) {
          final fallback = index + 1;
          return fallback < tokens.length ? fallback : null;
        }
        if (split.remaining != null) {
          tokens[index] = AozoraText(split.remaining!);
          tokens.insert(index + 1, AozoraText(split.matched));
          return index + 1;
        }
        return index;
      }
      if (token is AozoraGaiji ||
          token is AozoraAccentDecomposition ||
          token is AozoraTateTen) {
        index -= 1;
        continue;
      }
      break;
    }

    final start = index + 1;
    return start < tokens.length ? start : null;
  }

  _RubyTextSplit? _splitTrailingRubyText(String text) {
    if (text.isEmpty) {
      return null;
    }

    final tail = text[text.length - 1];
    final tailClass = _rubyBaseClass(tail);
    if (!_isRubyBaseCharacter(tail) || tailClass == _RubyBaseClass.other) {
      return null;
    }

    var splitIndex = text.length;
    while (splitIndex > 0) {
      final char = text[splitIndex - 1];
      if (!_isRubyBaseCharacter(char) || _rubyBaseClass(char) != tailClass) {
        break;
      }
      splitIndex -= 1;
    }

    if (splitIndex == text.length) {
      return null;
    }

    return _RubyTextSplit(
      remaining: splitIndex > 0 ? text.substring(0, splitIndex) : null,
      matched: text.substring(splitIndex),
    );
  }

  bool _isRubyBaseCharacter(String char) {
    return !_rubyBaseIgnorablePattern.hasMatch(char);
  }

  _RubyBaseClass _rubyBaseClass(String char) {
    if (_rubyHiraganaPattern.hasMatch(char)) {
      return _RubyBaseClass.hiragana;
    }
    if (_rubyKatakanaPattern.hasMatch(char)) {
      return _RubyBaseClass.katakana;
    }
    if (_rubyKanjiPattern.hasMatch(char)) {
      return _RubyBaseClass.kanji;
    }
    if (_rubyLatinPattern.hasMatch(char) || "−＆’，．#-\\&',".contains(char)) {
      return _RubyBaseClass.latinOrNumber;
    }
    return _RubyBaseClass.other;
  }

  bool _wrapLastMatchingText(
    List<AozoraToken> tokens,
    String target,
    AozoraAnnotation startToken,
    AozoraAnnotation endToken,
  ) {
    final lineStart =
        tokens.lastIndexWhere((token) => token is AozoraNewLine) + 1;
    final refs = <_VisibleCharRef>[];

    for (
      var tokenIndex = lineStart;
      tokenIndex < tokens.length;
      tokenIndex += 1
    ) {
      final token = tokens[tokenIndex];
      if (token is AozoraText) {
        for (var offset = 0; offset < token.text.length; offset += 1) {
          refs.add(_VisibleCharRef(tokenIndex, offset, token.text[offset]));
        }
      } else if (token is AozoraTateTen) {
        refs.add(_VisibleCharRef(tokenIndex, 0, '‐'));
      }
    }

    final visible = refs.map((ref) => ref.char).join();
    final startOffset = visible.lastIndexOf(target);
    if (startOffset < 0) {
      return false;
    }

    final endOffset = startOffset + target.length;
    final startRef = refs[startOffset];
    final endRef = refs[endOffset - 1];

    _splitTextTokenAt(tokens, endRef.tokenIndex, endRef.offset + 1);
    _splitTextTokenAt(tokens, startRef.tokenIndex, startRef.offset);

    var startInsertIndex = startRef.tokenIndex;
    if (startRef.offset > 0) {
      startInsertIndex += 1;
    }

    final endInsertIndex = _nextVisibleTokenIndex(
      tokens,
      startInsertIndex,
      target,
    );
    tokens.insert(startInsertIndex, startToken);
    tokens.insert(endInsertIndex + 2, endToken);
    return true;
  }

  void _splitTextTokenAt(List<AozoraToken> tokens, int tokenIndex, int offset) {
    final token = tokens[tokenIndex];
    if (token is! AozoraText) {
      return;
    }
    if (offset <= 0 || offset >= token.text.length) {
      return;
    }
    tokens[tokenIndex] = AozoraText(token.text.substring(0, offset));
    tokens.insert(tokenIndex + 1, AozoraText(token.text.substring(offset)));
  }

  int _nextVisibleTokenIndex(
    List<AozoraToken> tokens,
    int startTokenIndex,
    String target,
  ) {
    var remaining = target.length;
    var index = startTokenIndex;
    while (index < tokens.length && remaining > 0) {
      final token = tokens[index];
      if (token is AozoraText) {
        remaining -= token.text.length;
      } else if (token is AozoraTateTen) {
        remaining -= 1;
      }
      if (remaining <= 0) {
        return index;
      }
      index += 1;
    }
    return index - 1;
  }

  _OpenStyleEntry? _popOpenStyle(bool Function(_OpenStyleEntry) predicate) {
    for (var index = _openStyles.length - 1; index >= 0; index -= 1) {
      final entry = _openStyles[index];
      if (predicate(entry)) {
        return _openStyles.removeAt(index);
      }
    }
    return null;
  }

  List<AozoraToken> _mergeAdjacentText(List<AozoraToken> tokens) {
    final merged = <AozoraToken>[];
    for (final token in tokens) {
      if (token is AozoraText &&
          merged.isNotEmpty &&
          merged.last is AozoraText) {
        final last = merged.removeLast() as AozoraText;
        merged.add(AozoraText(last.text + token.text));
      } else {
        merged.add(token);
      }
    }
    return merged;
  }
}

enum _RubyBaseClass { hiragana, katakana, kanji, latinOrNumber, other }

class _RubyTextSplit {
  const _RubyTextSplit({required this.remaining, required this.matched});

  final String? remaining;
  final String matched;
}

class _RemarkResult {
  const _RemarkResult(this.token, this.nextIndex);

  final AozoraDocumentRemark token;
  final int nextIndex;
}

class _SingleTargetStyle {
  const _SingleTargetStyle({
    required this.target,
    required this.startToken,
    required this.endToken,
  });

  final String target;
  final AozoraAnnotation startToken;
  final AozoraAnnotation endToken;
}

class _OpenSpan {
  const _OpenSpan({required this.token, required this.entry});

  final AozoraToken token;
  final _OpenStyleEntry entry;
}

class _VisibleCharRef {
  const _VisibleCharRef(this.tokenIndex, this.offset, this.char);

  final int tokenIndex;
  final int offset;
  final String char;
}

class _OpenStyleEntry {
  const _OpenStyleEntry({
    required this.boundary,
    this.inlineDecorationKind,
    this.headingForm,
    this.headingLevel,
    this.textStyle,
    this.isCaption = false,
  });

  factory _OpenStyleEntry.inlineDecoration(AozoraInlineDecorationKind kind) {
    return _OpenStyleEntry(
      boundary: AozoraRangeBoundary.start,
      inlineDecorationKind: kind,
    );
  }

  factory _OpenStyleEntry.blockInlineDecoration(
    AozoraInlineDecorationKind kind,
  ) {
    return _OpenStyleEntry(
      boundary: AozoraRangeBoundary.blockStart,
      inlineDecorationKind: kind,
    );
  }

  factory _OpenStyleEntry.heading(
    AozoraHeadingForm form,
    AozoraHeadingLevel level,
  ) {
    return _OpenStyleEntry(
      boundary: AozoraRangeBoundary.start,
      headingForm: form,
      headingLevel: level,
    );
  }

  factory _OpenStyleEntry.blockHeading(
    AozoraHeadingForm form,
    AozoraHeadingLevel level,
  ) {
    return _OpenStyleEntry(
      boundary: AozoraRangeBoundary.blockStart,
      headingForm: form,
      headingLevel: level,
    );
  }

  factory _OpenStyleEntry.styled(AozoraTextStyle style, bool isBlock) {
    return _OpenStyleEntry(
      boundary: isBlock
          ? AozoraRangeBoundary.blockStart
          : AozoraRangeBoundary.start,
      textStyle: style,
    );
  }

  factory _OpenStyleEntry.caption(bool isBlock) {
    return _OpenStyleEntry(
      boundary: isBlock
          ? AozoraRangeBoundary.blockStart
          : AozoraRangeBoundary.start,
      isCaption: true,
    );
  }

  final AozoraRangeBoundary boundary;
  final AozoraInlineDecorationKind? inlineDecorationKind;
  final AozoraHeadingForm? headingForm;
  final AozoraHeadingLevel? headingLevel;
  final AozoraTextStyle? textStyle;
  final bool isCaption;
}
