import 'package:flutter/foundation.dart';

/// Which cell the keyboard is on.
///
/// A cell, not a row: a grid where the arrow keys only move vertically is a
/// list, and the whole point of the focus model is that Tab, the arrow keys,
/// Enter-to-edit and copy all agree about where "here" is.
///
/// The row is an index into the *whole* dataset and the column is an id, for
/// the same reason the selection is: a page turn, a sort or a hidden column
/// must not silently move the focus to whatever has taken that position.
class FitGridFocusState extends ChangeNotifier {
  int? _rowIndex;
  String? _columnId;

  /// Focused row, by index into the full row list, or null when nothing is
  /// focused.
  int? get rowIndex => _rowIndex;

  /// Focused column id, or null.
  String? get columnId => _columnId;

  bool get hasFocus => _rowIndex != null && _columnId != null;

  bool isFocusedCell(int rowIndex, String columnId) =>
      _rowIndex == rowIndex && _columnId == columnId;

  void moveTo(int rowIndex, String columnId) {
    if (_rowIndex == rowIndex && _columnId == columnId) return;
    _rowIndex = rowIndex;
    _columnId = columnId;
    notifyListeners();
  }

  void clear() {
    if (_rowIndex == null && _columnId == null) return;
    _rowIndex = null;
    _columnId = null;
    notifyListeners();
  }
}
