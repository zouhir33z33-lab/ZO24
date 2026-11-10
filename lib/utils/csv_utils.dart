import 'dart:convert';

/// CSV compatible Excel/LibreOffice : séparateur « ; » (Excel FR/AR) + BOM UTF-8.
List<int> toCsvBytes(List<List<String>> rows) {
  String q(String v) => '"${v.replaceAll('"', '""')}"';
  final text = rows.map((r) => r.map(q).join(';')).join('\r\n');
  return [0xEF, 0xBB, 0xBF, ...utf8.encode(text)];
}
