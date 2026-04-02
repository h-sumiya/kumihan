typedef AstData = List<AstToken>;

typedef AstInlineContent = List<AstInlineNode>;

abstract interface class AstInlineNode {}

sealed class AstToken {
  const AstToken();
}

enum AstRangeBoundary { start, end, blockStart, blockEnd }

enum AstTextSide { right, left }

class AstText extends AstToken implements AstInlineNode {
  final String text;

  const AstText(this.text);
}

class AstNewLine extends AstToken implements AstInlineNode {
  const AstNewLine();
}

class AstWarichuNewLine extends AstToken implements AstInlineNode {
  /*
  `［＃割り注］東は字大林四三七［＃改行］西は字神内一一一ノ一［＃割り注終わり］`
  の `［＃改行］` を表す。
  */
  const AstWarichuNewLine();
}

class AstAccentDecomposition extends AstToken implements AstInlineNode {
  /*
  `〔e'tiquette〕`
  `〔Sito^t qu'on le touche il re'sonne.〕`
  `jusqu'〔a`〕`
  の `〔...〕` 全体を、通常テキストとは区別して保持する。
  */
  final String text;

  const AstAccentDecomposition(this.text);
}

enum AstPageRegion { upper, middle, lower, one, two, three, four }

class AstPrintPosition {
  final int page;
  final int line;
  final AstPageRegion? region;

  const AstPrintPosition({required this.page, required this.line, this.region});
}

class AstJisCode {
  final int plane;
  final int row;
  final int cell;

  const AstJisCode({
    required this.plane,
    required this.row,
    required this.cell,
  });
}

enum AstGaijiKind { jisX0213, unicode, missingUnicode }

class AstGaiji extends AstToken implements AstInlineNode {
  /*
  `※［＃「てへん＋劣」、第3水準1-84-77］`
  `※［＃「口＋世」、U+546D、135-7］`
  `※［＃「土へん＋竒」、135-7］`
  `※［＃二の字点、1-2-22］`
  `※［＃始め二重山括弧、1-1-52］`
  などを表す。
  */
  final String description;
  final AstGaijiKind kind;
  final AstJisCode? jisCode;
  final int? jisLevel;
  final int? unicodeCodePoint;
  final AstPrintPosition? printPosition;

  const AstGaiji({
    required this.description,
    required this.kind,
    this.jisCode,
    this.jisLevel,
    this.unicodeCodePoint,
    this.printPosition,
  });
}

class AstTateTen extends AstToken implements AstInlineNode {
  /*
  `而敬‐［＃二］祭天神地祇［＃一］。`
  の全角ハイフン `‐` を、通常テキストと区別して持ちたい場合に使う。
  */
  const AstTateTen();
}

enum AstKaeritenPrimary {
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

class AstKaeriten extends AstToken implements AstInlineNode {
  /*
  `［＃二］`
  `［＃レ］`
  `［＃一レ］`
  `［＃上レ］`
  を表す。
  */
  final AstKaeritenPrimary? primary;
  final bool hasRe;

  const AstKaeriten({this.primary, this.hasRe = false});
}

class AstKuntenOkurigana extends AstToken implements AstInlineNode {
  /*
  `［＃（ノ）］`
  `［＃（弖）］`
  の `（...）` 内を表す。
  */
  final AstInlineContent content;

  const AstKuntenOkurigana(this.content);
}

sealed class AstAnnotation extends AstToken implements AstInlineNode {
  const AstAnnotation();
}

enum AstAttachedTextRole { ruby, note }

class AstAttachedText extends AstAnnotation {
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
  `AstAttachedText(start, ...)`
  `AstAttachedText(end, ...)`
  を置く。
  */
  final AstRangeBoundary boundary;
  final AstAttachedTextRole role;
  final AstTextSide side;
  final AstInlineContent? content;

  const AstAttachedText({
    required this.boundary,
    required this.role,
    required this.side,
    this.content,
  });
}

enum AstBoutenKind {
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

enum AstBosenKind { solid, doubleLine, chain, dashed, wave, cancel }

enum AstFontStyle { bold, italic }

enum AstFontScaleDirection { larger, smaller }

sealed class AstTextStyle {
  const AstTextStyle();
}

class AstBoutenStyle extends AstTextStyle {
  final AstBoutenKind kind;
  final AstTextSide side;

  const AstBoutenStyle({required this.kind, this.side = AstTextSide.right});
}

class AstBosenStyle extends AstTextStyle {
  final AstBosenKind kind;
  final AstTextSide side;

  const AstBosenStyle({required this.kind, this.side = AstTextSide.right});
}

class AstFontStyleAnnotation extends AstTextStyle {
  final AstFontStyle style;

  const AstFontStyleAnnotation(this.style);
}

class AstFontScaleStyle extends AstTextStyle {
  final AstFontScaleDirection direction;
  final int steps;

  const AstFontScaleStyle({required this.direction, required this.steps});
}

class AstTextColorStyle extends AstTextStyle {
  final int colorValue;

