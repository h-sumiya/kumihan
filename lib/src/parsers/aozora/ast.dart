typedef AozoraData = List<AozoraToken>;

typedef AozoraInlineContent = List<AozoraInlineNode>;

abstract interface class AozoraInlineNode {}

sealed class AozoraToken {
  const AozoraToken();
}

enum AozoraRangeBoundary { start, end, blockStart, blockEnd }

enum AozoraTextSide { right, left }

class AozoraText extends AozoraToken implements AozoraInlineNode {
  final String text;

  const AozoraText(this.text);
}

class AozoraNewLine extends AozoraToken implements AozoraInlineNode {
  const AozoraNewLine();
}

class AozoraWarichuNewLine extends AozoraToken implements AozoraInlineNode {
  /*
  `［＃割り注］東は字大林四三七［＃改行］西は字神内一一一ノ一［＃割り注終わり］`
  の `［＃改行］` を表す。
  */
  const AozoraWarichuNewLine();
}

class AozoraAccentDecomposition extends AozoraToken
    implements AozoraInlineNode {
  /*
  `〔e'tiquette〕`
  `〔Sito^t qu'on le touche il re'sonne.〕`
  `jusqu'〔a`〕`
  の `〔...〕` 全体を、通常テキストとは区別して保持する。
  */
  final String text;

  const AozoraAccentDecomposition(this.text);
}

enum AozoraPageRegion { upper, middle, lower, one, two, three, four }

class AozoraPrintPosition {
  final int page;
  final int line;
  final AozoraPageRegion? region;

  const AozoraPrintPosition({
    required this.page,
    required this.line,
    this.region,
  });
}

class AozoraJisCode {
  final int plane;
  final int row;
  final int cell;

  const AozoraJisCode({
    required this.plane,
    required this.row,
    required this.cell,
  });
}

enum AozoraGaijiKind { jisX0213, unicode, missingUnicode }

class AozoraGaiji extends AozoraToken implements AozoraInlineNode {
  /*
  `※［＃「てへん＋劣」、第3水準1-84-77］`
  `※［＃「口＋世」、U+546D、135-7］`
  `※［＃「土へん＋竒」、135-7］`
  `※［＃二の字点、1-2-22］`
  `※［＃始め二重山括弧、1-1-52］`
  などを表す。
  */
  final String description;
  final AozoraGaijiKind kind;
  final AozoraJisCode? jisCode;
  final int? jisLevel;
  final int? unicodeCodePoint;
  final AozoraPrintPosition? printPosition;

  const AozoraGaiji({
    required this.description,
    required this.kind,
    this.jisCode,
    this.jisLevel,
    this.unicodeCodePoint,
    this.printPosition,
  });
}

class AozoraTateTen extends AozoraToken implements AozoraInlineNode {
  /*
  `而敬‐［＃二］祭天神地祇［＃一］。`
  の全角ハイフン `‐` を、通常テキストと区別して持ちたい場合に使う。
  */
  const AozoraTateTen();
}

enum AozoraKaeritenPrimary {
  ichi,
  ni,
  san,
  yon,
  jou,
  chuu,
  ge,
  kou,
  otsu,
  hei,
  ten,
  chi,
  jin,
}

class AozoraKaeriten extends AozoraToken implements AozoraInlineNode {
  /*
  `［＃二］`
  `［＃レ］`
  `［＃一レ］`
  `［＃上レ］`
  を表す。
  */
  final AozoraKaeritenPrimary? primary;
  final bool hasRe;

  const AozoraKaeriten({this.primary, this.hasRe = false});
}

class AozoraKuntenOkurigana extends AozoraToken implements AozoraInlineNode {
  /*
  `［＃（ノ）］`
  `［＃（弖）］`
  の `（...）` 内を表す。
  */
  final AozoraInlineContent content;

  const AozoraKuntenOkurigana(this.content);
}

