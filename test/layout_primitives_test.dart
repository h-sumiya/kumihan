import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/src/engine/constants.dart';
import 'package:kumihan/src/engine/kumihan_engine.dart';
import 'package:kumihan/src/engine/layout_primitives.dart';

void main() {
  test(
    'rotated prolonged sound mark matches mirrored vertical rendering',
    () async {
      final engine = KumihanEngine(
        baseUri: null,
        initialPage: 0,
        onInvalidate: () {},
        onSnapshot: (_) {},
      );
      final block = LayoutTextBlock(engine)
        ..setText(rotatedProlongedSoundMark, 64, 0, false, false, 'v');
      final atom = block.atom.single..setRotated();
      final line = LayoutTextLine(block, 0, 1, atom.getFontSize(), 0);

      final actual = await _renderBytes((canvas) => line.draw(canvas, 48, 24));
      final mirrored = await _renderBytes(
        (canvas) => _drawRotatedGlyph(
          canvas,
          engine: engine,
          line: line,
          atom: atom,
          mirrorHorizontally: true,
        ),
      );
      final legacy = await _renderBytes(
        (canvas) => _drawRotatedGlyph(
          canvas,
          engine: engine,
          line: line,
          atom: atom,
          mirrorHorizontally: false,
        ),
      );

      expect(actual, equals(mirrored));
      expect(actual, isNot(equals(legacy)));
    },
  );
}

Future<Uint8List> _renderBytes(void Function(ui.Canvas canvas) draw) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  draw(canvas);
  final picture = recorder.endRecording();
  final image = await picture.toImage(160, 160);
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  image.dispose();
  return bytes;
}

void _drawRotatedGlyph(
  ui.Canvas canvas, {
  required KumihanEngine engine,
  required LayoutTextLine line,
  required LayoutAtom atom,
  required bool mirrorHorizontally,
}) {
  final measured = engine.layoutText(
    atom,
    rotatedProlongedSoundMark,
    engine.fontColor,
  );
  final painter = measured.painter;
  final x = 48 + line.width / 2 + atom.offsetX;
  final y = 24 + line.y + atom.offsetY + atom.tracking;

  canvas.save();
  canvas.translate(x, y);
  canvas.rotate(math.pi / 2);
  if (mirrorHorizontally) {
    canvas.scale(1, -1);
  }
  painter.paint(canvas, ui.Offset(0, -painter.height / 2));
  canvas.restore();
}
