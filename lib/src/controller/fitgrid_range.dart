import 'package:flutter/foundation.dart';

/// A rectangle of cells: every row between two rows and every column between
/// two columns, inclusive.
///
/// Rows are indices into the grid's rows in display order — the filtered,
/// sorted list, the same indices the selection and the focus use. Columns are
/// ids, so the rectangle survives a column being resized and means the
/// columns *between* its two edges in whatever order they are displayed.
@immutable
class FitGridCellRange {
  const FitGridCellRange({
    required this.anchorRow,
    required this.anchorColumnId,
    required this.extentRow,
    required this.extentColumnId,
  });

  /// Where the range started — the click, or the first cell of a drag.
  final int anchorRow;
  final String anchorColumnId;

  /// Where it ends — what Shift+click and Shift+Arrow move.
  final int extentRow;
  final String extentColumnId;

  int get firstRow => anchorRow < extentRow ? anchorRow : extentRow;
  int get lastRow => anchorRow < extentRow ? extentRow : anchorRow;
  int get rowCount => lastRow - firstRow + 1;

  bool get isSingleCell =>
      anchorRow == extentRow && anchorColumnId == extentColumnId;

  /// The column ids the range covers, in display order, given the columns as
  /// they are displayed. Empty if either edge is no longer displayed.
  List<String> columnIdsIn(List<String> displayed) {
    final a = displayed.indexOf(anchorColumnId);
    final b = displayed.indexOf(extentColumnId);
    if (a < 0 || b < 0) return const <String>[];
    final low = a < b ? a : b;
    final high = a < b ? b : a;
    return displayed.sublist(low, high + 1);
  }

  bool containsRow(int row) => row >= firstRow && row <= lastRow;

  @override
  bool operator ==(Object other) =>
      other is FitGridCellRange &&
      other.anchorRow == anchorRow &&
      other.anchorColumnId == anchorColumnId &&
      other.extentRow == extentRow &&
      other.extentColumnId == extentColumnId;

  @override
  int get hashCode =>
      Object.hash(anchorRow, anchorColumnId, extentRow, extentColumnId);

  @override
  String toString() =>
      'FitGridCellRange($anchorRow:$anchorColumnId → '
      '$extentRow:$extentColumnId)';
}

/// The selected rectangle of cells, when `FitGrid.cellSelection` is on.
///
/// Separate from the row selection rather than folded into it: selecting rows
/// and selecting cells answer different questions — "which records" and
/// "which values" — and a grid may want both at once, the way a spreadsheet
/// lets you select a column of numbers inside a table whose rows you have
/// also ticked.
class FitGridCellRangeState extends ChangeNotifier {
  FitGridCellRange? _range;

  /// The current range, or null when no cells are selected.
  FitGridCellRange? get range => _range;

  bool get isActive => _range != null;

  /// Whether more than one cell is selected — the point at which a range
  /// stops being the same thing as the focused cell and starts being painted.
  bool get isMultiCell => _range != null && !_range!.isSingleCell;

  /// Selects a single cell, making it the anchor of any later extension.
  void select(int row, String columnId) => _set(
    FitGridCellRange(
      anchorRow: row,
      anchorColumnId: columnId,
      extentRow: row,
      extentColumnId: columnId,
    ),
  );

  /// Moves the far corner of the range, keeping its anchor. Starts a range at
  /// the cell when there is none.
  void extendTo(int row, String columnId) {
    final current = _range;
    if (current == null) return select(row, columnId);
    _set(
      FitGridCellRange(
        anchorRow: current.anchorRow,
        anchorColumnId: current.anchorColumnId,
        extentRow: row,
        extentColumnId: columnId,
      ),
    );
  }

  /// Replaces the range outright.
  set range(FitGridCellRange? value) => _set(value);

  void clear() => _set(null);

  void _set(FitGridCellRange? value) {
    if (_range == value) return;
    _range = value;
    notifyListeners();
  }
}
