import 'package:flutter/painting.dart';

import 'ast.dart';
import 'document.dart';

Document ast(Iterable<Object> nodes) {
  return Document(nodes);
}

class LineBreak implements KumihanAstDslNode {
  const LineBreak();

  @override
  AstData toAst({bool inWarichu = false}) {
    return <AstToken>[
      inWarichu ? const AstWarichuNewLine() : const AstNewLine(),
    ];
  }
}

class Br extends LineBreak {
  const Br();
}

class WarichuBreak implements KumihanAstDslNode {
  const WarichuBreak();

  @override
  AstData toAst({bool inWarichu = false}) {
    return const <AstToken>[AstWarichuNewLine()];
  }
}

class Ruby implements KumihanAstDslNode {
  final KumihanAstDslChildren children;
  final KumihanAstDslChildren ruby;
  final AstTextSide side;

  const Ruby({
    required this.children,
    required this.ruby,
    this.side = AstTextSide.right,
  });

  factory Ruby.text(
    String base,
    String rubyText, {
    AstTextSide side = AstTextSide.right,
  }) {
    return Ruby(children: <Object>[base], ruby: <Object>[rubyText], side: side);
  }

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapAttachedText(
      children: children,
      role: AstAttachedTextRole.ruby,
      content: ruby,
      side: side,
    );
  }
}

class Note implements KumihanAstDslNode {
  final KumihanAstDslChildren children;
  final KumihanAstDslChildren note;
  final AstTextSide side;

  const Note({
    required this.children,
    required this.note,
    this.side = AstTextSide.right,
  });

  factory Note.text(
    String base,
    String noteText, {
    AstTextSide side = AstTextSide.right,
  }) {
    return Note(children: <Object>[base], note: <Object>[noteText], side: side);
  }

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapAttachedText(
      children: children,
      role: AstAttachedTextRole.note,
      content: note,
      side: side,
    );
  }
}

class Text implements KumihanAstDslNode {
  final String? value;
  final KumihanAstDslChildren children;
  final Color? color;
  final bool bold;
  final bool italic;
  final int? size;
  final KumihanAstDslChildren? ruby;
  final AstTextSide rubySide;
  final AstBoutenKind? bouten;
  final AstBosenKind? border;
  final bool tatechuyoko;
  final bool block;

  const Text({
    this.value,
    this.children = const <Object>[],
    this.color,
    this.bold = false,
    this.italic = false,
    this.size,
    this.ruby,
    this.rubySide = AstTextSide.right,
    this.bouten,
    this.border,
    this.tatechuyoko = false,
    this.block = false,
  }) : assert(
         value != null || children.length > 0,
         'Text requires value or children.',
       );

  KumihanAstDslChildren get _content {
    return <Object>[?value, ...children];
  }

  @override
  AstData toAst({bool inWarichu = false}) {
    AstData tokens = KumihanAstDsl.flatten(_content, inWarichu: inWarichu);

    if (tatechuyoko) {
      tokens = _wrapTokens(
        start: const AstInlineDecoration(
          boundary: AstRangeBoundary.start,
          kind: AstInlineDecorationKind.tatechuyoko,
        ),
        children: tokens,
        end: const AstInlineDecoration(
          boundary: AstRangeBoundary.end,
          kind: AstInlineDecorationKind.tatechuyoko,
        ),
      );
    }

    if (size case final steps?) {
      final boundary = block
          ? AstRangeBoundary.blockStart
          : AstRangeBoundary.start;
      final endBoundary = block
          ? AstRangeBoundary.blockEnd
          : AstRangeBoundary.end;
      if (steps > 0) {
        final style = AstFontScaleStyle(
          direction: AstFontScaleDirection.larger,
          steps: steps,
        );
        tokens = _wrapTokens(
          start: AstStyledText(boundary: boundary, style: style),
          children: tokens,
          end: AstStyledText(boundary: endBoundary, style: style),
        );
      } else if (steps < 0) {
        final style = AstFontScaleStyle(
          direction: AstFontScaleDirection.smaller,
          steps: -steps,
        );
        tokens = _wrapTokens(
          start: AstStyledText(boundary: boundary, style: style),
          children: tokens,
          end: AstStyledText(boundary: endBoundary, style: style),
        );
      }
    }

    if (italic) {
      tokens = _wrapStyledTokens(
        tokens,
        style: const AstFontStyleAnnotation(AstFontStyle.italic),
        block: block,
      );
    }

    if (bold) {
      tokens = _wrapStyledTokens(
        tokens,
        style: const AstFontStyleAnnotation(AstFontStyle.bold),
        block: block,
      );
    }

    if (border case final kind?) {
      tokens = _wrapStyledTokens(
        tokens,
        style: AstBosenStyle(kind: kind),
        block: block,
      );
    }

    if (bouten case final kind?) {
      tokens = _wrapStyledTokens(
        tokens,
        style: AstBoutenStyle(kind: kind),
        block: block,
      );
    }

    if (color case final textColor?) {
      tokens = _wrapStyledTokens(
        tokens,
        style: AstTextColorStyle(textColor.toARGB32()),
        block: block,
      );
    }

    if (ruby case final rubyContent?) {
      tokens = _wrapAttachedTextTokens(
        children: tokens,
        role: AstAttachedTextRole.ruby,
        content: rubyContent,
        side: rubySide,
      );
    }

    return tokens;
  }
}

