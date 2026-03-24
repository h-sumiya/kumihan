import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;

import '../kumihan_document.dart';
import 'aozora_parser.dart';

class KumihanHtmlParser implements KumihanDocumentParser<String> {
  const KumihanHtmlParser({
    this.author,
    this.headerTitle,
    this.includeCover = false,
    this.title,
  });

  final String? author;
  final String? headerTitle;
  final bool includeCover;
  final String? title;

  @override
  KumihanDocument parse(String input) {
    final blocks = <KumihanBlock>[];
    final documentTitle = title?.trim() ?? '';
    final documentAuthor = author?.trim() ?? '';

    if (includeCover &&
        (documentTitle.isNotEmpty || documentAuthor.isNotEmpty)) {
      blocks.add(
        KumihanCoverBlock(
          title: documentTitle.isNotEmpty ? documentTitle : documentAuthor,
          credit: documentTitle.isNotEmpty && documentAuthor.isNotEmpty
              ? documentAuthor
              : null,
        ),
      );
    }

    final normalized = input
        .replaceAll(RegExp(r'(\r\n|\r)'), '\n')
        .replaceFirst(RegExp(r'\n$'), '');
    if (normalized.isEmpty) {
      return KumihanDocument(
        blocks: blocks,
        headerTitle: _resolvedHeaderTitle(documentTitle, documentAuthor),
      );
    }

    final fragment = html_parser.parseFragment(normalized, container: 'body');
    for (final node in fragment.nodes) {
      blocks.addAll(_parseBlock(node));
    }

    return KumihanDocument(
      blocks: blocks,
      headerTitle: _resolvedHeaderTitle(documentTitle, documentAuthor),
    );
  }

  List<KumihanBlock> _parseBlock(html.Node node) {
    if (node is html.Text) {
      return _paragraphBlocksFromText(_normalizeBlockText(node.text));
    }
    if (node is! html.Element) {
      return const <KumihanBlock>[];
    }

    final tag = node.localName?.toLowerCase();
    switch (tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _paragraphBlocksFromInlines(<KumihanInline>[
          KumihanStyledInline(
            children: _parseInlineChildren(node.nodes),
            style: _headingStyle(tag!),
          ),
        ]);
      case 'p':
        return _paragraphBlocksFromInlines(_parseInlineChildren(node.nodes));
      case 'blockquote':
        return _paragraphBlocksFromText(_blockquoteText(node));
      case 'ul':
        return _listBlocks(node, ordered: false);
      case 'ol':
        return _listBlocks(node, ordered: true);
      case 'pre':
        return _codeBlockBlocks(node);
      case 'table':
        return _tableBlocks(node);
      case 'img':
        return _paragraphBlocksFromInlines(_parseInline(node));
      case 'hr':
        return const <KumihanBlock>[
          KumihanParagraphBlock(
            children: <KumihanInline>[KumihanTextInline('――――')],
          ),
        ];
      default:
        if (_transparentBlockTags.contains(tag) ||
            _containsBlockDescendant(node)) {
          return _parseBlockChildren(node.nodes);
        }
        return _paragraphBlocksFromInlines(_parseInlineChildren(node.nodes));
    }
  }

  List<KumihanBlock> _parseBlockChildren(Iterable<html.Node> nodes) {
    final blocks = <KumihanBlock>[];
    for (final node in nodes) {
      blocks.addAll(_parseBlock(node));
    }
    return blocks;
  }

  List<KumihanBlock> _listBlocks(
    html.Element list, {
    required bool ordered,
    int depth = 0,
  }) {
    final blocks = <KumihanBlock>[];
    var index = ordered ? int.tryParse(list.attributes['start'] ?? '') ?? 1 : 1;
    for (final child in list.nodes) {
      if (child is! html.Element || child.localName?.toLowerCase() != 'li') {
        continue;
      }
      blocks.addAll(
        _listItemBlocks(
          child,
          depth: depth,
          prefix: ordered ? _orderedPrefix(index) : '・',
        ),
      );
      index += 1;
    }
    return blocks;
  }

  List<KumihanBlock> _codeBlockBlocks(html.Element node) {
    final codeText = (node.text).replaceFirst(RegExp(r'\n$'), '');
    if (codeText.isEmpty) {
      return const <KumihanBlock>[];
    }

    final blocks = <KumihanBlock>[const KumihanCommandBlock('［＃ここから罫囲み］')];
    for (final line in codeText.split('\n')) {
      blocks.add(
        KumihanParagraphBlock(
          children: <KumihanInline>[
            KumihanStyledInline(
              children: <KumihanInline>[
                KumihanTextInline(line.isEmpty ? '　' : line),
              ],
              style: '横組み',
            ),
          ],
        ),
      );
    }
    blocks.add(const KumihanCommandBlock('［＃ここで罫囲み終わり］'));
    return blocks;
  }

