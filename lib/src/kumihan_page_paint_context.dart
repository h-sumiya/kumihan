import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

@immutable
class PagePaintContext {
  const PagePaintContext({
    required this.contentRect,
    this.backPage = false,
    this.recordInteractiveRegions = true,
  });

  final Rect contentRect;
  final bool backPage;
  final bool recordInteractiveRegions;
}
