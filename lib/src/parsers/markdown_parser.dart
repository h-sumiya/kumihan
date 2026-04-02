import 'package:flutter/painting.dart';
import 'package:highlight/highlight.dart' as hl;
import 'package:markdown/markdown.dart' as md;

import '../ast.dart';
import '../document.dart';

class MarkdownParser {
  const MarkdownParser();

  static final RegExp _blockquoteAttributionPrefixPattern = RegExp(
    r'^(?:'
    r'[―—–-]{1,3}\s*'
    r'|[（(]\s*'
    r'|(?:出典|引用元|作者|作|著|訳|編|監修|原文|source|by|from)\s*[:：]\s*'
    r')(.+?)'
    r'(?:\s*[）)])?$',
    caseSensitive: false,
  );

  static const List<AstToken> _quotedSpacerLine = <AstToken>[AstText('　')];

  Document parse(String input) {
    final normalized = input
        .replaceAll(RegExp(r'(\r\n|\r)'), '\n')
        .replaceFirst(RegExp(r'\n$'), '');
    if (normalized.isEmpty) {
      return Document.fromAst(const <AstToken>[]);
    }

    final parser = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    final tokens = <AstToken>[];
    for (final node in parser.parse(normalized)) {
      _appendBlock(tokens, _parseBlock(node));
    }
    return Document.fromAst(tokens);
  }

  void _appendBlock(List<AstToken> output, List<AstToken> block) {
    if (block.isEmpty) {
      return;
    }
    if (output.isNotEmpty && output.last is! AstNewLine) {
      output.add(const AstNewLine());
    }
    output.addAll(block);
  }

