import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kumihan/kumihan.dart';

import 'example_models.dart';

const List<ExamplePaperTextureOption> examplePaperTextureOptions =
    <ExamplePaperTextureOption>[
      ExamplePaperTextureOption(id: 'none', label: 'なし'),
      ExamplePaperTextureOption(
        id: '01',
        label: 'Paper 01',
        image: AssetImage('assets/paper_textures/01.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '02',
        label: 'Paper 02',
        image: AssetImage('assets/paper_textures/02.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '03',
        label: 'Paper 03',
        image: AssetImage('assets/paper_textures/03.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '04',
        label: 'Paper 04',
        image: AssetImage('assets/paper_textures/04.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '05',
        label: 'Paper 05',
        image: AssetImage('assets/paper_textures/05.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '06',
        label: 'Paper 06',
        image: AssetImage('assets/paper_textures/06.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '07',
        label: 'Paper 07',
        image: AssetImage('assets/paper_textures/07.jpg'),
      ),
      ExamplePaperTextureOption(
        id: '08',
        label: 'Paper 08',
        image: AssetImage('assets/paper_textures/08.jpg'),
      ),
    ];

const List<ExampleThemePreset> builtinThemePresets = <ExampleThemePreset>[
  ExampleThemePreset(
    id: 'washi',
    label: '和紙',
    builtIn: true,
    theme: KumihanThemeData(
      paperColor: Color(0xfffff7ea),
      textColor: Color(0xff3f3227),
      captionColor: Color(0xff6d8661),
      rubyColor: Color(0xff4a392c),
      linkColor: Color(0xff3b5bd6),
      internalLinkColor: Color(0xff1f8a56),
    ),
  ),
  ExampleThemePreset(
    id: 'sumi',
    label: '墨白',
    builtIn: true,
    theme: KumihanThemeData(
      paperColor: Color(0xfffafaf7),
      textColor: Color(0xff222222),
      captionColor: Color(0xff4a6a55),
      rubyColor: Color(0xff2f2f2f),
      linkColor: Color(0xff2458d3),
      internalLinkColor: Color(0xff0d8c6c),
    ),
  ),
  ExampleThemePreset(
    id: 'midnight',
    label: '夜更け',
    builtIn: true,
    theme: KumihanThemeData(
      paperColor: Color(0xff181411),
      textColor: Color(0xffece0cb),
      captionColor: Color(0xff9fbda7),
      rubyColor: Color(0xffd9c8ae),
      linkColor: Color(0xff8bbdff),
      internalLinkColor: Color(0xff7fd7a0),
    ),
  ),
  ExampleThemePreset(
    id: 'indigo',
    label: '藍紙',
    builtIn: true,
    theme: KumihanThemeData(
      paperColor: Color(0xffedf3f6),
      textColor: Color(0xff233341),
      captionColor: Color(0xff55796b),
      rubyColor: Color(0xff365064),
      linkColor: Color(0xff2e63df),
      internalLinkColor: Color(0xff1a8b72),
    ),
  ),
];

Future<List<ExampleSample>> loadExampleSamples() async {
  final aozoraText = await rootBundle.loadString('assets/sample_aozora.txt');
  final hashireMerosuText = await rootBundle.loadString(
    'assets/hashire_merosu.txt',
  );
  final markdownText = await rootBundle.loadString('assets/sample_markdown.md');

  return <ExampleSample>[
    ExampleSample(
      id: 'aozora',
      label: '青空形式',
      document: const KumihanAozoraParser(
        title: 'Kumihan Sample',
        author: '青空文庫 表示サンプル',
      ).parse(aozoraText),
    ),
    ExampleSample(
      id: 'hashire_merosu',
      label: '走れメロス',
      document: const KumihanAozoraParser(
        title: '走れメロス',
        author: '太宰治',
      ).parse(hashireMerosuText),
    ),
    ExampleSample(
      id: 'markdown',
      label: 'Markdown',
      document: const KumihanMarkdownParser(
        title: 'Kumihan Markdown Sample',
        author: 'Markdown 表示サンプル',
      ).parse(markdownText),
    ),
  ];
}

Future<ui.Image?> loadExampleImage(String path) async {
  final assetPath = _normalizeExampleAssetPath(path);
  if (assetPath == null) {
    return null;
  }

  try {
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      final frame = await codec.getNextFrame();
      return frame.image;
    } finally {
      codec.dispose();
    }
  } catch (_) {
    return null;
  }
}

ExamplePaperTextureOption textureOptionFor(String id) {
  return examplePaperTextureOptions.firstWhere((option) => option.id == id);
}

String textureIdFor(ImageProvider<Object>? provider) {
  for (final option in examplePaperTextureOptions) {
    if (option.image == provider) {
      return option.id;
    }
  }
  return 'none';
}

String? _normalizeExampleAssetPath(String path) {
  if (path.startsWith('http://') ||
      path.startsWith('https://') ||
      path.startsWith('data:') ||
      path.startsWith('blob:')) {
    return null;
  }

  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  if (trimmed.startsWith('assets/')) {
    return trimmed;
  }
  return 'assets/${trimmed.startsWith('./') ? trimmed.substring(2) : trimmed}';
}
