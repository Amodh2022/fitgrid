import 'dart:convert';
import 'dart:typed_data';

import 'fitgrid_export.dart';

/// Writes export data as an Excel workbook (`.xlsx`), returning its bytes.
///
/// Save them with whatever the platform offers — a file on desktop, a
/// download on the web, a share sheet on a phone. Nothing here touches
/// `dart:io`, so it runs everywhere Flutter does.
///
/// The workbook is deliberately plain: one sheet, the headers bold and frozen,
/// grouped rows carrying their outline level so Excel's outline buttons fold
/// them, and columns sized roughly to their content. Cells that read as
/// numbers are written as numbers — so a column of salaries sums — unless
/// [detectNumbers] is off.
///
/// The package's own rule is that no file format drags a dependency into
/// every app, and this keeps it: the zip is written with stored (uncompressed)
/// entries, which every spreadsheet reads, rather than pulling in a deflate
/// implementation. A large export is therefore larger on disk than one Excel
/// would save; re-saving it in Excel compresses it.
Uint8List fitGridToXlsx(
  FitGridExportData data, {
  String sheetName = 'Sheet1',
  bool detectNumbers = true,
  bool freezeHeader = true,
}) {
  final sheet = _sheetXml(
    data,
    detectNumbers: detectNumbers,
    freezeHeader: freezeHeader && data.headers.isNotEmpty,
  );
  final name = _escape(_sheetName(sheetName));
  final files = <String, String>{
    '[Content_Types].xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
        '<Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/>'
        '</Types>',
    '_rels/.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>',
    'xl/workbook.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        '<sheets><sheet name="$name" sheetId="1" r:id="rId1"/></sheets>'
        '</workbook>',
    'xl/_rels/workbook.xml.rels':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
        '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/>'
        '</Relationships>',
    // Style 0 is the default, style 1 bold — for the header row and for group
    // header rows.
    'xl/styles.xml':
        '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        '<fonts count="2"><font><sz val="11"/><name val="Calibri"/></font>'
        '<font><b/><sz val="11"/><name val="Calibri"/></font></fonts>'
        '<fills count="2"><fill><patternFill patternType="none"/></fill>'
        '<fill><patternFill patternType="gray125"/></fill></fills>'
        '<borders count="1"><border><left/><right/><top/><bottom/><diagonal/></border></borders>'
        '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
        '<cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>'
        '<xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs>'
        '</styleSheet>',
    'xl/worksheets/sheet1.xml': sheet,
  };
  return _zip(<String, List<int>>{
    for (final entry in files.entries) entry.key: utf8.encode(entry.value),
  });
}

/// Excel refuses a sheet name that is empty, longer than 31 characters, or
/// contains any of `[]:*?/\`.
String _sheetName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), ' ').trim();
  if (cleaned.isEmpty) return 'Sheet1';
  return cleaned.length > 31 ? cleaned.substring(0, 31) : cleaned;
}

final RegExp _number = RegExp(r'^-?(0|[1-9]\d*)(\.\d+)?([eE][-+]?\d+)?$');

/// Whether a cell should be written as a number.
///
/// Leading zeros — a postcode, a part number — are left as text, since the
/// zero is part of the value. So is anything with more than fifteen digits,
/// which is all the precision a spreadsheet keeps: an account number written
/// as a number would come back with its last digits turned to zeros.
bool _isNumber(String value) {
  if (!_number.hasMatch(value)) return false;
  final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length <= 15;
}

String _sheetXml(
  FitGridExportData data, {
  required bool detectNumbers,
  required bool freezeHeader,
}) {
  final out = StringBuffer()
    ..write('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>')
    ..write(
      '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">',
    );

  final columnCount = <int>[
    data.headers.length,
    for (final row in data.rows) row.cells.length,
  ].fold<int>(0, (a, b) => a > b ? a : b);

  final maxDepth = data.rows.fold<int>(0, (a, r) => r.depth > a ? r.depth : a);
  if (maxDepth > 0) {
    // Summary rows above their detail, the way the grid draws groups.
    out.write('<sheetPr><outlinePr summaryBelow="0"/></sheetPr>');
  }

  if (freezeHeader) {
    out.write(
      '<sheetViews><sheetView workbookViewId="0">'
      '<pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/>'
      '</sheetView></sheetViews>',
    );
  }

  if (maxDepth > 0) {
    out.write(
      '<sheetFormatPr defaultRowHeight="15" outlineLevelRow="$maxDepth"/>',
    );
  }

  // Widths from the longest text in each column, in Excel's own unit of
  // roughly one digit, clamped so one long note does not make a column the
  // width of the screen.
  if (columnCount > 0) {
    final widths = List<int>.filled(columnCount, 0);
    void measure(List<String> cells, int indent) {
      for (var c = 0; c < cells.length; c++) {
        final length = cells[c].length + (c == 0 ? indent : 0);
        if (length > widths[c]) widths[c] = length;
      }
    }

    measure(data.headers, 0);
    for (final row in data.rows) {
      measure(row.cells, row.depth * 2);
    }
    out.write('<cols>');
    for (var c = 0; c < columnCount; c++) {
      final width = (widths[c] + 2).clamp(6, 60);
      out.write(
        '<col min="${c + 1}" max="${c + 1}" width="$width" customWidth="1"/>',
      );
    }
    out.write('</cols>');
  }

  out.write('<sheetData>');
  var r = 0;
  void writeRow(List<String> cells, {int depth = 0, bool bold = false}) {
    r++;
    out.write('<row r="$r"');
    if (depth > 0) out.write(' outlineLevel="$depth"');
    out.write('>');
    for (var c = 0; c < cells.length; c++) {
      final value = cells[c];
      if (value.isEmpty) continue;
      final ref = '${_columnName(c)}$r';
      final style = bold ? ' s="1"' : '';
      if (detectNumbers && !bold && _isNumber(value)) {
        out.write('<c r="$ref"$style><v>$value</v></c>');
      } else {
        out.write(
          '<c r="$ref"$style t="inlineStr"><is><t xml:space="preserve">'
          '${_escape(value)}</t></is></c>',
        );
      }
    }
    out.write('</row>');
  }

  if (data.headers.isNotEmpty) writeRow(data.headers, bold: true);
  for (final row in data.rows) {
    writeRow(row.cells, depth: row.depth, bold: row.isHeader);
  }
  out
    ..write('</sheetData>')
    ..write('</worksheet>');
  return out.toString();
}

