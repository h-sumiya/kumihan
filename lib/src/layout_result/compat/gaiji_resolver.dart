import 'generated/gaiji_table.dart';

class ResolvedGaiji {
  const ResolvedGaiji({
    required this.text,
    required this.resolved,
    this.jisCode,
    this.unicodeCodePoint,
  });

  final String text;
  final bool resolved;
  final String? jisCode;
  final String? unicodeCodePoint;
}

class GaijiResolver {
  const GaijiResolver();

  static const String fallback = '〓';

  ResolvedGaiji resolve({
    required String description,
    String? jisCode,
    String? unicodeCodePoint,
  }) {
    if (jisCode != null) {
      final text = kumihanGaijiTable[jisCode];
      if (text != null) {
        return ResolvedGaiji(
          text: text,
          resolved: true,
          jisCode: jisCode,
          unicodeCodePoint: unicodeCodePoint,
        );
      }
    }

    if (unicodeCodePoint != null) {
      final codePoint = int.tryParse(unicodeCodePoint, radix: 16);
      if (codePoint != null) {
        return ResolvedGaiji(
          text: String.fromCharCode(codePoint),
          resolved: true,
          jisCode: jisCode,
          unicodeCodePoint: unicodeCodePoint,
        );
      }
    }

    final dakuten = RegExp(r'^濁点付き(平|片)仮名(.).*$').firstMatch(description);
    if (dakuten != null) {
      return ResolvedGaiji(
        text: '${dakuten.group(2)}゛',
        resolved: true,
        jisCode: jisCode,
        unicodeCodePoint: unicodeCodePoint,
      );
    }

    final handakuten = RegExp(r'^半濁点付き(平|片)仮名(.).*$').firstMatch(description);
    if (handakuten != null) {
      return ResolvedGaiji(
        text: '${handakuten.group(2)}゜',
        resolved: true,
        jisCode: jisCode,
        unicodeCodePoint: unicodeCodePoint,
      );
    }

    return ResolvedGaiji(
      text: fallback,
      resolved: false,
      jisCode: jisCode,
      unicodeCodePoint: unicodeCodePoint,
    );
  }
}
