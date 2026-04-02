import 'dart:math' as math;

const String warichuNewLineMarker = '［＃改行］';

class WarichuLayoutText {
  const WarichuLayoutText({required this.upper, required this.lower});

  final String upper;
  final String lower;

  int get placeholderLength => math.max(upper.length, lower.length);
}

WarichuLayoutText splitWarichuText(String body) {
  final markerIndex = body.indexOf(warichuNewLineMarker);
  if (markerIndex >= 0) {
    return WarichuLayoutText(
      upper: body.substring(0, markerIndex),
      lower: body
          .substring(markerIndex + warichuNewLineMarker.length)
          .replaceAll(warichuNewLineMarker, ''),
    );
  }

  final split = (body.length + 1) ~/ 2;
  return WarichuLayoutText(
    upper: body.substring(0, split),
    lower: body.substring(split),
  );
}
