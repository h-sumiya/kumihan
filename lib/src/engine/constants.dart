import 'dart:ui';

const String bundledFontPackage = 'kumihan';

const List<String> defaultMinchoFontFamilies = <String>[
  'WebFontMincho',
  'Noto Serif CJK JP',
  '游明朝体',
  'YuMincho',
  '游明朝',
  'Yu Mincho',
];
const List<String> defaultGothicFontFamilies = <String>[
  'WebFontGothic',
  'Noto Sans CJK JP Medium',
  'Yu Gothic M',
];
const List<String> defaultFixedMinchoFontFamilies = <String>[
  'WebFontMonoMincho',
  'WebFontMincho',
  'Noto Serif Mono CJK JP',
  'Yu Gothic M',
  '游明朝体',
  '游明朝',
];
const List<String> defaultFixedGothicFontFamilies = <String>[
  'WebFontMonoGothic',
  'WebFontGothic',
  'Noto Sans Mono CJK JP Medium',
  'Noto Sans CJK JP Medium',
  'Yu Gothic M',
];

const int paperColorValue = 0xfffffdf1;
const Color fontColor = Color(0xff444444);
const Color captionColor = Color(0xff446644);

const List<Color> markerColors = <Color>[
  Color(0xffffffff),
  Color(0xff0000ff),
  Color(0xff00ff00),
  Color(0xff00ffff),
  Color(0xffff0000),
  Color(0xffff00ff),
  Color(0xffffff00),
  Color(0xff000000),
];

const String openingBrackets = '‘“（〔［｛〈《「『【｟〘〖«〝';
const String closingBrackets = '’”）〕］｝〉》」』】｠〙〗»〟';
const String punctuationMarks = '，、。﹐﹑﹒，．';
const String rotatedProlongedSoundMark = 'ー';

const Map<String, String> accentsTable = <String, String>{
  '!@': '¡',
  '?@': '¿',
  'A`': 'À',
  "A'": 'Á',
  'A^': 'Â',
  'A~': 'Ã',
  'A:': 'Ä',
  'A&': 'Å',
  'AE&': 'Æ',
  'C,': 'Ç',
  'E`': 'È',
  "E'": 'É',
  'E^': 'Ê',
  'E:': 'Ë',
  'I`': 'Ì',
  "I'": 'Í',
  'I^': 'Î',
  'I:': 'Ï',
  'N~': 'Ñ',
  'O`': 'Ò',
  "O'": 'Ó',
  'O^': 'Ô',
  'O~': 'Õ',
  'O:': 'Ö',
  'O/': 'Ø',
  'U`': 'Ù',
  "U'": 'Ú',
  'U^': 'Û',
  'U:': 'Ü',
  "Y'": 'Ý',
  's&': 'ß',
  'a`': 'à',
  "a'": 'á',
  'a^': 'â',
  'a~': 'ã',
  'a:': 'ä',
  'a&': 'å',
  'ae&': 'æ',
  'c,': 'ç',
  'e`': 'è',
  "e'": 'é',
  'e^': 'ê',
  'e:': 'ë',
  'i`': 'ì',
  "i'": 'í',
  'i^': 'î',
  'i:': 'ï',
  'n~': 'ñ',
  'o`': 'ò',
  "o'": 'ó',
  'o^': 'ô',
  'o~': 'õ',
  'o:': 'ö',
  'o/': 'ø',
  'u`': 'ù',
  "u'": 'ú',
  'u^': 'û',
  'u:': 'ü',
  "y'": 'ý',
  'y:': 'ÿ',
  'A_': 'Ā',
  'a_': 'ā',
  'E_': 'Ē',
  'e_': 'ē',
  'I_': 'Ī',
  'i_': 'ī',
  'O_': 'Ō',
  'o_': 'ō',
  'OE&': 'Œ',
  'oe&': 'œ',
  'U_': 'Ū',
  'u_': 'ū',
};

enum EngineWritingDirection { vertical, horizontal }

enum EngineSpreadMode { single, doublePage }

class EngineLayoutState {
  const EngineLayoutState({
    this.writingDirection = EngineWritingDirection.vertical,
    this.spreadMode = EngineSpreadMode.single,
  });

  final EngineWritingDirection writingDirection;
  final EngineSpreadMode spreadMode;

  bool get isVertical => writingDirection == EngineWritingDirection.vertical;

  bool get isHorizontal =>
      writingDirection == EngineWritingDirection.horizontal;

  bool get isDoublePage => spreadMode == EngineSpreadMode.doublePage;
}

const EngineLayoutState defaultEngineLayoutState = EngineLayoutState();

double clampDouble(double value, double minimum, double maximum) {
  if (value < minimum) {
    return minimum;
  }
  if (value > maximum) {
    return maximum;
  }
  return value;
}
