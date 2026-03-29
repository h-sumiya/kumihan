import '../ast/ast.dart';

class AozoraAstParser {
  AozoraAstParser();

  static const String _directiveOpen = '［＃';
  static const String _directiveClose = '］';
  static const String _rubyOpen = '《';
  static const String _rubyClose = '》';
  static const String _rubyExplicitMarker = '｜';
  static const String _accentOpen = '〔';
  static const String _accentClose = '〕';

  DocumentNode parse(String source) {
    final normalized = source.replaceAll(RegExp(r'\r\n?'), '\n');
    final mapper = _SourceMapper(normalized);
    final diagnostics = <AstDiagnostic>[];
    final rootBlocks = <BlockNode>[];
    final blockStack = <_BlockFrame>[];

    void addBlock(BlockNode block) {
      if (blockStack.isEmpty) {
        rootBlocks.add(block);
      } else {
        blockStack.last.children.add(block);
      }
    }

    var lineStart = 0;
    while (lineStart <= normalized.length) {
      final lineEnd = normalized.indexOf('\n', lineStart);
      final endOffset = lineEnd >= 0 ? lineEnd : normalized.length;
      final line = normalized.substring(lineStart, endOffset);
      final lineSpan = mapper.span(lineStart, endOffset);

      if (line.isEmpty) {
        addBlock(EmptyLineNode(span: lineSpan));
      } else {
        final directive = _parseWholeLineDirective(line, lineStart, mapper);
        if (directive != null) {
          final handled = _handleDirectiveLine(
            directive,
            blockStack,
            addBlock,
            mapper,
            diagnostics,
          );
          if (!handled) {
            addBlock(
              DirectiveBlockNode(span: directive.span, directive: directive),
            );
          }
        } else {
          final paragraph = _parseParagraph(
            normalized,
            line,
            lineStart,
            mapper,
            diagnostics,
          );
          addBlock(paragraph);
        }
      }

      if (lineEnd < 0) {
        break;
      }
      lineStart = lineEnd + 1;
    }

    while (blockStack.isNotEmpty) {
      final frame = blockStack.removeLast();
      diagnostics.add(
        AstDiagnostic(
          code: 'unclosed_block_container',
          message: 'Block directive was not closed before end of document.',
          severity: AstDiagnosticSeverity.warning,
          span: frame.openDirective.span,
        ),
      );
      final span = mapper.mergeSpans(
        frame.openDirective.span,
        frame.children.isEmpty ? null : frame.children.last.span,
      );
      final node = ContainerBlockNode(
        span: span,
        kind: frame.kind,
        variant: frame.variant,
        attributes: frame.attributes,
        children: List<BlockNode>.unmodifiable(frame.children),
        openDirective: frame.openDirective,
        isClosed: false,
      );
      if (blockStack.isEmpty) {
        rootBlocks.add(node);
      } else {
        blockStack.last.children.add(node);
      }
    }

    return DocumentNode(
      span: mapper.span(0, normalized.length),
      children: List<BlockNode>.unmodifiable(rootBlocks),
      diagnostics: List<AstDiagnostic>.unmodifiable(diagnostics),
    );
  }

