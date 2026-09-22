import 'package:flutter/material.dart';

import '../controller/fitgrid_controller.dart';
import '../model/fitgrid_column.dart';
import '../model/row_height.dart';
import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
import '../sizing/column_sizer.dart';
import '../theme/fitgrid_theme.dart';
import 'fitgrid_header.dart';
import 'fitgrid_section.dart';

/// A data grid that measures its columns and paints its cells.
///
/// ```dart
/// FitGrid<Employee>(
///   rows: employees,
///   columns: [
///     FitGridColumn(id: 'name', label: 'Name', value: (e) => e.name),
///     FitGridColumn(
///       id: 'salary',
///       label: 'Salary',
///       value: (e) => e.salary.toString(),
///       alignment: FitGridAlignment.end,
///       width: const FitGridColumnWidth.auto(min: 100),
///     ),
///   ],
/// )
/// ```
///
/// Columns size themselves from their content by default, so the example above
/// has no width arithmetic in it and still comes out proportioned. Pass a
/// [FitGridController] when you want to drive sorting, selection or column
/// visibility from outside; otherwise the grid keeps one to itself.
class FitGrid<T> extends StatefulWidget {
  const FitGrid({
    this.rows = const [],
    this.columns = const [],
    this.controller,
    this.theme,
    this.rowHeight,
    this.striped = true,
    this.stretchColumnsToFill = true,
    this.showHeader = true,
    this.emptyState,
    this.onRowTap,
    super.key,
  });

  /// Rows to display. Ignored when [controller] is supplied — the controller
  /// owns the data in that case.
  final List<T> rows;

  /// Columns to display. Ignored when [controller] is supplied.
  final List<FitGridColumn<T>> columns;

  /// External state. When null the grid creates and disposes its own.
  final FitGridController<T>? controller;

  /// Visual configuration. Defaults to the nearest [FitGridTheme], or one
  /// derived from the ambient Material theme.
  final FitGridThemeData? theme;

  /// Row sizing. Null follows the theme's density.
  final FitGridRowHeight? rowHeight;

  /// Whether odd rows get the theme's alternate background.
  final bool striped;

  /// Whether auto-sized columns share leftover width when the grid is wider
  /// than its content.
  ///
  /// Leaving this on fills the grid, at the cost of columns being wider than
  /// they need to be. Turning it off keeps every column at its measured width
  /// and leaves the slack as empty space after the last column, which is what
  /// you want when the honest width of a column carries meaning.
  final bool stretchColumnsToFill;

  final bool showHeader;

  /// Shown instead of the body when there are no rows.
  final Widget? emptyState;

  final void Function(T row, int rowIndex)? onRowTap;

  @override
  State<FitGrid<T>> createState() => _FitGridState<T>();
}

class _FitGridState<T> extends State<FitGrid<T>> {
  final FitGridColumnSizer _sizer = FitGridColumnSizer();
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final GlobalKey _sectionKey = GlobalKey();

  FitGridController<T>? _ownedController;
  FitGridController<T> get _controller =>
      widget.controller ?? (_ownedController ??= FitGridController<T>());

  // Memoized column measurement. Measuring is cheap per build but not free, and
  // a build happens on every scroll frame, so the inputs are compared rather
  // than re-measured.
  FitGridColumnLayout? _layout;
  Object? _layoutKey;

  @override
  void initState() {
    super.initState();
    _syncOwnedController();
  }

