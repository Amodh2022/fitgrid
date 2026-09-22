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
    this.striped = true,
    this.editingCell = (-1, -1),
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
  final bool striped;

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
      striped: striped,
      editingRow: editingCell.$1,
      editingColumn: editingCell.$2,
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
      ..striped = striped
      ..editingCell = editingCell;
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