  ParagraphNode _parseParagraph(
    String source,
    String line,
    int lineStartOffset,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics,
  ) {
    final root = _InlineFrame.root();
    final stack = <_InlineFrame>[root];
    var explicitRubyStartIndex = -1;
    var index = 0;

    void addInline(InlineNode node) {
      _appendInline(stack.last.children, node);
    }

    void addText(String text, int start, int end) {
      if (text.isEmpty) {
        return;
      }
      addInline(
        TextNode(
          span: mapper.span(lineStartOffset + start, lineStartOffset + end),
          text: text,
        ),
      );
    }

    while (index < line.length) {
      if (line.startsWith('※$_directiveOpen', index)) {
        final directiveEnd = line.indexOf(_directiveClose, index + 3);
        if (directiveEnd >= 0) {
          final raw = line.substring(index, directiveEnd + 1);
          final body = line.substring(index + 3, directiveEnd);
          addInline(
            _buildGaijiNode(
              mapper: mapper,
              raw: raw,
              body: body,
              start: lineStartOffset + index,
              end: lineStartOffset + directiveEnd + 1,
            ),
          );
          index = directiveEnd + 1;
          continue;
        }
      }

      if (line.startsWith(_directiveOpen, index)) {
        final directiveEnd = line.indexOf(_directiveClose, index + 2);
        if (directiveEnd >= 0) {
          final raw = line.substring(index, directiveEnd + 1);
          final body = line.substring(index + 2, directiveEnd);
          final directive = SourceDirective(
            format: 'aozora',
            rawText: raw,
            body: body,
            span: mapper.span(
              lineStartOffset + index,
              lineStartOffset + directiveEnd + 1,
            ),
          );
          final handled = _handleInlineDirective(
            directive,
            stack,
            mapper,
            diagnostics,
            lineStartOffset,
          );
          if (!handled) {
            addInline(
              DirectiveInlineNode(span: directive.span, directive: directive),
            );
          }
          index = directiveEnd + 1;
          continue;
        }
      }

      if (line.startsWith(_accentOpen, index)) {
        final accentEnd = line.indexOf(_accentClose, index + 1);
        if (accentEnd >= 0) {
          final raw = line.substring(index + 1, accentEnd);
          final decoded = _decodeAccentText(raw);
          addText(decoded, index, accentEnd + 1);
          index = accentEnd + 1;
          continue;
        }
      }

      if (line.startsWith(_rubyExplicitMarker, index)) {
        explicitRubyStartIndex = stack.last.children.length;
        index += _rubyExplicitMarker.length;
        continue;
      }

      if (line.startsWith(_rubyOpen, index)) {
        final rubyEnd = line.indexOf(_rubyClose, index + 1);
        if (rubyEnd >= 0) {
          final rubyText = line.substring(index + 1, rubyEnd);
          final base = _takeRubyBase(
            stack.last.children,
            explicitRubyStartIndex: explicitRubyStartIndex,
            mapper: mapper,
            rubyStartOffset: lineStartOffset + index,
          );
          explicitRubyStartIndex = -1;
          if (base != null) {
            addInline(
              RubyNode(
                span: mapper.mergeSpans(
                  base.span,
                  mapper.span(
                    lineStartOffset + index,
                    lineStartOffset + rubyEnd + 1,
                  ),
                ),
                base: base.nodes,
                text: rubyText,
                kind: RubyKind.phonetic,
                position: RubyPosition.over,
              ),
            );
            index = rubyEnd + 1;
            continue;
          }
          diagnostics.add(
            AstDiagnostic(
              code: 'dangling_ruby',
              message: 'Ruby text has no preceding base text.',
              severity: AstDiagnosticSeverity.warning,
              span: mapper.span(
                lineStartOffset + index,
                lineStartOffset + rubyEnd + 1,
              ),
            ),
          );
        }
      }

      final next = _findNextSpecialIndex(line, index + 1);
      addText(line.substring(index, next), index, next);
      index = next;
    }

    while (stack.length > 1) {
      final frame = stack.removeLast();
      diagnostics.add(
        AstDiagnostic(
          code: 'unclosed_inline_container',
          message: 'Inline directive was not closed before end of line.',
          severity: AstDiagnosticSeverity.warning,
          span: frame.openDirective!.span,
        ),
      );
      final node = _finalizeInlineFrame(
        frame,
        mapper: mapper,
        closeDirective: null,
        isClosed: false,
      );
      _appendInline(stack.last.children, node);
    }

    return ParagraphNode(
      span: mapper.span(lineStartOffset, lineStartOffset + line.length),
      children: List<InlineNode>.unmodifiable(root.children),
    );
  }

  bool _handleDirectiveLine(
    SourceDirective directive,
    List<_BlockFrame> stack,
    void Function(BlockNode block) addBlock,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics,
  ) {
    final openSpec = _parseBlockOpenDirective(directive);
    if (openSpec != null) {
      stack.add(
        _BlockFrame(
          kind: openSpec.kind,
          variant: openSpec.variant,
          attributes: openSpec.attributes,
          closeMatcher: openSpec.closeMatcher,
          openDirective: directive.copyWith(category: 'block.open'),
        ),
      );
      return true;
    }

    final closeSpec = _parseBlockCloseDirective(directive);
    if (closeSpec == null) {
      return false;
    }
    if (stack.isEmpty || !closeSpec.matches(stack.last)) {
      diagnostics.add(
        AstDiagnostic(
          code: 'orphan_block_close',
          message: 'Block closing directive did not match the current block.',
          severity: AstDiagnosticSeverity.warning,
          span: directive.span,
        ),
      );
      return false;
    }

    final frame = stack.removeLast();
    final span = mapper.mergeSpans(frame.openDirective.span, directive.span);
    final node = ContainerBlockNode(
      span: span,
      kind: frame.kind,
      variant: frame.variant,
      attributes: frame.attributes,
      children: List<BlockNode>.unmodifiable(frame.children),
      openDirective: frame.openDirective,
      closeDirective: directive.copyWith(category: 'block.close'),
    );
    addBlock(node);
    return true;
  }

