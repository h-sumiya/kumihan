import 'package:flutter/material.dart';
import 'package:kumihan/kumihan.dart';

class ExampleSample {
  const ExampleSample({
    required this.id,
    required this.label,
    required this.document,
  });

  final String id;
  final String label;
  final KumihanDocument document;
}

class ExamplePaperTextureOption {
  const ExamplePaperTextureOption({
    required this.id,
    required this.label,
    this.image,
  });

  final String id;
  final String label;
  final ImageProvider<Object>? image;
}

class ExampleThemePreset {
  const ExampleThemePreset({
    required this.id,
    required this.label,
    required this.theme,
    this.builtIn = false,
  });

  final String id;
  final String label;
  final KumihanThemeData theme;
  final bool builtIn;

  ExampleThemePreset copyWith({
    String? id,
    String? label,
    KumihanThemeData? theme,
    bool? builtIn,
  }) {
    return ExampleThemePreset(
      id: id ?? this.id,
      label: label ?? this.label,
      theme: theme ?? this.theme,
      builtIn: builtIn ?? this.builtIn,
    );
  }
}
