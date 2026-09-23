import 'package:flutter/foundation.dart';

/// One cell's value, before and after an edit.
///
/// Values are the text an editor works in — `FitGridEditor.initialText`, or
/// the column's value — so undoing an edit hands the column's own commit the
/// same kind of string a user would have typed.
@immutable
class FitGridCellChange {
  const FitGridCellChange({
    required this.rowKey,
    required this.rowIndex,
    required this.columnId,
    required this.before,
    required this.after,
  });

  /// The row's identity — `FitGrid.rowKey`, or the row itself — so the change
  /// finds its row again after a sort has moved it.
  final Object rowKey;

  /// Where the row was, in the rows as displayed. The fallback when [rowKey]
  /// no longer matches anything, as it will not for a host that replaces an
  /// immutable row on every commit and has no `rowKey`.
  final int rowIndex;

  final String columnId;
  final String before;
  final String after;

  FitGridCellChange get inverse => FitGridCellChange(
    rowKey: rowKey,
    rowIndex: rowIndex,
    columnId: columnId,
    before: after,
    after: before,
  );

  @override
  String toString() =>
      'FitGridCellChange($columnId@$rowIndex: $before → $after)';
}

/// Edits the user has made, for undo and redo.
///
/// A step is a batch: one typed edit is a step, and so is a paste of a
/// hundred cells or a Delete over a range — undoing a paste should not take a
/// hundred key presses.
///
/// The history is data only. `FitGridController.undo` and `redo` replay it
/// through the columns' own editors, because only they know how to write a
/// value into a row.
class FitGridEditHistory extends ChangeNotifier {
  FitGridEditHistory({this.limit = 100}) : assert(limit > 0);

  /// How many steps are kept. The oldest are dropped beyond it.
  final int limit;

  final List<List<FitGridCellChange>> _undo = <List<FitGridCellChange>>[];
  final List<List<FitGridCellChange>> _redo = <List<FitGridCellChange>>[];

  /// How a row is identified, set by the grid from `FitGrid.rowKey`. Defaults
  /// to the row itself.
  Object Function(Object? row) keyOf = _identity;

  static Object _identity(Object? row) => row!;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  /// How many steps can be undone.
  int get undoDepth => _undo.length;

  /// Records a step. Any redo history is discarded: a new edit after an undo
  /// forks the timeline, and the old future no longer applies.
  void record(List<FitGridCellChange> step) {
    final changes = <FitGridCellChange>[
      for (final change in step)
        if (change.before != change.after) change,
    ];
    if (changes.isEmpty) return;
    _undo.add(List<FitGridCellChange>.unmodifiable(changes));
    if (_undo.length > limit) _undo.removeAt(0);
    _redo.clear();
    notifyListeners();
  }

  /// Takes the most recent step off the undo stack and puts its inverse on
  /// the redo stack. Returns the changes to apply, or null when there are
  /// none.
  List<FitGridCellChange>? takeUndo() => _move(_undo, _redo);

  /// The mirror of [takeUndo].
  List<FitGridCellChange>? takeRedo() => _move(_redo, _undo);

  List<FitGridCellChange>? _move(
    List<List<FitGridCellChange>> from,
    List<List<FitGridCellChange>> to,
  ) {
    if (from.isEmpty) return null;
    final step = from.removeLast();
    // Applied in reverse, so a step that wrote one cell twice unwinds to its
    // first value rather than its middle one.
    final inverse = <FitGridCellChange>[
      for (final change in step.reversed) change.inverse,
    ];
    to.add(inverse);
    notifyListeners();
    return inverse;
  }

  void clear() {
    if (_undo.isEmpty && _redo.isEmpty) return;
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }
}