  bool _handleInlineDirective(
    SourceDirective directive,
    List<_InlineFrame> stack,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics,
    int lineStartOffset,
  ) {
    if (directive.body == '改行') {
      _appendInline(
        stack.last.children,
        LineBreakNode(
          span: directive.span,
          sourceDirective: directive.copyWith(category: 'inline.lineBreak'),
        ),
      );
      return true;
    }

    if (directive.body == '注記付き') {
      stack.add(
        _InlineFrame.pendingRubyAnnotation(
          openDirective: directive.copyWith(category: 'inline.open'),
        ),
      );
      return true;
    }

    final closeNoteMatch = RegExp(
      r'^「(.+)」の注記付き終わり$',
    ).firstMatch(directive.body);
    if (closeNoteMatch != null &&
        stack.length > 1 &&
        stack.last.kind == 'rubyAnnotationPending') {
      final frame = stack.removeLast();
      final text = closeNoteMatch.group(1)!;
      final span = mapper.mergeSpans(frame.openDirective!.span, directive.span);
      _appendInline(
        stack.last.children,
        RubyNode(
          span: span,
          base: List<InlineNode>.unmodifiable(frame.children),
          text: text,
          kind: RubyKind.annotation,
          position: RubyPosition.over,
          sourceDirective: directive.copyWith(category: 'inline.close'),
        ),
      );
      return true;
    }

    if (directive.body.endsWith('終わり')) {
      final openBody = directive.body.substring(0, directive.body.length - 3);
      if (stack.length > 1 && stack.last.matches(openBody)) {
        final frame = stack.removeLast();
        final node = _finalizeInlineFrame(
          frame,
          mapper: mapper,
          closeDirective: directive.copyWith(category: 'inline.close'),
          isClosed: true,
        );
        _appendInline(stack.last.children, node);
        return true;
      }
      diagnostics.add(
        AstDiagnostic(
          code: 'orphan_inline_close',
          message: 'Inline closing directive did not match the current scope.',
          severity: AstDiagnosticSeverity.warning,
          span: directive.span,
        ),
      );
      return false;
    }

    final wrapped = _tryApplyTargetDirective(
      directive,
      stack.last.children,
      mapper,
      diagnostics,
    );
    if (wrapped) {
      return true;
    }

    final openSpec = _parseInlineOpenDirective(directive.body);
    if (openSpec == null) {
      return false;
    }
    stack.add(
      _InlineFrame.container(
        openBody: directive.body,
        kind: openSpec.kind,
        variant: openSpec.variant,
        attributes: openSpec.attributes,
        openDirective: directive.copyWith(category: 'inline.open'),
      ),
    );
    return true;
  }

  bool _tryApplyTargetDirective(
    SourceDirective directive,
    List<InlineNode> siblings,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics,
  ) {
    final match = RegExp(r'^「(.+?)」(?:に|は|の)(.+)$').firstMatch(directive.body);
    if (match == null) {
      return false;
    }

    final targetText = match.group(1)!;
    final action = match.group(2)!;
    final base = _takeTargetTail(siblings, targetText, mapper);
    if (base == null) {
      diagnostics.add(
        AstDiagnostic(
          code: 'missing_reference_target',
          message: 'Directive target could not be found in the preceding text.',
          severity: AstDiagnosticSeverity.warning,
          span: directive.span,
        ),
      );
      return false;
    }

    final rubyDirectional = RegExp(
      r'^(左|右|上|下)に「(.+?)」の(ルビ|注記)$',
    ).firstMatch(action);
    if (rubyDirectional != null) {
      final rubyText = rubyDirectional.group(2)!;
      final type = rubyDirectional.group(3)!;
      final position = switch (rubyDirectional.group(1)!) {
        '左' => RubyPosition.left,
        '右' => RubyPosition.right,
        '下' => RubyPosition.under,
        _ => RubyPosition.over,
      };
      _appendInline(
        siblings,
        RubyNode(
          span: mapper.mergeSpans(base.span, directive.span),
          base: base.nodes,
          text: rubyText,
          kind: type == '注記' ? RubyKind.annotation : RubyKind.phonetic,
          position: position,
          sourceDirective: directive.copyWith(category: 'inline.reference'),
        ),
      );
      return true;
    }

    final rubyMatch = RegExp(r'^「(.+?)」の(ルビ|注記)$').firstMatch(action);
    if (rubyMatch != null) {
      _appendInline(
        siblings,
        RubyNode(
          span: mapper.mergeSpans(base.span, directive.span),
          base: base.nodes,
          text: rubyMatch.group(1)!,
          kind: rubyMatch.group(2)! == '注記'
              ? RubyKind.annotation
              : RubyKind.phonetic,
          position: RubyPosition.over,
          sourceDirective: directive.copyWith(category: 'inline.reference'),
        ),
      );
      return true;
    }

    final inlineSpec = _parseInlineOpenDirective(action);
    if (inlineSpec == null) {
      return false;
    }
    _appendInline(
      siblings,
      InlineContainerNode(
        span: mapper.mergeSpans(base.span, directive.span),
        kind: inlineSpec.kind,
        variant: inlineSpec.variant,
        attributes: inlineSpec.attributes,
        children: base.nodes,
        openDirective: directive.copyWith(category: 'inline.reference'),
      ),
    );
    return true;
  }

  InlineNode _finalizeInlineFrame(
    _InlineFrame frame, {
    required _SourceMapper mapper,
    required SourceDirective? closeDirective,
    required bool isClosed,
  }) {
    final endSpan =
        closeDirective?.span ??
        (frame.children.isEmpty ? null : frame.children.last.span);
    final span = mapper.mergeSpans(frame.openDirective!.span, endSpan);
    return InlineContainerNode(
      span: span,
      kind: frame.kind,
      variant: frame.variant,
      attributes: frame.attributes,
      children: List<InlineNode>.unmodifiable(frame.children),
      openDirective: frame.openDirective!,
      closeDirective: closeDirective,
      isClosed: isClosed,
    );
  }