  const AstTextColorStyle(this.colorValue);
}

class AstStyledText extends AstAnnotation {
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
  final AstRangeBoundary boundary;
  final AstTextStyle style;

  const AstStyledText({required this.boundary, required this.style});
}

enum AstHeadingForm { standalone, runIn, window }

enum AstHeadingLevel { large, medium, small }

class AstHeading extends AstAnnotation {
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
  final AstRangeBoundary boundary;
  final AstHeadingForm form;
  final AstHeadingLevel level;

  const AstHeading({
    required this.boundary,
    required this.form,
    required this.level,
  });
}

class AstCaption extends AstAnnotation {
  /*
  `神戸港頭の袂別［＃「神戸港頭の袂別」はキャプション］`
  `［＃キャプション］アケビ...［＃キャプション終わり］`
  `［＃ここからキャプション］...［＃ここでキャプション終わり］`
  を表す。
  */
  final AstRangeBoundary boundary;

  const AstCaption(this.boundary);
}

enum AstInlineDecorationKind {
  tatechuyoko,
  warichu,
  lineRightSmall,
  lineLeftSmall,
  superscript,
  subscript,
  keigakomi,
  yokogumi,
}

class AstInlineDecoration extends AstAnnotation {
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
  final AstRangeBoundary boundary;
  final AstInlineDecorationKind kind;

  const AstInlineDecoration({required this.boundary, required this.kind});
}

class AstUnsupportedAnnotation extends AstAnnotation {
  /*
  docs に載っていない独自注記や、まだ構造化していない注記を保持する。
  */
  final String raw;

  const AstUnsupportedAnnotation(this.raw);
}

class AstImageSize {
  final int width;
  final int height;

  const AstImageSize({required this.width, required this.height});
}

class AstImage extends AstToken {
  /*
  `［＃コンドル博士の図（fig47728_06.png、横320×縦322）入る］`
  `［＃石鏃二つの図（fig42154_01.png）入る］`
  `［＃「阿耨達池とカイラス雪峰」のキャプション付きの図（fig49966_15.png、横453×縦350）入る］`
  を表す。
  */
  final String description;
  final String fileName;
  final AstImageSize? size;
  final bool hasCaption;

  const AstImage({
    required this.description,
    required this.fileName,
    this.size,
    this.hasCaption = false,
  });
}

enum AstPageBreakKind { kaicho, kaipage, kaimihiraki, kaidan }

class AstPageBreak extends AstToken {
  /*
  `［＃改丁］`
  `［＃改ページ］`
  `［＃改見開き］`
  `［＃改段］`
  を表す。

  `extra.md` の空白ページは `AstPageBreak(kaipage)` を 2 個並べて表現する。
  */
  final AstPageBreakKind kind;

  const AstPageBreak(this.kind);
}

class AstPageCenter extends AstToken {
  /*
  `［＃ページの左右中央］`
  を表す。

  左寄り / 右寄りは注記ではなく前後の空行数で表れるので、この型では持たない。
  */
  const AstPageCenter();
}

enum AstIndentKind { singleLine, block }

class AstIndent extends AstToken {
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
  final AstIndentKind kind;
  final AstRangeBoundary? boundary;
  final int lineIndent;
  final int? hangingIndent;

  const AstIndent({
    required this.kind,
    this.boundary,
    required this.lineIndent,
    this.hangingIndent,
  });
}

enum AstBottomAlignKind { bottom, raisedFromBottom }

enum AstBottomAlignScope { inlineTail, singleLine, block }

class AstBottomAlign extends AstToken {
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
  final AstBottomAlignKind kind;
  final AstBottomAlignScope scope;
  final AstRangeBoundary? boundary;
  final int offset;

  const AstBottomAlign({
    required this.kind,
    required this.scope,
    this.boundary,
    this.offset = 0,
  });
}

class AstJizume extends AstToken {
  /*
  `［＃ここから１０字詰め］`
  `［＃ここで字詰め終わり］`
  を表す。
  */
  final AstRangeBoundary boundary;
  final int? width;

  const AstJizume({required this.boundary, this.width});
}

class AstBodyEnd extends AstToken {
  /*
  `［＃本文終わり］`
  を表す。
  */
  const AstBodyEnd();
}

enum AstDocumentRemarkKind {
  baseTextIsHorizontal,
  omittedLowerHeadingLevels,
  madoHeadingLineCount,
  replacedOuterKikkouWithSquareBrackets,
}

class AstDocumentRemark extends AstToken {
  /*
  本文中の注記ではなく、docs に出てくるファイル末の補足を保持する。

  - `※底本は横組みです。`
  - `※小見出しよりもさらに下位の見出しには、注記しませんでした。`
  - `※窓見出しは、３行どりです。`
  - `※底本の「〔〕」を「［］」に置き換えました。`
  */
  final AstDocumentRemarkKind kind;
  final int? value;

  const AstDocumentRemark({required this.kind, this.value});
}
