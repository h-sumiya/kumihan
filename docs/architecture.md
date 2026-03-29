# kumihan-v1 Architecture

## Layers

`kumihan-v1` separates vertical composition into four layers.

1. Input
   Raw source text such as Aozora Bunko notation, Markdown, or HTML.
2. AST
   A format-aware but renderer-independent document tree.
3. Layout IR
   A composition-oriented intermediate representation for line breaking, ruby placement, tate-chu-yoko, tables, and pagination.
4. Renderer
   Flutter widgets and paint logic that draw the layout IR.

## Dependency Direction

The dependency direction is one way.

`Input -> AST -> Layout IR -> Renderer`

Each downstream layer can depend on upstream output, but no layer may interpret upstream raw syntax again.

## Layer Responsibilities

### Input

- Owns source decoding, newline normalization, and parser entry points.
- Does not know typography, glyph positions, or Flutter widgets.

### AST

- Preserves document meaning rather than HTML output details.
- Represents paragraphs, inline annotations, ruby, gaiji, generic containers, and future structures such as tables.
- Keeps unsupported directives as typed opaque nodes with raw text and source spans.
- May carry source-format metadata, but not renderer instructions such as coordinates or pixels.

### Layout IR

- Converts AST semantics into composition primitives.
- Resolves writing direction, ruby placement strategy, inline annotations, spacing, table geometry, and pagination hints.
- Must not parse Aozora directives directly.

### Renderer

- Draws only Layout IR.
- Must not inspect Aozora raw strings like `［＃...］`.
- Owns Flutter-specific concerns such as text measurement, painting, hit testing, and scrolling.

## AST Design Rules

- The AST is not Aozora-only.
- Generic blocks and inline containers are first-class so future Markdown or HTML parsers can map into the same tree.
- Source spans are attached to every node to support diagnostics, tooling, and lossless fallback.
- Unknown or currently unsupported directives are preserved as opaque directive nodes instead of being dropped.
- Tables are part of the core AST model even before the Aozora parser emits them, so downstream layers are not forced into a paragraph-only assumption.

## Parser Rules

- The parser should eagerly recognize stable semantics such as ruby, gaiji, inline decoration, tate-chu-yoko, and multiline containers.
- When semantics are unclear, the parser should preserve the original directive and emit a diagnostic instead of guessing.
- The parser may normalize surface syntax, but it must not erase authoring intent or source location.
