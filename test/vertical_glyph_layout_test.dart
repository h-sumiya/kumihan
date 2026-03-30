import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan_v1/kumihan.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('vertical glyph layout', () {
    test('rotates box drawing dash like v0', () {
      const theme = KumihanRenderThemeData(fontSize: 18);
      const style = TextStyle(fontSize: 18);
      final rect = Rect.fromLTWH(0, 0, 18, 18);

      final layout = computeVerticalGlyphLayout(rect, '─', style, theme);

      expect(layout.text, '─');
      expect(layout.isRotated, isTrue);
      expect(layout.rotation, closeTo(math.pi / 2, 1e-6));
    });

    test('treats box drawing dash as rotated glyph', () {
      expect(shouldRotateVerticalGlyph('─'), isTrue);
      expect(shouldRotateVerticalGlyph('―'), isFalse);
    });
  });
}
