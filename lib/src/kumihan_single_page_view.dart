import 'package:flutter/widgets.dart';

import 'document.dart';
import 'engine/kumihan_engine.dart';
import 'kumihan_paged_canvas.dart';
import 'kumihan_theme.dart';
import 'kumihan_types.dart';

class KumihanSinglePageCanvas extends StatelessWidget {
  const KumihanSinglePageCanvas({
    super.key,
    required this.document,
    this.baseUri,
    this.imageLoader,
    this.layout = const KumihanLayoutData(),
    this.theme = const KumihanThemeData(),
    this.selectable = true,
    this.onSnapshotChanged,
  });

  final Document document;
  final Uri? baseUri;
  final KumihanImageLoader? imageLoader;
  final KumihanLayoutData layout;
  final KumihanThemeData theme;
  final bool selectable;
  final ValueChanged<KumihanPagedSnapshot>? onSnapshotChanged;

  @override
  Widget build(BuildContext context) {
    return KumihanPagedCanvas(
      document: document,
      baseUri: baseUri,
      imageLoader: imageLoader,
      maxPages: 1,
      layout: layout,
      theme: theme,
      selectable: selectable,
      onSnapshotChanged: onSnapshotChanged,
    );
  }
}
