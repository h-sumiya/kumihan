import '../kumihan_document.dart';

class CompiledKumihanDocument {
  const CompiledKumihanDocument({
    required this.cover,
    required this.entries,
    required this.headerTitle,
    required this.sourceText,
  });

  final KumihanCoverBlock? cover;
  final List<CompiledKumihanEntry> entries;
  final String headerTitle;
  final String sourceText;
}

sealed class CompiledKumihanEntry {
  const CompiledKumihanEntry();
}

class CompiledKumihanTextEntry extends CompiledKumihanEntry {
  const CompiledKumihanTextEntry(this.text);

  final String text;
}

class CompiledKumihanTableEntry extends CompiledKumihanEntry {
  const CompiledKumihanTableEntry(this.table);

  final KumihanTableBlock table;
}

CompiledKumihanDocument compileKumihanDocument(KumihanDocument document) {
  final entries = <CompiledKumihanEntry>[];
  final lines = <String>[];
  KumihanCoverBlock? cover;

  for (var index = 0; index < document.blocks.length; index += 1) {
    final block = document.blocks[index];

    if (index == 0 && block is KumihanCoverBlock) {
      cover = block;
      continue;
    }

    if (block is KumihanCommandBlock) {
      lines.add(block.command);
      entries.add(CompiledKumihanTextEntry(block.command));
      continue;
    }

    if (block is KumihanParagraphBlock) {
      final buffer = StringBuffer();
      if (block.keepWithPrevious) {
        buffer.write('‌');
      }
      for (final command in block.leadingCommands) {
        buffer.write(command);
      }
      buffer.write(_serializeInlines(block.children));
      final line = buffer.toString();
      lines.add(line);
      entries.add(CompiledKumihanTextEntry(line));
      continue;
    }

    if (block is KumihanTableBlock) {
      entries.add(CompiledKumihanTableEntry(block));
    }
  }

  return CompiledKumihanDocument(
    cover: cover,
    entries: entries,
    headerTitle: document.headerTitle.isNotEmpty
        ? document.headerTitle
        : _deriveHeaderTitle(cover),
    sourceText: lines.join('\n'),
  );
}

String _deriveHeaderTitle(KumihanCoverBlock? cover) {
  if (cover == null) {
    return '';
  }
  final credit = cover.credit?.trim() ?? '';
  if (credit.isNotEmpty) {
    return '${cover.title} / $credit';
  }
  final subtitle = cover.subtitle?.trim() ?? '';
  if (subtitle.isNotEmpty) {
    return '${cover.title} / $subtitle';
  }
  return cover.title;
}

String _serializeInlines(List<KumihanInline> children) {
  final buffer = StringBuffer();
  for (final child in children) {
    buffer.write(_serializeInline(child));
  }
  return buffer.toString();
}

String _serializeInline(KumihanInline inline) {
  switch (inline) {
    case KumihanTextInline():
      return inline.text;
    case KumihanRubyInline():
      final visible = _serializeInlines(inline.children);
      final plain = _plainText(inline.children);
      if (plain.isEmpty) {
        return visible;
      }
      final annotationType = inline.side == KumihanRubySide.left ? 'る' : 'ル';
      return '$visible￹$annotationType$plain￺${inline.ruby}￻';
    case KumihanStyledInline():
      final visible = _serializeInlines(inline.children);
      final plain = _plainText(inline.children);
      if (plain.isEmpty) {
        return visible;
      }
      if (inline.style == '割り注') {
        return '$visible￹割$plain￺$plain￻';
      }
      return '$visible￹${_annotationTypeForStyle(inline.style)}$plain￺${inline.style}￻';
    case KumihanLinkInline():
      final visible = _serializeInlines(inline.children);
      final fallback = visible.isEmpty ? inline.target : visible;
      final plain = _plainText(inline.children).isEmpty
          ? inline.target
          : _plainText(inline.children);
      return '$fallback￹リ$plain￺${inline.target}￻';
    case KumihanAnchorInline():
      return '￹ア￺${inline.name}￻';
    case KumihanImageInline():
      final width = inline.width?.toString() ?? '';
      final height = inline.height?.toString() ?? '';
      final annotationType = inline.kind == KumihanImageKind.gaiji ? '外' : '画';
      return '￼￹$annotationType￺${inline.path}\t$width\t$height￻';
    case KumihanRawInline():
      return inline.source;
  }
}

String _plainText(List<KumihanInline> children) {
  final buffer = StringBuffer();
  for (final child in children) {
    buffer.write(_plainTextInline(child));
  }
  return buffer.toString();
}

String _plainTextInline(KumihanInline inline) {
  switch (inline) {
    case KumihanTextInline():
      return inline.text;
    case KumihanRubyInline():
      return _plainText(inline.children);
    case KumihanStyledInline():
      return _plainText(inline.children);
    case KumihanLinkInline():
      return _plainText(inline.children);
    case KumihanAnchorInline():
      return '';
    case KumihanImageInline():
      return '￼';
    case KumihanRawInline():
      return inline.source;
  }
}

String _annotationTypeForStyle(String style) {
  switch (style) {
    case '大見出し':
    case '中見出し':
    case '小見出し':
      return '見';
    case '縦中横':
      return '横';
    case '横組み':
      return '回';
    case '行右小書き':
    case '行左小書き':
    case '上付き小文字':
    case '下付き小文字':
      return '小';
    case '罫囲み':
      return '罫';
    case '割り注':
      return '割';
    default:
      return '字';
  }
}
