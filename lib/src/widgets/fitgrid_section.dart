import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
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
    required this.rowCount,
    required this.rowHeight,
    required this.vertical,
    required this.horizontal,
    this.overscanRows = 2,
    this.rowColor,
    this.striped = true,
    super.children,
    super.key,
  });

  final FitGridColumnLayout columnLayout;
  final List<FitGridPaintColumn> paintColumns;
  final FitGridCellSpecResolver cellSpec;
  final int specVersion;
  final FitGridThemeData theme;
  final int rowCount;
  final double rowHeight;
  final ViewportOffset vertical;
  final ViewportOffset horizontal;
  final int overscanRows;
  final FitGridRowColorResolver? rowColor;
  final bool striped;

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
      rowCount: rowCount,
      rowHeight: rowHeight,
      vertical: vertical,
      horizontal: horizontal,
      overscanRows: overscanRows,
      rowColor: rowColor,
      striped: striped,
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
      ..rowCount = rowCount
      ..rowHeight = rowHeight
      ..vertical = vertical
      ..horizontal = horizontal
      ..overscanRows = overscanRows
      ..rowColor = rowColor
      ..striped = striped;
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