sealed class AozoraAnnotation extends AozoraToken implements AozoraInlineNode {
  const AozoraAnnotation();
}

enum AozoraAttachedTextRole { ruby, note }

class AozoraAttachedText extends AozoraAnnotation {
  /*
  右ルビ
  - `青空文庫《あおぞらぶんこ》`
  - `［＃注記付き］名※［＃二の字点、1-2-22］［＃「（銘々）」の注記付き終わり］`
  - `［＃「喋」に「ママ」の注記］`
  - `［＃「紋附だとか」は底本では「絞附だとか」］`
  - `［＃ルビの「ざる」は底本では「さる」］`
  - `［＃「広場へに」はママ］`
  - `［＃ルビの「ゆう」はママ］`

  左ルビ・左注記
  - `［＃「青空文庫」の左に「あおぞらぶんこ」のルビ］`
  - `［＃左にルビ付き］...［＃左に「れんじまど」のルビ付き終わり］`
  - `［＃「皆身」の左に「南」の注記］`
  - `［＃左に注記付き］...［＃左に「（銘々）」の注記付き終わり］`

  正規化後は、対象範囲の前後に
  `AozoraAttachedText(start, ...)`
  `AozoraAttachedText(end, ...)`
  を置く。
  */
  final AozoraRangeBoundary boundary;
  final AozoraAttachedTextRole role;
  final AozoraTextSide side;
  final AozoraInlineContent? content;

  const AozoraAttachedText({
    required this.boundary,
    required this.role,
    required this.side,
    this.content,
  });
}

enum AozoraBoutenKind {
  sesame,
  whiteSesame,
  blackCircle,
  whiteCircle,
  blackTriangle,
  whiteTriangle,
  bullseye,
  fisheye,
  saltire,
}

enum AozoraBosenKind { solid, doubleLine, chain, dashed, wave }

enum AozoraFontStyle { bold, italic }

enum AozoraFontScaleDirection { larger, smaller }

sealed class AozoraTextStyle {
  const AozoraTextStyle();
}

class AozoraBoutenStyle extends AozoraTextStyle {
  final AozoraBoutenKind kind;
  final AozoraTextSide side;

  const AozoraBoutenStyle({
    required this.kind,
    this.side = AozoraTextSide.right,
  });
}

class AozoraBosenStyle extends AozoraTextStyle {
  final AozoraBosenKind kind;
  final AozoraTextSide side;

  const AozoraBosenStyle({
    required this.kind,
    this.side = AozoraTextSide.right,
  });
}

class AozoraFontStyleAnnotation extends AozoraTextStyle {
  final AozoraFontStyle style;

  const AozoraFontStyleAnnotation(this.style);
}

class AozoraFontScaleStyle extends AozoraTextStyle {
  final AozoraFontScaleDirection direction;
  final int steps;

  const AozoraFontScaleStyle({required this.direction, required this.steps});
}

class AozoraStyledText extends AozoraAnnotation {
  /*
  傍点
  - `責［＃「責」に白丸傍点］空文庫`
  - `［＃左に蛇の目傍点］青空文庫［＃左に蛇の目傍点終わり］`

  傍線
  - `責［＃「責」に波線］空文庫`
  - `［＃左に二重傍線］青空文庫［＃左に二重傍線終わり］`

  太字・斜体
  - `待つ［＃「待つ」は太字］`
  - `［＃太字］...［＃太字終わり］`
  - `［＃ここから太字］...［＃ここで太字終わり］`
  - `Nothing ... born.［＃「Nothing ... born.」は斜体］`
  - `［＃斜体］...［＃斜体終わり］`
  - `［＃ここから斜体］...［＃ここで斜体終わり］`

  文字サイズ
  - `県立高女の怪事［＃「県立高女の怪事」は２段階大きな文字］`
  - `［＃１段階小さな文字］...［＃小さな文字終わり］`
  - `［＃ここから２段階大きな文字］...［＃ここで大きな文字終わり］`
  */
  final AozoraRangeBoundary boundary;
  final AozoraTextStyle style;