  List<KumihanBlock> _tableBlocks(html.Element table) {
    final rows = <List<KumihanTableCell>>[];
    for (final row in _tableRows(table)) {
      final cells = <KumihanTableCell>[];
      for (final cell in row.nodes) {
        if (cell is! html.Element) {
          continue;
        }
        final cellTag = cell.localName?.toLowerCase();
        if (cellTag == 'th' || cellTag == 'td') {
          cells.add(
            KumihanTableCell(
              text: _normalizeBlockText(cell.text).trim(),
              alignment: _tableAlignment(cell.attributes['align']),
            ),
          );
        }
      }
      if (cells.isNotEmpty) {
        rows.add(cells);
      }
    }
    if (rows.isEmpty) {
      return const <KumihanBlock>[];
    }
    return <KumihanBlock>[
      KumihanTableBlock(rows: rows, headerRowCount: _headerRowCount(table)),
    ];
  }

  List<KumihanInline> _parseInlineChildren(Iterable<html.Node> nodes) {
    final children = <KumihanInline>[];
    for (final node in nodes) {
      children.addAll(_parseInline(node));
    }
    return _trimParagraphEdgeWhitespace(_mergeAdjacentTextInlines(children));
  }

  List<KumihanInline> _parseInline(html.Node node) {
    if (node is html.Text) {
      final text = _normalizeInlineText(node.text);
      return text.isEmpty
          ? const <KumihanInline>[]
          : <KumihanInline>[KumihanTextInline(text)];
    }
    if (node is! html.Element) {
      return const <KumihanInline>[];
    }

    final tag = node.localName?.toLowerCase();
    switch (tag) {
      case 'em':
      case 'i':
        return <KumihanInline>[
          KumihanStyledInline(
            children: _parseInlineChildren(node.nodes),
            style: '斜体',
          ),
        ];
      case 'strong':
      case 'b':
        return <KumihanInline>[
          KumihanStyledInline(
            children: _parseInlineChildren(node.nodes),
            style: '太字',
          ),
        ];
      case 'a':
        final target = node.attributes['href']?.trim() ?? '';
        final children = _parseInlineChildren(node.nodes);
        if (target.isEmpty) {
          return children;
        }
        return <KumihanInline>[
          KumihanLinkInline(
            children: children.isEmpty
                ? <KumihanInline>[KumihanTextInline(target)]
                : children,
            target: target,
          ),
        ];
      case 'code':
        return <KumihanInline>[
          KumihanStyledInline(
            children: <KumihanInline>[
              KumihanStyledInline(
                children: <KumihanInline>[
                  KumihanTextInline(_normalizeInlineText(node.text)),
                ],
                style: '横組み',
              ),
            ],
            style: '罫囲み',
          ),
        ];
      case 'br':
        return <KumihanInline>[KumihanTextInline('\n')];
      case 'img':
        return _imageInlines(
          src: node.attributes['src'],
          fallbackText: node.attributes['alt'],
          width: node.attributes['width'],
          height: node.attributes['height'],
        );
      case 'del':
      case 's':
      case 'strike':
        return <KumihanInline>[
          const KumihanTextInline('~~'),
          ..._parseInlineChildren(node.nodes),
          const KumihanTextInline('~~'),
        ];
      case 'ruby':
        return _rubyInline(node);
      default:
        return _parseInlineChildren(node.nodes);
    }
  }