  SourceDirective? _parseWholeLineDirective(
    String line,
    int lineStart,
    _SourceMapper mapper,
  ) {
    if (!line.startsWith(_directiveOpen) || !line.endsWith(_directiveClose)) {
      return null;
    }
    final firstClose = line.indexOf(_directiveClose, _directiveOpen.length);
    if (firstClose != line.length - 1) {
      return null;
    }
    final body = line.substring(_directiveOpen.length, line.length - 1);
    return SourceDirective(
      format: 'aozora',
      rawText: line,
      body: body,
      span: mapper.span(lineStart, lineStart + line.length),
    );
  }

  _BlockOpenSpec? _parseBlockOpenDirective(SourceDirective directive) {
    final body = directive.body;
    if (body.startsWith('ここから')) {
      final inner = body.substring('ここから'.length);
      final spec = _parseStandaloneBlockType(inner);
      if (spec != null) {
        return spec;
      }
    }
    return _parseStandaloneBlockType(body);
  }

  _BlockOpenSpec? _parseStandaloneBlockType(String body) {
    final indentMatch = RegExp(r'^(.+?)字下げ$').firstMatch(body);
    if (indentMatch != null) {
      final width = _parseLength(indentMatch.group(1)!);
      return _BlockOpenSpec(
        kind: 'indent',
        variant: 'jisage',
        attributes: <String, String>{
          if (width != null) 'width': width.toString(),
        },
        closeMatcher: (frame) => frame.kind == 'indent',
      );
    }

    final jizumeMatch = RegExp(r'^(.+?)字詰め$').firstMatch(body);
    if (jizumeMatch != null) {
      final width = _parseLength(jizumeMatch.group(1)!);
      return _BlockOpenSpec(
        kind: 'measure',
        variant: 'jizume',
        attributes: <String, String>{
          if (width != null) 'width': width.toString(),
        },
        closeMatcher: (frame) => frame.kind == 'measure',
      );
    }

    if (body == '地付き' || body == '字上げ') {
      return _BlockOpenSpec(
        kind: 'alignment',
        variant: body == '地付き' ? 'chitsuki' : 'jiage',
        closeMatcher: (frame) => frame.kind == 'alignment',
      );
    }

    if (body == '横組み') {
      return _BlockOpenSpec(
        kind: 'flow',
        variant: 'yokogumi',
        closeMatcher: (frame) => frame.kind == 'flow',
      );
    }

    if (body == '罫囲み') {
      return _BlockOpenSpec(
        kind: 'frame',
        variant: 'keigakomi',
        closeMatcher: (frame) => frame.kind == 'frame',
      );
    }

    if (body == 'キャプション') {
      return _BlockOpenSpec(
        kind: 'caption',
        variant: 'caption',
        closeMatcher: (frame) => frame.kind == 'caption',
      );
    }

    if (body == '太字' || body == '斜体') {
      return _BlockOpenSpec(
        kind: 'style',
        variant: body == '太字' ? 'bold' : 'italic',
        closeMatcher: (frame) => frame.kind == 'style',
      );
    }

    final charSize = _parseCharSize(body);
    if (charSize != null) {
      return _BlockOpenSpec(
        kind: 'fontSize',
        variant: charSize.variant,
        attributes: charSize.attributes,
        closeMatcher: (frame) => frame.kind == 'fontSize',
      );
    }

    final heading = _parseHeading(body);
    if (heading != null) {
      return _BlockOpenSpec(
        kind: 'heading',
        variant: heading.variant,
        attributes: heading.attributes,
        closeMatcher: (frame) => frame.kind == 'heading',
      );
    }

    return null;
  }

  _BlockCloseSpec? _parseBlockCloseDirective(SourceDirective directive) {
    var body = directive.body;
    if (body.startsWith('ここで')) {
      body = body.substring('ここで'.length);
    }
    if (!body.endsWith('終わり')) {
      return null;
    }
    final target = body.substring(0, body.length - '終わり'.length);
    if (target == '字下げ') {
      return _BlockCloseSpec((frame) => frame.kind == 'indent');
    }
    if (target == '地付き' || target == '字上げ') {
      return _BlockCloseSpec((frame) => frame.kind == 'alignment');
    }
    if (target == '字詰め') {
      return _BlockCloseSpec((frame) => frame.kind == 'measure');
    }
    if (target == '横組み') {
      return _BlockCloseSpec((frame) => frame.kind == 'flow');
    }
    if (target == '罫囲み') {
      return _BlockCloseSpec((frame) => frame.kind == 'frame');
    }
    if (target == 'キャプション') {
      return _BlockCloseSpec((frame) => frame.kind == 'caption');
    }
    if (target == '太字' || target == '斜体') {
      return _BlockCloseSpec((frame) => frame.kind == 'style');
    }
    if (_parseHeading(target) != null) {
      return _BlockCloseSpec((frame) => frame.kind == 'heading');
    }
    if (_parseCharSize(target) != null) {
      return _BlockCloseSpec((frame) => frame.kind == 'fontSize');
    }
    return null;
  }