class Styled implements KumihanAstDslNode {
  final AstTextStyle style;
  final KumihanAstDslChildren children;
  final bool block;

  const Styled({
    required this.style,
    required this.children,
    this.block = false,
  });

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapBoundary(
      start: AstStyledText(
        boundary: block ? AstRangeBoundary.blockStart : AstRangeBoundary.start,
        style: style,
      ),
      children: children,
      end: AstStyledText(
        boundary: block ? AstRangeBoundary.blockEnd : AstRangeBoundary.end,
        style: style,
      ),
      inWarichu: inWarichu,
    );
  }
}

class Bold extends Styled {
  const Bold({required super.children, super.block})
    : super(style: const AstFontStyleAnnotation(AstFontStyle.bold));
}

class Italic extends Styled {
  const Italic({required super.children, super.block})
    : super(style: const AstFontStyleAnnotation(AstFontStyle.italic));
}

class FontScale extends Styled {
  FontScale.larger({required super.children, required int steps, super.block})
    : super(
        style: AstFontScaleStyle(
          direction: AstFontScaleDirection.larger,
          steps: steps,
        ),
      );

  FontScale.smaller({required super.children, required int steps, super.block})
    : super(
        style: AstFontScaleStyle(
          direction: AstFontScaleDirection.smaller,
          steps: steps,
        ),
      );
}

class TextColor extends Styled {
  TextColor({required Color color, required super.children, super.block})
    : super(style: AstTextColorStyle(color.toARGB32()));
}

class Bouten extends Styled {
  Bouten({
    required super.children,
    required AstBoutenKind kind,
    AstTextSide side = AstTextSide.right,
    super.block,
  }) : super(
         style: AstBoutenStyle(kind: kind, side: side),
       );
}

class Bosen extends Styled {
  Bosen({
    required super.children,
    required AstBosenKind kind,
    AstTextSide side = AstTextSide.right,
    super.block,
  }) : super(
         style: AstBosenStyle(kind: kind, side: side),
       );
}

class Heading implements KumihanAstDslNode {
  final AstHeadingLevel level;
  final AstHeadingForm form;
  final KumihanAstDslChildren children;
  final bool block;

  const Heading({
    required this.level,
    required this.children,
    this.form = AstHeadingForm.standalone,
    this.block = false,
  });

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapBoundary(
      start: AstHeading(
        boundary: block ? AstRangeBoundary.blockStart : AstRangeBoundary.start,
        form: form,
        level: level,
      ),
      children: children,
      end: AstHeading(
        boundary: block ? AstRangeBoundary.blockEnd : AstRangeBoundary.end,
        form: form,
        level: level,
      ),
      inWarichu: inWarichu,
    );
  }
}

class Caption implements KumihanAstDslNode {
  final KumihanAstDslChildren children;
  final bool block;

  const Caption({required this.children, this.block = false});

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapBoundary(
      start: AstCaption(
        block ? AstRangeBoundary.blockStart : AstRangeBoundary.start,
      ),
      children: children,
      end: AstCaption(block ? AstRangeBoundary.blockEnd : AstRangeBoundary.end),
      inWarichu: inWarichu,
    );
  }
}

