import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  test('KumihanThemeData preserves backPageOpacity through copyWith', () {
    const theme = KumihanThemeData(backPageOpacity: 0.0);

    final updated = theme.copyWith(paperTextureOpacity: 0.25);

    expect(updated.backPageOpacity, 0.0);
    expect(updated.paperTextureOpacity, 0.25);
  });

  test('KumihanThemeData equality includes backPageOpacity', () {
    const left = KumihanThemeData(backPageOpacity: 0.0);
    const right = KumihanThemeData(backPageOpacity: 0.08);

    expect(left, isNot(right));
  });
}
