import 'package:flutter/painting.dart';
import 'package:kumihan/kumihan.dart';

AstData buildDslSampleDocument() {
  return ast([
    const Heading(
      level: AstHeadingLevel.large,
      children: <Object>[
        Text(value: 'DSL見本', ruby: <Object>['でぃーえすえるみほん']),
      ],
    ),
    const Br(),
    const Text(value: 'これは '),
    const Text(value: '組版', ruby: <Object>['くみはん']),
    const Text(value: ' の DSL サンプルです。'),
    const Br(),
    const Text(value: '虹色の文字列: '),
    const Text(value: '虹', color: Color(0xffe53935), bold: true),
    const Text(value: '色', color: Color(0xfffb8c00), bold: true),
    const Text(value: 'サ', color: Color(0xfffdd835), bold: true),
    const Text(value: 'ン', color: Color(0xff43a047), bold: true),
    const Text(value: 'プ', color: Color(0xff1e88e5), bold: true),
    const Text(value: 'ル', color: Color(0xff8e24aa), bold: true),
    const Text(value: '。'),
    const Br(),
    const Text(value: '太字', bold: true),
    const Text(value: '、'),
    const Text(value: '斜体', italic: true),
    const Text(value: '、'),
    const Text(value: '傍点', bouten: AstBoutenKind.sesame),
    const Text(value: '、'),
    const Text(value: '波線', border: AstBosenKind.wave),
    const Text(value: '、'),
    const Text(value: '2026', tatechuyoko: true),
    const Text(value: ' も同じ DSL で表せます。'),
    const Br(),
    Indent.block(
      lineIndent: 2,
      children: <Object>[
        Keigakomi(
          children: <Object>[
            Text(value: 'ここはインデント付きの囲み段落です。'),
            Br(),
            Text(value: '割り注', ruby: <Object>['わりちゅう']),
            Text(value: ' も '),
            Warichu(
              children: <Object>[
                Text(value: '上段に注記'),
                WarichuBreak(),
                Text(value: '下段に補足'),
              ],
            ),
            Text(value: ' の形で入れられます。'),
          ],
        ),
      ],
    ),
    const Br(),
    const Text(value: 'サンプルは example 内でべた書きしています。'),
  ]);
}