class InlineDecoration implements KumihanAstDslNode {
  final AstInlineDecorationKind kind;
  final KumihanAstDslChildren children;
  final bool block;

  const InlineDecoration({
    required this.kind,
    required this.children,
    this.block = false,
  });

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapBoundary(
      start: AstInlineDecoration(
        boundary: block ? AstRangeBoundary.blockStart : AstRangeBoundary.start,
        kind: kind,
      ),
      children: children,
      end: AstInlineDecoration(
        boundary: block ? AstRangeBoundary.blockEnd : AstRangeBoundary.end,
        kind: kind,
      ),
      inWarichu: inWarichu,
    );
  }
}

class Tatechuyoko extends InlineDecoration {
  const Tatechuyoko({required super.children})
    : super(kind: AstInlineDecorationKind.tatechuyoko);
}

class Warichu extends InlineDecoration {
  Warichu({String? text, KumihanAstDslChildren children = const <Object>[]})
    : super(
        kind: AstInlineDecorationKind.warichu,
        children: text == null ? children : <Object>[text],
      );

  @override
  AstData toAst({bool inWarichu = false}) {
    return <AstToken>[
      const AstInlineDecoration(
        boundary: AstRangeBoundary.start,
        kind: AstInlineDecorationKind.warichu,
      ),
      ...KumihanAstDsl.flatten(children, inWarichu: true),
      const AstInlineDecoration(
        boundary: AstRangeBoundary.end,
        kind: AstInlineDecorationKind.warichu,
      ),
    ];
  }
}

class LineRightSmall extends InlineDecoration {
  const LineRightSmall({required super.children})
    : super(kind: AstInlineDecorationKind.lineRightSmall);
}

class LineLeftSmall extends InlineDecoration {
  const LineLeftSmall({required super.children})
    : super(kind: AstInlineDecorationKind.lineLeftSmall);
}

class Superscript extends InlineDecoration {
  const Superscript({required super.children})
    : super(kind: AstInlineDecorationKind.superscript);
}

class Subscript extends InlineDecoration {
  const Subscript({required super.children})
    : super(kind: AstInlineDecorationKind.subscript);
}

class Keigakomi extends InlineDecoration {
  const Keigakomi({required super.children, super.block})
    : super(kind: AstInlineDecorationKind.keigakomi);
}

class Yokogumi extends InlineDecoration {
  const Yokogumi({required super.children, super.block})
    : super(kind: AstInlineDecorationKind.yokogumi);
}

class Indent implements KumihanAstDslNode {
  final int lineIndent;
  final int? hangingIndent;
  final KumihanAstDslChildren? children;

  const Indent.line({required this.lineIndent, this.hangingIndent})
    : children = null;

  const Indent.block({
    required this.lineIndent,
    this.hangingIndent,
    required KumihanAstDslChildren this.children,
  });

  @override
  AstData toAst({bool inWarichu = false}) {
    if (children == null) {
      return <AstToken>[
        AstIndent(
          kind: AstIndentKind.singleLine,
          lineIndent: lineIndent,
          hangingIndent: hangingIndent,
        ),
      ];
    }
    return _wrapBoundary(
      start: AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockStart,
        lineIndent: lineIndent,
        hangingIndent: hangingIndent,
      ),
      children: children!,
      end: const AstIndent(
        kind: AstIndentKind.block,
        boundary: AstRangeBoundary.blockEnd,
        lineIndent: 0,
      ),
      inWarichu: inWarichu,
    );
  }
}

class BottomAlign implements KumihanAstDslNode {
  final AstBottomAlignKind kind;
  final int offset;
  final AstBottomAlignScope scope;
  final KumihanAstDslChildren? children;

  const BottomAlign.inlineTail({this.offset = 0})
    : kind = offset == 0
          ? AstBottomAlignKind.bottom
          : AstBottomAlignKind.raisedFromBottom,
      scope = AstBottomAlignScope.inlineTail,
      children = null;

  const BottomAlign.singleLine({this.offset = 0})
    : kind = offset == 0
          ? AstBottomAlignKind.bottom
          : AstBottomAlignKind.raisedFromBottom,
      scope = AstBottomAlignScope.singleLine,
      children = null;

  const BottomAlign.block({
    this.offset = 0,
    required KumihanAstDslChildren this.children,
  }) : kind = offset == 0
           ? AstBottomAlignKind.bottom
           : AstBottomAlignKind.raisedFromBottom,
       scope = AstBottomAlignScope.block;

