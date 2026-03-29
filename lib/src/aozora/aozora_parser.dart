import '../ast/ast.dart';

typedef _BuildBlockNode =
    BlockNode Function(
      SourceSpan span,
      List<BlockNode> children,
      SourceDirective openDirective,
      SourceDirective? closeDirective,
      bool isClosed,
    );

typedef _BuildInlineNode =
    InlineNode Function(
      SourceSpan span,
      List<InlineNode> children,
      SourceDirective openDirective,
      SourceDirective? closeDirective,
      bool isClosed,
    );

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

    if (normalized.isNotEmpty) {
      var lineStart = 0;
      while (lineStart < normalized.length) {
        final lineEnd = normalized.indexOf('\n', lineStart);
        final endOffset = lineEnd >= 0 ? lineEnd : normalized.length;
        var line = normalized.substring(lineStart, endOffset);
        final lineSpan = mapper.span(lineStart, endOffset);
        var keepWithPrevious = false;

        if (line.startsWith('‌')) {
          keepWithPrevious = true;
          line = line.substring(1);
        }

        if (line.isEmpty) {
          addBlock(EmptyLineNode(span: lineSpan));
        } else {
          final directive = _parseWholeLineDirective(line, lineStart, mapper);
          if (directive != null && _looksLikeBlockDirective(directive.body)) {
            final handled = _handleDirectiveLine(
              directive,
              blockStack,
              addBlock,
              mapper,
              diagnostics,
            );
            if (!handled) {
              addBlock(
                OpaqueBlockNode(span: directive.span, directive: directive),
              );
            }
          } else {
            addBlock(
              _parseParagraph(
                line,
                lineStart,
                mapper,
                diagnostics,
                keepWithPrevious: keepWithPrevious,
              ),
            );
          }
        }

        if (lineEnd < 0) {
          break;
        }
        lineStart = lineEnd + 1;
      }
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
      final node = frame.buildNode(
        span,
        List<BlockNode>.unmodifiable(frame.children),
        frame.openDirective,
        null,
        false,
      );
      addBlock(node);
    }

    return DocumentNode(
      span: mapper.span(0, normalized.length),
      children: List<BlockNode>.unmodifiable(rootBlocks),
      diagnostics: List<AstDiagnostic>.unmodifiable(diagnostics),
    );
  }

  ParagraphNode _parseParagraph(
    String line,
    int lineStartOffset,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics, {
    bool keepWithPrevious = false,
  }) {
    final root = _InlineFrame.root();
    final stack = <_InlineFrame>[root];
    var explicitRubyStartIndex = -1;
    var hadOrphanInlineClose = false;
    var index = 0;

    void addInline(InlineNode node) {
      _appendInline(stack.last.children, node);
    }

    void addTextRange(String text, int start, int end) {
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
        final directiveEnd = _findDirectiveEnd(line, index + 1);
        if (directiveEnd >= 0) {
          final raw = line.substring(index, directiveEnd + 1);
          final body = line.substring(index + 3, directiveEnd);
          addInline(
            _buildGaijiOrUnresolvedNode(
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
        final directiveEnd = _findDirectiveEnd(line, index);
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
          );
          if (!handled) {
            if (directive.body.endsWith('終わり')) {
              hadOrphanInlineClose = true;
            }
            addInline(
              OpaqueInlineNode(span: directive.span, directive: directive),
            );
          }
          index = directiveEnd + 1;
          continue;
        }
      }

      if (line.startsWith(_accentOpen, index)) {
        final accentEnd = line.indexOf(_accentClose, index + 1);
        if (accentEnd >= 0) {
          final content = line.substring(index + 1, accentEnd);
          final nodes = _parseAccentNodes(
            content: content,
            contentStartOffset: lineStartOffset + index + 1,
            mapper: mapper,
          );
          for (final node in nodes) {
            addInline(node);
          }
          index = accentEnd + 1;
          continue;
        }
        diagnostics.add(
          AstDiagnostic(
            code: 'unclosed_accent_bracket',
            message: 'Accent bracket was not closed before end of line.',
            severity: AstDiagnosticSeverity.warning,
            span: mapper.span(
              lineStartOffset + index,
              lineStartOffset + line.length,
            ),
          ),
        );
        addTextRange(line.substring(index), index, line.length);
        index = line.length;
        continue;
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
      addTextRange(line.substring(index, next), index, next);
      index = next;
    }

    while (stack.length > 1) {
      final frame = stack.removeLast();
      if (!hadOrphanInlineClose) {
        diagnostics.add(
          AstDiagnostic(
            code: 'inline_container_crossed_line',
            message:
                'Inline directive crossed a line break. Use a block directive instead.',
            severity: AstDiagnosticSeverity.warning,
            span: frame.openDirective!.span,
          ),
        );
      }
      if (frame.kind == _InlineScopeKind.pendingRubyAnnotation) {
        _appendInline(
          stack.last.children,
          OpaqueInlineNode(
            span: frame.openDirective!.span,
            directive: frame.openDirective!,
          ),
        );
        for (final child in frame.children) {
          _appendInline(stack.last.children, child);
        }
        continue;
      }
      _appendInline(
        stack.last.children,
        _finalizeInlineFrame(
          frame,
          mapper: mapper,
          closeDirective: null,
          isClosed: false,
        ),
      );
    }

    return ParagraphNode(
      span: mapper.span(lineStartOffset, lineStartOffset + line.length),
      children: List<InlineNode>.unmodifiable(root.children),
      keepWithPrevious: keepWithPrevious,
    );
  }

  bool _handleDirectiveLine(
    SourceDirective directive,
    List<_BlockFrame> stack,
    void Function(BlockNode block) addBlock,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics,
  ) {
    final openSpec = _parseBlockOpenDirective(directive, diagnostics);
    if (openSpec != null) {
      stack.add(
        _BlockFrame(
          openSpec: openSpec,
          openDirective: directive.copyWith(
            category: SourceDirectiveCategory.blockOpen,
          ),
        ),
      );
      return true;
    }

    final closeSpec = _parseBlockCloseDirective(directive);
    if (closeSpec == null) {
      return false;
    }
    if (stack.isEmpty || stack.last.kind != closeSpec.kind) {
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
    addBlock(
      frame.buildNode(
        span,
        List<BlockNode>.unmodifiable(frame.children),
        frame.openDirective,
        directive.copyWith(category: SourceDirectiveCategory.blockClose),
        true,
      ),
    );
    return true;
  }

  bool _handleInlineDirective(
    SourceDirective directive,
    List<_InlineFrame> stack,
    _SourceMapper mapper,
    List<AstDiagnostic> diagnostics,
  ) {
    if (directive.body == '改行') {
      _appendInline(
        stack.last.children,
        LineBreakNode(
          span: directive.span,
          sourceDirective: directive.copyWith(
            category: SourceDirectiveCategory.inlineLineBreak,
          ),
        ),
      );
      return true;
    }

    if (directive.body == '注記付き') {
      stack.add(
        _InlineFrame.pendingRubyAnnotation(
          openDirective: directive.copyWith(
            category: SourceDirectiveCategory.inlineOpen,
          ),
        ),
      );
      return true;
    }

    final noteClose = RegExp(r'^「(.+)」の注記付き終わり$').firstMatch(directive.body);
    if (noteClose != null &&
        stack.length > 1 &&
        stack.last.kind == _InlineScopeKind.pendingRubyAnnotation) {
      final frame = stack.removeLast();
      final text = noteClose.group(1)!;
      final span = mapper.mergeSpans(frame.openDirective!.span, directive.span);
      _appendInline(
        stack.last.children,
        RubyNode(
          span: span,
          base: List<InlineNode>.unmodifiable(frame.children),
          text: text,
          kind: RubyKind.annotation,
          position: RubyPosition.over,
          sourceDirective: directive.copyWith(
            category: SourceDirectiveCategory.inlineClose,
          ),
        ),
      );
      return true;
    }

    if (directive.body.endsWith('終わり')) {
      final openBody = directive.body.substring(0, directive.body.length - 3);
      if (stack.length > 1 && stack.last.openBody == openBody) {
        final frame = stack.removeLast();
        _appendInline(
          stack.last.children,
          _finalizeInlineFrame(
            frame,
            mapper: mapper,
            closeDirective: directive.copyWith(
              category: SourceDirectiveCategory.inlineClose,
            ),
            isClosed: true,
          ),
        );
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

    if (_tryApplyTargetDirective(
      directive,
      stack.last.children,
      mapper,
      diagnostics,
    )) {
      return true;
    }

    final leafNode = _parseInlineLeafDirective(directive);
    if (leafNode != null) {
      _appendInline(stack.last.children, leafNode);
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
        buildNode: openSpec.buildNode,
        openDirective: directive.copyWith(
          category: SourceDirectiveCategory.inlineOpen,
        ),
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
    final match = RegExp(
      r'^「([^「」]*(?:「.+」)*[^「」]*)」[にはの](「.+」の)*(.+)$',
    ).firstMatch(directive.body);
    if (match == null) {
      return false;
    }

    final originalSiblings = List<InlineNode>.from(siblings);
    final targetText = match.group(1)!;
    final actionPrefix = match.group(2);
    final action = actionPrefix == null
        ? match.group(3)!
        : '$actionPrefix${match.group(3)!}';
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
      siblings
        ..clear()
        ..addAll(originalSiblings);
      return false;
    }

    final referenceDirective = directive.copyWith(
      category: SourceDirectiveCategory.inlineReference,
    );
    final rubyDirectional = RegExp(
      r'^(左|右|上|下)に「(.+?)」の(ルビ|注記)$',
    ).firstMatch(action);
    if (rubyDirectional != null) {
      _appendInline(
        siblings,
        RubyNode(
          span: mapper.mergeSpans(base.span, directive.span),
          base: base.nodes,
          text: rubyDirectional.group(2)!,
          kind: rubyDirectional.group(3)! == '注記'
              ? RubyKind.annotation
              : RubyKind.phonetic,
          position: _rubyPositionFromKanji(rubyDirectional.group(1)!),
          sourceDirective: referenceDirective,
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
          sourceDirective: referenceDirective,
        ),
      );
      return true;
    }

    final boukiMatch = RegExp(r'^「(.)」の傍記$').firstMatch(action);
    if (boukiMatch != null) {
      final mark = boukiMatch.group(1)!;
      _appendInline(
        siblings,
        RubyNode(
          span: mapper.mergeSpans(base.span, directive.span),
          base: base.nodes,
          text: List<String>.filled(
            _plainTextListLength(base.nodes),
            mark,
          ).join(' '),
          kind: RubyKind.annotation,
          position: RubyPosition.over,
          sourceDirective: referenceDirective,
        ),
      );
      return true;
    }

    final script = _parseScriptAction(action);
    if (script != null) {
      _appendInline(
        siblings,
        ScriptInlineNode(
          span: mapper.mergeSpans(base.span, directive.span),
          kind: script,
          text: _plainTextFromNodes(base.nodes),
          sourceDirective: referenceDirective,
        ),
      );
      return true;
    }

    final openSpec = _parseInlineOpenDirective(action);
    if (openSpec != null) {
      _appendInline(
        siblings,
        openSpec.buildNode(
          mapper.mergeSpans(base.span, directive.span),
          base.nodes,
          referenceDirective,
          null,
          true,
        ),
      );
      return true;
    }

    siblings
      ..clear()
      ..addAll(originalSiblings);
    _appendInline(
      siblings,
      EditorNoteNode(
        span: directive.span,
        text: directive.body,
        sourceDirective: directive,
      ),
    );
    return true;
  }

  InlineNode? _parseInlineLeafDirective(SourceDirective directive) {
    final image = _parseImageDirective(directive);
    if (image != null) {
      return image;
    }

    final unresolvedGaiji = _parseStandaloneUnresolvedGaijiDirective(directive);
    if (unresolvedGaiji != null) {
      return unresolvedGaiji;
    }

    if (_kaeritenPattern.hasMatch(directive.body)) {
      return KaeritenNode(
        span: directive.span,
        text: directive.body,
        sourceDirective: directive,
      );
    }

    final okurigana = RegExp(r'^（(.+)）$').firstMatch(directive.body);
    if (okurigana != null) {
      return OkuriganaNode(
        span: directive.span,
        text: okurigana.group(1)!,
        sourceDirective: directive,
      );
    }

    if (_isEditorNoteDirective(directive.body)) {
      return EditorNoteNode(
        span: directive.span,
        text: directive.body,
        sourceDirective: directive,
      );
    }

    return null;
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
    return frame.buildNode!(
      span,
      List<InlineNode>.unmodifiable(frame.children),
      frame.openDirective!,
      closeDirective,
      isClosed,
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

  bool _looksLikeBlockDirective(String body) {
    return body.startsWith('ここから') || body.startsWith('ここで');
  }

  _BlockOpenSpec? _parseBlockOpenDirective(
    SourceDirective directive,
    List<AstDiagnostic> diagnostics,
  ) {
    if (!directive.body.startsWith('ここから')) {
      return null;
    }
    final inner = directive.body.substring('ここから'.length);

    final indent = _parseIndent(inner);
    if (indent != null) {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.indent,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            IndentBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              width: indent,
            ),
      );
    }

    final jizume = _parseJizume(inner);
    if (jizume != null) {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.jizume,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            JizumeBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              width: jizume,
            ),
      );
    }

    if (inner == '地付き' || inner == '字上げ') {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.alignment,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            AlignmentBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: inner == '地付き'
                  ? BlockAlignmentKind.chitsuki
                  : BlockAlignmentKind.jiage,
            ),
      );
    }

    if (inner == '横組み') {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.flow,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            FlowBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: FlowKind.yokogumi,
            ),
      );
    }

    final frame = _parseFrame(inner);
    if (frame != null) {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.frame,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            FrameBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: FrameKind.keigakomi,
              borderWidth: frame,
            ),
      );
    }

    if (inner == 'キャプション') {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.caption,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            CaptionBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
            ),
      );
    }

    final style = _parseTextStyle(inner);
    if (style != null) {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.style,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            StyledBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              style: style,
            ),
      );
    }

    final fontSize = _parseFontSize(inner);
    if (fontSize != null) {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.fontSize,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            FontSizeBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: fontSize.kind,
              steps: fontSize.steps,
            ),
      );
    }
    if (_looksLikeFontSize(inner)) {
      diagnostics.add(
        AstDiagnostic(
          code: 'invalid_font_size',
          message: 'Font size directive is invalid.',
          severity: AstDiagnosticSeverity.warning,
          span: directive.span,
        ),
      );
      return null;
    }

    final heading = _parseHeading(inner);
    if (heading != null) {
      return _BlockOpenSpec(
        kind: _BlockScopeKind.heading,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            HeadingBlockNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              level: heading.level,
              display: heading.display,
            ),
      );
    }
    if (inner.contains('見出し')) {
      diagnostics.add(
        AstDiagnostic(
          code: 'invalid_heading',
          message: 'Heading directive is invalid.',
          severity: AstDiagnosticSeverity.warning,
          span: directive.span,
        ),
      );
    }

    return null;
  }

  _BlockCloseSpec? _parseBlockCloseDirective(SourceDirective directive) {
    if (!directive.body.startsWith('ここで') || !directive.body.endsWith('終わり')) {
      return null;
    }
    final target = directive.body.substring(
      'ここで'.length,
      directive.body.length - '終わり'.length,
    );
    if (target == '字下げ') {
      return const _BlockCloseSpec(_BlockScopeKind.indent);
    }
    if (target == '地付き' || target == '字上げ') {
      return const _BlockCloseSpec(_BlockScopeKind.alignment);
    }
    if (target == '字詰め') {
      return const _BlockCloseSpec(_BlockScopeKind.jizume);
    }
    if (target == '横組み') {
      return const _BlockCloseSpec(_BlockScopeKind.flow);
    }
    if (_parseFrame(target) != null) {
      return const _BlockCloseSpec(_BlockScopeKind.frame);
    }
    if (target == 'キャプション') {
      return const _BlockCloseSpec(_BlockScopeKind.caption);
    }
    if (_parseTextStyle(target) != null) {
      return const _BlockCloseSpec(_BlockScopeKind.style);
    }
    if (_parseHeading(target) != null) {
      return const _BlockCloseSpec(_BlockScopeKind.heading);
    }
    if (_parseFontSize(target) != null) {
      return const _BlockCloseSpec(_BlockScopeKind.fontSize);
    }
    return null;
  }

  _InlineOpenSpec? _parseInlineOpenDirective(String body) {
    if (body == '縦中横') {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.direction,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            DirectionInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: DirectionKind.tateChuYoko,
            ),
      );
    }
    if (body == '横組み') {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.flow,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            FlowInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: FlowKind.yokogumi,
            ),
      );
    }
    final frame = _parseFrame(body);
    if (frame != null) {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.frame,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            FrameInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: FrameKind.keigakomi,
              borderWidth: frame,
            ),
      );
    }
    if (body == 'キャプション') {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.caption,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            CaptionInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
            ),
      );
    }
    if (body == '割り注' || body == '割書') {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.note,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            NoteInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: body == '割り注' ? NoteKind.warichu : NoteKind.warigaki,
            ),
      );
    }
    final style = _parseTextStyle(body);
    if (style != null) {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.style,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            StyledInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              style: style,
            ),
      );
    }
    final fontSize = _parseFontSize(body);
    if (fontSize != null) {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.fontSize,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            FontSizeInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: fontSize.kind,
              steps: fontSize.steps,
            ),
      );
    }
    final heading = _parseHeading(body);
    if (heading != null) {
      return _InlineOpenSpec(
        kind: _InlineScopeKind.heading,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            HeadingInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              level: heading.level,
              display: heading.display,
            ),
      );
    }
    final decoration = _parseDecoration(body);
    if (decoration != null) {
      return _InlineOpenSpec(
        kind: decoration.scopeKind,
        buildNode: decoration.buildNode,
      );
    }
    return null;
  }

  TextStyleKind? _parseTextStyle(String body) {
    return switch (body) {
      '太字' => TextStyleKind.bold,
      '斜体' => TextStyleKind.italic,
      _ => null,
    };
  }

  int? _parseIndent(String body) {
    final match = RegExp(r'^(.+?)字下げ$').firstMatch(body);
    if (match == null) {
      return null;
    }
    return _parseLength(match.group(1)!);
  }

  int? _parseJizume(String body) {
    final match = RegExp(r'^(.+?)字詰め$').firstMatch(body);
    if (match == null) {
      return null;
    }
    return _parseLength(match.group(1)!);
  }

  int? _parseFrame(String body) {
    if (body == '罫囲み') {
      return 1;
    }
    if (body == '2重罫囲み') {
      return 2;
    }
    return null;
  }

  _ParsedHeading? _parseHeading(String body) {
    final display = switch (true) {
      _ when body.startsWith('同行') => HeadingDisplay.dogyo,
      _ when body.startsWith('窓') => HeadingDisplay.mado,
      _ => HeadingDisplay.normal,
    };
    final stripped = switch (display) {
      HeadingDisplay.dogyo => body.substring('同行'.length),
      HeadingDisplay.mado => body.substring('窓'.length),
      HeadingDisplay.normal => body,
    };
    final level = switch (stripped) {
      '小見出し' => HeadingLevel.small,
      '中見出し' => HeadingLevel.medium,
      '大見出し' => HeadingLevel.large,
      _ => null,
    };
    if (level == null) {
      return null;
    }
    return _ParsedHeading(level: level, display: display);
  }

  _ParsedFontSize? _parseFontSize(String body) {
    final match = RegExp(r'^(.+?)段階(..)な文字$').firstMatch(body);
    if (match == null) {
      return null;
    }
    final steps = _parseLength(match.group(1)!);
    if (steps == null || steps <= 0) {
      return null;
    }
    final kind = switch (match.group(2)!) {
      '大き' => FontSizeKind.larger,
      '小さ' => FontSizeKind.smaller,
      _ => null,
    };
    if (kind == null) {
      return null;
    }
    return _ParsedFontSize(kind: kind, steps: steps);
  }

  bool _looksLikeFontSize(String body) {
    return body.contains('段階') && body.endsWith('な文字');
  }

  _ParsedDecoration? _parseDecoration(String body) {
    var core = body;
    var side = EmphasisSide.auto;
    var decorationSide = DecorationSide.auto;

    final directionMatch = RegExp(r'^(右|左|上|下)に(.+)$').firstMatch(body);
    if (directionMatch != null) {
      core = directionMatch.group(2)!;
      side = _emphasisSideFromKanji(directionMatch.group(1)!);
      decorationSide = _decorationSideFromKanji(directionMatch.group(1)!);
    }

    final emphasis = <String, EmphasisMark>{
      '傍点': EmphasisMark.sesameDot,
      '白ゴマ傍点': EmphasisMark.whiteSesameDot,
      '丸傍点': EmphasisMark.blackCircle,
      '白丸傍点': EmphasisMark.whiteCircle,
      '黒三角傍点': EmphasisMark.blackTriangle,
      '白三角傍点': EmphasisMark.whiteTriangle,
      '二重丸傍点': EmphasisMark.bullseye,
      '蛇の目傍点': EmphasisMark.fisheye,
      'ばつ傍点': EmphasisMark.saltire,
    }[core];
    if (emphasis != null) {
      return _ParsedDecoration(
        scopeKind: _InlineScopeKind.emphasis,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            EmphasisInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              mark: emphasis,
              side: side,
            ),
      );
    }

    final decoration = <String, DecorationKind>{
      '傍線': DecorationKind.underlineSolid,
      '二重傍線': DecorationKind.underlineDouble,
      '鎖線': DecorationKind.underlineDotted,
      '破線': DecorationKind.underlineDashed,
      '波線': DecorationKind.underlineWave,
    }[core];
    if (decoration != null) {
      return _ParsedDecoration(
        scopeKind: _InlineScopeKind.decoration,
        buildNode: (span, children, openDirective, closeDirective, isClosed) =>
            DecorationInlineNode(
              span: span,
              children: children,
              openDirective: openDirective,
              closeDirective: closeDirective,
              isClosed: isClosed,
              kind: decoration,
              side: decorationSide,
            ),
      );
    }

    return null;
  }

  ScriptKind? _parseScriptAction(String action) {
    return switch (action) {
      '上付き小文字' => ScriptKind.superscript,
      '行右小書き' => ScriptKind.superscript,
      '下付き小文字' => ScriptKind.subscript,
      '行左小書き' => ScriptKind.subscript,
      _ => null,
    };
  }

  InlineNode _buildGaijiOrUnresolvedNode({
    required _SourceMapper mapper,
    required String raw,
    required String body,
    required int start,
    required int end,
  }) {
    final jisCode = RegExp(r'(\d+-\d+-\d+)').firstMatch(body)?.group(1);
    final unicode = RegExp(r'U\+([0-9A-Fa-f]{4,6})').firstMatch(body)?.group(1);
    if (jisCode == null && unicode == null) {
      return UnresolvedGaijiNode(
        span: mapper.span(start, end),
        rawNotation: raw,
        text: body,
      );
    }
    return GaijiNode(
      span: mapper.span(start, end),
      rawNotation: raw,
      description: body,
      jisCode: jisCode,
      unicodeCodePoint: unicode,
    );
  }

  UnresolvedGaijiNode? _parseStandaloneUnresolvedGaijiDirective(
    SourceDirective directive,
  ) {
    if (!directive.body.startsWith('「') ||
        !directive.body.contains('ページ数-行数')) {
      return null;
    }
    return UnresolvedGaijiNode(
      span: directive.span,
      rawNotation: '※${directive.rawText}',
      text: directive.body,
      sourceDirective: directive,
    );
  }

  ImageNode? _parseImageDirective(SourceDirective directive) {
    final match = RegExp(
      r'^(.*?)（([^、)]+\.png)(?:、横([0-9０-９]+)×縦([0-9０-９]+))?）入る$',
    ).firstMatch(directive.body);
    if (match == null) {
      return null;
    }
    final alt = match.group(1)!.trim();
    final width = match.group(3) == null ? null : _parseLength(match.group(3)!);
    final height = match.group(4) == null
        ? null
        : _parseLength(match.group(4)!);
    final className = switch (true) {
      _ when alt.contains('写真') => 'photo',
      _ => RegExp(r'(\S+)$').firstMatch(alt)?.group(1),
    };
    return ImageNode(
      span: directive.span,
      source: match.group(2)!,
      alt: alt.isEmpty ? null : alt,
      className: className,
      width: width,
      height: height,
      sourceDirective: directive,
    );
  }

  bool _isEditorNoteDirective(String body) {
    if (body == '注記付き') {
      return false;
    }
    return body.startsWith('注記') ||
        body.startsWith('ルビの') ||
        body.contains('底本') ||
        body.contains('ママ');
  }

  List<InlineNode> _parseAccentNodes({
    required String content,
    required int contentStartOffset,
    required _SourceMapper mapper,
  }) {
    final nodes = <InlineNode>[];
    var index = 0;
    var textStart = 0;
    while (index < content.length) {
      final match = _matchAccentSequence(content, index);
      if (match == null) {
        index += 1;
        continue;
      }
      if (textStart < index) {
        nodes.add(
          TextNode(
            span: mapper.span(
              contentStartOffset + textStart,
              contentStartOffset + index,
            ),
            text: content.substring(textStart, index),
          ),
        );
      }
      nodes.add(
        GaijiNode(
          span: mapper.span(
            contentStartOffset + index,
            contentStartOffset + index + match.length,
          ),
          rawNotation: match.raw,
          description: match.description,
          unicodeCodePoint: match.unicodeCodePoint,
        ),
      );
      index += match.length;
      textStart = index;
    }
    if (textStart < content.length) {
      nodes.add(
        TextNode(
          span: mapper.span(
            contentStartOffset + textStart,
            contentStartOffset + content.length,
          ),
          text: content.substring(textStart),
        ),
      );
    }
    return nodes;
  }

  _AccentSequence? _matchAccentSequence(String input, int index) {
    if (index + 1 >= input.length) {
      return null;
    }

    final twoChar = input.substring(index, index + 2);
    const twoMap = <String, (String, String)>{
      '!@': ('¡', '逆感嘆符'),
      '?@': ('¿', '逆疑問符'),
      's&': ('ß', 'エスツェット'),
    };
    final twoValue = twoMap[twoChar];
    if (twoValue != null) {
      return _AccentSequence(
        raw: twoChar,
        unicodeCodePoint: _unicodeCodePoint(twoValue.$1),
        description: twoValue.$2,
        length: 2,
      );
    }

    if (index + 2 < input.length) {
      final threeChar = input.substring(index, index + 3);
      const threeMap = <String, (String, String)>{
        'AE&': ('Æ', 'AE合字'),
        'ae&': ('æ', 'AE合字小文字'),
        'OE&': ('Œ', 'OE合字'),
        'oe&': ('œ', 'OE合字小文字'),
      };
      final threeValue = threeMap[threeChar];
      if (threeValue != null) {
        return _AccentSequence(
          raw: threeChar,
          unicodeCodePoint: _unicodeCodePoint(threeValue.$1),
          description: threeValue.$2,
          length: 3,
        );
      }
    }

    final accentName = switch (input[index + 1]) {
      '`' => 'グレーブアクセント',
      '\'' => 'アキュートアクセント',
      '^' => 'サーカムフレックスアクセント',
      '~' => 'チルダ',
      ':' => 'トレマ',
      '&' => 'リング',
      '_' => 'マクロン',
      ',' => 'セディーユ',
      '/' => 'スラッシュ',
      _ => null,
    };
    if (accentName == null) {
      return null;
    }

    final unicode = switch (twoChar) {
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
      _ => null,
    };
    if (unicode == null) {
      return null;
    }

    return _AccentSequence(
      raw: twoChar,
      unicodeCodePoint: _unicodeCodePoint(unicode),
      description: '$accentName付き${_accentLetterName(twoChar[0])}',
      length: 2,
    );
  }

  String _unicodeCodePoint(String value) {
    return value.runes.first.toRadixString(16).toUpperCase();
  }

  String _accentLetterName(String char) {
    if (char.toUpperCase() == char) {
      return char;
    }
    return '${char.toUpperCase()}小文字';
  }

  RubyPosition _rubyPositionFromKanji(String direction) {
    return switch (direction) {
      '左' => RubyPosition.left,
      '右' => RubyPosition.right,
      '下' => RubyPosition.under,
      _ => RubyPosition.over,
    };
  }

  EmphasisSide _emphasisSideFromKanji(String direction) {
    return switch (direction) {
      '左' => EmphasisSide.left,
      '右' => EmphasisSide.right,
      '下' => EmphasisSide.under,
      '上' => EmphasisSide.over,
      _ => EmphasisSide.auto,
    };
  }

  DecorationSide _decorationSideFromKanji(String direction) {
    return switch (direction) {
      '左' => DecorationSide.left,
      '右' => DecorationSide.right,
      '下' => DecorationSide.under,
      '上' => DecorationSide.over,
      _ => DecorationSide.auto,
    };
  }

  _RubyBase? _takeRubyBase(
    List<InlineNode> siblings, {
    required int explicitRubyStartIndex,
    required _SourceMapper mapper,
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

    return _takeTrailingRubyNodes(siblings, mapper);
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
          break;
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
    if (text.isEmpty) {
      return const _SplitTextResult();
    }

    var splitIndex = text.length;
    final tailClass = _rubyBaseClass(text[text.length - 1]);
    while (splitIndex > 0) {
      final char = text[splitIndex - 1];
      if (!_isRubyBaseCharacter(char) || _rubyBaseClass(char) != tailClass) {
        break;
      }
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
      UnresolvedGaijiNode() => true,
      DirectionInlineNode() => true,
      LinkNode() => true,
      FlowInlineNode() => true,
      CaptionInlineNode() => true,
      FrameInlineNode() => true,
      NoteInlineNode() => true,
      StyledInlineNode() => true,
      FontSizeInlineNode() => true,
      HeadingInlineNode() => true,
      EmphasisInlineNode() => true,
      DecorationInlineNode() => true,
      ScriptInlineNode() => true,
      KaeritenNode() => true,
      OkuriganaNode() => true,
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

    final working = List<InlineNode>.from(siblings);
    var remaining = targetText;
    final matched = <InlineNode>[];

    while (working.isNotEmpty && remaining.isNotEmpty) {
      final candidate = working.removeLast();
      final plain = _plainText(candidate);
      if (plain.isEmpty) {
        working.add(candidate);
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
          working.add(
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

      working.add(candidate);
      break;
    }

    if (remaining.isNotEmpty || matched.isEmpty) {
      return null;
    }

    siblings
      ..clear()
      ..addAll(working);
    return _TargetTail(
      nodes: List<InlineNode>.unmodifiable(matched),
      span: mapper.mergeSpans(matched.first.span, matched.last.span),
    );
  }

  int _plainTextListLength(List<InlineNode> nodes) {
    return _plainTextFromNodes(nodes).runes.length;
  }

  String _plainTextFromNodes(List<InlineNode> nodes) {
    return nodes.map(_plainText).join();
  }

  String _plainText(InlineNode node) {
    return switch (node) {
      TextNode(:final text) => text,
      GaijiNode(:final rawNotation) => rawNotation,
      UnresolvedGaijiNode(:final rawNotation) => rawNotation,
      LinkNode(:final children) => children.map(_plainText).join(),
      DirectionInlineNode(:final children) => children.map(_plainText).join(),
      FlowInlineNode(:final children) => children.map(_plainText).join(),
      CaptionInlineNode(:final children) => children.map(_plainText).join(),
      FrameInlineNode(:final children) => children.map(_plainText).join(),
      NoteInlineNode(:final children) => children.map(_plainText).join(),
      StyledInlineNode(:final children) => children.map(_plainText).join(),
      FontSizeInlineNode(:final children) => children.map(_plainText).join(),
      HeadingInlineNode(:final children) => children.map(_plainText).join(),
      EmphasisInlineNode(:final children) => children.map(_plainText).join(),
      DecorationInlineNode(:final children) => children.map(_plainText).join(),
      ScriptInlineNode(:final text) => text,
      KaeritenNode(:final text) => text,
      OkuriganaNode(:final text) => text,
      RubyNode(:final base) => base.map(_plainText).join(),
      _ => '',
    };
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

  int _findDirectiveEnd(String line, int start) {
    var depth = 0;
    for (var index = start; index < line.length; index += 1) {
      final char = line[index];
      if (char == '［') {
        depth += 1;
      } else if (char == '］') {
        depth -= 1;
        if (depth == 0) {
          return index;
        }
      }
    }
    return -1;
  }

  bool _isRubyBaseCharacter(String char) {
    return !RegExp(r'[\s、。，．,.「」『』（）()［］【】〈〉《》!?！？…―ー]').hasMatch(char);
  }

  _RubyBaseClass _rubyBaseClass(String char) {
    if (RegExp(r'[ぁ-んゝゞ]').hasMatch(char)) {
      return _RubyBaseClass.hiragana;
    }
    if (RegExp(r'[ァ-ンーヽヾヴ]').hasMatch(char)) {
      return _RubyBaseClass.katakana;
    }
    if (RegExp('[\\u3400-\\u9FFF\\uF900-\\uFAFF々〆〇ヶ]').hasMatch(char)) {
      return _RubyBaseClass.kanji;
    }
    if (RegExp(r'[A-Za-z0-9０-９Ａ-Ｚａ-ｚΑ-Ωα-ωА-Яа-я]').hasMatch(char) ||
        '−＆’，．#-\\&\','.contains(char)) {
      return _RubyBaseClass.latinOrNumber;
    }
    return _RubyBaseClass.other;
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

  static final RegExp _kaeritenPattern = RegExp(r'^[一二三四五六七八九十レ上中下甲乙丙丁天地人]+$');
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

enum _BlockScopeKind {
  indent,
  alignment,
  jizume,
  flow,
  frame,
  caption,
  style,
  heading,
  fontSize,
}

class _BlockFrame {
  _BlockFrame({required _BlockOpenSpec openSpec, required this.openDirective})
    : kind = openSpec.kind,
      buildNode = openSpec.buildNode;

  final _BlockScopeKind kind;
  final _BuildBlockNode buildNode;
  final SourceDirective openDirective;
  final List<BlockNode> children = <BlockNode>[];
}

class _BlockOpenSpec {
  const _BlockOpenSpec({required this.kind, required this.buildNode});

  final _BlockScopeKind kind;
  final _BuildBlockNode buildNode;
}

class _BlockCloseSpec {
  const _BlockCloseSpec(this.kind);

  final _BlockScopeKind kind;
}

enum _InlineScopeKind {
  root,
  pendingRubyAnnotation,
  direction,
  flow,
  frame,
  caption,
  note,
  style,
  heading,
  fontSize,
  emphasis,
  decoration,
}

class _InlineFrame {
  _InlineFrame.root()
    : openBody = '',
      kind = _InlineScopeKind.root,
      buildNode = null,
      openDirective = null;

  _InlineFrame.container({
    required this.openBody,
    required this.kind,
    required this.buildNode,
    required this.openDirective,
  });

  _InlineFrame.pendingRubyAnnotation({required this.openDirective})
    : openBody = '注記付き',
      kind = _InlineScopeKind.pendingRubyAnnotation,
      buildNode = null;

  final String openBody;
  final _InlineScopeKind kind;
  final _BuildInlineNode? buildNode;
  final SourceDirective? openDirective;
  final List<InlineNode> children = <InlineNode>[];
}

class _InlineOpenSpec {
  const _InlineOpenSpec({required this.kind, required this.buildNode});

  final _InlineScopeKind kind;
  final _BuildInlineNode buildNode;
}

class _ParsedHeading {
  const _ParsedHeading({required this.level, required this.display});

  final HeadingLevel level;
  final HeadingDisplay display;
}

class _ParsedFontSize {
  const _ParsedFontSize({required this.kind, required this.steps});

  final FontSizeKind kind;
  final int steps;
}

class _ParsedDecoration {
  const _ParsedDecoration({required this.scopeKind, required this.buildNode});

  final _InlineScopeKind scopeKind;
  final _BuildInlineNode buildNode;
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

class _AccentSequence {
  const _AccentSequence({
    required this.raw,
    required this.description,
    required this.length,
    this.unicodeCodePoint,
  });

  final String raw;
  final String description;
  final String? unicodeCodePoint;
  final int length;
}

enum _RubyBaseClass { hiragana, katakana, kanji, latinOrNumber, other }

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