  _InlineOpenSpec? _parseInlineOpenDirective(String body) {
    if (body == '縦中横') {
      return const _InlineOpenSpec(kind: 'direction', variant: 'tateChuYoko');
    }
    if (body == '横組み') {
      return const _InlineOpenSpec(kind: 'flow', variant: 'yokogumi');
    }
    if (body == '罫囲み') {
      return const _InlineOpenSpec(kind: 'frame', variant: 'keigakomi');
    }
    if (body == 'キャプション') {
      return const _InlineOpenSpec(kind: 'caption', variant: 'caption');
    }
    if (body == '割り注') {
      return const _InlineOpenSpec(kind: 'note', variant: 'warichu');
    }
    if (body == '割書') {
      return const _InlineOpenSpec(kind: 'note', variant: 'warigaki');
    }
    if (body == '太字') {
      return const _InlineOpenSpec(kind: 'style', variant: 'bold');
    }
    if (body == '斜体') {
      return const _InlineOpenSpec(kind: 'style', variant: 'italic');
    }

    final charSize = _parseCharSize(body);
    if (charSize != null) {
      return _InlineOpenSpec(
        kind: 'fontSize',
        variant: charSize.variant,
        attributes: charSize.attributes,
      );
    }

    final heading = _parseHeading(body);
    if (heading != null) {
      return _InlineOpenSpec(
        kind: 'heading',
        variant: heading.variant,
        attributes: heading.attributes,
      );
    }

    final decoration = _parseDecoration(body);
    if (decoration != null) {
      return _InlineOpenSpec(
        kind: decoration.kind,
        variant: decoration.variant,
        attributes: decoration.attributes,
      );
    }

    return null;
  }

  _SpecParts? _parseHeading(String body) {
    final display = body.startsWith('同行')
        ? 'dogyo'
        : body.startsWith('窓')
        ? 'mado'
        : 'normal';
    final stripped = body
        .replaceFirst('同行', '')
        .replaceFirst('窓', '')
        .replaceFirst('見出し', '見出し');
    final level = switch (stripped) {
      '大見出し' => 'large',
      '中見出し' => 'medium',
      '小見出し' => 'small',
      _ => null,
    };
    if (level == null) {
      return null;
    }
    return _SpecParts(
      variant: level,
      attributes: <String, String>{'display': display},
    );
  }

  _SpecParts? _parseCharSize(String body) {
    final match = RegExp(r'^(.+?)段階(..)な文字$').firstMatch(body);
    if (match == null) {
      return null;
    }
    final amount = _parseLength(match.group(1)!);
    final type = match.group(2)! == '大き' ? 'larger' : 'smaller';
    return _SpecParts(
      variant: type,
      attributes: <String, String>{
        if (amount != null) 'steps': amount.toString(),
      },
    );
  }

  _SpecParts? _parseDecoration(String body) {
    final directionMatch = RegExp(r'^(右|左|上|下)に(.+)$').firstMatch(body);
    var direction = 'default';
    var core = body;
    if (directionMatch != null) {
      direction = directionMatch.group(1)!;
      core = directionMatch.group(2)!;
    }

    final mapping = <String, String>{
      '傍点': 'sesameDot',
      '白ゴマ傍点': 'whiteSesameDot',
      '丸傍点': 'blackCircle',
      '白丸傍点': 'whiteCircle',
      '黒三角傍点': 'blackTriangle',
      '白三角傍点': 'whiteTriangle',
      '二重丸傍点': 'bullseye',
      '蛇の目傍点': 'fisheye',
      'ばつ傍点': 'saltire',
      '傍線': 'underlineSolid',
      '二重傍線': 'underlineDouble',
      '鎖線': 'underlineDotted',
      '破線': 'underlineDashed',
      '波線': 'underlineWave',
    };
    final variant = mapping[core];
    if (variant == null) {
      return null;
    }
    return _SpecParts(
      variant: variant,
      kind: core.endsWith('点') ? 'emphasis' : 'decoration',
      attributes: <String, String>{
        if (direction != 'default') 'direction': direction,
      },
    );
  }

  GaijiNode _buildGaijiNode({
    required _SourceMapper mapper,
    required String raw,
    required String body,
    required int start,
    required int end,
  }) {
    final jisCode = RegExp(r'(\d+-\d+-\d+)').firstMatch(body)?.group(1);
    final unicode = RegExp(r'U\+([0-9A-Fa-f]{4,6})').firstMatch(body)?.group(1);
    return GaijiNode(
      span: mapper.span(start, end),
      rawNotation: raw,
      description: body,
      jisCode: jisCode,
      unicodeCodePoint: unicode,
    );
  }