  @override
  AstData toAst({bool inWarichu = false}) {
    if (children == null) {
      return <AstToken>[
        AstBottomAlign(kind: kind, scope: scope, offset: offset),
      ];
    }
    return _wrapBoundary(
      start: AstBottomAlign(
        kind: kind,
        scope: scope,
        boundary: AstRangeBoundary.blockStart,
        offset: offset,
      ),
      children: children!,
      end: AstBottomAlign(
        kind: kind,
        scope: scope,
        boundary: AstRangeBoundary.blockEnd,
        offset: offset,
      ),
      inWarichu: inWarichu,
    );
  }
}

class Jizume implements KumihanAstDslNode {
  final int width;
  final KumihanAstDslChildren children;

  const Jizume({required this.width, required this.children});

  @override
  AstData toAst({bool inWarichu = false}) {
    return _wrapBoundary(
      start: AstJizume(boundary: AstRangeBoundary.blockStart, width: width),
      children: children,
      end: const AstJizume(boundary: AstRangeBoundary.blockEnd),
      inWarichu: inWarichu,
    );
  }
}

class PageBreak implements KumihanAstDslNode {
  final AstPageBreakKind kind;

  const PageBreak(this.kind);

  @override
  AstData toAst({bool inWarichu = false}) {
    return <AstToken>[AstPageBreak(kind)];
  }
}

class PageCenter implements KumihanAstDslNode {
  const PageCenter();

  @override
  AstData toAst({bool inWarichu = false}) {
    return const <AstToken>[AstPageCenter()];
  }
}

class BodyEnd implements KumihanAstDslNode {
  const BodyEnd();

  @override
  AstData toAst({bool inWarichu = false}) {
    return const <AstToken>[AstBodyEnd()];
  }
}

AstData _wrapBoundary({
  required AstToken start,
  required KumihanAstDslChildren children,
  required AstToken end,
  required bool inWarichu,
}) {
  if (_isBlockBoundary(start) && _isBlockBoundary(end)) {
    return <AstToken>[
      start,
      const AstNewLine(),
      ...KumihanAstDsl.flatten(children, inWarichu: inWarichu),
      const AstNewLine(),
      end,
    ];
  }
  return _wrapTokens(
    start: start,
    children: KumihanAstDsl.flatten(children, inWarichu: inWarichu),
    end: end,
  );
}

bool _isBlockBoundary(AstToken token) {
  return switch (token) {
    AstStyledText(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    AstHeading(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    AstCaption(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    AstInlineDecoration(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    AstIndent(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    AstBottomAlign(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    AstJizume(
      boundary: AstRangeBoundary.blockStart || AstRangeBoundary.blockEnd,
    ) =>
      true,
    _ => false,
  };
}

AstData _wrapTokens({
  required AstToken start,
  required AstData children,
  required AstToken end,
}) {
  return <AstToken>[start, ...children, end];
}

AstData _wrapAttachedText({
  required KumihanAstDslChildren children,
  required AstAttachedTextRole role,
  required KumihanAstDslChildren content,
  required AstTextSide side,
}) {
  return _wrapAttachedTextTokens(
    children: KumihanAstDsl.flatten(children, inWarichu: false),
    role: role,
    content: content,
    side: side,
  );
}

AstData _wrapAttachedTextTokens({
  required AstData children,
  required AstAttachedTextRole role,
  required KumihanAstDslChildren content,
  required AstTextSide side,
}) {
  return <AstToken>[
    AstAttachedText(boundary: AstRangeBoundary.start, role: role, side: side),
    ...children,
    AstAttachedText(
      boundary: AstRangeBoundary.end,
      role: role,
      side: side,
      content: KumihanAstDsl.inline(content),
    ),
  ];
}

AstData _wrapStyledTokens(
  AstData children, {
  required AstTextStyle style,
  required bool block,
}) {
  return _wrapTokens(
    start: AstStyledText(
      boundary: block ? AstRangeBoundary.blockStart : AstRangeBoundary.start,
      style: style,
    ),
    children: children,
    end: AstStyledText(
      boundary: block ? AstRangeBoundary.blockEnd : AstRangeBoundary.end,
      style: style,
    ),
  );
}
