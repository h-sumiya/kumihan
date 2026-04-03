import 'package:flutter/widgets.dart';

import 'engine/kumihan_engine.dart';
import 'kumihan_paged_canvas.dart';
import 'kumihan_paged_controller.dart';
import 'kumihan_types.dart';
import 'parsers/aozora_parser.dart';
import 'parsers/html_parser.dart';
import 'parsers/markdown_parser.dart';

class KumihanCanvas extends KumihanPagedCanvas {
  const KumihanCanvas({
    super.key,
    required super.document,
    super.controller,
    super.imageLoader,
    super.initialPage,
    super.layout,
    super.onSnapshotChanged,
  });

  factory KumihanCanvas.aozora({
    Key? key,
    required String text,
    KumihanPagedController? controller,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanPagedSnapshot>? onSnapshotChanged,
  }) {
    return KumihanCanvas(
      key: key,
      document: const AozoraParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      initialPage: initialPage,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  factory KumihanCanvas.markdown({
    Key? key,
    required String text,
    KumihanPagedController? controller,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanPagedSnapshot>? onSnapshotChanged,
  }) {
    return KumihanCanvas(
      key: key,
      document: const MarkdownParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      initialPage: initialPage,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }

  factory KumihanCanvas.html({
    Key? key,
    required String text,
    KumihanPagedController? controller,
    KumihanImageLoader? imageLoader,
    int initialPage = 0,
    KumihanLayoutData layout = const KumihanLayoutData(),
    ValueChanged<KumihanPagedSnapshot>? onSnapshotChanged,
  }) {
    return KumihanCanvas(
      key: key,
      document: const HtmlParser().parse(text),
      controller: controller,
      imageLoader: imageLoader,
      initialPage: initialPage,
      layout: layout,
      onSnapshotChanged: onSnapshotChanged,
    );
  }
}