  const AozoraStyledText({required this.boundary, required this.style});
}

enum AozoraHeadingForm { standalone, runIn, window }

enum AozoraHeadingLevel { large, medium, small }

class AozoraHeading extends AozoraAnnotation {
  /*
  通常見出し
  - `独り寝の別れ［＃「独り寝の別れ」は大見出し］`
  - `［＃中見出し］...［＃中見出し終わり］`
  - `［＃ここから小見出し］...［＃ここで小見出し終わり］`

  同行見出し
  - `...［＃「入藏を思ひ立ツた原因」は同行中見出し］`
  - `［＃同行大見出し］...［＃同行大見出し終わり］`

  窓見出し
  - `龍王岬［＃「龍王岬」は窓中見出し］`
  - `［＃窓小見出し］...［＃窓小見出し終わり］`

  前方参照型は対象範囲を特定したあと、開始・終了へ正規化して保持する。
  */
  final AozoraRangeBoundary boundary;
  final AozoraHeadingForm form;
  final AozoraHeadingLevel level;

  const AozoraHeading({
    required this.boundary,
    required this.form,
    required this.level,
  });
}

class AozoraCaption extends AozoraAnnotation {
  /*
  `神戸港頭の袂別［＃「神戸港頭の袂別」はキャプション］`
  `［＃キャプション］アケビ...［＃キャプション終わり］`
  `［＃ここからキャプション］...［＃ここでキャプション終わり］`
  を表す。
  */
  final AozoraRangeBoundary boundary;

  const AozoraCaption(this.boundary);
}

enum AozoraInlineDecorationKind {
  tatechuyoko,
  warichu,
  lineRightSmall,
  lineLeftSmall,
  superscript,
  subscript,
  keigakomi,
  yokogumi,
}

class AozoraInlineDecoration extends AozoraAnnotation {
  /*
  縦中横
  - `29［＃「29」は縦中横］`
  - `［＃縦中横］...［＃縦中横終わり］`

  割り注
  - `［＃割り注］ヒロソヒイ［＃割り注終わり］`

  行右小書き・行左小書き
  - `（５）［＃「（５）」は行右小書き］`
  - `（５）［＃「（５）」は行左小書き］`
  - `［＃行右小書き］...［＃行右小書き終わり］`

  上付き小文字・下付き小文字
  - `2［＃「2」は上付き小文字］`
  - `2［＃「2」は下付き小文字］`
  - `［＃上付き小文字］...［＃上付き小文字終わり］`

  罫囲み
  - `キ劇の［＃「キ劇の」は罫囲み］`
  - `［＃罫囲み］...［＃罫囲み終わり］`
  - `［＃ここから罫囲み］...［＃ここで罫囲み終わり］`

  横組み
  - `スハフ［＃「スハフ」は横組み］`
  - `［＃横組み］...［＃横組み終わり］`
  - `［＃ここから横組み］...［＃ここで横組み終わり］`
  */
  final AozoraRangeBoundary boundary;
  final AozoraInlineDecorationKind kind;

  const AozoraInlineDecoration({required this.boundary, required this.kind});
}

class AozoraUnsupportedAnnotation extends AozoraAnnotation {
  /*
  docs に載っていない独自注記や、まだ構造化していない注記を保持する。
  */
  final String raw;

  const AozoraUnsupportedAnnotation(this.raw);
}

class AozoraImageSize {
  final int width;
  final int height;

  const AozoraImageSize({required this.width, required this.height});
}

class AozoraImage extends AozoraToken {
  /*
  `［＃コンドル博士の図（fig47728_06.png、横320×縦322）入る］`
  `［＃石鏃二つの図（fig42154_01.png）入る］`
  `［＃「阿耨達池とカイラス雪峰」のキャプション付きの図（fig49966_15.png、横453×縦350）入る］`
  を表す。
  */
  final String description;
  final String fileName;
  final AozoraImageSize? size;
  final bool hasCaption;

