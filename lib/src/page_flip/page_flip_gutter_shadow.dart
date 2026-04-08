import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import 'page_flip_types.dart';

void paintBookGutterShadow(
  Canvas canvas, {
  required Size size,
  required double pageWidth,
  required PageDensity density,
}) {
  if (density == PageDensity.hard) {
    return;
  }

  final shadowSize = pageWidth / 10;
  final shadowRect = Rect.fromLTWH(
    pageWidth - shadowSize / 2,
    0,
    shadowSize,
    size.height * 2,
  );
  const colors = <Color>[
    Color.fromRGBO(0, 0, 0, 0),
    Color.fromRGBO(0, 0, 0, 0.2),
    Color.fromRGBO(0, 0, 0, 0.1),
    Color.fromRGBO(0, 0, 0, 0.5),
    Color.fromRGBO(0, 0, 0, 0.4),
    Color.fromRGBO(0, 0, 0, 0),
  ];
  const stops = <double>[0, 0.4, 0.49, 0.5, 0.51, 1];
  final shader = ui.Gradient.linear(
    shadowRect.topLeft,
    shadowRect.topRight,
    colors,
    stops,
  );

  final paint = Paint()..shader = shader;
  canvas.save();
  canvas.clipRect(Offset.zero & size);
  canvas.drawRect(shadowRect, paint);
  canvas.restore();
}