/// 0 → A, 25 → Z, 26 → AA.
String _columnName(int index) {
  var n = index + 1;
  final chars = <int>[];
  while (n > 0) {
    chars.add(65 + (n - 1) % 26);
    n = (n - 1) ~/ 26;
  }
  return String.fromCharCodes(chars.reversed);
}

/// Escapes XML text, and drops the control characters XML 1.0 cannot carry
/// at all — a stray one in the data would otherwise make Excel refuse the
/// whole file.
String _escape(String value) {
  final out = StringBuffer();
  for (final rune in value.runes) {
    switch (rune) {
      case 0x26:
        out.write('&amp;');
      case 0x3C:
        out.write('&lt;');
      case 0x3E:
        out.write('&gt;');
      case 0x22:
        out.write('&quot;');
      case 0x09 || 0x0A || 0x0D:
        out.writeCharCode(rune);
      default:
        if (rune >= 0x20 && rune != 0xFFFE && rune != 0xFFFF) {
          out.writeCharCode(rune);
        }
    }
  }
  return out.toString();
}

// ------------------------------------------------------------------- zip

/// A zip archive of stored entries, in order.
Uint8List _zip(Map<String, List<int>> files) {
  final body = BytesBuilder(copy: false);
  final directory = BytesBuilder(copy: false);
  var offset = 0;

  for (final entry in files.entries) {
    final name = utf8.encode(entry.key);
    final data = entry.value;
    final crc = _crc32(data);

    final local = _Bytes()
      ..u32(0x04034b50)
      ..u16(20) // version needed
      ..u16(0x0800) // UTF-8 names
      ..u16(0) // stored
      ..u16(0) // time
      ..u16(0x21) // date: 1980-01-01
      ..u32(crc)
      ..u32(data.length)
      ..u32(data.length)
      ..u16(name.length)
      ..u16(0)
      ..bytes(name);
    body
      ..add(local.take())
      ..add(data);

    final central = _Bytes()
      ..u32(0x02014b50)
      ..u16(20) // version made by
      ..u16(20) // version needed
      ..u16(0x0800)
      ..u16(0)
      ..u16(0)
      ..u16(0x21)
      ..u32(crc)
      ..u32(data.length)
      ..u32(data.length)
      ..u16(name.length)
      ..u16(0) // extra
      ..u16(0) // comment
      ..u16(0) // disk
      ..u16(0) // internal attributes
      ..u32(0) // external attributes
      ..u32(offset)
      ..bytes(name);
    directory.add(central.take());
    offset += 30 + name.length + data.length;
  }

  final centralBytes = directory.takeBytes();
  final end = _Bytes()
    ..u32(0x06054b50)
    ..u16(0)
    ..u16(0)
    ..u16(files.length)
    ..u16(files.length)
    ..u32(centralBytes.length)
    ..u32(offset)
    ..u16(0);
  body
    ..add(centralBytes)
    ..add(end.take());
  return body.takeBytes();
}

class _Bytes {
  final BytesBuilder _builder = BytesBuilder();

  void u16(int value) => _builder
    ..addByte(value & 0xFF)
    ..addByte((value >> 8) & 0xFF);

  void u32(int value) => _builder
    ..addByte(value & 0xFF)
    ..addByte((value >> 8) & 0xFF)
    ..addByte((value >> 16) & 0xFF)
    ..addByte((value >> 24) & 0xFF);

  void bytes(List<int> value) => _builder.add(value);

  Uint8List take() => _builder.takeBytes();
}

final Uint32List _crcTable = () {
  final table = Uint32List(256);
  for (var n = 0; n < 256; n++) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
    }
    table[n] = c;
  }
  return table;
}();

int _crc32(List<int> data) {
  var crc = 0xFFFFFFFF;
  for (final byte in data) {
    crc = _crcTable[(crc ^ byte) & 0xFF] ^ (crc >> 8);
  }
  return (crc ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}
