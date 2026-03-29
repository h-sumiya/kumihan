import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan_v1/kumihan.dart';

DocumentNode parseDocument(String source) {
  return AozoraAstParser().parse(source);
}

ParagraphNode onlyParagraph(DocumentNode document) {
  expect(document.children, hasLength(1));
  final node = document.children.single;
  expect(node, isA<ParagraphNode>());
  return node as ParagraphNode;
}

T inlineNodeAt<T extends InlineNode>(ParagraphNode paragraph, int index) {
  return paragraph.children[index] as T;
}

T blockNodeAt<T extends BlockNode>(DocumentNode document, int index) {
  return document.children[index] as T;
}

class TestInlineContainerView {
  const TestInlineContainerView({
    required this.children,
    this.attributes = const <String, String>{},
    this.isClosed = true,
  });

  final List<InlineNode> children;
  final Map<String, String> attributes;
  final bool isClosed;
}

class TestBlockContainerView {
  const TestBlockContainerView({
    required this.children,
    this.attributes = const <String, String>{},
    this.isClosed = true,
  });

  final List<BlockNode> children;
  final Map<String, String> attributes;
  final bool isClosed;
}

void expectInlineAnnotation(
  InlineNode node, {
  required String kind,
  required String text,
}) {
  switch (kind) {
    case 'unresolvedGaiji':
      expectUnresolvedGaijiNode(node, text);
    case 'okurigana':
      expectOkuriganaNode(node, text);
    case 'kaeriten':
      expectKaeritenNode(node, text);
    case 'editorNote':
      expectEditorNoteNode(node, text);
    case 'superscript':
      expectScriptNode(node, kind: ScriptKind.superscript, text: text);
    case 'subscript':
      expectScriptNode(node, kind: ScriptKind.subscript, text: text);
    default:
      fail('Unsupported inline annotation kind: $kind');
  }
}

TestInlineContainerView expectInlineContainer(
  InlineNode node, {
  required String kind,
  String? variant,
}) {
  switch ((kind, variant)) {
    case ('direction', 'tateChuYoko'):
      final direction = expectDirectionNode(node);
      return TestInlineContainerView(children: direction.children);
    case ('flow', 'yokogumi'):
      final flow = expectFlowNode(node);
      return TestInlineContainerView(children: flow.children);
    case ('caption', 'caption'):
      final caption = expectCaptionNode(node);
      return TestInlineContainerView(children: caption.children);
    case ('frame', 'keigakomi'):
      final frame = expectFrameInlineNode(node);
      return TestInlineContainerView(
        children: frame.children,
        attributes: <String, String>{
          'borderWidth': frame.borderWidth.toString(),
        },
      );
    case ('note', 'warichu'):
      final note = expectNoteNode(node, NoteKind.warichu);
      return TestInlineContainerView(children: note.children);
    case ('note', 'warigaki'):
      final note = expectNoteNode(node, NoteKind.warigaki);
      return TestInlineContainerView(children: note.children);
    case ('style', 'bold'):
      final styled = expectStyledInlineNode(node, TextStyleKind.bold);
      return TestInlineContainerView(children: styled.children);
    case ('style', 'italic'):
      final styled = expectStyledInlineNode(node, TextStyleKind.italic);
      return TestInlineContainerView(children: styled.children);
    case ('fontSize', 'larger'):
      final fontSize = node as FontSizeInlineNode;
      expect(fontSize.kind, FontSizeKind.larger);
      return TestInlineContainerView(
        children: fontSize.children,
        attributes: <String, String>{'steps': fontSize.steps.toString()},
      );
    case ('fontSize', 'smaller'):
      final fontSize = node as FontSizeInlineNode;
      expect(fontSize.kind, FontSizeKind.smaller);
      return TestInlineContainerView(
        children: fontSize.children,
        attributes: <String, String>{'steps': fontSize.steps.toString()},
      );
    case ('heading', 'small'):
      final heading = node as HeadingInlineNode;
      expect(heading.level, HeadingLevel.small);
      return TestInlineContainerView(
        children: heading.children,
        attributes: <String, String>{'display': heading.display.name},
      );
    case ('heading', 'medium'):
      final heading = node as HeadingInlineNode;
      expect(heading.level, HeadingLevel.medium);
      return TestInlineContainerView(
        children: heading.children,
        attributes: <String, String>{'display': heading.display.name},
      );
    case ('heading', 'large'):
      final heading = node as HeadingInlineNode;
      expect(heading.level, HeadingLevel.large);
      return TestInlineContainerView(
        children: heading.children,
        attributes: <String, String>{'display': heading.display.name},
      );
    case ('emphasis', _):
      final emphasis = node as EmphasisInlineNode;
      expect(emphasis.mark.name, variant);
      return TestInlineContainerView(
        children: emphasis.children,
        attributes: <String, String>{
          if (emphasis.side != EmphasisSide.auto)
            'direction': _sideToJapanese(emphasis.side),
        },
      );
    case ('decoration', _):
      final decoration = node as DecorationInlineNode;
      expect(decoration.kind.name, variant);
      return TestInlineContainerView(
        children: decoration.children,
        attributes: <String, String>{
          if (decoration.side != DecorationSide.auto)
            'direction': _decorationSideToJapanese(decoration.side),
        },
      );
    default:
      fail('Unsupported inline container kind/variant: ($kind, $variant)');
  }
}

