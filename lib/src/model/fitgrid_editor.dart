import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'fitgrid_column.dart';

/// What opens an editor on a cell.
enum FitGridEditTrigger {
  /// Double-tap the cell. The default, because a single tap already means
  /// "select this row" in most grids.
  doubleTap,

  /// A single tap. Only sensible on a grid whose rows are not themselves
  /// tappable.
  singleTap,

  /// Nothing opens an editor by itself; the host calls
  /// `controller.editing.begin` when it wants one.
  programmatic,
}

/// What a committed edit should do to a cell that failed validation.
typedef FitGridCellValidator<T> = String? Function(T row, String value);

/// Applies a committed edit.
///
/// The grid never mutates your rows — it does not know how. This hands back the
/// row, its index in the full row list, and the text the user typed; updating
/// the model and pushing new rows to the controller is the host's job. That is
/// what keeps the grid free of an opinion about your state management.
typedef FitGridCellCommit<T> = void Function(T row, int rowIndex, String value);

/// Builds a bespoke editor for a cell, in place of the default text field.
///
/// Use it for a dropdown, a date picker, a stepper — anything whose editing
/// affordance is not a line of text. [commit] ends the edit with a value,
/// [cancel] abandons it; call one of them or the editor stays open.
typedef FitGridEditorBuilder<T> =
    Widget Function(BuildContext context, FitGridEditorSession<T> session);

/// Everything a custom editor needs to do its job.
@immutable
class FitGridEditorSession<T> {
  const FitGridEditorSession({
    required this.row,
    required this.rowIndex,
    required this.initialText,
    required this.commit,
    required this.cancel,
  });

  final T row;

  /// Index into the full row list, not the page.
  final int rowIndex;

  final String initialText;

  /// Ends the edit, running the validator first. Returns false when the
  /// validator rejected the value, in which case the editor stays open and
  /// should show [FitGridEditingState.error].
  final bool Function(String value) commit;

  /// Abandons the edit, changing nothing.
  final VoidCallback cancel;
}

/// Makes a column editable, and says how.
///
/// Editing is where a painted grid wins rather than loses: a widget-per-cell
/// table carries the cost of every cell all the time so that any of them could
/// become editable. Here exactly one real editor exists, and only while it is
/// open — it is an overlay child of the section, the same mechanism a
/// [FitGridColumn.cellBuilder] column uses.
@immutable
class FitGridEditor<T> {
  const FitGridEditor({
    required this.onCommit,
    this.initialText,
    this.validator,
    this.builder,
    this.keyboardType,
    this.inputFormatters,
    this.textAlign,
    this.selectAllOnOpen = true,
    this.commitOnFocusLoss = true,
  });

  /// Applies the edit. See [FitGridCellCommit].
  final FitGridCellCommit<T> onCommit;

  /// Seeds the editor. Defaults to the column's painted text, which is right
  /// for plain text and wrong for anything the column formats — a currency
  /// column painting `$72,000` wants `72000` in the editor.
  final String Function(T row)? initialText;

  /// Returns an error message to block the commit, or null to allow it.
  final FitGridCellValidator<T>? validator;

  /// Replaces the default text field entirely. See [FitGridEditorBuilder].
  final FitGridEditorBuilder<T>? builder;

  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextAlign? textAlign;

  /// Whether opening the editor selects the existing text, so typing replaces
  /// it. What a spreadsheet does.
  final bool selectAllOnOpen;

  /// Whether clicking away commits the edit or abandons it. Committing is the
  /// spreadsheet convention and the less surprising of the two, but a grid
  /// whose edits are expensive — a write per commit — may want the opposite.
  final bool commitOnFocusLoss;
}

/// One value written to one cell, by anything other than the user typing into
/// an editor — a paste, a Delete over a range, a fill-handle drag.
///
/// Each goes through the column's own [FitGridEditor.validator] and
/// [FitGridEditor.onCommit], exactly as a typed edit would.
@immutable
class FitGridCellEdit<T> {
  const FitGridCellEdit({
    required this.row,
    required this.rowIndex,
    required this.column,
    required this.value,
  });

  final T row;

  /// Index into the full row list, not the page.
  final int rowIndex;

  final FitGridColumn<T> column;

  /// The text being committed.
  final String value;
}
