import 'dart:convert';
import 'dart:typed_data';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Reads a zip of stored entries back into files, checking each entry's
/// CRC — enough of a zip reader to prove the writer is honest.
Map<String, String> unzipStored(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  final files = <String, String>{};
  var at = 0;
  while (data.getUint32(at, Endian.little) == 0x04034b50) {
    final method = data.getUint16(at + 8, Endian.little);
    final crc = data.getUint32(at + 14, Endian.little);
    final size = data.getUint32(at + 18, Endian.little);
    final nameLength = data.getUint16(at + 26, Endian.little);
    final extra = data.getUint16(at + 28, Endian.little);
    final name = utf8.decode(bytes.sublist(at + 30, at + 30 + nameLength));
    final start = at + 30 + nameLength + extra;
    final body = bytes.sublist(start, start + size);
    expect(method, 0, reason: '$name is stored');
    expect(_crc32(body), crc, reason: '$name CRC');
    files[name] = utf8.decode(body);
    at = start + size;
  }
  // The central directory follows, and its end record closes the file.
  expect(data.getUint32(at, Endian.little), 0x02014b50);
  expect(
    data.getUint32(bytes.length - 22, Endian.little),
    0x06054b50,
    reason: 'end of central directory',
  );
  return files;
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final byte in bytes) {
    crc ^= byte;
    for (var k = 0; k < 8; k++) {
      crc = (crc & 1) != 0 ? 0xEDB88320 ^ (crc >> 1) : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

void main() {
  const data = FitGridExportData(
    headers: <String>['Name', 'Salary', 'Code'],
    rows: <FitGridExportRow>[
      FitGridExportRow(cells: <String>['Team A', '', ''], isHeader: true),
      FitGridExportRow(
        cells: <String>['Amit & <co>', '72000', '007'],
        depth: 1,
      ),
      FitGridExportRow(
        cells: <String>['Big', '12345678901234567890', '-1.5'],
        depth: 1,
      ),
    ],
  );

  test('a workbook with every part a spreadsheet looks for', () {
    final files = unzipStored(fitGridToXlsx(data));
    expect(
      files.keys,
      containsAll(<String>[
        '[Content_Types].xml',
        '_rels/.rels',
        'xl/workbook.xml',
        'xl/_rels/workbook.xml.rels',
        'xl/styles.xml',
        'xl/worksheets/sheet1.xml',
      ]),
    );
  });

  test('numbers are numbers, except where that would lose something', () {
    final sheet = unzipStored(fitGridToXlsx(data))['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('<c r="B3"><v>72000</v></c>'));
    expect(sheet, contains('<c r="C4"><v>-1.5</v></c>'));
    // A leading zero, and more digits than a spreadsheet keeps, stay text.
    expect(sheet, contains('<t xml:space="preserve">007</t>'));
    expect(sheet, contains('<t xml:space="preserve">12345678901234567890</t>'));
    expect(sheet, contains('Amit &amp; &lt;co&gt;'));

    final text = unzipStored(
      fitGridToXlsx(data, detectNumbers: false),
    )['xl/worksheets/sheet1.xml']!;
    expect(text, isNot(contains('<v>72000</v>')));
  });

  test('headers are bold and frozen; groups carry outline levels', () {
    final sheet = unzipStored(fitGridToXlsx(data))['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('<c r="A1" s="1" t="inlineStr">'));
    expect(sheet, contains('state="frozen"'));
    expect(sheet, contains('<c r="A2" s="1"'), reason: 'group header bold');
    expect(sheet, contains('<row r="3" outlineLevel="1">'));
    expect(sheet, contains('outlineLevelRow="1"'));
  });

  test('sheet names are made legal', () {
    final workbook = unzipStored(
      fitGridToXlsx(data, sheetName: 'Q3 [draft]: a/b*c? with a long tail'),
    )['xl/workbook.xml']!;
    final name = RegExp(r'name="([^"]*)"').firstMatch(workbook)!.group(1)!;
    expect(name.length, lessThanOrEqualTo(31));
    expect(name, isNot(matches(RegExp(r'[\[\]:*?/\\]'))));
  });

  test('columns past Z are named AA, AB …', () {
    final wide = FitGridExportData(
      headers: <String>[for (var i = 0; i < 28; i++) 'c$i'],
      rows: const <FitGridExportRow>[],
    );
    final sheet = unzipStored(fitGridToXlsx(wide))['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('r="Z1"'));
    expect(sheet, contains('r="AB1"'));
  });

  test('straight from a controller', () {
    final controller = FitGridController<Employee>(
      rows: makeRows(3),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    final sheet = unzipStored(
      fitGridToXlsx(controller.export()),
    )['xl/worksheets/sheet1.xml']!;
    expect(sheet, contains('Person 2'));
    expect(sheet, contains('<v>50002</v>'));
  });
}