TestBlockContainerView expectBlockContainer(
  BlockNode node, {
  required String kind,
  String? variant,
}) {
  switch ((kind, variant)) {
    case ('indent', _):
      final indent = node as IndentBlockNode;
      return TestBlockContainerView(
        children: indent.children,
        attributes: <String, String>{
          if (indent.width != null) 'width': indent.width.toString(),
        },
        isClosed: indent.isClosed,
      );
    case ('measure', 'jizume'):
      final jizume = node as JizumeBlockNode;
      return TestBlockContainerView(
        children: jizume.children,
        attributes: <String, String>{
          if (jizume.width != null) 'width': jizume.width.toString(),
        },
        isClosed: jizume.isClosed,
      );
    case ('flow', 'yokogumi'):
      final flow = node as FlowBlockNode;
      return TestBlockContainerView(
        children: flow.children,
        isClosed: flow.isClosed,
      );
    case ('caption', 'caption'):
      final caption = node as CaptionBlockNode;
      return TestBlockContainerView(
        children: caption.children,
        isClosed: caption.isClosed,
      );
    case ('frame', 'keigakomi'):
      final frame = node as FrameBlockNode;
      return TestBlockContainerView(
        children: frame.children,
        attributes: <String, String>{
          'borderWidth': frame.borderWidth.toString(),
        },
        isClosed: frame.isClosed,
      );
    case ('style', 'bold'):
      final styled = node as StyledBlockNode;
      expect(styled.style, TextStyleKind.bold);
      return TestBlockContainerView(
        children: styled.children,
        isClosed: styled.isClosed,
      );
    case ('style', 'italic'):
      final styled = node as StyledBlockNode;
      expect(styled.style, TextStyleKind.italic);
      return TestBlockContainerView(
        children: styled.children,
        isClosed: styled.isClosed,
      );
    case ('fontSize', 'larger'):
      final fontSize = node as FontSizeBlockNode;
      expect(fontSize.kind, FontSizeKind.larger);
      return TestBlockContainerView(
        children: fontSize.children,
        attributes: <String, String>{'steps': fontSize.steps.toString()},
        isClosed: fontSize.isClosed,
      );
    case ('fontSize', 'smaller'):
      final fontSize = node as FontSizeBlockNode;
      expect(fontSize.kind, FontSizeKind.smaller);
      return TestBlockContainerView(
        children: fontSize.children,
        attributes: <String, String>{'steps': fontSize.steps.toString()},
        isClosed: fontSize.isClosed,
      );
    case ('heading', 'small'):
      final heading = node as HeadingBlockNode;
      expect(heading.level, HeadingLevel.small);
      return TestBlockContainerView(
        children: heading.children,
        attributes: <String, String>{'display': heading.display.name},
        isClosed: heading.isClosed,
      );
    case ('heading', 'medium'):
      final heading = node as HeadingBlockNode;
      expect(heading.level, HeadingLevel.medium);
      return TestBlockContainerView(
        children: heading.children,
        attributes: <String, String>{'display': heading.display.name},
        isClosed: heading.isClosed,
      );
    case ('heading', 'large'):
      final heading = node as HeadingBlockNode;
      expect(heading.level, HeadingLevel.large);
      return TestBlockContainerView(
        children: heading.children,
        attributes: <String, String>{'display': heading.display.name},
        isClosed: heading.isClosed,
      );
    default:
      fail('Unsupported block container kind/variant: ($kind, $variant)');
  }
}

