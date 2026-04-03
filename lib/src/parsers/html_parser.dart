import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;

import '../ast.dart';
import '../document.dart';

class HtmlParser {
  const HtmlParser();

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

    final fragment = html_parser.parseFragment(normalized, container: 'body');
    final tokens = <AstToken>[];
    for (final node in fragment.nodes) {
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

  List<AstToken> _parseBlock(html.Node node) {
    if (node is html.Text) {
      return _paragraphTokensFromText(_normalizeBlockText(node.text));
    }
    if (node is! html.Element) {
      return const <AstToken>[];
    }

    final tag = node.localName?.toLowerCase();
    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _headingTokens(tag!, node);
      case 'p':
        return _paragraphTokensFromInlines(_parseInlineChildren(node.nodes));
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
        return const <AstToken>[AstText('――――')];
      default:
        if (_sectionIndentTags.contains(tag)) {
          return _indentedContainerTokens(node);
        }
        if (_transparentBlockTags.contains(tag) ||
            _containsBlockDescendant(node)) {
          return _parseBlockChildren(node.nodes);
        }
        return _paragraphTokensFromInlines(_parseInlineChildren(node.nodes));
    }
  }

  List<AstToken> _parseBlockChildren(Iterable<html.Node> nodes) {
    final blocks = <AstToken>[];
    for (final node in nodes) {
      _appendBlock(blocks, _parseBlock(node));
    }
    return blocks;
  }

