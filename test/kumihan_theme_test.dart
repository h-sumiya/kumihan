import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kumihan/kumihan.dart';

void main() {
  test('KumihanThemeData keeps rubyColor through copyWith', () {
    const theme = KumihanThemeData(rubyColor: Color(0xff102030));

    final updated = theme.copyWith(linkColor: const Color(0xffabcdef));

    expect(updated.rubyColor, const Color(0xff102030));
    expect(updated.linkColor, const Color(0xffabcdef));
  });

  test('KumihanThemeData equality includes internalLinkColor', () {
    const left = KumihanThemeData(internalLinkColor: Color(0xff123456));
    const right = KumihanThemeData(internalLinkColor: Color(0xff654321));

    expect(left, isNot(right));
  });

  test('KumihanLayoutData equality includes pagePadding', () {
    const left = KumihanLayoutData(
      pagePadding: EdgeInsets.symmetric(horizontal: 16),
    );
    const right = KumihanLayoutData(
      pagePadding: EdgeInsets.symmetric(horizontal: 24),
    );

    expect(left, isNot(right));
  });
}
