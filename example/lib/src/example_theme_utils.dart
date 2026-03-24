import 'package:flutter/material.dart';
import 'package:kumihan/kumihan.dart';

ThemeData buildExampleShellTheme(KumihanThemeData readerTheme) {
  final brightness = readerTheme.isDark ? Brightness.dark : Brightness.light;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: readerTheme.linkColor,
    brightness: brightness,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme.copyWith(
      surface: blendExampleColor(
        readerTheme.paperColor,
        brightness == Brightness.dark
            ? const Color(0xff131514)
            : const Color(0xfffcf8f0),
        brightness == Brightness.dark ? 0.26 : 0.72,
      ),
    ),
    scaffoldBackgroundColor: blendExampleColor(
      readerTheme.paperColor,
      brightness == Brightness.dark
          ? const Color(0xff0c0d0d)
          : const Color(0xfff3ede2),
      brightness == Brightness.dark ? 0.18 : 0.88,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: blendExampleColor(
        readerTheme.paperColor,
        brightness == Brightness.dark
            ? const Color(0xff171918)
            : const Color(0xffffffff),
        brightness == Brightness.dark ? 0.22 : 0.78,
      ),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
      ),
    ),
  );
}

Color blendExampleColor(Color foreground, Color background, double opacity) {
  return Color.alphaBlend(
    foreground.withValues(alpha: opacity.clamp(0.0, 1.0)),
    background,
  );
}

Color? tryParseHexColor(String value) {
  final normalized = value.trim().replaceAll('#', '');
  if (!RegExp(r'^(?:[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$').hasMatch(normalized)) {
    return null;
  }

  final hex = normalized.length == 6 ? 'FF$normalized' : normalized;
  return Color(int.parse(hex, radix: 16));
}

String formatHexColor(Color color) {
  final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase();
  return hex.startsWith('FF') ? '#${hex.substring(2)}' : '#$hex';
}
