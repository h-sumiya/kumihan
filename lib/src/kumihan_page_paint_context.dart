import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'kumihan_types.dart';

@immutable
class PagePaintContext {
  const PagePaintContext({
    required this.contentRect,
    this.backPage = false,
    this.recordInteractiveRegions = true,
    this.inlineAlignment,
  });

  final Rect contentRect;
  final bool backPage;
  final bool recordInteractiveRegions;
  final KumihanFullPageAlignment? inlineAlignment;
}
