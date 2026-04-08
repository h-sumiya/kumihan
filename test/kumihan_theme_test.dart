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

  test('KumihanThemeData copyWith keeps disableGutterShadow', () {
    const theme = KumihanThemeData(disableGutterShadow: true);

    final updated = theme.copyWith(backPageOpacity: 0.12);

    expect(updated.disableGutterShadow, isTrue);
    expect(updated.backPageOpacity, 0.12);
  });

  test('KumihanBookThemeData applies only book overrides to base theme', () {
    const baseTheme = KumihanThemeData(
      paperColor: Color(0xfffff0dd),
      backPageOpacity: 0.04,
    );
    const bookTheme = KumihanBookThemeData(
      backPageOpacity: 0.18,
      borderColor: Color(0xff998877),
    );

    final applied = bookTheme.applyTo(baseTheme);

    expect(applied.paperColor, const Color(0xfffff0dd));
    expect(applied.backPageOpacity, 0.18);
    expect(bookTheme.borderColor, const Color(0xff998877));
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

  test('KumihanLayoutData equality includes fullPageAlignment', () {
    const left = KumihanLayoutData(
      fullPageAlignment: KumihanFullPageAlignment.left,
    );
    const right = KumihanLayoutData(
      fullPageAlignment: KumihanFullPageAlignment.center,
    );

    expect(left, isNot(right));
  });

  test('KumihanBookLayoutData keeps top/body/bottom padding', () {
    const layout = KumihanBookLayoutData(
      topUiPadding: EdgeInsets.fromLTRB(8, 10, 12, 14),
      bodyPadding: KumihanBookBodyPadding(
        top: 4,
        inner: 16,
        outer: 18,
        bottom: 20,
      ),
      bottomUiPadding: EdgeInsets.fromLTRB(2, 6, 10, 12),
    );

    final updated = layout.copyWith(showTitle: false);

    expect(updated.topUiPadding, const EdgeInsets.fromLTRB(8, 10, 12, 14));
    expect(
      updated.bodyPadding,
      const KumihanBookBodyPadding(top: 4, inner: 16, outer: 18, bottom: 20),
    );
    expect(updated.bottomUiPadding, const EdgeInsets.fromLTRB(2, 6, 10, 12));
    expect(updated.showTitle, isFalse);
  });

  test(
    'KumihanBookLayoutData copyWith keeps left and right full-page alignment',
    () {
      const layout = KumihanBookLayoutData(
        rightPageFullPageAlignment: KumihanFullPageAlignment.center,
        leftPageFullPageAlignment: KumihanFullPageAlignment.left,
      );

      final updated = layout.copyWith(showPageNumber: false);

      expect(
        updated.rightPageFullPageAlignment,
        KumihanFullPageAlignment.center,
      );
      expect(updated.leftPageFullPageAlignment, KumihanFullPageAlignment.left);
      expect(updated.showPageNumber, isFalse);
    },
  );

  test('AozoraParser resolves headerTitle from title and author', () {
    final document = const AozoraParser(
      title: '題名',
      author: '著者',
    ).parse('本文です。');

    expect(document.headerTitle, '題名 / 著者');
  });
}