  _RubyBase? _takeRubyBase(
    List<InlineNode> siblings, {
    required int explicitRubyStartIndex,
    required _SourceMapper mapper,
    required int rubyStartOffset,
  }) {
    if (siblings.isEmpty) {
      return null;
    }

    if (explicitRubyStartIndex >= 0 &&
        explicitRubyStartIndex < siblings.length) {
      final nodes = siblings.sublist(explicitRubyStartIndex);
      siblings.removeRange(explicitRubyStartIndex, siblings.length);
      return _RubyBase(
        nodes: List<InlineNode>.unmodifiable(nodes),
        span: mapper.mergeSpans(nodes.first.span, nodes.last.span),
      );
    }

    final tail = _takeTrailingRubyNodes(siblings, mapper);
    return tail;
  }

  _RubyBase? _takeTrailingRubyNodes(
    List<InlineNode> siblings,
    _SourceMapper mapper,
  ) {
    if (siblings.isEmpty) {
      return null;
    }

    final matched = <InlineNode>[];
    while (siblings.isNotEmpty) {
      final candidate = siblings.removeLast();
      if (candidate is TextNode) {
        final split = _splitRubyText(candidate, mapper);
        if (split.matched != null) {
          if (split.remaining != null) {
            siblings.add(split.remaining!);
          }
          matched.insert(0, split.matched!);
          continue;
        }
        siblings.add(candidate);
        break;
      }
      if (_isRubyEligibleNode(candidate)) {
        matched.insert(0, candidate);
        continue;
      }
      siblings.add(candidate);
      break;
    }

    if (matched.isEmpty) {
      return null;
    }
    return _RubyBase(
      nodes: List<InlineNode>.unmodifiable(matched),
      span: mapper.mergeSpans(matched.first.span, matched.last.span),
    );
  }

  _SplitTextResult _splitRubyText(TextNode node, _SourceMapper mapper) {
    final text = node.text;
    var splitIndex = text.length;
    while (splitIndex > 0 && _isRubyBaseCharacter(text[splitIndex - 1])) {
      splitIndex -= 1;
    }
    if (splitIndex == text.length) {
      return const _SplitTextResult();
    }

    final remainingText = text.substring(0, splitIndex);
    final matchedText = text.substring(splitIndex);
    TextNode? remaining;
    if (remainingText.isNotEmpty) {
      remaining = TextNode(
        span: mapper.span(
          node.span.start.offset,
          node.span.start.offset + remainingText.length,
        ),
        text: remainingText,
      );
    }
    final matched = TextNode(
      span: mapper.span(
        node.span.start.offset + splitIndex,
        node.span.end.offset,
      ),
      text: matchedText,
    );
    return _SplitTextResult(remaining: remaining, matched: matched);
  }

  bool _isRubyEligibleNode(InlineNode node) {
    return switch (node) {
      TextNode() => true,
      GaijiNode() => true,
      InlineContainerNode() => true,
      InlineAnnotationNode() => true,
      _ => false,
    };
  }

  _TargetTail? _takeTargetTail(
    List<InlineNode> siblings,
    String targetText,
    _SourceMapper mapper,
  ) {
    if (siblings.isEmpty) {
      return null;
    }

    var remaining = targetText;
    final matched = <InlineNode>[];
    while (siblings.isNotEmpty && remaining.isNotEmpty) {
      final candidate = siblings.removeLast();
      final plain = _plainText(candidate);
      if (plain.isEmpty) {
        siblings.add(candidate);
        break;
      }

      if (remaining.endsWith(plain)) {
        matched.insert(0, candidate);
        remaining = remaining.substring(0, remaining.length - plain.length);
        continue;
      }

      if (candidate is TextNode && plain.endsWith(remaining)) {
        final splitPoint = plain.length - remaining.length;
        final leading = plain.substring(0, splitPoint);
        if (leading.isNotEmpty) {
          siblings.add(
            TextNode(
              span: mapper.span(
                candidate.span.start.offset,
                candidate.span.start.offset + leading.length,
              ),
              text: leading,
            ),
          );
        }
        matched.insert(
          0,
          TextNode(
            span: mapper.span(
              candidate.span.start.offset + splitPoint,
              candidate.span.end.offset,
            ),
            text: remaining,
          ),
        );
        remaining = '';
        continue;
      }

      siblings.add(candidate);
      break;
    }

    if (remaining.isNotEmpty || matched.isEmpty) {
      return null;
    }

    return _TargetTail(
      nodes: List<InlineNode>.unmodifiable(matched),
      span: mapper.mergeSpans(matched.first.span, matched.last.span),
    );
  }

  String _plainText(InlineNode node) {
    return switch (node) {
      TextNode(:final text) => text,
      GaijiNode(:final rawNotation) => rawNotation,
      InlineContainerNode(:final children) => children.map(_plainText).join(),
      InlineAnnotationNode(:final text) => text,
      RubyNode(:final base) => base.map(_plainText).join(),
      _ => '',
    };
  }

