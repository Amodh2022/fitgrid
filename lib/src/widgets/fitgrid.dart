import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/fitgrid_controller.dart';
import '../controller/fitgrid_pagination.dart';
import '../model/page_view.dart';
import '../model/enums.dart';
import '../model/fitgrid_editor.dart';
import '../model/fitgrid_column.dart';
import '../model/row_height.dart';
import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
import '../sizing/column_sizer.dart';
import '../sizing/row_metrics.dart';
import '../sizing/row_sizer.dart';
import '../theme/fitgrid_theme.dart';
import 'fitgrid_cell_editor.dart';
import 'fitgrid_header.dart';
import 'fitgrid_pager.dart';
import 'fitgrid_section.dart';
import 'fitgrid_tooltip.dart';

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
    this.resizableColumns = true,
    this.paginated = false,
    this.pageSize,
    this.pagerBuilder,
    this.overscanRows = 2,
    this.editTrigger = FitGridEditTrigger.doubleTap,
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
  ///
  /// [FitGridRowHeight.contentSized] measures each row against the columns that
  /// can wrap — see [FitGridColumn.maxLines] — and is free when none of them
  /// can, since every row then resolves to the same height anyway.
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

  /// Whether the header offers drag handles on its column dividers.
  ///
  /// Drag one to set a column's width; double-click it to hand the column back
  /// to its width policy, which for an `auto` column means measuring the
  /// content again. Individual columns opt out with
  /// [FitGridColumn.resizable], and a column whose policy pins it to one width
  /// gets no handle either — there would be nothing for the drag to do.
  ///
  /// A dragged width is still clamped by the column's own `min`/`max`, so the
  /// bounds you declared hold whatever the user does with the mouse.
  final bool resizableColumns;

  /// Shows one page of rows at a time, with a pager below the grid.
  ///
  /// Paging is a window onto the same list, not a copy of part of it, so it
  /// costs nothing per page. Column widths are still measured against the whole
  /// dataset rather than the page on screen, or columns would visibly jump
  /// every time the user turned a page.
  ///
  /// Row indices reported to [onRowTap] and held in the selection stay global,
  /// so a selection survives paging rather than reattaching to whatever now
  /// sits at that position.
  final bool paginated;

  /// Rows per page. Null keeps whatever the controller's
  /// [FitGridPaginationState] already holds, which defaults to 25.
  final int? pageSize;

  /// Replaces the built-in pager entirely. Given the same state the default one
  /// reads, so a custom pager is a peer rather than a workaround.
  final Widget Function(
    BuildContext context,
    FitGridPaginationState pagination,
  )?
  pagerBuilder;

  /// Extra rows laid out above and below the viewport so a fast fling has
  /// something to show while the next frame is built. Raise it for very fast
  /// scrolling on slow devices; it costs painters, not widgets.
  final int overscanRows;

  /// What opens an editor on an editable cell. See [FitGridColumn.editor].
  ///
  /// Only cells in columns that declared an editor respond at all, so leaving
  /// this at its default costs nothing on a read-only grid.
  final FitGridEditTrigger editTrigger;

  /// Shown instead of the body when there are no rows.
  final Widget? emptyState;

  final void Function(T row, int rowIndex)? onRowTap;

  @override
  State<FitGrid<T>> createState() => _FitGridState<T>();
}

class _FitGridState<T> extends State<FitGrid<T>> {
  final FitGridColumnSizer _sizer = FitGridColumnSizer();
  final FitGridRowSizer _rowSizer = FitGridRowSizer();
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

  // Row measurement is memoized the same way, and separately: a horizontal
  // scroll changes neither, but a resize changes the column widths, which is
  // exactly what a wrapped cell's height depends on.
  FitGridRowMetrics? _rowMetrics;
  Object? _rowMetricsKey;

  FitGridTooltipTarget? _tooltip;

  FitGridPageView<T>? _page;
  Object? _pageKey;

  @override
  void initState() {
    super.initState();
    _syncOwnedController();
    _syncPagination();
  }