  List<AstToken> _parseBlock(md.Node node) {
    if (node is md.Text) {
      return _paragraphTokensFromText(node.text);
    }
    if (node is! md.Element) {
      return const <AstToken>[];
    }

    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _headingTokens(node);
      case 'p':
        return _paragraphTokensFromInlines(_parseInlineChildren(node.children));
      case 'blockquote':
        return _blockquoteTokens(node);
      case 'ul':
        return _listTokens(node, ordered: false);
      case 'ol':
        return _listTokens(node, ordered: true);
      case 'pre':
        return _codeBlockTokens(node);
      case 'table':
        return _tableTokens(node);
      case 'img':
        return _paragraphTokensFromInlines(_parseInline(node));
      case 'hr':
        return _paragraphTokensFromInlines(const <AstToken>[AstText('――――')]);
      default:
        return _paragraphTokensFromText(node.textContent);
    }
  }

  List<AstToken> _headingTokens(md.Element node) {
    final level = _headingLevel(node.tag);
    return <AstToken>[
      AstHeading(
        boundary: AstRangeBoundary.start,
        form: AstHeadingForm.standalone,
        level: level,
      ),
      ..._parseInlineChildren(node.children),
      AstHeading(
        boundary: AstRangeBoundary.end,
        form: AstHeadingForm.standalone,
        level: level,
      ),
    ];
  }

  List<AstToken> _listTokens(
    md.Element list, {
    required bool ordered,
    int depth = 0,
  }) {
    final tokens = <AstToken>[];
    var index = 1;
    for (final child in list.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'li') {
        continue;
      }
      _appendBlock(
        tokens,
        _listItemTokens(
          child,
          depth: depth,
          prefix: ordered ? _orderedPrefix(index) : '・',
        ),
      );
      index += 1;
    }
    return tokens;
  }

  List<AstToken> _listItemTokens(
    md.Element item, {
    required int depth,
    required String prefix,
  }) {
    final bodyTokens = <AstToken>[];
    final nestedTokens = <AstToken>[];
    final pendingInlineNodes = <md.Node>[];
    var hasBody = false;

    void appendBody(List<AstToken> tokens) {
      if (tokens.isEmpty) {
        return;
      }
      if (bodyTokens.isNotEmpty && bodyTokens.last is! AstNewLine) {
        bodyTokens.add(const AstNewLine());
      }
      bodyTokens.addAll(tokens);
      hasBody = true;
    }

    void flushInlineNodes() {
      if (pendingInlineNodes.isEmpty) {
        return;
      }
      appendBody(
        _paragraphTokensFromInlines(_parseInlineChildren(pendingInlineNodes)),
      );
      pendingInlineNodes.clear();
    }

    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Text) {
        pendingInlineNodes.add(child);
        continue;
      }
      if (child is! md.Element) {
        continue;
      }
      if (child.tag == 'ul' || child.tag == 'ol') {
        flushInlineNodes();
        _appendBlock(
          nestedTokens,
          _listTokens(child, ordered: child.tag == 'ol', depth: depth + 1),
        );
        continue;
      }
      if (child.tag == 'p') {
        flushInlineNodes();
        appendBody(
          _paragraphTokensFromInlines(_parseInlineChildren(child.children)),
        );
        continue;
      }
      pendingInlineNodes.add(child);
    }
    flushInlineNodes();

    if (!hasBody) {
      bodyTokens.add(AstText(prefix.trimRight()));
    } else {
      _prependPrefix(bodyTokens, prefix);
    }

    final baseIndent = depth * 2;
    final contentIndent = baseIndent + prefix.length;
    final tokens = <AstToken>[
      AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockStart,
        lineIndent: baseIndent,
        hangingIndent: contentIndent,
      ),
      ...bodyTokens,
      const AstNewLine(),
      const AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockEnd,
        lineIndent: 0,
      ),
    ];
    _appendBlock(tokens, nestedTokens);
    return tokens;
  }

  void _prependPrefix(List<AstToken> tokens, String prefix) {
    final firstTextIndex = tokens.indexWhere((token) => token is AstText);
    if (firstTextIndex >= 0) {
      final text = tokens[firstTextIndex] as AstText;
      tokens[firstTextIndex] = AstText(prefix + text.text);
      return;
    }
    tokens.insert(0, AstText(prefix));
  }

  List<AstToken> _codeBlockTokens(md.Element node) {
    final code = _findFirstChildTag(node, 'code');
    final codeText = code?.textContent.replaceFirst(RegExp(r'\n$'), '') ?? '';
    if (codeText.isEmpty) {
      return const <AstToken>[];
    }

    final language = _codeLanguage(code);
    final tokens = <AstToken>[
      const AstInlineDecoration(
        boundary: AstRangeBoundary.blockStart,
        kind: AstInlineDecorationKind.keigakomi,
      ),
      const AstNewLine(),
    ];

    final lines = codeText.split('\n');
    for (var index = 0; index < lines.length; index += 1) {
      if (index > 0) {
        tokens.add(const AstNewLine());
      }
      tokens.add(
        const AstInlineDecoration(
          boundary: AstRangeBoundary.start,
          kind: AstInlineDecorationKind.yokogumi,
        ),
      );
      tokens.addAll(_highlightCodeLine(lines[index], language: language));
      tokens.add(
        const AstInlineDecoration(
          boundary: AstRangeBoundary.end,
          kind: AstInlineDecorationKind.yokogumi,
        ),
      );
    }

    tokens.add(const AstNewLine());
    tokens.add(
      const AstInlineDecoration(
        boundary: AstRangeBoundary.blockEnd,
        kind: AstInlineDecorationKind.keigakomi,
      ),
    );
    return tokens;
  }

  List<AstToken> _tableTokens(md.Element table) {
    final rows = <List<AstTableCell>>[];
    for (final section in table.children ?? const <md.Node>[]) {
      if (section is! md.Element) {
        continue;
      }
      for (final row in section.children ?? const <md.Node>[]) {
        if (row is! md.Element || row.tag != 'tr') {
          continue;
        }
        final cells = <AstTableCell>[];
        for (final cell in row.children ?? const <md.Node>[]) {
          if (cell is md.Element && (cell.tag == 'th' || cell.tag == 'td')) {
            final text = cell.textContent.trim();
            cells.add(
              AstTableCell(
                content: text.isEmpty
                    ? const <AstInlineNode>[]
                    : <AstInlineNode>[AstText(text)],
                alignment: _tableAlignment(cell.attributes['align']),
              ),
            );
          }
        }
        if (cells.isNotEmpty) {
          rows.add(cells);
        }
      }
    }
    if (rows.isEmpty) {
      return const <AstToken>[];
    }
    return <AstToken>[
      AstTable(rows: rows, headerRowCount: _headerRowCount(table)),
    ];
  }

  List<AstToken> _paragraphTokensFromText(String text) {
    final normalized = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (normalized.isEmpty) {
      return const <AstToken>[];
    }
    final tokens = <AstToken>[];
    final lines = normalized.split('\n');
    for (var index = 0; index < lines.length; index += 1) {
      if (index > 0) {
        tokens.add(const AstNewLine());
      }
      if (lines[index].isNotEmpty) {
        tokens.add(AstText(lines[index]));
      }
    }
    return tokens;
  }

  List<AstToken> _paragraphTokensFromInlines(List<AstToken> children) {
    if (children.isEmpty) {
      return const <AstToken>[AstText('　')];
    }
    return children;
  }

  List<AstToken> _blockquoteTokens(md.Element node) {
    final tokens = <AstToken>[const AstBlockQuote(AstRangeBoundary.blockStart)];
    final children = node.children ?? const <md.Node>[];
    final blocks = <List<AstToken>>[
      for (final child in children) _parseBlock(child),
    ];
    _rewriteBlockquoteAttribution(blocks);
    for (final block in blocks) {
      _appendBlock(tokens, block);
    }
    if (tokens.isNotEmpty && tokens.last is! AstNewLine) {
      tokens.add(const AstNewLine());
    }
    tokens.add(const AstBlockQuote(AstRangeBoundary.blockEnd));
    return tokens;
  }

  void _rewriteBlockquoteAttribution(List<List<AstToken>> blocks) {
    if (blocks.isEmpty) {
      return;
    }
    final lastIndex = blocks.length - 1;
    final text = _plainParagraphText(blocks[lastIndex]);
    if (text == null) {
      return;
    }

    final lines = text.split('\n');
    if (lines.isEmpty) {
      return;
    }

    final attribution = _normalizeBlockquoteAttribution(lines.last);
    if (attribution == null) {
      return;
    }

    if (lines.length >= 2) {
      blocks[lastIndex] = _blockquoteBodyTokens(lines);
      blocks.add(_quotedSpacerLine);
      blocks.add(_blockquoteAttributionTailTokens(attribution));
      return;
    }

    blocks[lastIndex] = _quotedSpacerLine;
    blocks.add(_blockquoteAttributionTailTokens(attribution));
  }

  List<AstToken> _blockquoteBodyTokens(List<String> lines) {
    final prefixLines = lines.sublist(0, lines.length - 2);
    final anchorLine = lines[lines.length - 2];
    final tokens = <AstToken>[];
    if (prefixLines.isNotEmpty) {
      tokens.addAll(_paragraphTokensFromText(prefixLines.join('\n')));
      tokens.add(const AstNewLine());
    }
    if (anchorLine.isNotEmpty) {
      tokens.add(AstText(anchorLine));
    }
    return tokens;
  }

  List<AstToken> _blockquoteAttributionTailTokens(String attribution) {
    return <AstToken>[
      const AstBlockQuoteAttribution(),
      const AstBottomAlign(
        kind: AstBottomAlignKind.raisedFromBottom,
        scope: AstBottomAlignScope.inlineTail,
        offset: 2,
      ),
      AstText(attribution),
    ];
  }

  String? _plainParagraphText(List<AstToken> block) {
    final buffer = StringBuffer();
    for (final token in block) {
      switch (token) {
        case AstText(text: final text):
          buffer.write(text);
        case AstNewLine():
          buffer.write('\n');
        default:
          return null;
      }
    }
    return buffer.toString();
  }

  String? _normalizeBlockquoteAttribution(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final match = _blockquoteAttributionPrefixPattern.firstMatch(trimmed);
    if (match == null) {
      return null;
    }
    final normalized = match.group(1)?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  List<AstToken> _parseInlineChildren(List<md.Node>? nodes) {
    if (nodes == null || nodes.isEmpty) {
      return const <AstToken>[];
    }
    final children = <AstToken>[];
    for (final node in nodes) {
      children.addAll(_parseInline(node));
    }
    return _mergeAdjacentText(children);
  }

  List<AstToken> _parseInline(md.Node node) {
    if (node is md.Text) {
      return node.text.isEmpty
          ? const <AstToken>[]
          : <AstToken>[AstText(node.text)];
    }
    if (node is! md.Element) {
      return const <AstToken>[];
    }

    switch (node.tag) {
      case 'em':
        return _wrapStyle(
          _parseInlineChildren(node.children),
          const AstFontStyleAnnotation(AstFontStyle.italic),
        );
      case 'strong':
        return _wrapStyle(
          _parseInlineChildren(node.children),
          const AstFontStyleAnnotation(AstFontStyle.bold),
        );
      case 'a':
        final target = node.attributes['href']?.trim() ?? '';
        final children = _parseInlineChildren(node.children);
        if (target.isEmpty) {
          return children;
        }
        final label = children.isEmpty ? <AstToken>[AstText(target)] : children;
        return <AstToken>[
          const AstLink(boundary: AstRangeBoundary.start),
          ...label,
          AstLink(boundary: AstRangeBoundary.end, target: target),
        ];
      case 'code':
        final text = node.textContent;
        if (text.isEmpty) {
          return const <AstToken>[];
        }
        return <AstToken>[
          const AstInlineDecoration(
            boundary: AstRangeBoundary.start,
            kind: AstInlineDecorationKind.keigakomi,
          ),
          const AstInlineDecoration(
            boundary: AstRangeBoundary.start,
            kind: AstInlineDecorationKind.yokogumi,
          ),
          AstText(text),
          const AstInlineDecoration(
            boundary: AstRangeBoundary.end,
            kind: AstInlineDecorationKind.yokogumi,
          ),
          const AstInlineDecoration(
            boundary: AstRangeBoundary.end,
            kind: AstInlineDecorationKind.keigakomi,
          ),
        ];
      case 'br':
        return const <AstToken>[AstNewLine()];
      case 'img':
        return _imageTokens(
          src: node.attributes['src'],
          fallbackText: node.attributes['alt'],
          width: node.attributes['width'],
          height: node.attributes['height'],
        );
      case 'del':
        return _wrapStyle(
          _parseInlineChildren(node.children),
          const AstBosenStyle(kind: AstBosenKind.cancel),
        );
      default:
        final text = node.textContent;
        return text.isEmpty ? const <AstToken>[] : <AstToken>[AstText(text)];
    }
  }

  List<AstToken> _imageTokens({
    String? src,
    String? fallbackText,
    String? width,
    String? height,
  }) {
    final path = src?.trim() ?? '';
    if (path.isNotEmpty) {
      return <AstToken>[
        AstImage(
          description: '画像',
          fileName: path,
          size: _parseImageSize(width, height),
        ),
      ];
    }

    final fallback = fallbackText?.trim() ?? '';
    if (fallback.isEmpty) {
      return const <AstToken>[];
    }
    return <AstToken>[AstText(fallback)];
  }

  List<AstToken> _wrapStyle(List<AstToken> children, AstTextStyle style) {
    if (children.isEmpty) {
      return const <AstToken>[];
    }
    return <AstToken>[
      AstStyledText(boundary: AstRangeBoundary.start, style: style),
      ...children,
      AstStyledText(boundary: AstRangeBoundary.end, style: style),
    ];
  }

  List<AstToken> _highlightCodeLine(String line, {String? language}) {
    if (line.isEmpty) {
      return const <AstToken>[AstText('　')];
    }

    hl.Result result;
    try {
      final normalizedLanguage = _normalizeHighlightLanguage(language);
      result = normalizedLanguage == null
          ? hl.highlight.parse(line, autoDetection: true)
          : hl.highlight.parse(line, language: normalizedLanguage);
    } catch (_) {
      return <AstToken>[AstText(line)];
    }

    final segments = <_HighlightedSegment>[];
    for (final node in result.nodes ?? const <hl.Node>[]) {
      _flattenHighlightNode(node, const <String>[], segments);
    }
    if (segments.isEmpty) {
      return <AstToken>[AstText(line)];
    }

    final tokens = <AstToken>[];
    for (final segment in segments) {
      final color = _colorForHighlightScope(segment.scopes);
      if (color != null) {
        tokens.add(
          AstStyledText(
            boundary: AstRangeBoundary.start,
            style: AstTextColorStyle(color.toARGB32()),
          ),
        );
      }
      tokens.add(AstText(segment.text));
      if (color != null) {
        tokens.add(
          AstStyledText(
            boundary: AstRangeBoundary.end,
            style: AstTextColorStyle(color.toARGB32()),
          ),
        );
      }
    }
    return _mergeAdjacentText(tokens);
  }

  void _flattenHighlightNode(
    hl.Node node,
    List<String> scopes,
    List<_HighlightedSegment> output,
  ) {
    final nextScopes = <String>[
      ...scopes,
      if (node.className != null && node.className!.isNotEmpty) node.className!,
    ];

    final value = node.value;
    if (value != null && value.isNotEmpty) {
      if (output.isNotEmpty && _sameScopes(output.last.scopes, nextScopes)) {
        output[output.length - 1] = _HighlightedSegment(
          text: output.last.text + value,
          scopes: output.last.scopes,
        );
      } else {
        output.add(_HighlightedSegment(text: value, scopes: nextScopes));
      }
    }

    for (final child in node.children ?? const <hl.Node>[]) {
      _flattenHighlightNode(child, nextScopes, output);
    }
  }

  bool _sameScopes(List<String> left, List<String> right) {
    if (left.length != right.length) {
      return false;
    }
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) {
        return false;
      }
    }
    return true;
  }

  Color? _colorForHighlightScope(List<String> scopes) {
    const colors = <String, Color>{
      'keyword': Color(0xffcf222e),
      'built_in': Color(0xff8250df),
      'type': Color(0xff953800),
      'literal': Color(0xff0550ae),
      'number': Color(0xff0550ae),
      'string': Color(0xff0a7f42),
      'subst': Color(0xff24292f),
      'comment': Color(0xff6e7781),
      'title': Color(0xff8250df),
      'title.function': Color(0xff8250df),
      'function': Color(0xff8250df),
      'params': Color(0xff24292f),
      'meta': Color(0xff116329),
      'symbol': Color(0xff0550ae),
      'variable': Color(0xff953800),
      'property': Color(0xff953800),
      'operator': Color(0xffcf222e),
      'punctuation': Color(0xff57606a),
    };

    for (final scope in scopes.reversed) {
      final normalized = scope.replaceAll('_', '.');
      if (colors.containsKey(normalized)) {
        return colors[normalized];
      }
      final parts = normalized.split(RegExp(r'[\s.]+'));
      for (final part in parts.reversed) {
        if (colors.containsKey(part)) {
          return colors[part];
        }
      }
    }
    return null;
  }

  List<AstToken> _mergeAdjacentText(List<AstToken> tokens) {
    final merged = <AstToken>[];
    for (final token in tokens) {
      if (token is AstText && merged.isNotEmpty && merged.last is AstText) {
        final previous = merged.removeLast() as AstText;
        merged.add(AstText(previous.text + token.text));
        continue;
      }
      merged.add(token);
    }
    return merged;
  }

  AstHeadingLevel _headingLevel(String tag) {
    return switch (tag) {
      'h1' => AstHeadingLevel.large,
      'h2' => AstHeadingLevel.medium,
      _ => AstHeadingLevel.small,
    };
  }

  int _headerRowCount(md.Element table) {
    var count = 0;
    for (final section in table.children ?? const <md.Node>[]) {
      if (section is! md.Element || section.tag != 'thead') {
        continue;
      }
      for (final row in section.children ?? const <md.Node>[]) {
        if (row is md.Element && row.tag == 'tr') {
          count += 1;
        }
      }
    }
    return count;
  }

  AstTableAlignment _tableAlignment(String? align) {
    switch (align) {
      case 'center':
        return AstTableAlignment.center;
      case 'right':
        return AstTableAlignment.end;
      default:
        return AstTableAlignment.start;
    }
  }

  AstImageSize? _parseImageSize(String? width, String? height) {
    final parsedWidth = _parseDimension(width);
    final parsedHeight = _parseDimension(height);
    if (parsedWidth == null && parsedHeight == null) {
      return null;
    }
    return AstImageSize(width: parsedWidth ?? 0, height: parsedHeight ?? 0);
  }

  int? _parseDimension(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final match = RegExp(r'^[0-9]+(?:\.[0-9]+)?').firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!)?.round();
  }

  String _orderedPrefix(int value) {
    return '${_kanjiNumber(value)}、';
  }

  String _kanjiNumber(int value) {
    if (value <= 0 || value >= 10000) {
      return value.toString();
    }
    const numerals = <String>['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    const units = <String>['', '十', '百', '千'];
    final digits = value
        .toString()
        .split('')
        .map(int.parse)
        .toList(growable: false);
    final buffer = StringBuffer();
    for (var index = 0; index < digits.length; index += 1) {
      final digit = digits[index];
      if (digit == 0) {
        continue;
      }
      final place = digits.length - index - 1;
      if (digit > 1 || place == 0) {
        buffer.write(numerals[digit]);
      }
      buffer.write(units[place]);
    }
    return buffer.toString();
  }

  md.Element? _findFirstChildTag(md.Element element, String tag) {
    for (final child in element.children ?? const <md.Node>[]) {
      if (child is md.Element && child.tag == tag) {
        return child;
      }
    }
    return null;
  }

  String? _codeLanguage(md.Element? code) {
    final className = code?.attributes['class'] ?? '';
    if (className.isEmpty) {
      return null;
    }
    for (final name in className.split(RegExp(r'\s+'))) {
      if (name.startsWith('language-') && name.length > 9) {
        return name.substring(9);
      }
    }
    return null;
  }

  String? _normalizeHighlightLanguage(String? language) {
    final normalized = language?.trim().toLowerCase();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return switch (normalized) {
      'c++' => 'cpp',
      'c#' => 'cs',
      'sh' => 'bash',
      'shell' => 'bash',
      'js' => 'javascript',
      'ts' => 'typescript',
      'md' => 'markdown',
      _ => normalized,
    };
  }
}

class _HighlightedSegment {
  const _HighlightedSegment({required this.text, required this.scopes});

  final String text;
  final List<String> scopes;
}