  List<KumihanInline> _rubyInline(html.Element node) {
    final ruby = <String>[];
    final baseChildren = <KumihanInline>[];

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
      _mergeAdjacentTextInlines(baseChildren),
    );
    final annotation = ruby.join(' ').trim();
    if (mergedBase.isEmpty) {
      return annotation.isEmpty
          ? const <KumihanInline>[]
          : <KumihanInline>[KumihanTextInline(annotation)];
    }
    if (annotation.isEmpty) {
      return mergedBase;
    }
    return <KumihanInline>[
      KumihanRubyInline(children: mergedBase, ruby: annotation),
    ];
  }

  List<KumihanParagraphBlock> _paragraphBlocksFromText(String text) {
    final normalized = text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
    if (normalized.isEmpty) {
      return const <KumihanParagraphBlock>[];
    }

    return normalized
        .split('\n')
        .map(
          (line) => KumihanParagraphBlock(
            children: line.isEmpty
                ? const <KumihanInline>[]
                : <KumihanInline>[KumihanTextInline(line)],
          ),
        )
        .toList(growable: false);
  }

  List<KumihanParagraphBlock> _paragraphBlocksFromInlines(
    List<KumihanInline> children,
  ) {
    final normalizedChildren = _trimParagraphEdgeWhitespace(children);
    if (normalizedChildren.isEmpty) {
      return const <KumihanParagraphBlock>[
        KumihanParagraphBlock(children: <KumihanInline>[]),
      ];
    }

    final blocks = <KumihanParagraphBlock>[];
    var current = <KumihanInline>[];

    void flush() {
      blocks.add(
        KumihanParagraphBlock(children: _trimParagraphEdgeWhitespace(current)),
      );
      current = <KumihanInline>[];
    }

    for (final child in normalizedChildren) {
      final text = switch (child) {
        KumihanTextInline() => child.text,
        KumihanRawInline() => child.source,
        _ => null,
      };

      if (text == null || !text.contains('\n')) {
        current.add(child);
        continue;
      }

      final parts = text.split('\n');
      for (var index = 0; index < parts.length; index += 1) {
        final part = parts[index];
        if (part.isNotEmpty) {
          current.add(KumihanTextInline(part));
        }
        if (index < parts.length - 1) {
          flush();
        }
      }
    }

    if (current.isNotEmpty || blocks.isEmpty) {
      flush();
    }

    return blocks;
  }

  List<KumihanInline> _mergeAdjacentTextInlines(List<KumihanInline> children) {
    final merged = <KumihanInline>[];
    for (final child in children) {
      if (child is KumihanTextInline &&
          merged.isNotEmpty &&
          merged.last is KumihanTextInline) {
        final previous = merged.removeLast() as KumihanTextInline;
        merged.add(KumihanTextInline(previous.text + child.text));
        continue;
      }
      merged.add(child);
    }
    return merged;
  }

  List<KumihanInline> _imageInlines({
    String? src,
    String? fallbackText,
    String? width,
    String? height,
  }) {
    final path = src?.trim() ?? '';
    if (path.isNotEmpty) {
      return <KumihanInline>[
        KumihanImageInline(
          path: path,
          width: _parseDimension(width),
          height: _parseDimension(height),
        ),
      ];
    }

    final fallback = fallbackText?.trim() ?? '';
    if (fallback.isEmpty) {
      return const <KumihanInline>[];
    }
    return <KumihanInline>[KumihanTextInline(fallback)];
  }

  double? _parseDimension(String? raw) {
    final normalized = raw?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }
    final match = RegExp(r'^[0-9]+(?:\.[0-9]+)?').firstMatch(normalized);
    if (match == null) {
      return null;
    }
    return double.tryParse(match.group(0)!);
  }

  List<KumihanInline> _trimParagraphEdgeWhitespace(
    List<KumihanInline> children,
  ) {
    final trimmed = List<KumihanInline>.from(children);

    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.first is KumihanTextInline) {
      final text = (trimmed.first as KumihanTextInline).text.replaceFirst(
        RegExp(r'^[ \t\f]+'),
        '',
      );
      if (text.isEmpty) {
        trimmed.removeAt(0);
      } else {
        trimmed[0] = KumihanTextInline(text);
      }
    }

    if (trimmed.isEmpty) {
      return trimmed;
    }

    if (trimmed.last is KumihanTextInline) {
      final text = (trimmed.last as KumihanTextInline).text.replaceFirst(
        RegExp(r'[ \t\f]+$'),
        '',
      );
      if (text.isEmpty) {
        trimmed.removeLast();
      } else {
        trimmed[trimmed.length - 1] = KumihanTextInline(text);
      }
    }

    return trimmed;
  }

  String _blockquoteText(html.Element node) {
    final lines = <String>[];
    for (final child in node.nodes) {
      final text = _normalizeBlockText(child.text ?? '').trim();
      if (text.isEmpty) {
        continue;
      }
      for (final line in text.split('\n')) {
        lines.add('> $line');
      }
    }
    return lines.join('\n');
  }

  List<KumihanBlock> _listItemBlocks(
    html.Element item, {
    required int depth,
    required String prefix,
  }) {
    final blocks = <KumihanBlock>[];
    final baseIndent = depth * 2;
    final contentIndent = baseIndent + prefix.length;
    var prefixed = false;

    void appendParagraphs(List<KumihanParagraphBlock> paragraphs) {
      for (final paragraph in paragraphs) {
        final children = prefixed
            ? paragraph.children
            : <KumihanInline>[KumihanTextInline(prefix), ...paragraph.children];
        blocks.addAll(
          _withIndent(
            KumihanParagraphBlock(children: children),
            firstIndent: prefixed ? contentIndent : baseIndent,
            restIndent: contentIndent,
          ),
        );
        prefixed = true;
      }
    }

    for (final child in item.nodes) {
      if (child is html.Text) {
        appendParagraphs(
          _paragraphBlocksFromText(_normalizeInlineText(child.text)),
        );
        continue;
      }
      if (child is! html.Element) {
        continue;
      }

      final tag = child.localName?.toLowerCase();
      if (tag == 'ul' || tag == 'ol') {
        blocks.addAll(
          _listBlocks(child, ordered: tag == 'ol', depth: depth + 1),
        );
        continue;
      }
      if (tag == 'p') {
        appendParagraphs(
          _paragraphBlocksFromInlines(_parseInlineChildren(child.nodes)),
        );
        continue;
      }

      appendParagraphs(
        _paragraphBlocksFromText(_normalizeBlockText(child.text)),
      );
    }

    if (!prefixed) {
      blocks.addAll(
        _withIndent(
          KumihanParagraphBlock(
            children: <KumihanInline>[KumihanTextInline(prefix.trimRight())],
          ),
          firstIndent: baseIndent,
          restIndent: contentIndent,
        ),
      );
    }

    return blocks;
  }

  List<KumihanBlock> _withIndent(
    KumihanParagraphBlock paragraph, {
    required int firstIndent,
    required int restIndent,
  }) {
    if (firstIndent <= 0 && restIndent <= 0) {
      return <KumihanBlock>[paragraph];
    }

    return <KumihanBlock>[
      KumihanCommandBlock(_indentCommand(firstIndent, restIndent)),
      paragraph,
      const KumihanCommandBlock('［＃ここで字下げ終わり］'),
    ];
  }

  String _indentCommand(int firstIndent, int restIndent) {
    final first = _fullWidthDigits(firstIndent);
    if (firstIndent == restIndent) {
      return '［＃ここから$first字下げ］';
    }
    return '［＃ここから$first字下げ、折り返して${_fullWidthDigits(restIndent)}字下げ］';
  }

  String _orderedPrefix(int value) {
    return '${_kanjiNumber(value)}、';
  }

  String _fullWidthDigits(int value) {
    const digits = <String>['０', '１', '２', '３', '４', '５', '６', '７', '８', '９'];
    return value
        .toString()
        .split('')
        .map((digit) => digits[int.parse(digit)])
        .join();
  }

  String _kanjiNumber(int value) {
    if (value <= 0) {
      return value.toString();
    }

    const numerals = <String>['', '一', '二', '三', '四', '五', '六', '七', '八', '九'];
    const units = <String>['', '十', '百', '千'];
    if (value >= 10000) {
      return value.toString();
    }

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

  String _headingStyle(String tag) {
    return switch (tag) {
      'h1' => '大見出し',
      'h2' => '中見出し',
      _ => '小見出し',
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

  KumihanTableAlignment _tableAlignment(String? align) {
    switch (align?.toLowerCase()) {
      case 'center':
        return KumihanTableAlignment.center;
      case 'right':
        return KumihanTableAlignment.end;
      default:
        return KumihanTableAlignment.start;
    }
  }

  bool _containsBlockDescendant(html.Element element) {
    for (final child in element.nodes) {
      if (child is! html.Element) {
        continue;
      }
      final tag = child.localName?.toLowerCase();
      if (_blockTags.contains(tag) || _transparentBlockTags.contains(tag)) {
        return true;
      }
      if (_containsBlockDescendant(child)) {
        return true;
      }
    }
    return false;
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

  String _resolvedHeaderTitle(String documentTitle, String documentAuthor) {
    final explicit = headerTitle?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }
    if (documentTitle.isEmpty) {
      return documentAuthor;
    }
    if (documentAuthor.isEmpty) {
      return documentTitle;
    }
    return '$documentTitle / $documentAuthor';
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
  'article',
  'aside',
  'body',
  'div',
  'footer',
  'header',
  'html',
  'main',
  'nav',
  'section',
};
