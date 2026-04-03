import 'ast.dart';

typedef KumihanAstDslChildren = List<Object>;

abstract interface class KumihanAstDslNode {
  const KumihanAstDslNode();

  AstData toAst({bool inWarichu = false});
}

class Document {
  Document([Iterable<Object> nodes = const <Object>[]])
    : this.fromAst(KumihanAstDsl.flatten(nodes, inWarichu: false));

  Document.fromAst(Iterable<AstToken> ast, {this.headerTitle = '', this.value})
    : ast = List<AstToken>.unmodifiable(ast);

  final AstData ast;
  final String headerTitle;
  final Object? value;
}

final class KumihanAstDsl {
  static AstData flatten(Iterable<Object> nodes, {required bool inWarichu}) {
    final tokens = <AstToken>[];
    for (final node in nodes) {
      _appendNode(tokens, node, inWarichu: inWarichu);
    }
    return tokens;
  }

  static AstInlineContent inline(Iterable<Object> nodes) {
    final tokens = flatten(nodes, inWarichu: false);
    final inlineNodes = <AstInlineNode>[];
    for (final token in tokens) {
      if (token is! AstInlineNode) {
        throw ArgumentError.value(
          token,
          'nodes',
          'Inline content must resolve to AstInlineNode.',
        );
      }
      inlineNodes.add(token as AstInlineNode);
    }
    return inlineNodes;
  }

  static void _appendNode(
    List<AstToken> tokens,
    Object node, {
    required bool inWarichu,
  }) {
    switch (node) {
      case String():
        _appendString(tokens, node, inWarichu: inWarichu);
      case KumihanAstDslNode():
        tokens.addAll(node.toAst(inWarichu: inWarichu));
      case AstNewLine():
        tokens.add(inWarichu ? const AstWarichuNewLine() : node);
      case Iterable():
        for (final child in node) {
          _appendNode(tokens, child, inWarichu: inWarichu);
        }
      case AstToken():
        tokens.add(node);
      default:
        throw ArgumentError.value(
          node,
          'node',
          'Unsupported AST DSL node type: ${node.runtimeType}',
        );
    }
  }

  static void _appendString(
    List<AstToken> tokens,
    String value, {
    required bool inWarichu,
  }) {
    final normalized = value.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    var start = 0;

    for (var index = 0; index < normalized.length; index++) {
      if (normalized.codeUnitAt(index) != 0x0A) {
        continue;
      }
      if (start < index) {
        tokens.add(AstText(normalized.substring(start, index)));
      }
      tokens.add(inWarichu ? const AstWarichuNewLine() : const AstNewLine());
      start = index + 1;
    }

    if (start < normalized.length) {
      tokens.add(AstText(normalized.substring(start)));
    }
  }
}
