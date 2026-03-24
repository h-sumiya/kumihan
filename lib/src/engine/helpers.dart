int? codePointAt(String text, int index) {
  if (index < 0 || index >= text.length) {
    return null;
  }

  final code = text.codeUnitAt(index);
  if (code < 0xd800 || code > 0xdbff || index + 1 >= text.length) {
    return code;
  }

  final next = text.codeUnitAt(index + 1);
  if (next < 0xdc00 || next > 0xdfff) {
    return code;
  }

  return (code - 0xd800) * 1024 + (next - 0xdc00) + 0x10000;
}

String charAt(String text, int index) {
  if (index < 0 || index >= text.length) {
    return '';
  }
  return text.substring(index, index + 1);
}