  @override
  void didUpdateWidget(FitGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller ||
        !identical(widget.rows, oldWidget.rows) ||
        !identical(widget.columns, oldWidget.columns)) {
      _syncOwnedController();
      _layoutKey = null;
      _rowMetricsKey = null;
      _pageKey = null;
    }
    if (widget.paginated != oldWidget.paginated ||
        widget.pageSize != oldWidget.pageSize) {
      _syncPagination();
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

  /// Pushes the widget's paging preferences onto the controller, which is where
  /// the state actually lives so a host can drive it too.
  void _syncPagination() {
    final pagination = _controller.pagination;
    pagination.enabled = widget.paginated;
    if (widget.pageSize != null) pagination.pageSize = widget.pageSize!;
    pagination.rowCount = _controller.data.length;
  }

  @override
  void dispose() {
    _sizer.dispose();
    _rowSizer.dispose();
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
        controller.pagination,
        controller.editing,
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
    final allRows = controller.data.view;
    final rows = _pageOf(allRows, controller.pagination);

    final layout = _resolveLayout(
      columns: columns,
      rows: allRows,
      theme: theme,
      availableWidth: constraints.maxWidth,
      textDirection: textDirection,
      textScaler: textScaler,
      overrides: controller.columns.widthOverrides,
    );

    // After the columns, never before: how tall a wrapped cell is depends on
    // how wide its column came out.
    final rowMetrics = _resolveRowMetrics(
      columns: columns,
      rows: rows,
      layout: layout,
      theme: theme,
      textDirection: textDirection,
      textScaler: textScaler,
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

    final pageOffset = rows is FitGridPageView<T> ? rows.offset : 0;

    FitGridCellSpec cellSpec(int rowIndex, int columnIndex) {
      final column = columns[columnIndex];
      final row = rows[rowIndex];
      return FitGridCellSpec(
        text: column.value(row),
        style: column.cellStyle?.call(row, rowIndex) ?? theme.cellTextStyle,
        alignment: column.alignment,
        overflow: column.overflow,
        maxLines: column.maxLines,
      );
    }

    // Selection and taps speak in indices into the whole dataset, so they stay
    // meaningful when the user turns a page.
    Color? rowColor(int rowIndex) =>
        controller.selection.contains(pageOffset + rowIndex)
        ? theme.selectedBackground
        : null;

    final wantsTooltips = columns.any(
      (column) => column.overflow == FitGridOverflow.tooltipOnTruncate,
    );

    final editorChild = _buildEditor(
      context: context,
      columns: columns,
      rows: rows,
      pageOffset: pageOffset,
      theme: theme,
    );

    final wantsTapEdit =
        widget.editTrigger == FitGridEditTrigger.singleTap &&
        columns.any((column) => column.isEditable);
    final wantsDoubleTapEdit =
        widget.editTrigger == FitGridEditTrigger.doubleTap &&
        columns.any((column) => column.isEditable);

    final body = rows.isEmpty
        ? (widget.emptyState ?? _defaultEmptyState(theme))
        : GestureDetector(
            behavior: HitTestBehavior.translucent,
            onDoubleTapDown: wantsDoubleTapEdit
                ? (details) => _beginEdit(details.globalPosition, columns, rows)
                : null,
            onDoubleTap: wantsDoubleTapEdit ? () {} : null,
            onTapUp: widget.onRowTap == null && !wantsTapEdit
                ? null
                : (details) {
                    if (wantsTapEdit) {
                      _beginEdit(details.globalPosition, columns, rows);
                    }
                    if (widget.onRowTap != null) {
                      _handleTap(details.globalPosition, rows);
                    }
                  },
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
                        rowMetrics: rowMetrics,
                        vertical: verticalOffset,
                        horizontal: horizontalOffset,
                        rowColor: rowColor,
                        striped: widget.striped,
                        overscanRows: widget.overscanRows,
                        editingCell: _editingCellIn(
                          columns,
                          controller,
                          pageOffset,
                          rows.length,
                        ),
                        children: <Widget>[?editorChild],
                      ),
                ),
              ),
            ),
          );

    final hoverable = wantsTooltips
        ? MouseRegion(
            onHover: (event) => _updateTooltip(event.position, columns, rows),
            onExit: (_) => _clearTooltip(),
            child: body,
          )
        : body;

    final frame = Column(
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
              onResize: widget.resizableColumns
                  ? controller.columns.setWidth
                  : null,
              onAutoSize: widget.resizableColumns
                  ? controller.columns.autoSize
                  : null,
            ),
          ),
        Expanded(child: hoverable),
        if (widget.paginated)
          widget.pagerBuilder?.call(context, controller.pagination) ??
              FitGridPager(pagination: controller.pagination, theme: theme),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.rowBackground,
        border: Border.all(color: theme.border, width: theme.dividerThickness),
        borderRadius: theme.borderRadius,
      ),
      child: ClipRRect(
        borderRadius: theme.borderRadius,
        child: Stack(
          children: [
            frame,
            if (_tooltip != null)
              FitGridTooltip(
                target: _tooltip!,
                theme: theme,
                bounds: constraints.biggest,
              ),
          ],
        ),
      ),
    );
  }

  /// Turns a tap into a row, without a gesture detector per row.
  ///
  /// A conventional table wraps every row in its own detector, which is another
  /// few hundred objects. Here the hit lands on the section and the row is
  /// recovered from the y coordinate — arithmetic when rows share a height, a
  /// binary search when they do not.
  void _handleTap(Offset globalPosition, List<T> rows) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return;
    final local = render.globalToLocal(globalPosition);
    final rowIndex = render.rowAtOffset(local.dy);
    if (rowIndex < 0 || rowIndex >= rows.length) return;
    final offset = rows is FitGridPageView<T> ? rows.offset : 0;
    widget.onRowTap!(rows[rowIndex], offset + rowIndex);
  }

  /// The cell an editor covers, in this section's own indices, or (-1, -1).
  (int, int) _editingCellIn(
    List<FitGridColumn<T>> columns,
    FitGridController<T> controller,
    int pageOffset,
    int pageLength,
  ) {
    final editing = controller.editing;
    final globalRow = editing.rowIndex;
    final columnId = editing.columnId;
    if (globalRow == null || columnId == null) return (-1, -1);

    final localRow = globalRow - pageOffset;
    if (localRow < 0 || localRow >= pageLength) return (-1, -1);

    final columnIndex = columns.indexWhere((column) => column.id == columnId);
    return columnIndex < 0 ? (-1, -1) : (localRow, columnIndex);
  }

  /// The editor overlay, or null when nothing is being edited.
  ///
  /// It is tagged with [FitGridCell] and handed to the section as a child, so
  /// the render object lays it into the cell's own box — including the right
  /// width after a resize, and the mirrored position under RTL. None of that
  /// geometry is duplicated here.
  Widget? _buildEditor({
    required BuildContext context,
    required List<FitGridColumn<T>> columns,
    required List<T> rows,
    required int pageOffset,
    required FitGridThemeData theme,
  }) {
    final controller = _controller;
    final (localRow, columnIndex) = _editingCellIn(
      columns,
      controller,
      pageOffset,
      rows.length,
    );
    if (localRow < 0) return null;

    final column = columns[columnIndex];
    final editor = column.editor;
    if (editor == null) return null;

    final row = rows[localRow];
    final globalRow = pageOffset + localRow;

    final session = FitGridEditorSession<T>(
      row: row,
      rowIndex: globalRow,
      initialText: editor.initialText?.call(row) ?? column.value(row),
      commit: (value) => _commitEdit(column, editor, row, globalRow, value),
      cancel: controller.editing.cancel,
    );

    return FitGridCell(
      rowIndex: localRow,
      columnIndex: columnIndex,
      child: FitGridCellEditor<T>(
        // Keyed on the cell, so moving the editor to a different cell builds a
        // fresh field rather than carrying the previous cell's text across.
        key: ValueKey<String>('fitgrid-editor-$globalRow-${column.id}'),
        editor: editor,
        session: session,
        theme: theme,
        alignment: switch (column.alignment) {
          FitGridAlignment.start => TextAlign.start,
          FitGridAlignment.center => TextAlign.center,
          FitGridAlignment.end => TextAlign.end,
        },
        onNext: () =>
            _editNext(columns, columnIndex, globalRow, rows.length, pageOffset),
      ),
    );
  }

  /// Runs the validator, then either applies the edit and closes, or keeps the
  /// editor open with the message.
  bool _commitEdit(
    FitGridColumn<T> column,
    FitGridEditor<T> editor,
    T row,
    int globalRow,
    String value,
  ) {
    final error = editor.validator?.call(row, value);
    if (error != null) {
      _controller.editing.reject(error);
      return false;
    }
    _controller.editing.cancel();
    editor.onCommit(row, globalRow, value);
    return true;
  }

  /// Tab: the next editable column on this row, then the first editable column
  /// of the next row. Stops at the end of the page rather than paging on, which
  /// would move the ground under the user mid-edit.
  void _editNext(
    List<FitGridColumn<T>> columns,
    int fromColumn,
    int globalRow,
    int pageLength,
    int pageOffset,
  ) {
    for (var i = fromColumn + 1; i < columns.length; i++) {
      if (columns[i].isEditable) {
        return _controller.editing.begin(globalRow, columns[i].id);
      }
    }
    final nextLocal = globalRow - pageOffset + 1;
    if (nextLocal >= pageLength) return;
    for (final column in columns) {
      if (column.isEditable) {
        return _controller.editing.begin(pageOffset + nextLocal, column.id);
      }
    }
  }

  /// Turns a tap into an editor, if it landed on an editable cell.
  void _beginEdit(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    List<T> rows,
  ) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return;

    final local = render.globalToLocal(globalPosition);
    final localRow = render.rowAtOffset(local.dy);
    final columnIndex = render.columnAtOffset(local.dx);
    if (localRow < 0 || columnIndex < 0) return;
    if (localRow >= rows.length || columnIndex >= columns.length) return;

    final offset = rows is FitGridPageView<T> ? rows.offset : 0;
    final globalRow = offset + localRow;
    final editing = _controller.editing;
    final target = columns[columnIndex];

    // A tap on another cell ends the open edit first. The painted body is not
    // focusable, so without this the field would keep focus and the edit would
    // hang around behind the new one.
    if (editing.isEditing && !editing.isEditingCell(globalRow, target.id)) {
      FocusManager.instance.primaryFocus?.unfocus();
    }

    if (!target.isEditable) return;
    editing.begin(globalRow, target.id);
  }

  /// The slice of [rows] currently on screen.
  ///
  /// Memoized on the source list, the page and the page size so the same view
  /// object comes back between builds: every downstream cache — the column
  /// layout, the row metrics, the painted cell specs — is keyed on its
  /// identity, and a fresh wrapper each build would throw all three away on
  /// every scroll frame.
  List<T> _pageOf(List<T> rows, FitGridPaginationState pagination) {
    if (!widget.paginated || !pagination.enabled) return rows;

    final key = Object.hash(
      identityHashCode(rows),
      pagination.pageIndex,
      pagination.pageSize,
      rows.length,
    );
    final cached = _page;
    if (cached != null && _pageKey == key) return cached;

    final start = math.min(pagination.firstRowIndex, rows.length);
    final view = FitGridPageView<T>(
      rows,
      start,
      math.min(pagination.pageSize, rows.length - start),
    );
    _page = view;
    _pageKey = key;
    return view;
  }

  /// Tracks which truncated cell the pointer is over.
  ///
  /// The expensive part of a tooltip elsewhere — working out whether the text
  /// was actually cut — is free here: the render layer recorded it while
  /// painting. All that is left is a hit test, and the state is only touched
  /// when the pointer crosses into a different cell, so moving across one cell
  /// does not rebuild anything.
  void _updateTooltip(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    List<T> rows,
  ) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return _clearTooltip();

    final local = render.globalToLocal(globalPosition);
    final row = render.rowAtOffset(local.dy);
    final column = render.columnAtOffset(local.dx);
    if (row < 0 || column < 0 || row >= rows.length) return _clearTooltip();
    if (column >= columns.length) return _clearTooltip();

    if (columns[column].overflow != FitGridOverflow.tooltipOnTruncate ||
        !render.isTruncated(row, column)) {
      return _clearTooltip();
    }

    final current = _tooltip;
    if (current != null && current.row == row && current.column == column) {
      return;
    }

    final origin = render.localToGlobal(Offset.zero);
    final self = context.findRenderObject()! as RenderBox;
    final anchor = self.globalToLocal(
      origin +
          Offset(local.dx, render.rowOffsetAt(row) + render.rowHeightAt(row)) -
          Offset(0, render.verticalOffset),
    );

    setState(() {
      _tooltip = FitGridTooltipTarget(
        row: row,
        column: column,
        text: render.cellText(row, column),
        anchor: anchor,
      );
    });
  }

  void _clearTooltip() {
    if (_tooltip == null) return;
    setState(() => _tooltip = null);
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

  FitGridRowMetrics _resolveRowMetrics({
    required List<FitGridColumn<T>> columns,
    required List<T> rows,
    required FitGridColumnLayout layout,
    required FitGridThemeData theme,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final key = Object.hash(
      identityHashCode(columns),
      identityHashCode(rows),
      rows.length,
      layout,
      theme,
      widget.rowHeight,
      textDirection,
      textScaler,
    );
    final cached = _rowMetrics;
    if (cached != null && _rowMetricsKey == key) return cached;

    final metrics = _rowSizer.resolve(
      policy: widget.rowHeight,
      columns: columns,
      rows: rows,
      layout: layout,
      theme: theme,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    _rowMetrics = metrics;
    _rowMetricsKey = key;
    return metrics;
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