  String _decodeAccentText(String input) {
    final output = StringBuffer();
    var index = 0;
    while (index < input.length) {
      final matched = _matchAccentSequence(input, index);
      if (matched != null) {
        output.write(matched.value);
        index += matched.length;
      } else {
        output.write(input[index]);
        index += 1;
      }
    }
    return output.toString();
  }

  _AccentMatch? _matchAccentSequence(String input, int index) {
    if (index + 1 >= input.length) {
      return null;
    }
    final twoChar = input.substring(index, index + 2);
    final twoMap = <String, String>{'!@': '¡', '?@': '¿', 's&': 'ß'};
    final twoValue = twoMap[twoChar];
    if (twoValue != null) {
      return _AccentMatch(twoValue, 2);
    }

    if (index + 2 < input.length) {
      final threeChar = input.substring(index, index + 3);
      final threeMap = <String, String>{
        'AE&': 'Æ',
        'ae&': 'æ',
        'OE&': 'Œ',
        'oe&': 'œ',
      };
      final threeValue = threeMap[threeChar];
      if (threeValue != null) {
        return _AccentMatch(threeValue, 3);
      }
    }

    final pair = input.substring(index, index + 2);
    final composed = switch (pair) {
      'A`' => 'À',
      "A'" => 'Á',
      'A^' => 'Â',
      'A~' => 'Ã',
      'A:' => 'Ä',
      'A&' => 'Å',
      'A_' => 'Ā',
      'C,' => 'Ç',
      'E`' => 'È',
      "E'" => 'É',
      'E^' => 'Ê',
      'E:' => 'Ë',
      'E_' => 'Ē',
      'I`' => 'Ì',
      "I'" => 'Í',
      'I^' => 'Î',
      'I:' => 'Ï',
      'I_' => 'Ī',
      'N~' => 'Ñ',
      'O`' => 'Ò',
      "O'" => 'Ó',
      'O^' => 'Ô',
      'O~' => 'Õ',
      'O:' => 'Ö',
      'O/' => 'Ø',
      'O_' => 'Ō',
      'U`' => 'Ù',
      "U'" => 'Ú',
      'U^' => 'Û',
      'U:' => 'Ü',
      'U_' => 'Ū',
      "Y'" => 'Ý',
      'a`' => 'à',
      "a'" => 'á',
      'a^' => 'â',
      'a~' => 'ã',
      'a:' => 'ä',
      'a&' => 'å',
      'a_' => 'ā',
      'c,' => 'ç',
      'e`' => 'è',
      "e'" => 'é',
      'e^' => 'ê',
      'e:' => 'ë',
      'e_' => 'ē',
      'i`' => 'ì',
      "i'" => 'í',
      'i^' => 'î',
      'i:' => 'ï',
      'i_' => 'ī',
      'n~' => 'ñ',
      'o`' => 'ò',
      "o'" => 'ó',
      'o^' => 'ô',
      'o~' => 'õ',
      'o:' => 'ö',
      'o/' => 'ø',
      'o_' => 'ō',
      'u`' => 'ù',
      "u'" => 'ú',
      'u^' => 'û',
      'u:' => 'ü',
      'u_' => 'ū',
      "y'" => 'ý',
      'y:' => 'ÿ',
      _ => '',
    };
    if (composed.isEmpty) {
      return null;
    }
    return _AccentMatch(composed, 2);
  }

  int _findNextSpecialIndex(String line, int from) {
    final candidates = <int>[
      line.indexOf('※$_directiveOpen', from),
      line.indexOf(_directiveOpen, from),
      line.indexOf(_rubyOpen, from),
      line.indexOf(_rubyExplicitMarker, from),
      line.indexOf(_accentOpen, from),
    ].where((value) => value >= 0).toList();
    if (candidates.isEmpty) {
      return line.length;
    }
    candidates.sort();
    return candidates.first;
  }

  bool _isRubyBaseCharacter(String char) {
    return !RegExp(r'[\s、。，．,.「」『』（）()［］【】〈〉《》!?！？…―ー]').hasMatch(char);
  }

  int? _parseLength(String raw) {
    final normalized = raw
        .replaceAll('０', '0')
        .replaceAll('１', '1')
        .replaceAll('２', '2')
        .replaceAll('３', '3')
        .replaceAll('４', '4')
        .replaceAll('５', '5')
        .replaceAll('６', '6')
        .replaceAll('７', '7')
        .replaceAll('８', '8')
        .replaceAll('９', '9');
    if (RegExp(r'^\d+$').hasMatch(normalized)) {
      return int.parse(normalized);
    }

    final digits = <String, int>{
      '〇': 0,
      '一': 1,
      '二': 2,
      '三': 3,
      '四': 4,
      '五': 5,
      '六': 6,
      '七': 7,
      '八': 8,
      '九': 9,
    };
    final units = <String, int>{'十': 10, '百': 100, '千': 1000};
    var total = 0;
    var current = 0;
    for (final char in raw.split('')) {
      if (digits.containsKey(char)) {
        current = digits[char]!;
        continue;
      }
      if (units.containsKey(char)) {
        total += (current == 0 ? 1 : current) * units[char]!;
        current = 0;
        continue;
      }
      return null;
    }
    return total + current;
  }
}

