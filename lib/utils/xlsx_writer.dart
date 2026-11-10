import 'dart:convert';
import 'package:archive/archive.dart';

/// Écrit un vrai classeur Excel (.xlsx) sans dépendance supplémentaire :
/// en-tête en gras sur fond gris, bordures, largeur de colonnes adaptée, nombres
/// reconnus et feuille orientée de droite à gauche (adaptée à l'arabe).
List<int> toXlsxBytes(List<List<String>> rows, {String sheetName = 'EPS', bool rtl = true}) {
  String esc(String v) => v
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  String col(int i) {
    var n = i + 1;
    var out = '';
    while (n > 0) {
      final r = (n - 1) % 26;
      out = String.fromCharCode(65 + r) + out;
      n = (n - 1) ~/ 26;
    }
    return out;
  }

  final width = <int, int>{};
  for (final r in rows) {
    for (var c = 0; c < r.length; c++) {
      final len = r[c].length;
      if (len > (width[c] ?? 0)) width[c] = len;
    }
  }

  final sheet = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write('<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">')
    ..write('<sheetViews><sheetView workbookViewId="0"${rtl ? ' rightToLeft="1"' : ''}/></sheetViews>')
    ..write('<cols>');
  for (var c = 0; c < width.length; c++) {
    final w = ((width[c] ?? 8) + 3).clamp(8, 60);
    sheet.write('<col min="${c + 1}" max="${c + 1}" width="$w" customWidth="1"/>');
  }
  sheet.write('</cols><sheetData>');
  for (var r = 0; r < rows.length; r++) {
    sheet.write('<row r="${r + 1}">');
    for (var c = 0; c < rows[r].length; c++) {
      final v = rows[r][c];
      final ref = '${col(c)}${r + 1}';
      final style = r == 0 ? 1 : 2;
      final t = v.trim();
      final parsed = r == 0 ? null : double.tryParse(t.replaceAll(',', '.'));
      // nombre « simple » seulement (évite de transformer des matricules à zéros en nombres)
      final isPlainNumber = parsed != null &&
          RegExp(r'^-?(0|[1-9]\d{0,8})([.,]\d+)?$').hasMatch(t);
      if (isPlainNumber) {
        sheet.write('<c r="$ref" s="$style"><v>$parsed</v></c>');
      } else {
        sheet.write('<c r="$ref" s="$style" t="inlineStr"><is><t xml:space="preserve">${esc(v)}</t></is></c>');
      }
    }
    sheet.write('</row>');
  }
  sheet.write('</sheetData></worksheet>');

  const styles = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<fonts count="2"><font><sz val="11"/><name val="Arial"/></font>'
      '<font><b/><sz val="11"/><name val="Arial"/></font></fonts>'
      '<fills count="3"><fill><patternFill patternType="none"/></fill>'
      '<fill><patternFill patternType="gray125"/></fill>'
      '<fill><patternFill patternType="solid"><fgColor rgb="FFDCE6F1"/><bgColor indexed="64"/></patternFill></fill></fills>'
      '<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>'
      '<border><left style="thin"><color rgb="FF999999"/></left><right style="thin"><color rgb="FF999999"/></right>'
      '<top style="thin"><color rgb="FF999999"/></top><bottom style="thin"><color rgb="FF999999"/></bottom><diagonal/></border></borders>'
      '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
      '<cellXfs count="3">'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
      '<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center"/></xf>'
      '<xf numFmtId="0" fontId="0" fillId="0" borderId="1" xfId="0" applyBorder="1" applyAlignment="1"><alignment vertical="center"/></xf>'
      '</cellXfs><cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles></styleSheet>';

  final safeName = esc(sheetName.length > 31 ? sheetName.substring(0, 31) : sheetName);
  final files = <String, String>{
    '[Content_Types].xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>',
    '_rels/.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="$safeName" sheetId="1" r:id="rId1"/></sheets></workbook>',
    'xl/_rels/workbook.xml.rels': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>',
    'xl/styles.xml': styles,
    'xl/worksheets/sheet1.xml': sheet.toString(),
  };

  final archive = Archive();
  files.forEach((name, content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  });
  return ZipEncoder().encode(archive)!;
}
