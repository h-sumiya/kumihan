class KumihanDocument {
  const KumihanDocument({required this.blocks, this.headerTitle = ''});

  final List<KumihanBlock> blocks;
  final String headerTitle;
}

sealed class KumihanBlock {
  const KumihanBlock();
}

class KumihanCoverBlock extends KumihanBlock {
  const KumihanCoverBlock({required this.title, this.subtitle, this.credit});

  final String title;
  final String? subtitle;
  final String? credit;
}

class KumihanCommandBlock extends KumihanBlock {
  const KumihanCommandBlock(this.command);

  final String command;
}

class KumihanParagraphBlock extends KumihanBlock {
  const KumihanParagraphBlock({
    required this.children,
    this.keepWithPrevious = false,
    this.leadingCommands = const <String>[],
  });

  final List<KumihanInline> children;
  final bool keepWithPrevious;
  final List<String> leadingCommands;
}

enum KumihanTableAlignment { start, center, end }

class KumihanTableCell {
  const KumihanTableCell({
    required this.text,
    this.alignment = KumihanTableAlignment.start,
  });

  final String text;
  final KumihanTableAlignment alignment;
}

class KumihanTableBlock extends KumihanBlock {
  const KumihanTableBlock({required this.rows, this.headerRowCount = 0});

  final List<List<KumihanTableCell>> rows;
  final int headerRowCount;
}

sealed class KumihanInline {
  const KumihanInline();
}

class KumihanTextInline extends KumihanInline {
  const KumihanTextInline(this.text);

  final String text;
}

enum KumihanRubySide { right, left }

class KumihanRubyInline extends KumihanInline {
  const KumihanRubyInline({
    required this.children,
    required this.ruby,
    this.side = KumihanRubySide.right,
  });

  final List<KumihanInline> children;
  final String ruby;
  final KumihanRubySide side;
}

class KumihanStyledInline extends KumihanInline {
  const KumihanStyledInline({required this.children, required this.style});

  final List<KumihanInline> children;
  final String style;
}

class KumihanLinkInline extends KumihanInline {
  const KumihanLinkInline({required this.children, required this.target});

  final List<KumihanInline> children;
  final String target;
}

class KumihanAnchorInline extends KumihanInline {
  const KumihanAnchorInline(this.name);

  final String name;
}

enum KumihanImageKind { painted, gaiji }

class KumihanImageInline extends KumihanInline {
  const KumihanImageInline({
    required this.path,
    this.height,
    this.kind = KumihanImageKind.painted,
    this.width,
  });

  final double? height;
  final KumihanImageKind kind;
  final String path;
  final double? width;
}

enum KumihanRawSyntax { aozora, engine }

class KumihanRawInline extends KumihanInline {
  const KumihanRawInline(this.source, {this.syntax = KumihanRawSyntax.aozora});

  final String source;
  final KumihanRawSyntax syntax;
}
