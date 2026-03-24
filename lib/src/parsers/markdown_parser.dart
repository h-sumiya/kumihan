import 'package:markdown/markdown.dart' as md;

import '../kumihan_document.dart';
import 'aozora_parser.dart';

class KumihanMarkdownParser implements KumihanDocumentParser<String> {
  const KumihanMarkdownParser({
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

    final parser = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    for (final node in parser.parse(normalized)) {
      blocks.addAll(_parseBlock(node));
    }

    return KumihanDocument(
      blocks: blocks,
      headerTitle: _resolvedHeaderTitle(documentTitle, documentAuthor),
    );
  }

  List<KumihanBlock> _parseBlock(md.Node node) {
    if (node is md.Text) {
      return _paragraphBlocksFromText(node.text);
    }
    if (node is! md.Element) {
      return const <KumihanBlock>[];
    }

    switch (node.tag) {
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return _paragraphBlocksFromInlines(<KumihanInline>[
          KumihanStyledInline(
            children: _parseInlineChildren(node.children),
            style: _headingStyle(node.tag),
          ),
        ]);
      case 'p':
        return _paragraphBlocksFromInlines(_parseInlineChildren(node.children));
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
        return _paragraphBlocksFromText(node.textContent);
    }
  }

  List<KumihanBlock> _listBlocks(
    md.Element list, {
    required bool ordered,
    int depth = 0,
  }) {
    final blocks = <KumihanBlock>[];
    var index = 1;
    for (final child in list.children ?? const <md.Node>[]) {
      if (child is! md.Element || child.tag != 'li') {
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

  List<KumihanBlock> _codeBlockBlocks(md.Element node) {
    final codeText = node.textContent.replaceFirst(RegExp(r'\n$'), '');
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

  List<KumihanBlock> _tableBlocks(md.Element table) {
    final rows = <List<KumihanTableCell>>[];
    for (final section in table.children ?? const <md.Node>[]) {
      if (section is! md.Element) {
        continue;
      }
      for (final row in section.children ?? const <md.Node>[]) {
        if (row is! md.Element || row.tag != 'tr') {
          continue;
        }
        final cells = <KumihanTableCell>[];
        for (final cell in row.children ?? const <md.Node>[]) {
          if (cell is md.Element && (cell.tag == 'th' || cell.tag == 'td')) {
            cells.add(
              KumihanTableCell(
                text: cell.textContent.trim(),
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
      return const <KumihanBlock>[];
    }
    return <KumihanBlock>[
      KumihanTableBlock(rows: rows, headerRowCount: _headerRowCount(table)),
    ];
  }

  List<KumihanInline> _parseInlineChildren(List<md.Node>? nodes) {
    if (nodes == null || nodes.isEmpty) {
      return const <KumihanInline>[];
    }

    final children = <KumihanInline>[];
    for (final node in nodes) {
      children.addAll(_parseInline(node));
    }
    return _mergeAdjacentTextInlines(children);
  }

  List<KumihanInline> _parseInline(md.Node node) {
    if (node is md.Text) {
      return <KumihanInline>[KumihanTextInline(node.text)];
    }
    if (node is! md.Element) {
      return const <KumihanInline>[];
    }

    switch (node.tag) {
      case 'em':
        return <KumihanInline>[
          KumihanStyledInline(
            children: _parseInlineChildren(node.children),
            style: '斜体',
          ),
        ];
      case 'strong':
        return <KumihanInline>[
          KumihanStyledInline(
            children: _parseInlineChildren(node.children),
            style: '太字',
          ),
        ];
      case 'a':
        final target = node.attributes['href']?.trim() ?? '';
        final children = _parseInlineChildren(node.children);
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
                children: <KumihanInline>[KumihanTextInline(node.textContent)],
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
        return <KumihanInline>[
          const KumihanTextInline('~~'),
          ..._parseInlineChildren(node.children),
          const KumihanTextInline('~~'),
        ];
      default:
        final text = node.textContent;
        return text.isEmpty
            ? const <KumihanInline>[]
            : <KumihanInline>[KumihanTextInline(text)];
    }
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
    if (children.isEmpty) {
      return const <KumihanParagraphBlock>[
        KumihanParagraphBlock(children: <KumihanInline>[]),
      ];
    }

    final blocks = <KumihanParagraphBlock>[];
    var current = <KumihanInline>[];

    void flush() {
      blocks.add(KumihanParagraphBlock(children: current));
      current = <KumihanInline>[];
    }

    for (final child in children) {
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

  String _blockquoteText(md.Element node) {
    final lines = <String>[];
    for (final child in node.children ?? const <md.Node>[]) {
      final text = child.textContent.trim();
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
    md.Element item, {
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

    for (final child in item.children ?? const <md.Node>[]) {
      if (child is md.Text) {
        appendParagraphs(_paragraphBlocksFromText(child.text));
        continue;
      }
      if (child is! md.Element) {
        continue;
      }
      if (child.tag == 'ul' || child.tag == 'ol') {
        blocks.addAll(
          _listBlocks(child, ordered: child.tag == 'ol', depth: depth + 1),
        );
        continue;
      }
      if (child.tag == 'p') {
        appendParagraphs(
          _paragraphBlocksFromInlines(_parseInlineChildren(child.children)),
        );
        continue;
      }
      appendParagraphs(_paragraphBlocksFromText(child.textContent));
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

  KumihanTableAlignment _tableAlignment(String? align) {
    switch (align) {
      case 'center':
        return KumihanTableAlignment.center;
      case 'right':
        return KumihanTableAlignment.end;
      default:
        return KumihanTableAlignment.start;
    }
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
