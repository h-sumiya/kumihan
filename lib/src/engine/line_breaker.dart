import 'dart:typed_data';

import 'generated/line_break_data.dart';
import 'generated/unicode_trie_data.dart';

const int _bk = 30;
const int _cr = 33;
const int _lf = 34;
const int _nl = 35;
const int _cb = 31;
const int _ba = 17;
const int _sp = 38;
const int _wj = 22;
const int _ai = 29;
const int _al = 12;
const int _sa = 36;
const int _sg = 37;
const int _xx = 39;
const int _cj = 32;
const int _ns = 5;

const int _diBrk = 0;
const int _inBrk = 1;
const int _ciBrk = 2;
const int _cpBrk = 3;

class _UnicodeTrie {
  _UnicodeTrie()
    : _data = Uint32List.fromList(kumihanUnicodeTrieData),
      _highStart = kumihanUnicodeTrieHighStart,
      _errorValue = kumihanUnicodeTrieErrorValue;

  final Uint32List _data;
  final int _highStart;
  final int _errorValue;

  int get(int codePoint) {
    if (codePoint < 0 || codePoint > 0x10ffff) {
      return _errorValue;
    }

    if (codePoint < 0xd800 || (codePoint > 0xdbff && codePoint <= 0xffff)) {
      final index = (_data[codePoint >> 5] << 2) + (codePoint & 31);
      return _data[index];
    }

    if (codePoint <= 0xffff) {
      final index =
          (_data[2048 + ((codePoint - 0xd800) >> 5)] << 2) + (codePoint & 31);
      return _data[index];
    }

    if (codePoint < _highStart) {
      var index = _data[2080 + (codePoint >> 11)];
      index = _data[index + ((codePoint >> 5) & 63)];
      index = (index << 2) + (codePoint & 31);
      return _data[index];
    }

    return _data[_data.length - 4];
  }
}

int _mapClass(int classId) {
  switch (classId) {
    case _ai:
    case _sa:
    case _sg:
    case _xx:
      return _al;
    case _cj:
      return _ns;
    default:
      return classId;
  }
}

int _mapInitialClass(int classId) {
  switch (classId) {
    case _lf:
    case _nl:
      return _bk;
    case _cb:
      return _ba;
    case _sp:
      return _wj;
    default:
      return classId;
  }
}

final _UnicodeTrie _classTrie = _UnicodeTrie();

class LineBreak {
  const LineBreak(this.position, {this.required = false});

  final int position;
  final bool required;
}

class LineBreaker {
  LineBreaker(this._text);

  final String _text;
  int _position = 0;
  int _lastPosition = 0;
  int? _currentClass;
  int? _nextClass;

  int _nextCodePoint() {
    final code = _text.codeUnitAt(_position);
    _position += 1;

    if (code >= 0xd800 && code <= 0xdbff && _position < _text.length) {
      final next = _text.codeUnitAt(_position);
      if (next >= 0xdc00 && next <= 0xdfff) {
        _position += 1;
        return (code - 0xd800) * 1024 + (next - 0xdc00) + 0x10000;
      }
    }

    return code;
  }

  int _nextCharClass() => _mapClass(_classTrie.get(_nextCodePoint()));

  LineBreak? nextBreak() {
    _currentClass ??= _mapInitialClass(_nextCharClass());

    while (_position < _text.length) {
      _lastPosition = _position;
      final previousClass = _nextClass;
      _nextClass = _nextCharClass();

      if (_currentClass == _bk || (_currentClass == _cr && _nextClass != _lf)) {
        _currentClass = _mapInitialClass(_mapClass(_nextClass!));
        return LineBreak(_lastPosition, required: true);
      }

      final mappedClass = switch (_nextClass) {
        _sp => _currentClass,
        _bk || _lf || _nl => _bk,
        _cr => _cr,
        _cb => _ba,
        _ => null,
      };

      if (mappedClass != null) {
        _currentClass = mappedClass;
        if (_nextClass == _cb) {
          return LineBreak(_lastPosition);
        }
        continue;
      }

      var shouldBreak = false;
      switch (kumihanPairTable[_currentClass!][_nextClass!]) {
        case _diBrk:
          shouldBreak = true;
        case _inBrk:
          shouldBreak = previousClass == _sp;
        case _ciBrk:
          if (previousClass != _sp) {
            continue;
          }
          shouldBreak = true;
        case _cpBrk:
          if (previousClass != _sp) {
            continue;
          }
      }

      _currentClass = _nextClass;
      if (shouldBreak) {
        return LineBreak(_lastPosition);
      }
    }

    if (_lastPosition < _text.length) {
      _lastPosition = _text.length;
      return LineBreak(_text.length);
    }

    return null;
  }
}