UnresolvedGaijiNode expectUnresolvedGaijiNode(InlineNode node, String text) {
  expect(node, isA<UnresolvedGaijiNode>());
  final unresolved = node as UnresolvedGaijiNode;
  expect(unresolved.text, text);
  return unresolved;
}

OkuriganaNode expectOkuriganaNode(InlineNode node, String text) {
  expect(node, isA<OkuriganaNode>());
  final okurigana = node as OkuriganaNode;
  expect(okurigana.text, text);
  return okurigana;
}

KaeritenNode expectKaeritenNode(InlineNode node, String text) {
  expect(node, isA<KaeritenNode>());
  final kaeriten = node as KaeritenNode;
  expect(kaeriten.text, text);
  return kaeriten;
}

EditorNoteNode expectEditorNoteNode(InlineNode node, String text) {
  expect(node, isA<EditorNoteNode>());
  final note = node as EditorNoteNode;
  expect(note.text, text);
  return note;
}

ScriptInlineNode expectScriptNode(
  InlineNode node, {
  required ScriptKind kind,
  required String text,
}) {
  expect(node, isA<ScriptInlineNode>());
  final script = node as ScriptInlineNode;
  expect(script.kind, kind);
  expect(script.text, text);
  return script;
}

DirectionInlineNode expectDirectionNode(InlineNode node) {
  expect(node, isA<DirectionInlineNode>());
  final direction = node as DirectionInlineNode;
  expect(direction.kind, DirectionKind.tateChuYoko);
  return direction;
}

FlowInlineNode expectFlowNode(InlineNode node) {
  expect(node, isA<FlowInlineNode>());
  final flow = node as FlowInlineNode;
  expect(flow.kind, FlowKind.yokogumi);
  return flow;
}

CaptionInlineNode expectCaptionNode(InlineNode node) {
  expect(node, isA<CaptionInlineNode>());
  return node as CaptionInlineNode;
}

FrameInlineNode expectFrameInlineNode(InlineNode node, {int borderWidth = 1}) {
  expect(node, isA<FrameInlineNode>());
  final frame = node as FrameInlineNode;
  expect(frame.kind, FrameKind.keigakomi);
  expect(frame.borderWidth, borderWidth);
  return frame;
}

NoteInlineNode expectNoteNode(InlineNode node, NoteKind kind) {
  expect(node, isA<NoteInlineNode>());
  final note = node as NoteInlineNode;
  expect(note.kind, kind);
  return note;
}

StyledInlineNode expectStyledInlineNode(InlineNode node, TextStyleKind style) {
  expect(node, isA<StyledInlineNode>());
  final styled = node as StyledInlineNode;
  expect(styled.style, style);
  return styled;
}

FontSizeInlineNode expectFontSizeInlineNode(
  InlineNode node, {
  required FontSizeKind kind,
  required int steps,
}) {
  expect(node, isA<FontSizeInlineNode>());
  final fontSize = node as FontSizeInlineNode;
  expect(fontSize.kind, kind);
  expect(fontSize.steps, steps);
  return fontSize;
}

HeadingInlineNode expectHeadingInlineNode(
  InlineNode node, {
  required HeadingLevel level,
  required HeadingDisplay display,
}) {
  expect(node, isA<HeadingInlineNode>());
  final heading = node as HeadingInlineNode;
  expect(heading.level, level);
  expect(heading.display, display);
  return heading;
}

EmphasisInlineNode expectEmphasisNode(
  InlineNode node, {
  required EmphasisMark mark,
}) {
  expect(node, isA<EmphasisInlineNode>());
  final emphasis = node as EmphasisInlineNode;
  expect(emphasis.mark, mark);
  return emphasis;
}

DecorationInlineNode expectDecorationNode(
  InlineNode node, {
  required DecorationKind kind,
}) {
  expect(node, isA<DecorationInlineNode>());
  final decoration = node as DecorationInlineNode;
  expect(decoration.kind, kind);
  return decoration;
}