  List<AstToken> _indentedContainerTokens(html.Element node) {
    final children = _parseBlockChildren(node.nodes);
    if (children.isEmpty) {
      return const <AstToken>[];
    }

    final tokens = <AstToken>[
      const AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockStart,
        lineIndent: 1,
        hangingIndent: 1,
      ),
    ];
    for (final child in _splitBlocks(children)) {
      _appendBlock(tokens, child);
    }
    if (tokens.isNotEmpty && tokens.last is! AstNewLine) {
      tokens.add(const AstNewLine());
    }
    tokens.add(
      const AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockEnd,
        lineIndent: 0,
      ),
    );
    return tokens;
  }

  Iterable<List<AstToken>> _splitBlocks(List<AstToken> tokens) sync* {
    var current = <AstToken>[];
    for (final token in tokens) {
      if (token is AstNewLine) {
        if (current.isNotEmpty) {
          yield current;
          current = <AstToken>[];
        }
        continue;
      }
      current.add(token);
    }
    if (current.isNotEmpty) {
      yield current;
    }
  }

  List<AstToken> _headingTokens(String tag, html.Element node) {
    final level = _headingLevel(tag);
    return <AstToken>[
      AstHeading(
        boundary: AstRangeBoundary.start,
        form: AstHeadingForm.standalone,
        level: level,
      ),
      ..._parseInlineChildren(node.nodes),
      AstHeading(
        boundary: AstRangeBoundary.end,
        form: AstHeadingForm.standalone,
        level: level,
      ),
    ];
  }

  List<AstToken> _blockquoteTokens(html.Element node) {
    final tokens = <AstToken>[const AstBlockQuote(AstRangeBoundary.blockStart)];
    final blocks = <List<AstToken>>[
      for (final child in node.nodes) _parseBlock(child),
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

  List<AstToken> _listTokens(
    html.Element list, {
    required bool ordered,
    int depth = 0,
  }) {
    final tokens = <AstToken>[];
    var index = ordered ? int.tryParse(list.attributes['start'] ?? '') ?? 1 : 1;
    for (final child in list.nodes) {
      if (child is! html.Element || child.localName?.toLowerCase() != 'li') {
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
    html.Element item, {
    required int depth,
    required String prefix,
  }) {
    final bodyTokens = <AstToken>[];
    final nestedTokens = <AstToken>[];
    final pendingInlineNodes = <html.Node>[];
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

    for (final child in item.nodes) {
      if (child is html.Text) {
        pendingInlineNodes.add(child);
        continue;
      }
      if (child is! html.Element) {
        continue;
      }

      final tag = child.localName?.toLowerCase();
      if (tag == 'ul' || tag == 'ol') {
        flushInlineNodes();
        _appendBlock(
          nestedTokens,
          _listTokens(child, ordered: tag == 'ol', depth: depth + 1),
        );
        continue;
      }
      if (tag == 'p') {
        flushInlineNodes();
        appendBody(
          _paragraphTokensFromInlines(_parseInlineChildren(child.nodes)),
        );
        continue;
      }
      if (_blockTags.contains(tag) || _transparentBlockTags.contains(tag)) {
        flushInlineNodes();
        appendBody(_parseBlock(child));
        continue;
      }
      pendingInlineNodes.add(child);
    }
    flushInlineNodes();

    if (!hasBody) {
      bodyTokens.add(AstText(prefix.trimRight()));
    } else {
      bodyTokens.insert(0, AstText(prefix));
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

  List<AstToken> _codeBlockTokens(html.Element node) {
    final code = _findFirstChildTag(node, 'code');
    final codeText = (code?.text ?? node.text).replaceFirst(RegExp(r'\n$'), '');
    if (codeText.isEmpty) {
      return const <AstToken>[];
    }

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
      tokens.add(AstText(lines[index].isEmpty ? '　' : lines[index]));
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

  List<AstToken> _tableTokens(html.Element table) {
    final rows = <List<AstTableCell>>[];
    for (final row in _tableRows(table)) {
      final cells = <AstTableCell>[];
      for (final cell in row.nodes) {
        if (cell is! html.Element) {
          continue;
        }
        final tag = cell.localName?.toLowerCase();
        if (tag != 'th' && tag != 'td') {
          continue;
        }
        final text = _normalizeBlockText(cell.text).trim();
        cells.add(
          AstTableCell(
            content: text.isEmpty
                ? const <AstInlineNode>[]
                : <AstInlineNode>[AstText(text)],
            alignment: _tableAlignment(cell.attributes['align']),
          ),
        );
      }
      if (cells.isNotEmpty) {
        rows.add(cells);
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

  List<AstToken> _parseInlineChildren(Iterable<html.Node> nodes) {
    final children = <AstToken>[];
    for (final node in nodes) {
      children.addAll(_parseInline(node));
    }
    return _trimParagraphEdgeWhitespace(_mergeAdjacentText(children));
  }

  List<AstToken> _parseInline(html.Node node) {
    if (node is html.Text) {
      final text = _normalizeInlineText(node.text);
      return text.isEmpty ? const <AstToken>[] : <AstToken>[AstText(text)];
    }
    if (node is! html.Element) {
      return const <AstToken>[];
    }

    final tag = node.localName?.toLowerCase();
    switch (tag) {
      case 'em':
      case 'i':
        return _wrapStyle(
          _parseInlineChildren(node.nodes),
          const AstFontStyleAnnotation(AstFontStyle.italic),
        );
      case 'strong':
      case 'b':
        return _wrapStyle(
          _parseInlineChildren(node.nodes),
          const AstFontStyleAnnotation(AstFontStyle.bold),
        );
      case 'a':
        final target = node.attributes['href']?.trim() ?? '';
        final children = _parseInlineChildren(node.nodes);
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
        final text = _normalizeInlineText(node.text);
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
      case 's':
      case 'strike':
        return _wrapStyle(
          _parseInlineChildren(node.nodes),
          const AstBosenStyle(kind: AstBosenKind.cancel),
        );
      case 'ins':
      case 'u':
        return _wrapStyle(
          _parseInlineChildren(node.nodes),
          const AstBosenStyle(kind: AstBosenKind.solid),
        );
      case 'ruby':
        return _rubyTokens(node);
      default:
        return _parseInlineChildren(node.nodes);
    }
  }

  List<AstToken> _rubyTokens(html.Element node) {
    final ruby = <String>[];
    final baseChildren = <AstToken>[];

    for (final child in node.nodes) {
      if (child is html.Element) {
        final tag = child.localName?.toLowerCase();
        if (tag == 'rt') {
          final text = _normalizeInlineText(child.text).trim();
          if (text.isNotEmpty) {
            ruby.add(text);
          }
          continue;
        }
        if (tag == 'rp') {
          continue;
        }
      }
      baseChildren.addAll(_parseInline(child));
    }

    final mergedBase = _trimParagraphEdgeWhitespace(
      _mergeAdjacentText(baseChildren),
    );
    final annotation = ruby.join(' ').trim();
    if (mergedBase.isEmpty) {
      return annotation.isEmpty
          ? const <AstToken>[]
          : <AstToken>[AstText(annotation)];
    }
    if (annotation.isEmpty) {
      return mergedBase;
    }

    return <AstToken>[
      const AstAttachedText(
        boundary: AstRangeBoundary.start,
        role: AstAttachedTextRole.ruby,
        side: AstTextSide.right,
      ),
      ...mergedBase,
      AstAttachedText(
        boundary: AstRangeBoundary.end,
        role: AstAttachedTextRole.ruby,
        side: AstTextSide.right,
        content: <AstInlineNode>[AstText(annotation)],
      ),
    ];
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

  List<AstToken> _trimParagraphEdgeWhitespace(List<AstToken> tokens) {
    final trimmed = List<AstToken>.from(tokens);
    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.first case AstText(text: final text)) {
      final next = text.replaceFirst(RegExp(r'^[ \t\f]+'), '');
      if (next.isEmpty) {
        trimmed.removeAt(0);
      } else {
        trimmed[0] = AstText(next);
      }
    }

    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.last case AstText(text: final text)) {
      final next = text.replaceFirst(RegExp(r'[ \t\f]+$'), '');
      if (next.isEmpty) {
        trimmed.removeLast();
      } else {
        trimmed[trimmed.length - 1] = AstText(next);
      }
    }

    return trimmed;
  }

  String _normalizeInlineText(String text) {
    return text.replaceAll(RegExp(r'[ \t\r\n\f]+'), ' ');
  }

  String _normalizeBlockText(String text) {
    return text
        .replaceAll(RegExp(r'[ \t\f]*\n[ \t\f]*'), '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .replaceAll(RegExp(r'[ \t\f]+'), ' ');
  }

  AstHeadingLevel _headingLevel(String tag) {
    return switch (tag) {
      'h1' => AstHeadingLevel.large,
      'h2' => AstHeadingLevel.medium,
      _ => AstHeadingLevel.small,
    };
  }

  Iterable<html.Element> _tableRows(html.Element table) sync* {
    for (final child in table.nodes) {
      if (child is! html.Element) {
        continue;
      }
      final tag = child.localName?.toLowerCase();
      if (tag == 'tr') {
        yield child;
        continue;
      }
      if (tag == 'thead' || tag == 'tbody' || tag == 'tfoot') {
        for (final row in child.nodes) {
          if (row is html.Element && row.localName?.toLowerCase() == 'tr') {
            yield row;
          }
        }
      }
    }
  }

  int _headerRowCount(html.Element table) {
    var count = 0;
    for (final child in table.nodes) {
      if (child is! html.Element) {
        continue;
      }
      final tag = child.localName?.toLowerCase();
      if (tag == 'thead') {
        for (final row in child.nodes) {
          if (row is html.Element && row.localName?.toLowerCase() == 'tr') {
            count += 1;
          }
        }
      }
    }
    if (count > 0) {
      return count;
    }

    for (final row in _tableRows(table)) {
      final cellTags = row.nodes
          .whereType<html.Element>()
          .map((cell) => cell.localName?.toLowerCase())
          .whereType<String>()
          .toList(growable: false);
      if (cellTags.isEmpty || cellTags.any((tag) => tag != 'th')) {
        break;
      }
      count += 1;
    }
    return count;
  }

  AstTableAlignment _tableAlignment(String? align) {
    switch (align?.toLowerCase()) {
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

  html.Element? _findFirstChildTag(html.Element element, String tag) {
    for (final child in element.nodes) {
      if (child is html.Element && child.localName?.toLowerCase() == tag) {
        return child;
      }
    }
    return null;
  }

  bool _containsBlockDescendant(html.Element element) {
    for (final child in element.nodes) {
      if (child is! html.Element) {
        continue;
      }
      final tag = child.localName?.toLowerCase();
      if (_blockTags.contains(tag) ||
          _transparentBlockTags.contains(tag) ||
          _sectionIndentTags.contains(tag)) {
        return true;
      }
      if (_containsBlockDescendant(child)) {
        return true;
      }
    }
    return false;
  }
}

const Set<String> _blockTags = <String>{
  'blockquote',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'hr',
  'ol',
  'p',
  'pre',
  'table',
  'ul',
};

const Set<String> _transparentBlockTags = <String>{
  'body',
  'div',
  'footer',
  'header',
  'html',
  'main',
};

const Set<String> _sectionIndentTags = <String>{
  'article',
  'aside',
  'nav',
  'section',
};
