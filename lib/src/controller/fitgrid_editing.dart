import 'package:flutter/foundation.dart';

/// Which cell, if any, is open for editing.
///
/// One cell at a time, deliberately. A grid that can edit several cells at once
/// is a grid carrying several focus nodes, several controllers and an ambiguous
/// answer to "what does Escape do", and none of the spreadsheets people are
/// comparing this to work that way either.
///
/// Its own notifier, like the rest of the cluster: opening an editor must not
/// re-measure columns or invalidate the row view.
class FitGridEditingState extends ChangeNotifier {
  int? _rowIndex;
  String? _columnId;
  String? _error;

  /// Index into the rows as displayed of the cell being edited, or null when
  /// nothing is. Global, not page-local, and re-pointed when the view is
  /// reordered, so an open editor stays on its record through a sort.
  int? get rowIndex => _rowIndex;

  /// Id of the column being edited, or null.
  String? get columnId => _columnId;

  /// Validation message from the last rejected commit, or null.
  String? get error => _error;

  bool get isEditing => _rowIndex != null && _columnId != null;

  /// Whether this exact cell is the one open.
  bool isEditingCell(int rowIndex, String columnId) =>
      _rowIndex == rowIndex && _columnId == columnId;

  /// Opens an editor, closing any other. Idempotent for the same cell, so a
  /// stray second tap does not reset what the user has typed.
  void begin(int rowIndex, String columnId) {
    if (_rowIndex == rowIndex && _columnId == columnId) return;
    _rowIndex = rowIndex;
    _columnId = columnId;
    _error = null;
    notifyListeners();
  }

  /// Moves the open editor to [rowIndex] after the view has been reordered,
  /// so it stays on the same record. Unlike [begin], a validation message
  /// stays: the user is still looking at the value that was rejected.
  @internal
  void follow(int rowIndex) {
    if (_rowIndex == null || _rowIndex == rowIndex) return;
    _rowIndex = rowIndex;
    notifyListeners();
  }

  /// Closes the editor without applying anything.
  void cancel() {
    if (_rowIndex == null && _columnId == null && _error == null) return;
    _rowIndex = null;
    _columnId = null;
    _error = null;
    notifyListeners();
  }

  /// Rejects a commit and keeps the editor open showing [message].
  void reject(String message) {
    if (_error == message) return;
    _error = message;
    notifyListeners();
  }
}
