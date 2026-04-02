<p align="center">
  <img src="https://raw.githubusercontent.com/h-sumiya/kumihan/main/screenshot/merosu_light_washi.png" width="480" />
</p>

<h1 align="center">組版 — kumihan</h1>

<p align="center">
  Flutter で日本語縦書きを、美しく。
</p>

<p align="center">

[![pub package](https://img.shields.io/pub/v/kumihan.svg)](https://pub.dev/packages/kumihan)
[![likes](https://img.shields.io/pub/likes/kumihan)](https://pub.dev/packages/kumihan/score)
[![pub points](https://img.shields.io/pub/points/kumihan)](https://pub.dev/packages/kumihan/score)

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-stable-02569B.svg?logo=flutter)](https://flutter.dev)

</p>

---

日本語組版ウィジェット。縦書き・横書き・見開き表示に対応。
青空文庫形式・Markdown・HTML をパースしてそのまま描画できる。

## v1 Development Note

`v1` ブランチは `main` から切り直し、`lib/src/engine` を基点に段階的に責務を切り出していく方針に変更した。
大きな置き換えは避け、動作を保ったまま小さく分離していく。開発メモは `docs/development_strategy.md` を参照。

## スクリーンショット

|                                                    |                                                  |
| :------------------------------------------------: | :----------------------------------------------: |
|       ![青空文庫 1](screenshot/aozora1.png)        |      ![青空文庫 2](screenshot/aozora2.png)       |
|       ![青空文庫 3](screenshot/aozora3.png)        |      ![青空文庫 4](screenshot/aozora4.png)       |
| ![Markdown 横書き](screenshot/markdown_normal.png) | ![Markdown 縦書き](screenshot/markdown_tate.png) |
|    ![ダークテーマ](screenshot/merosu_dark.png)     | ![和紙テーマ](screenshot/merosu_light_washi.png) |

## 使い方

```dart
import 'package:kumihan/kumihan.dart';

final controller = KumihanController();
final document = AozoraParser().parse(aozoraText);

KumihanCanvas(
  controller: controller,
  document: document,
  layout: KumihanLayoutData(fontSize: 18),
  theme: KumihanThemeData.light(),
)
```

DSL 経由で一部分だけ色を変えることもできる。

```dart
final document = Document([
  '通常の本文と',
  TextColor(
    color: const Color(0xffd32f2f),
    children: ['赤文字'],
  ),
  'です。',
]);
```

## インストール

```yaml
dependencies:
  kumihan: ^0.0.1
```

## 対応フォーマット

- **青空文庫形式** — ルビ・傍点・注記
- **Markdown** — 見出し・リスト・強調
- **HTML** — 基本タグ

## ライセンス

MIT
