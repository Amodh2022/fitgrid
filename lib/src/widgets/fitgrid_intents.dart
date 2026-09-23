import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Moves the focused cell by whole steps.
class FitGridMoveIntent extends Intent {
  const FitGridMoveIntent(
    this.rowDelta,
    this.columnDelta, {
    this.extend = false,
  });

  final int rowDelta;
  final int columnDelta;

  /// Whether the move should drag the selection with it, as Shift+Arrow does
  /// in every other table.
  final bool extend;
}

/// Jumps the focus to an edge — Home, End, and their Ctrl variants.
class FitGridJumpIntent extends Intent {
  const FitGridJumpIntent({
    required this.toRowEdge,
    required this.toStart,
    this.extend = false,
  });

  /// Whether the jump is vertical (first/last row) rather than horizontal
  /// (first/last column).
  final bool toRowEdge;
  final bool toStart;
  final bool extend;
}

/// Moves the focus by a viewport of rows.
class FitGridPageIntent extends Intent {
  const FitGridPageIntent(this.direction, {this.extend = false});

  /// -1 for Page Up, 1 for Page Down.
  final int direction;
  final bool extend;
}

/// Opens an editor on the focused cell, or fires the tap callbacks when the
/// cell is not editable — the keyboard equivalent of activating it.
class FitGridActivateIntent extends Intent {
  const FitGridActivateIntent();
}

/// Toggles the focused row's membership of the selection.
class FitGridToggleSelectionIntent extends Intent {
  const FitGridToggleSelectionIntent();
}

/// Selects every row.
class FitGridSelectAllIntent extends Intent {
  const FitGridSelectAllIntent();
}

/// Copies the selection — or the focused cell, when nothing is selected — to
/// the clipboard.
class FitGridCopyIntent extends Intent {
  const FitGridCopyIntent();
}

/// Pastes tab-separated text from the clipboard into the editable cells at
/// the selected range or the focused cell.
class FitGridPasteIntent extends Intent {
  const FitGridPasteIntent();
}

/// Empties the editable cells of the selected range, or the focused cell.
class FitGridClearCellsIntent extends Intent {
  const FitGridClearCellsIntent();
}

/// Clears the selection, or closes an open editor.
class FitGridDismissIntent extends Intent {
  const FitGridDismissIntent();
}

/// The default keyboard map.
///
/// Deliberately the one people already have in their fingers from every
/// spreadsheet and every desktop table: arrows move, Shift extends, Ctrl jumps
/// to the edge, Space toggles, Enter activates. A grid that invents its own
/// bindings makes every user learn it twice.
///
/// Pass your own map to [FitGrid] through a `Shortcuts` ancestor to override
/// any of it; the actions are resolved by intent, not by key.
const Map<ShortcutActivator, Intent>
kFitGridShortcuts = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowUp): FitGridMoveIntent(-1, 0),
  SingleActivator(LogicalKeyboardKey.arrowDown): FitGridMoveIntent(1, 0),
  SingleActivator(LogicalKeyboardKey.arrowLeft): FitGridMoveIntent(0, -1),
  SingleActivator(LogicalKeyboardKey.arrowRight): FitGridMoveIntent(0, 1),
  SingleActivator(LogicalKeyboardKey.arrowUp, shift: true): FitGridMoveIntent(
    -1,
    0,
    extend: true,
  ),
  SingleActivator(LogicalKeyboardKey.arrowDown, shift: true): FitGridMoveIntent(
    1,
    0,
    extend: true,
  ),
  SingleActivator(LogicalKeyboardKey.arrowLeft, shift: true): FitGridMoveIntent(
    0,
    -1,
    extend: true,
  ),
  SingleActivator(LogicalKeyboardKey.arrowRight, shift: true):
      FitGridMoveIntent(0, 1, extend: true),
  SingleActivator(LogicalKeyboardKey.tab): FitGridMoveIntent(0, 1),
  SingleActivator(LogicalKeyboardKey.tab, shift: true): FitGridMoveIntent(
    0,
    -1,
  ),

  SingleActivator(LogicalKeyboardKey.home): FitGridJumpIntent(
    toRowEdge: false,
    toStart: true,
  ),
  SingleActivator(LogicalKeyboardKey.end): FitGridJumpIntent(
    toRowEdge: false,
    toStart: false,
  ),
  SingleActivator(LogicalKeyboardKey.home, control: true): FitGridJumpIntent(
    toRowEdge: true,
    toStart: true,
  ),
  SingleActivator(LogicalKeyboardKey.end, control: true): FitGridJumpIntent(
    toRowEdge: true,
    toStart: false,
  ),
  SingleActivator(LogicalKeyboardKey.home, meta: true): FitGridJumpIntent(
    toRowEdge: true,
    toStart: true,
  ),
  SingleActivator(LogicalKeyboardKey.end, meta: true): FitGridJumpIntent(
    toRowEdge: true,
    toStart: false,
  ),

  SingleActivator(LogicalKeyboardKey.pageUp): FitGridPageIntent(-1),
  SingleActivator(LogicalKeyboardKey.pageDown): FitGridPageIntent(1),

  SingleActivator(LogicalKeyboardKey.enter): FitGridActivateIntent(),
  SingleActivator(LogicalKeyboardKey.numpadEnter): FitGridActivateIntent(),
  SingleActivator(LogicalKeyboardKey.space): FitGridToggleSelectionIntent(),

  SingleActivator(LogicalKeyboardKey.keyA, control: true):
      FitGridSelectAllIntent(),
  SingleActivator(LogicalKeyboardKey.keyA, meta: true):
      FitGridSelectAllIntent(),
  SingleActivator(LogicalKeyboardKey.keyC, control: true): FitGridCopyIntent(),
  SingleActivator(LogicalKeyboardKey.keyC, meta: true): FitGridCopyIntent(),
  SingleActivator(LogicalKeyboardKey.keyV, control: true): FitGridPasteIntent(),
  SingleActivator(LogicalKeyboardKey.keyV, meta: true): FitGridPasteIntent(),
  SingleActivator(LogicalKeyboardKey.delete): FitGridClearCellsIntent(),
  SingleActivator(LogicalKeyboardKey.backspace): FitGridClearCellsIntent(),

  SingleActivator(LogicalKeyboardKey.escape): FitGridDismissIntent(),
};