  @override
  void didUpdateWidget(FitGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        !identical(widget.rows, oldWidget.rows) ||
        !identical(widget.columns, oldWidget.columns)) {
      _syncOwnedController();
      _layoutKey = null;
    }
  }

  /// Keeps the internally-owned controller in step with the widget's own `rows`
  /// and `columns`. A caller-supplied controller is left alone — it is theirs.
  void _syncOwnedController() {
    if (widget.controller != null) return;
    final controller = _controller;
    if (!identical(controller.columns.columns, widget.columns)) {
      controller.columns.columns = widget.columns;
    }
    controller.data.rows = widget.rows;
  }

  @override
  void dispose() {
    _sizer.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ListenableBuilder(
      listenable: Listenable.merge([
        controller.data,
        controller.columns,
        controller.selection,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => _build(context, constraints),
      ),
    );
  }

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final controller = _controller;
    final theme = widget.theme ?? FitGridTheme.of(context);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    final columns = controller.columns.visible;
    final rows = controller.data.view;

    final rowHeight = switch (widget.rowHeight) {
      FitGridFixedRowHeight(:final pixels) => pixels,
      // Content-sized rows land with the measurement pass in a later release;
      // until then they fall back to the density height rather than silently
      // pretending to measure.
      _ => theme.effectiveRowHeight,
    };

    final layout = _resolveLayout(
      columns: columns,
      rows: rows,
      theme: theme,
      availableWidth: constraints.maxWidth,
      textDirection: textDirection,
      textScaler: textScaler,
      overrides: controller.columns.widthOverrides,
    );

    final paintColumns = <FitGridPaintColumn>[
      for (final column in columns)
        FitGridPaintColumn(
          alignment: column.alignment,
          overflow: column.overflow,
          isWidgetColumn: column.cellBuilder != null,
        ),
    ];

    // Identity of the row list changes whenever the data or the sort changes,
    // which is exactly when painted text could be stale.
    final specVersion = Object.hash(
      identityHashCode(rows),
      identityHashCode(columns),
      theme,
      rows.length,
    );

    FitGridCellSpec cellSpec(int rowIndex, int columnIndex) {
      final column = columns[columnIndex];
      final row = rows[rowIndex];
      return FitGridCellSpec(
        text: column.value(row),
        style: column.cellStyle?.call(row, rowIndex) ?? theme.cellTextStyle,
        alignment: column.alignment,
        overflow: column.overflow,
      );
    }

    Color? rowColor(int rowIndex) => controller.selection.contains(rowIndex)
        ? theme.selectedBackground
        : null;

    final body = rows.isEmpty
        ? (widget.emptyState ?? _defaultEmptyState(theme))
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: widget.onRowTap == null
                ? null
                : (details) => _handleTap(details.globalPosition, rows),
            child: Scrollbar(
              controller: _verticalController,
              child: Scrollable(
                controller: _verticalController,
                axisDirection: AxisDirection.down,
                viewportBuilder: (context, verticalOffset) => Scrollable(
                  controller: _horizontalController,
                  axisDirection: textDirection == TextDirection.rtl
                      ? AxisDirection.left
                      : AxisDirection.right,
                  viewportBuilder: (context, horizontalOffset) =>
                      FitGridSection(
                        key: _sectionKey,
                        columnLayout: layout,
                        paintColumns: paintColumns,
                        cellSpec: cellSpec,
                        specVersion: specVersion,
                        theme: theme,
                        rowCount: rows.length,
                        rowHeight: rowHeight,
                        vertical: verticalOffset,
                        horizontal: horizontalOffset,
                        rowColor: rowColor,
                        striped: widget.striped,
                      ),
                ),
              ),
            ),
          );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.rowBackground,
        border: Border.all(color: theme.border, width: theme.dividerThickness),
        borderRadius: theme.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: theme.borderRadius,
        child: Column(
          children: [
            if (widget.showHeader)
              ListenableBuilder(
                listenable: _horizontalController,
                builder: (context, _) => FitGridHeader<T>(
                  columns: columns,
                  layout: layout,
                  theme: theme,
                  horizontalOffset: _horizontalController.hasClients
                      ? _horizontalController.offset
                      : 0.0,
                  sortColumnId: controller.data.sortColumnId,
                  sortDirection: controller.data.sortDirection,
                  onSort: controller.toggleSort,
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  /// Turns a tap into a row, without a gesture detector per row.
  ///
  /// A conventional table wraps every row in its own detector, which is another
  /// few hundred objects. Here the hit lands on the section and the row is
  /// recovered from the y coordinate — arithmetic today, a binary search once
  /// rows can differ in height.
  void _handleTap(Offset globalPosition, List<T> rows) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return;
    final local = render.globalToLocal(globalPosition);
    final rowIndex = render.rowAtOffset(local.dy);
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    widget.onRowTap!(rows[rowIndex], rowIndex);
  }

  FitGridColumnLayout _resolveLayout({
    required List<FitGridColumn<T>> columns,
    required List<T> rows,
    required FitGridThemeData theme,
    required double availableWidth,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required Map<String, double> overrides,
  }) {
    final key = Object.hash(
      identityHashCode(columns),
      identityHashCode(rows),
      theme,
      availableWidth,
      textDirection,
      textScaler,
      Object.hashAll(overrides.entries.map((e) => Object.hash(e.key, e.value))),
      widget.stretchColumnsToFill,
    );
    final cached = _layout;
    if (cached != null && _layoutKey == key) return cached;

    final layout = _sizer.resolve(
      columns: columns,
      rows: rows,
      theme: theme,
      availableWidth: availableWidth,
      textDirection: textDirection,
      textScaler: textScaler,
      overrides: overrides,
      stretchToFill: widget.stretchColumnsToFill,
    );
    _layout = layout;
    _layoutKey = key;
    return layout;
  }

  Widget _defaultEmptyState(FitGridThemeData theme) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Text(
        'No rows',
        style: theme.cellTextStyle.copyWith(color: theme.placeholderForeground),
      ),
    ),
  );
}
