## 1.0.0

- Replace the original `KumihanCanvas`-centered API with a `Document`/AST model and dedicated reader widgets.
- Add `KumihanBook`, `KumihanPagedView`, `KumihanSinglePageView`, and `KumihanScrollView` with controller/snapshot APIs.
- Add a Flutter DSL for authoring documents, richer styling, header titles, warichu support, and improved layout primitives.
- Add page-flip book rendering and book-specific theming/defaults for cover-based reading experiences.
- Expand parser coverage for Aozora Bunko, HTML, and Markdown, including inline formatting and code block language metadata.
- Add regression tests for AST building, parsing, layout primitives, paged/scroll rendering, and book/page-flip behavior.

Breaking changes:

- Remove `KumihanCanvas`, `KumihanDocument`, `KumihanTap`, and the previous single-widget rendering entry points.
- Callers now build a `Document` explicitly or parse content into one before passing it to a reader widget.

## 0.0.3

- Add render trace support and back page opacity controls.

## 0.0.2

- Add EventSystem.
