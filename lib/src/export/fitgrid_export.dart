import '../model/fitgrid_column.dart';
import '../model/row_model.dart';

/// What a row looks like to an exporter.
///
/// Headers stay headers rather than being flattened into a value column, so an
/// exporter that understands outline levels — xlsx does — can use them, and one
/// that does not can write the label and move on.
class FitGridExportRow {
  const FitGridExportRow({
    required this.cells,
    this.depth = 0,
    this.isHeader = false,
  });

  final List<String> cells;
  final int depth;
  final bool isHeader;
}

/// The grid's contents, in the shape an exporter wants.
///
/// The point of this type is that it has no opinion about a file format.
/// The package writes three from it without a single dependency — CSV and TSV
/// with [fitGridToCsv] and [fitGridToTsv], and Excel with `fitGridToXlsx` —
/// and anything else (a PDF, a styled workbook) is a writer of your own over
/// the same rows, rather than a font stack and an XML schema dragged into
/// every application whether it exports or not.
class FitGridExportData {
  const FitGridExportData({required this.headers, required this.rows});

  /// Column labels, in display order. Empty when headers were not wanted.
  final List<String> headers;

  final List<FitGridExportRow> rows;

  int get columnCount => headers.length;
}

/// Builds export data from columns and rows.
///
/// [columns] should be the visible columns in display order.
/// [FitGridColumn.copyValue] decides what each cell contributes, so a column
/// painted as "£72,000" exports as `72000` without the caller reformatting
/// anything — which is the difference between a file a spreadsheet can add up
/// and one it cannot.
FitGridExportData buildFitGridExport<T>({
  required List<FitGridColumn<T>> columns,
  required List<T> rows,
  List<FitGridDisplayRow<T>>? display,
  Iterable<int>? only,
  bool includeHeaders = true,
}) {
  // The selection checkbox is a control, not data.
  final exported = <FitGridColumn<T>>[
    for (final column in columns)
      if (!column.id.startsWith('__fitgrid')) column,
  ];

  List<String> cellsOf(T row) => <String>[
    for (final column in exported) column.copyTextFor(row),
  ];

  final selected = only?.toSet();
  final out = <FitGridExportRow>[];

  if (display != null) {
    for (final line in display) {
      // A detail panel is a widget, not data.
      if (line.isDetail) continue;
      if (line.isHeader) {
        // Exporting a selection exports rows, not the structure they happened
        // to be sitting in.
        if (selected != null) continue;
        out.add(
          FitGridExportRow(
            cells: <String>[
              line.label ?? '',
              for (var i = 1; i < exported.length; i++) '',
            ],
            depth: line.depth,
            isHeader: true,
          ),
        );
        continue;
      }
      if (selected != null && !selected.contains(line.sourceIndex)) continue;
      out.add(
        FitGridExportRow(cells: cellsOf(line.row as T), depth: line.depth),
      );
    }
  } else {
    for (var i = 0; i < rows.length; i++) {
      if (selected != null && !selected.contains(i)) continue;
      out.add(FitGridExportRow(cells: cellsOf(rows[i])));
    }
  }

  return FitGridExportData(
    headers: includeHeaders
        ? <String>[for (final column in exported) column.label]
        : const <String>[],
    rows: out,
  );
}

/// Writes export data as delimited text.
///
/// The two formats worth shipping in the box, because between them they cover
/// getting the numbers into the other window: tab-separated pastes into a
/// spreadsheet with no import dialog, and comma-separated is what every backend
/// expects in a file.
///
/// Quoting follows RFC 4180 — a field containing the delimiter, a quote or a
/// newline is wrapped in quotes and its own quotes are doubled. Skipping that is
/// how an address column silently becomes three columns.
String fitGridToDelimited(
  FitGridExportData data, {
  String delimiter = ',',
  String lineEnding = '\n',
  bool indentNesting = true,
}) {
  final buffer = StringBuffer();

  String escape(String value) {
    final needsQuotes =
        value.contains(delimiter) ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  void write(List<String> cells) {
    for (var i = 0; i < cells.length; i++) {
      if (i > 0) buffer.write(delimiter);
      buffer.write(escape(cells[i]));
    }
  }

  if (data.headers.isNotEmpty) {
    write(data.headers);
    if (data.rows.isNotEmpty) buffer.write(lineEnding);
  }

  for (var i = 0; i < data.rows.length; i++) {
    if (i > 0) buffer.write(lineEnding);
    final row = data.rows[i];
    final cells = indentNesting && row.depth > 0 && row.cells.isNotEmpty
        ? <String>[
            '${'  ' * row.depth}${row.cells.first}',
            ...row.cells.skip(1),
          ]
        : row.cells;
    write(cells);
  }

  return buffer.toString();
}

/// Shorthand for [fitGridToDelimited] with a comma.
String fitGridToCsv(FitGridExportData data) => fitGridToDelimited(data);

/// Shorthand for [fitGridToDelimited] with a tab — what the clipboard uses, and
/// what pastes into a spreadsheet without an import dialog.
String fitGridToTsv(FitGridExportData data) =>
    fitGridToDelimited(data, delimiter: '\t');

/// Parses delimited text — what [fitGridToDelimited] writes, and what a
/// spreadsheet puts on the clipboard — back into rows of cells.
///
/// Understands RFC 4180 quoting: a quoted field may hold the delimiter, a
/// newline, or a doubled quote. A trailing line ending does not produce an
/// empty last row, because every spreadsheet puts one on the clipboard and
/// nobody means it as a row.
List<List<String>> fitGridParseDelimited(
  String text, {
  String delimiter = ',',
}) {
  assert(delimiter.length == 1, 'The delimiter must be one character.');
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var quoted = false;
  var i = 0;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final char = text[i];
    if (quoted) {
      if (char == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        quoted = false;
      } else {
        field.write(char);
      }
      i++;
      continue;
    }
    if (char == '"' && field.isEmpty) {
      quoted = true;
    } else if (char == delimiter) {
      endField();
    } else if (char == '\r') {
      if (i + 1 < text.length && text[i + 1] == '\n') i++;
      endRow();
    } else if (char == '\n') {
      endRow();
    } else {
      field.write(char);
    }
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}
