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

  test('KumihanThemeData equality includes paperColor and backPageOpacity', () {
    const left = KumihanThemeData(
      paperColor: Color(0xfffff0dd),
      backPageOpacity: 0.04,
    );
    const right = KumihanThemeData(
      paperColor: Color(0xfff5f5f5),
      backPageOpacity: 0.12,
    );

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

  test('KumihanBookLayoutData keeps outer/content padding and gap', () {
    const layout = KumihanBookLayoutData(
      outerPadding: EdgeInsets.fromLTRB(8, 10, 12, 14),
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      pageGap: 18,
    );

    final updated = layout.copyWith(showTitle: false);

    expect(updated.outerPadding, const EdgeInsets.fromLTRB(8, 10, 12, 14));
    expect(updated.contentPadding, const EdgeInsets.symmetric(horizontal: 16));
    expect(updated.pageGap, 18);
    expect(updated.showTitle, isFalse);
  });

  test('AozoraParser resolves headerTitle from title and author', () {
    final document = const AozoraParser(
      title: '題名',
      author: '著者',
    ).parse('本文です。');

    expect(document.headerTitle, '題名 / 著者');
  });
}