extension on SourceDirective {
  SourceDirective copyWith({String? category, AstAttributes? attributes}) {
    return SourceDirective(
      format: format,
      rawText: rawText,
      body: body,
      span: span,
      category: category ?? this.category,
      attributes: attributes ?? this.attributes,
    );
  }
}

class _SourceMapper {
  _SourceMapper(this.source) : _lineStarts = _buildLineStarts(source);

  final String source;
  final List<int> _lineStarts;

  SourceSpan span(int start, int end) {
    return SourceSpan(start: _locationOf(start), end: _locationOf(end));
  }

  SourceSpan mergeSpans(SourceSpan first, SourceSpan? second) {
    if (second == null) {
      return first;
    }
    return SourceSpan(start: first.start, end: second.end);
  }

  SourceLocation _locationOf(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low <= high) {
      final mid = (low + high) >> 1;
      final lineStart = _lineStarts[mid];
      final nextLineStart = mid + 1 < _lineStarts.length
          ? _lineStarts[mid + 1]
          : source.length + 1;
      if (offset < lineStart) {
        high = mid - 1;
      } else if (offset >= nextLineStart) {
        low = mid + 1;
      } else {
        return SourceLocation(
          offset: offset,
          line: mid + 1,
          column: offset - lineStart + 1,
        );
      }
    }
    final lastStart = _lineStarts.isEmpty ? 0 : _lineStarts.last;
    return SourceLocation(
      offset: offset,
      line: _lineStarts.length,
      column: offset - lastStart + 1,
    );
  }

  static List<int> _buildLineStarts(String source) {
    final starts = <int>[0];
    for (var i = 0; i < source.length; i += 1) {
      if (source[i] == '\n') {
        starts.add(i + 1);
      }
    }
    return starts;
  }
}

class _BlockFrame {
  _BlockFrame({
    required this.kind,
    required this.variant,
    required this.attributes,
    required this.closeMatcher,
    required this.openDirective,
  });

  final String kind;
  final String? variant;
  final AstAttributes attributes;
  final bool Function(_BlockFrame frame) closeMatcher;
  final SourceDirective openDirective;
  final List<BlockNode> children = <BlockNode>[];
}

class _InlineFrame {
  _InlineFrame.root()
    : openBody = '',
      kind = 'root',
      variant = null,
      attributes = const <String, String>{},
      openDirective = null;

  _InlineFrame.container({
    required this.openBody,
    required this.kind,
    required this.variant,
    required this.attributes,
    required this.openDirective,
  });

  _InlineFrame.pendingRubyAnnotation({required this.openDirective})
    : openBody = '注記付き',
      kind = 'rubyAnnotationPending',
      variant = 'annotation',
      attributes = const <String, String>{};

  final String openBody;
  final String kind;
  final String? variant;
  final AstAttributes attributes;
  final SourceDirective? openDirective;
  final List<InlineNode> children = <InlineNode>[];

  bool matches(String body) => openBody == body;
}

class _BlockOpenSpec {
  const _BlockOpenSpec({
    required this.kind,
    this.variant,
    this.attributes = const <String, String>{},
    required this.closeMatcher,
  });

  final String kind;
  final String? variant;
  final AstAttributes attributes;
  final bool Function(_BlockFrame frame) closeMatcher;
}

class _BlockCloseSpec {
  const _BlockCloseSpec(this.matches);

  final bool Function(_BlockFrame frame) matches;
}

class _InlineOpenSpec {
  const _InlineOpenSpec({
    required this.kind,
    this.variant,
    this.attributes = const <String, String>{},
  });

  final String kind;
  final String? variant;
  final AstAttributes attributes;
}

class _SpecParts {
  const _SpecParts({
    required this.variant,
    this.kind = 'style',
    this.attributes = const <String, String>{},
  });

  final String kind;
  final String variant;
  final AstAttributes attributes;
}

class _RubyBase {
  const _RubyBase({required this.nodes, required this.span});

  final List<InlineNode> nodes;
  final SourceSpan span;
}

class _TargetTail {
  const _TargetTail({required this.nodes, required this.span});

  final List<InlineNode> nodes;
  final SourceSpan span;
}

class _SplitTextResult {
  const _SplitTextResult({this.remaining, this.matched});

  final TextNode? remaining;
  final TextNode? matched;
}

class _AccentMatch {
  const _AccentMatch(this.value, this.length);

  final String value;
  final int length;
}

void _appendInline(List<InlineNode> nodes, InlineNode node) {
  if (node is TextNode &&
      nodes.isNotEmpty &&
      nodes.last is TextNode &&
      nodes.last.span.end.offset == node.span.start.offset) {
    final previous = nodes.removeLast() as TextNode;
    nodes.add(
      TextNode(
        span: SourceSpan(start: previous.span.start, end: node.span.end),
        text: previous.text + node.text,
      ),
    );
    return;
  }
  nodes.add(node);
}