  const AozoraImage({
    required this.description,
    required this.fileName,
    this.size,
    this.hasCaption = false,
  });
}

enum AozoraPageBreakKind { kaicho, kaipage, kaimihiraki, kaidan }

class AozoraPageBreak extends AozoraToken {
  /*
  `［＃改丁］`
  `［＃改ページ］`
  `［＃改見開き］`
  `［＃改段］`
  を表す。

  `extra.md` の空白ページは `AozoraPageBreak(kaipage)` を 2 個並べて表現する。
  */
  final AozoraPageBreakKind kind;

  const AozoraPageBreak(this.kind);
}

class AozoraPageCenter extends AozoraToken {
  /*
  `［＃ページの左右中央］`
  を表す。

  左寄り / 右寄りは注記ではなく前後の空行数で表れるので、この型では持たない。
  */
  const AozoraPageCenter();
}

enum AozoraIndentKind { singleLine, block }

class AozoraIndent extends AozoraToken {
  /*
  1 行だけ
  - `［＃３字下げ］`

  ブロック
  - `［＃ここから５字下げ］`
  - `［＃ここで字下げ終わり］`

  凹凸
  - `［＃ここから２字下げ、折り返して３字下げ］`
  - `［＃ここから改行天付き、折り返して１字下げ］`

  `lineIndent == 0` かつ `hangingIndent != null` は
  `改行天付き、折り返して○字下げ` を表す。
  */
  final AozoraIndentKind kind;
  final AozoraRangeBoundary? boundary;
  final int lineIndent;
  final int? hangingIndent;

  const AozoraIndent({
    required this.kind,
    this.boundary,
    required this.lineIndent,
    this.hangingIndent,
  });
}

enum AozoraBottomAlignKind { bottom, raisedFromBottom }

enum AozoraBottomAlignScope { inlineTail, singleLine, block }

class AozoraBottomAlign extends AozoraToken {
  /*
  地付き
  - `［＃地付き］`
  - `［＃ここから地付き］`
  - `［＃ここで地付き終わり］`

  地寄せ
  - `［＃地から２字上げ］`
  - `［＃ここから地から１字上げ］`
  - `［＃ここで字上げ終わり］`

  `offset == 0` は地付き。
  `scope == inlineTail` は行末の一部分だけが地付き / 地寄せであるケース。
  */
  final AozoraBottomAlignKind kind;
  final AozoraBottomAlignScope scope;
  final AozoraRangeBoundary? boundary;
  final int offset;

  const AozoraBottomAlign({
    required this.kind,
    required this.scope,
    this.boundary,
    this.offset = 0,
  });
}

class AozoraJizume extends AozoraToken {
  /*
  `［＃ここから１０字詰め］`
  `［＃ここで字詰め終わり］`
  を表す。
  */
  final AozoraRangeBoundary boundary;
  final int? width;

  const AozoraJizume({required this.boundary, this.width});
}

class AozoraBodyEnd extends AozoraToken {
  /*
  `［＃本文終わり］`
  を表す。
  */
  const AozoraBodyEnd();
}

enum AozoraDocumentRemarkKind {
  baseTextIsHorizontal,
  omittedLowerHeadingLevels,
  madoHeadingLineCount,
  replacedOuterKikkouWithSquareBrackets,
}

class AozoraDocumentRemark extends AozoraToken {
  /*
  本文中の注記ではなく、docs に出てくるファイル末の補足を保持する。

  - `※底本は横組みです。`
  - `※小見出しよりもさらに下位の見出しには、注記しませんでした。`
  - `※窓見出しは、３行どりです。`
  - `※底本の「〔〕」を「［］」に置き換えました。`
  */
  final AozoraDocumentRemarkKind kind;
  final int? value;

  const AozoraDocumentRemark({required this.kind, this.value});
}
