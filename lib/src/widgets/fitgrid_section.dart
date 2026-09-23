import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
import '../sizing/row_metrics.dart';
import '../theme/fitgrid_theme.dart';

/// Widget wrapper around [RenderFitGridSection].
///
/// Children are overlay cells — the real widgets layered over the painted grid
/// — and each must be tagged with a [FitGridCell] naming the cell it occupies.
class FitGridSection extends MultiChildRenderObjectWidget {
  const FitGridSection({
    required this.columnLayout,
    required this.paintColumns,
    required this.cellSpec,
    required this.specVersion,
    required this.theme,
    required this.rowMetrics,
    required this.vertical,
    required this.horizontal,
    this.overscanRows = 2,
    this.rowColor,
    this.isRowSelected,
    this.striped = true,
    this.editingCell = (-1, -1),
    this.focusedCell = (-1, -1),
    this.hoveredRow = -1,
    this.rowIndexOffset = 0,
    this.onCellActivate,
    super.children,
    super.key,
  });

  final FitGridColumnLayout columnLayout;
  final List<FitGridPaintColumn> paintColumns;
  final FitGridCellSpecResolver cellSpec;
  final int specVersion;
  final FitGridThemeData theme;
  final FitGridRowMetrics rowMetrics;
  final ViewportOffset vertical;
  final ViewportOffset horizontal;
  final int overscanRows;
  final FitGridRowColorResolver? rowColor;

  /// Whether a row is selected, for the semantics tree. Separate from
  /// [rowColor] because "selected" is a state a screen reader announces, and a
  /// colour is not.
  final FitGridRowFlagResolver? isRowSelected;
  final bool striped;

  /// The cell carrying the keyboard focus ring, or (-1, -1).
  final (int, int) focusedCell;

  /// The row under the pointer, or -1.
  final int hoveredRow;

  /// Added to a local row index to name it in the full dataset. Non-zero only
  /// when paginated, and used only by semantics.
  final int rowIndexOffset;

  /// Invoked when a screen reader activates a cell.
  final void Function(int row, int column)? onCellActivate;

  /// The cell an editor is covering, as (row, column) indices into this
  /// section, or (-1, -1) when none is open.
  final (int, int) editingCell;

  @override
  RenderFitGridSection createRenderObject(BuildContext context) {
    return RenderFitGridSection(
      columnLayout: columnLayout,
      paintColumns: paintColumns,
      cellSpec: cellSpec,
      specVersion: specVersion,
      theme: theme,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      rowMetrics: rowMetrics,
      vertical: vertical,
      horizontal: horizontal,
      overscanRows: overscanRows,
      rowColor: rowColor,
      isRowSelected: isRowSelected,
      striped: striped,
      editingRow: editingCell.$1,
      editingColumn: editingCell.$2,
      focusedRow: focusedCell.$1,
      focusedColumn: focusedCell.$2,
      hoveredRow: hoveredRow,
      rowIndexOffset: rowIndexOffset,
      onCellActivate: onCellActivate,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderFitGridSection renderObject,
  ) {
    renderObject
      ..columnLayout = columnLayout
      ..paintColumns = paintColumns
      ..cellSpec = cellSpec
      ..specVersion = specVersion
      ..theme = theme
      ..textDirection = Directionality.of(context)
      ..textScaler = MediaQuery.textScalerOf(context)
      ..rowMetrics = rowMetrics
      ..vertical = vertical
      ..horizontal = horizontal
      ..overscanRows = overscanRows
      ..rowColor = rowColor
      ..isRowSelected = isRowSelected
      ..striped = striped
      ..editingCell = editingCell
      ..focusedCell = focusedCell
      ..hoveredRow = hoveredRow
      ..rowIndexOffset = rowIndexOffset
      ..onCellActivate = onCellActivate;
  }
}

/// Tags an overlay child with the cell it occupies.
class FitGridCell extends ParentDataWidget<FitGridCellParentData> {
  const FitGridCell({
    required this.rowIndex,
    required this.columnIndex,
    required super.child,
    super.key,
  });

  final int rowIndex;
  final int columnIndex;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as FitGridCellParentData;
    var changed = false;
    if (data.rowIndex != rowIndex) {
      data.rowIndex = rowIndex;
      changed = true;
    }
    if (data.columnIndex != columnIndex) {
      data.columnIndex = columnIndex;
      changed = true;
    }
    if (changed) {
      renderObject.parent?.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FitGridSection;
}
