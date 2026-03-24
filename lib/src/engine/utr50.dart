import 'generated/utr50_table.dart';

String getUtr50Type(int? codePoint) {
  if (codePoint == null) {
    return '?';
  }

  var start = 0;
  var end = kumihanUtr50Table.length;

  while (start < end) {
    final middle = (start + end) >> 1;
    if (kumihanUtr50Table[middle].$1 >= codePoint) {
      end = middle;
    } else {
      start = middle + 1;
    }
  }

  return kumihanUtr50Table[start].$2;
}