IndentBlockNode expectIndentBlockNode(
  BlockNode node, {
  int? width,
  bool? isClosed,
}) {
  expect(node, isA<IndentBlockNode>());
  final indent = node as IndentBlockNode;
  expect(indent.width, width);
  if (isClosed != null) {
    expect(indent.isClosed, isClosed);
  }
  return indent;
}

JizumeBlockNode expectJizumeBlockNode(BlockNode node, {required int? width}) {
  expect(node, isA<JizumeBlockNode>());
  final jizume = node as JizumeBlockNode;
  expect(jizume.width, width);
  return jizume;
}

FlowBlockNode expectFlowBlockNode(BlockNode node) {
  expect(node, isA<FlowBlockNode>());
  final flow = node as FlowBlockNode;
  expect(flow.kind, FlowKind.yokogumi);
  return flow;
}

CaptionBlockNode expectCaptionBlockNode(BlockNode node) {
  expect(node, isA<CaptionBlockNode>());
  return node as CaptionBlockNode;
}

FrameBlockNode expectFrameBlockNode(BlockNode node, {int borderWidth = 1}) {
  expect(node, isA<FrameBlockNode>());
  final frame = node as FrameBlockNode;
  expect(frame.kind, FrameKind.keigakomi);
  expect(frame.borderWidth, borderWidth);
  return frame;
}

StyledBlockNode expectStyledBlockNode(
  BlockNode node, {
  required TextStyleKind style,
  bool? isClosed,
}) {
  expect(node, isA<StyledBlockNode>());
  final styled = node as StyledBlockNode;
  expect(styled.style, style);
  if (isClosed != null) {
    expect(styled.isClosed, isClosed);
  }
  return styled;
}

FontSizeBlockNode expectFontSizeBlockNode(
  BlockNode node, {
  required FontSizeKind kind,
  required int steps,
}) {
  expect(node, isA<FontSizeBlockNode>());
  final fontSize = node as FontSizeBlockNode;
  expect(fontSize.kind, kind);
  expect(fontSize.steps, steps);
  return fontSize;
}

HeadingBlockNode expectHeadingBlockNode(
  BlockNode node, {
  required HeadingLevel level,
  required HeadingDisplay display,
}) {
  expect(node, isA<HeadingBlockNode>());
  final heading = node as HeadingBlockNode;
  expect(heading.level, level);
  expect(heading.display, display);
  return heading;
}

TextNode expectTextNode(InlineNode node, String text) {
  expect(node, isA<TextNode>());
  final textNode = node as TextNode;
  expect(textNode.text, text);
  return textNode;
}

RubyNode expectRubyNode(
  InlineNode node, {
  required RubyKind kind,
  required RubyPosition position,
  required String text,
}) {
  expect(node, isA<RubyNode>());
  final ruby = node as RubyNode;
  expect(ruby.kind, kind);
  expect(ruby.position, position);
  expect(ruby.text, text);
  return ruby;
}

GaijiNode expectGaijiNode(
  InlineNode node, {
  required String description,
  String? jisCode,
  String? unicodeCodePoint,
}) {
  expect(node, isA<GaijiNode>());
  final gaiji = node as GaijiNode;
  expect(gaiji.description, description);
  if (jisCode != null) {
    expect(gaiji.jisCode, jisCode);
  }
  if (unicodeCodePoint != null) {
    expect(gaiji.unicodeCodePoint, unicodeCodePoint);
  }
  return gaiji;
}

ImageNode expectImageNode(
  InlineNode node, {
  required String source,
  String? alt,
  String? className,
  int? width,
  int? height,
}) {
  expect(node, isA<ImageNode>());
  final image = node as ImageNode;
  expect(image.source, source);
  expect(image.alt, alt);
  expect(image.className, className);
  expect(image.width, width);
  expect(image.height, height);
  return image;
}

String _sideToJapanese(EmphasisSide side) {
  return switch (side) {
    EmphasisSide.left => '左',
    EmphasisSide.right => '右',
    EmphasisSide.over => '上',
    EmphasisSide.under => '下',
    EmphasisSide.auto => 'auto',
  };
}

String _decorationSideToJapanese(DecorationSide side) {
  return switch (side) {
    DecorationSide.left => '左',
    DecorationSide.right => '右',
    DecorationSide.over => '上',
    DecorationSide.under => '下',
    DecorationSide.auto => 'auto',
  };
}
