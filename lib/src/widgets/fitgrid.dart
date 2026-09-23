import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../controller/fitgrid_controller.dart';
import '../controller/fitgrid_pagination.dart';
import '../model/column_width.dart';
import '../model/data_source.dart';
import '../model/enums.dart';
import '../model/fitgrid_column.dart';
import '../model/fitgrid_editor.dart';
import '../model/row_height.dart';
import '../model/rows_view.dart';
import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
import '../sizing/column_sizer.dart';
import '../sizing/row_metrics.dart';
import '../sizing/row_sizer.dart';
import '../theme/fitgrid_theme.dart';
import 'fitgrid_cell_editor.dart';
import 'fitgrid_footer.dart';
import 'fitgrid_header.dart';
import 'fitgrid_intents.dart';
import 'fitgrid_pager.dart';
import 'fitgrid_section.dart';
import 'fitgrid_tooltip.dart';

/// Where a context menu was asked for.
@immutable
class FitGridContextMenuTarget<T> {
  const FitGridContextMenuTarget({
    required this.row,
    required this.rowIndex,
    required this.columnId,
    required this.position,
    required this.selection,
  });

  /// The row under the pointer, or null if the pointer missed the rows.
  final T? row;

  /// Its index into the full row list, or -1.
  final int rowIndex;

  /// The column under the pointer, or null.
  final String? columnId;

  /// Where the menu was asked for, in global coordinates.
  final Offset position;

  /// The rows selected at the moment the menu opened, by global index.
  final Set<int> selection;
}

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
/// [FitGridController] when you want to drive sorting, selection, focus or
/// column visibility from outside; otherwise the grid keeps one to itself.
class FitGrid<T> extends StatefulWidget {
  const FitGrid({
    this.rows = const [],
    this.columns = const [],
    this.controller,
    this.dataSource,
    this.theme,
    this.rowHeight,
    this.striped = true,
    this.stretchColumnsToFill = true,
    this.showHeader = true,
    this.showFooter = true,
    this.resizableColumns = true,
    this.reorderableColumns = false,
    this.paginated = false,
    this.pageSize,
    this.pagerBuilder,
    this.overscanRows = 2,
    this.editTrigger = FitGridEditTrigger.doubleTap,
    this.selectionMode = FitGridSelectionMode.none,
    this.showSelectionColumn = false,
    this.onSelectionChanged,
    this.keyboardNavigation = true,
    this.autofocus = false,
    this.enableCopy = true,
    this.hoverHighlight = true,
    this.contextMenuBuilder,
    this.emptyState,
    this.loadingState,
    this.onRowTap,
    this.onCellTap,
    this.focusNode,
    super.key,
  }) : assert(
         dataSource == null || !paginated,
         'A data source pages itself; combining it with `paginated` would put '
         'two pagers on the same rows.',
       );

  /// The id of the built-in selection column. Reserved: do not give a column
  /// of your own this id.
  static const String selectionColumnId = '__fitgrid_selection';

  /// Rows to display. Ignored when [controller] or [dataSource] is supplied.
  final List<T> rows;

  /// Columns to display. Ignored when [controller] is supplied.
  final List<FitGridColumn<T>> columns;

  /// External state. When null the grid creates and disposes its own.
  final FitGridController<T>? controller;

  /// Rows fetched on demand rather than held in memory.
  ///
  /// With one attached the grid stops sorting and filtering for itself and
  /// forwards both to the source: reordering a fifty-row window out of a
  /// million would produce an order that changes as the user scrolls.
  final FitGridDataSource<T>? dataSource;

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

  /// Whether to show the aggregate row. It appears only when at least one
  /// column declares a [FitGridColumn.aggregate], so leaving this on costs
  /// nothing on a grid with no totals.
  final bool showFooter;

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

  /// Whether a header cell can be dragged onto another to move the column.
  /// Off by default: a grid whose column order carries meaning should not lose
  /// it to a stray drag.
  final bool reorderableColumns;

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

  /// Whether, and how many, rows the user may select.
  final FitGridSelectionMode selectionMode;

  /// Adds a pinned checkbox column at the leading edge.
  ///
  /// It is a painted column like any other — the checkbox is a glyph, not a
  /// `Checkbox` widget — so turning it on does not put a widget per row back
  /// into a grid that exists to avoid exactly that.
  final bool showSelectionColumn;

  /// Called whenever the selection changes, with global row indices.
  final void Function(Set<int> selection)? onSelectionChanged;

  /// Whether the grid takes focus and responds to the arrow keys, Home/End,
  /// Page Up/Down, Enter, Space, Ctrl+A and Ctrl+C.
  final bool keyboardNavigation;

  /// Whether the grid claims focus when it is first built.
  final bool autofocus;

  /// Whether Ctrl+C (Cmd+C) copies the selection to the clipboard as
  /// tab-separated text.
  final bool enableCopy;

  /// Whether the row under the pointer is highlighted. Painted, not built.
  final bool hoverHighlight;

  /// Builds the menu shown on a right-click or long-press. Returning null
  /// suppresses the menu for that target.
  final List<PopupMenuEntry<void>>? Function(
    BuildContext context,
    FitGridContextMenuTarget<T> target,
  )?
  contextMenuBuilder;

  /// Shown instead of the body when there are no rows.
  final Widget? emptyState;

  /// Shown over the body while a [dataSource] is fetching and has nothing yet.
  final Widget? loadingState;

  final void Function(T row, int rowIndex)? onRowTap;

  /// Called with the cell a tap landed on. Fires alongside [onRowTap].
  final void Function(T row, int rowIndex, String columnId)? onCellTap;

  /// The node the grid focuses. Supply one to move focus into the grid from
  /// elsewhere; otherwise it keeps its own.
  final FocusNode? focusNode;

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

  FocusNode? _ownedFocusNode;
  FocusNode get _focusNode =>
      widget.focusNode ??
      (_ownedFocusNode ??= FocusNode(debugLabel: 'FitGrid'));

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

  // The displayed column list, which may carry a synthesized selection column
  // in front of the real ones. Memoized because its identity is a cache key.
  List<FitGridColumn<T>>? _displayColumns;
  Object? _displayColumnsKey;

  FitGridTooltipTarget? _tooltip;

  FitGridRowsView<T>? _page;
  Object? _pageKey;

  int _hoveredRow = -1;

  /// Bumped whenever an attached data source notifies, so everything keyed on
  /// the row view re-derives when rows arrive.
  int _sourceRevision = 0;

  /// The last window the render object reported, used to tell a data source
  /// what to fetch and to decide which rows are available for measuring.
  (int, int) _window = (0, 0);

  Set<int> _lastReportedSelection = const <int>{};

  @override
  void initState() {
    super.initState();
    _syncOwnedController();
    _syncPagination();
    _controller.selection.addListener(_onSelectionChanged);
    _controller.attachViewport(_reveal);
    widget.dataSource?.addListener(_onSourceChanged);
    _lastReportedSelection = _controller.selection.selected;
  }

  @override
  void didUpdateWidget(FitGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.selection.removeListener(_onSelectionChanged);
      oldWidget.controller?.attachViewport(null);
      _controller.selection.addListener(_onSelectionChanged);
      _controller.attachViewport(_reveal);
    }
    if (widget.dataSource != oldWidget.dataSource) {
      oldWidget.dataSource?.removeListener(_onSourceChanged);
      widget.dataSource?.addListener(_onSourceChanged);
      _sourceRevision++;
    }
    if (widget.controller != oldWidget.controller ||
        !identical(widget.rows, oldWidget.rows) ||
        !identical(widget.columns, oldWidget.columns)) {
      _syncOwnedController();
      _layoutKey = null;
      _rowMetricsKey = null;
      _pageKey = null;
      _displayColumnsKey = null;
    }
    if (widget.selectionMode != oldWidget.selectionMode) {
      _controller.selection.mode = widget.selectionMode;
    }
    if (widget.paginated != oldWidget.paginated ||
        widget.pageSize != oldWidget.pageSize) {
      _syncPagination();
    }
    if (widget.showSelectionColumn != oldWidget.showSelectionColumn) {
      _displayColumnsKey = null;
    }
  }

  /// Keeps the internally-owned controller in step with the widget's own `rows`
  /// and `columns`. A caller-supplied controller is left alone — it is theirs.
  void _syncOwnedController() {
    final controller = _controller;
    controller.selection.mode = widget.selectionMode;
    if (widget.controller != null) return;
    if (!identical(controller.columns.columns, widget.columns)) {
      controller.columns.columns = widget.columns;
    }
    if (widget.dataSource == null) controller.data.rows = widget.rows;
  }

  /// Pushes the widget's paging preferences onto the controller, which is where
  /// the state actually lives so a host can drive it too.
  void _syncPagination() {
    final pagination = _controller.pagination;
    pagination.enabled = widget.paginated;
    if (widget.pageSize != null) pagination.pageSize = widget.pageSize!;
    pagination.rowCount = _controller.data.length;
  }

  void _onSourceChanged() {
    if (!mounted) return;
    setState(() => _sourceRevision++);
  }

  void _onSelectionChanged() {
    final callback = widget.onSelectionChanged;
    if (callback == null) return;
    final now = _controller.selection.selected;
    if (setEquals(now, _lastReportedSelection)) return;
    _lastReportedSelection = now;
    callback(now);
  }

  @override
  void dispose() {
    widget.dataSource?.removeListener(_onSourceChanged);
    _controller.selection.removeListener(_onSelectionChanged);
    _controller.attachViewport(null);
    _sizer.dispose();
    _rowSizer.dispose();
    _verticalController.dispose();
    _horizontalController.dispose();
    _ownedFocusNode?.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return ListenableBuilder(
      listenable: Listenable.merge(<Listenable?>[
        controller.data,
        controller.columns,
        controller.selection,
        controller.pagination,
        controller.editing,
        controller.focus,
        controller.filter,
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
    final source = widget.dataSource;

    final columns = _resolveColumns(theme);
    final rowsView = _resolveRows(source);

    // Widths are measured against everything available, never against the page
    // on screen — or columns would visibly jump every time the user turned one.
    final measurable = source == null ? controller.data.view : rowsView.loaded;

    final layout = _resolveLayout(
      columns: columns,
      rows: measurable,
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
      rows: rowsView,
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
          freeze: column.freeze,
          label: column.label,
        ),
    ];

    // Identity of the row list changes whenever the data or the sort changes,
    // which is exactly when painted text could be stale. The selection revision
    // and the search query join it because both change what a cell paints
    // without changing which rows are on screen.
    final specVersion = Object.hash(
      identityHashCode(rowsView.identity),
      identityHashCode(columns),
      theme,
      rowsView.length,
      controller.selection.revision,
      controller.filter.query,
      _sourceRevision,
    );

    final pageOffset = rowsView.offset;
    final filter = controller.filter;
    final selection = controller.selection;
    final blank = FitGridCellSpec(
      text: '',
      style: theme.cellTextStyle.copyWith(color: theme.placeholderForeground),
      alignment: FitGridAlignment.start,
      overflow: FitGridOverflow.clip,
    );

    FitGridCellSpec cellSpec(int rowIndex, int columnIndex) {
      final column = columns[columnIndex];
      final row = rowsView.rowAt(rowIndex);
      if (row == null) return blank;
      final globalRow = pageOffset + rowIndex;

      if (column.id == FitGrid.selectionColumnId) {
        final on = selection.contains(globalRow);
        return FitGridCellSpec(
          text: '',
          style: theme.cellTextStyle,
          alignment: FitGridAlignment.center,
          overflow: FitGridOverflow.clip,
          icon: on ? theme.checkboxCheckedIcon : theme.checkboxIcon,
          iconColor: on ? theme.focusOutline : theme.placeholderForeground,
          iconSize: theme.sortIconSize,
          semanticLabel: on ? 'Selected' : 'Not selected',
        );
      }

      final text = column.value(row);
      return FitGridCellSpec(
        text: text,
        style: column.cellStyle?.call(row, globalRow) ?? theme.cellTextStyle,
        alignment: column.alignment,
        overflow: column.overflow,
        maxLines: column.maxLines,
        icon: column.icon?.call(row, globalRow),
        iconColor: column.iconColor?.call(row, globalRow),
        semanticLabel: column.semanticValue?.call(row),
        // Matches are computed only for the columns the search actually looks
        // at, and only while there is a query — a grid with an empty search box
        // pays nothing for having one.
        highlights: column.searchable ? filter.matchesIn(text) : const <int>[],
      );
    }

    // Selection and taps speak in indices into the whole dataset, so they stay
    // meaningful when the user turns a page.
    Color? rowColor(int rowIndex) => selection.contains(pageOffset + rowIndex)
        ? theme.selectedBackground
        : null;

    final focusedCell = _focusedCellIn(columns, pageOffset, rowsView.length);

    final wantsTooltips = columns.any(
      (column) => column.overflow == FitGridOverflow.tooltipOnTruncate,
    );

    final editorChild = _buildEditor(
      context: context,
      columns: columns,
      rows: rowsView,
      theme: theme,
    );

    // The offsets only exist inside the viewport builders, so the section is a
    // closure rather than a value: everything above depends on the layout, and
    // the layout must be settled before the scrollables are built.
    FitGridSection buildSection(
      ViewportOffset vertical,
      ViewportOffset horizontal,
    ) => FitGridSection(
      key: _sectionKey,
      columnLayout: layout,
      paintColumns: paintColumns,
      cellSpec: cellSpec,
      specVersion: specVersion,
      theme: theme,
      rowMetrics: rowMetrics,
      vertical: vertical,
      horizontal: horizontal,
      rowColor: rowColor,
      isRowSelected: (row) => selection.contains(pageOffset + row),
      striped: widget.striped,
      overscanRows: widget.overscanRows,
      editingCell: _editingCellIn(
        columns,
        controller,
        pageOffset,
        rowsView.length,
      ),
      focusedCell: focusedCell,
      hoveredRow: widget.hoverHighlight ? _hoveredRow : -1,
      rowIndexOffset: pageOffset,
      onCellActivate: (row, column) =>
          _activateCell(pageOffset + row, columns[column], rowsView, row),
      children: <Widget>[?editorChild],
    );

    final body = rowsView.isEmpty
        ? (widget.emptyState ?? _defaultEmptyState(theme, source))
        : _wrapGestures(
            context: context,
            columns: columns,
            rows: rowsView,
            theme: theme,
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
                      buildSection(verticalOffset, horizontalOffset),
                ),
              ),
            ),
          );

    final hoverable = (wantsTooltips || widget.hoverHighlight)
        ? MouseRegion(
            onHover: (event) =>
                _onHover(event.position, columns, rowsView, wantsTooltips),
            onExit: (_) => _onHoverExit(),
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
              onSort: _sort,
              onResize: widget.resizableColumns
                  ? controller.columns.setWidth
                  : null,
              onAutoSize: widget.resizableColumns
                  ? controller.columns.autoSize
                  : null,
              onReorder: widget.reorderableColumns
                  ? controller.moveColumnBefore
                  : null,
            ),
          ),
        Expanded(child: hoverable),
        if (widget.showFooter && columns.any((c) => c.aggregate != null))
          ListenableBuilder(
            listenable: _horizontalController,
            builder: (context, _) => FitGridFooter<T>(
              columns: columns,
              layout: layout,
              theme: theme,
              horizontalOffset: _horizontalController.hasClients
                  ? _horizontalController.offset
                  : 0.0,
              rows: measurable,
            ),
          ),
        if (widget.paginated)
          widget.pagerBuilder?.call(context, controller.pagination) ??
              FitGridPager(pagination: controller.pagination, theme: theme),
      ],
    );

    final decorated = DecoratedBox(
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
            if (source != null && source.isLoading && rowsView.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: widget.showHeader ? theme.effectiveHeaderHeight : 0,
                child: LinearProgressIndicator(
                  minHeight: 2,
                  color: theme.focusOutline,
                  backgroundColor: Colors.transparent,
                ),
              ),
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

    if (source != null) _scheduleWindowLoad(source);
    if (!widget.keyboardNavigation) return decorated;

    return FocusableActionDetector(
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      shortcuts: kFitGridShortcuts,
      actions: _actions(columns, rowsView),
      child: decorated,
    );
  }

  // ------------------------------------------------------------- resolution

  /// The columns to display, with the selection checkbox in front when asked
  /// for.
  ///
  /// Synthesized here rather than pushed into the controller, because it is a
  /// presentation choice: a host reading `controller.columns` should see the
  /// columns it declared, not one the grid added behind its back.
  List<FitGridColumn<T>> _resolveColumns(FitGridThemeData theme) {
    final base = _controller.columns.visible;
    final key = Object.hash(
      identityHashCode(base),
      widget.showSelectionColumn,
      theme.selectionColumnWidth,
    );
    final cached = _displayColumns;
    if (cached != null && _displayColumnsKey == key) return cached;

    final resolved = widget.showSelectionColumn
        ? <FitGridColumn<T>>[_selectionColumn(theme), ...base]
        : base;
    _displayColumns = resolved;
    _displayColumnsKey = key;
    return resolved;
  }

  FitGridColumn<T> _selectionColumn(FitGridThemeData theme) => FitGridColumn<T>(
    id: FitGrid.selectionColumnId,
    label: '',
    value: (_) => '',
    width: FitGridColumnWidth.fixed(theme.selectionColumnWidth),
    alignment: FitGridAlignment.center,
    freeze: FitGridFreeze.start,
    resizable: false,
    reorderable: false,
    sortable: false,
    searchable: false,
    headerBuilder: (context) => _SelectAllBox(
      selection: _controller.selection,
      total: _controller.data.length,
      theme: theme,
      onChanged: _toggleSelectAll,
    ),
  );

  /// The rows on screen, whichever way they are supplied.
  FitGridRowsView<T> _resolveRows(FitGridDataSource<T>? source) {
    if (source != null) {
      final (first, last) = _window;
      final loaded = <T>[];
      for (var i = first; i < last && i < source.rowCount; i++) {
        final row = source.rowAt(i);
        if (row != null) loaded.add(row);
      }
      return FitGridRowsView<T>(
        length: source.rowCount,
        offset: 0,
        rowAt: source.rowAt,
        loaded: loaded,
        // The revision, not the source: the source is one long-lived object,
        // so its identity would never tell the caches that rows had arrived.
        identity: _SourceIdentity(source, _sourceRevision),
      );
    }
    return _pageOf(_controller.data.view, _controller.pagination);
  }

  /// Tells a data source what is on screen, once the frame that knows has been
  /// laid out.
  ///
  /// Reading the window during build would mean reading the *previous* frame's,
  /// and asking a source to fetch during build is how you get a rebuild inside
  /// a build. So it happens after.
  void _scheduleWindowLoad(FitGridDataSource<T> source) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final render = _sectionKey.currentContext?.findRenderObject();
      if (render is! RenderFitGridSection) return;
      final first = render.firstVisibleRow;
      final last = math.min(
        render.firstVisibleRow + render.visibleRowCount,
        render.rowCount,
      );
      if (_window == (first, last)) {
        source.loadWindow(first, math.max(first, last - 1));
        return;
      }
      _window = (first, last);
      source.loadWindow(first, math.max(first, last - 1));
      setState(() {});
    });
  }

  void _sort(String columnId) {
    final controller = _controller;
    controller.toggleSort(columnId);
    // A source sorts for itself; sorting a window would order page two
    // differently from page three.
    widget.dataSource?.sortBy(
      controller.data.sortColumnId,
      controller.data.sortDirection,
    );
  }

  // ------------------------------------------------------------- gestures

  Widget _wrapGestures({
    required BuildContext context,
    required List<FitGridColumn<T>> columns,
    required FitGridRowsView<T> rows,
    required FitGridThemeData theme,
    required Widget child,
  }) {
    final wantsTapEdit =
        widget.editTrigger == FitGridEditTrigger.singleTap &&
        columns.any((column) => column.isEditable);
    final wantsDoubleTapEdit =
        widget.editTrigger == FitGridEditTrigger.doubleTap &&
        columns.any((column) => column.isEditable);
    final wantsMenu = widget.contextMenuBuilder != null || widget.enableCopy;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onDoubleTapDown: wantsDoubleTapEdit
          ? (details) => _beginEdit(details.globalPosition, columns, rows)
          : null,
      onDoubleTap: wantsDoubleTapEdit ? () {} : null,
      onSecondaryTapDown: wantsMenu
          ? (details) =>
                _openMenu(context, details.globalPosition, columns, rows)
          : null,
      onLongPressStart: wantsMenu
          ? (details) =>
                _openMenu(context, details.globalPosition, columns, rows)
          : null,
      onTapDown: (details) => _handleTap(
        details.globalPosition,
        columns,
        rows,
        openEditor: wantsTapEdit,
      ),
      child: child,
    );
  }

  /// Turns a tap into a cell, without a gesture detector per row.
  ///
  /// A conventional table wraps every row in its own detector, which is another
  /// few hundred objects. Here the hit lands on the section and the cell is
  /// recovered from the coordinates — arithmetic when rows share a height, a
  /// binary search when they do not.
  void _handleTap(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows, {
    required bool openEditor,
  }) {
    final hit = _cellAt(globalPosition, columns, rows);
    if (hit == null) return;
    final (localRow, columnIndex) = hit;
    final row = rows.rowAt(localRow);
    if (row == null) return;
    final globalRow = rows.globalIndex(localRow);
    final column = columns[columnIndex];

    if (widget.keyboardNavigation) {
      _focusNode.requestFocus();
      _controller.focus.moveTo(globalRow, column.id);
    }

    final keys = HardwareKeyboard.instance;
    final toggleKey =
        keys.isControlPressed ||
        keys.isMetaPressed ||
        column.id == FitGrid.selectionColumnId;
    _controller.selection.applyGesture(
      globalRow,
      toggleKey: toggleKey,
      rangeKey: keys.isShiftPressed,
    );

    // The checkbox column is a selection control, not a cell: a tap on it
    // should not also open an editor or report a cell tap.
    if (column.id == FitGrid.selectionColumnId) return;

    if (openEditor) _beginEdit(globalPosition, columns, rows);
    widget.onRowTap?.call(row, globalRow);
    widget.onCellTap?.call(row, globalRow, column.id);
  }

  /// The cell under a global position, or null.
  (int, int)? _cellAt(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return null;
    final local = render.globalToLocal(globalPosition);
    final row = render.rowAtOffset(local.dy);
    final column = render.columnAtOffset(local.dx);
    if (row < 0 || row >= rows.length) return null;
    if (column < 0 || column >= columns.length) return null;
    return (row, column);
  }

  void _onHover(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
    bool wantsTooltips,
  ) {
    final hit = _cellAt(globalPosition, columns, rows);
    if (hit == null) return _onHoverExit();
    final (row, column) = hit;

    if (widget.hoverHighlight && _hoveredRow != row) {
      setState(() => _hoveredRow = row);
    }
    if (!wantsTooltips) return;
    _updateTooltip(globalPosition, columns, row, column);
  }

  void _onHoverExit() {
    if (_hoveredRow != -1) setState(() => _hoveredRow = -1);
    _clearTooltip();
  }

  Future<void> _openMenu(
    BuildContext context,
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) async {
    final hit = _cellAt(globalPosition, columns, rows);
    final localRow = hit?.$1 ?? -1;
    final row = localRow < 0 ? null : rows.rowAt(localRow);
    final globalRow = localRow < 0 ? -1 : rows.globalIndex(localRow);

    // Right-clicking outside the selection moves it, the way every file manager
    // does: otherwise "Copy" silently applies to rows the user cannot see.
    if (globalRow >= 0 && !_controller.selection.contains(globalRow)) {
      _controller.selection.applyGesture(globalRow);
    }

    final target = FitGridContextMenuTarget<T>(
      row: row,
      rowIndex: globalRow,
      columnId: hit == null ? null : columns[hit.$2].id,
      position: globalPosition,
      selection: _controller.selection.selected,
    );

    final items =
        widget.contextMenuBuilder?.call(context, target) ??
        <PopupMenuEntry<void>>[
          if (widget.enableCopy)
            PopupMenuItem<void>(
              onTap: () => _copy(columns, rows),
              child: const Text('Copy'),
            ),
        ];
    if (items.isEmpty || !context.mounted) return;

    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    await showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: items,
    );
  }

  // -------------------------------------------------------------- keyboard

  Map<Type, Action<Intent>> _actions(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) => <Type, Action<Intent>>{
    FitGridMoveIntent: CallbackAction<FitGridMoveIntent>(
      onInvoke: (intent) {
        _moveFocus(
          columns,
          rows,
          rowDelta: intent.rowDelta,
          columnDelta: intent.columnDelta,
          extend: intent.extend,
        );
        return null;
      },
    ),
    FitGridJumpIntent: CallbackAction<FitGridJumpIntent>(
      onInvoke: (intent) {
        _jumpFocus(columns, rows, intent);
        return null;
      },
    ),
    FitGridPageIntent: CallbackAction<FitGridPageIntent>(
      onInvoke: (intent) {
        _moveFocus(
          columns,
          rows,
          rowDelta: intent.direction * _viewportRows(),
          columnDelta: 0,
          extend: intent.extend,
        );
        return null;
      },
    ),
    FitGridActivateIntent: CallbackAction<FitGridActivateIntent>(
      onInvoke: (_) {
        final focus = _controller.focus;
        final columnIndex = _focusedColumnIndex(columns);
        if (focus.rowIndex == null || columnIndex < 0) return null;
        _activateCell(
          focus.rowIndex!,
          columns[columnIndex],
          rows,
          focus.rowIndex! - rows.offset,
        );
        return null;
      },
    ),
    FitGridToggleSelectionIntent: CallbackAction<FitGridToggleSelectionIntent>(
      onInvoke: (_) {
        final row = _controller.focus.rowIndex;
        if (row != null) {
          _controller.selection.applyGesture(row, toggleKey: true);
        }
        return null;
      },
    ),
    FitGridSelectAllIntent: CallbackAction<FitGridSelectAllIntent>(
      onInvoke: (_) {
        if (_controller.selection.mode != FitGridSelectionMode.multiple) {
          return null;
        }
        _controller.selection.select(
          List<int>.generate(_controller.data.length, (i) => i),
        );
        return null;
      },
    ),
    FitGridCopyIntent: CallbackAction<FitGridCopyIntent>(
      onInvoke: (_) {
        if (widget.enableCopy) _copy(columns, rows);
        return null;
      },
    ),
    FitGridDismissIntent: CallbackAction<FitGridDismissIntent>(
      onInvoke: (_) {
        if (_controller.editing.isEditing) {
          _controller.editing.cancel();
        } else {
          _controller.selection.clear();
        }
        return null;
      },
    ),
  };

  /// How many rows a Page Up or Page Down should travel.
  int _viewportRows() {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return 10;
    // One row of overlap, so the user keeps a line of context across the jump —
    // the same courtesy every text editor extends.
    return math.max(1, render.visibleRowCount - 2 * render.overscanRows - 1);
  }

  int _focusedColumnIndex(List<FitGridColumn<T>> columns) {
    final id = _controller.focus.columnId;
    if (id == null) return -1;
    return columns.indexWhere((column) => column.id == id);
  }

  void _moveFocus(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows, {
    required int rowDelta,
    required int columnDelta,
    required bool extend,
  }) {
    if (columns.isEmpty) return;
    final total = widget.dataSource?.rowCount ?? _controller.data.length;
    if (total == 0) return;

    final focus = _controller.focus;
    final currentRow = focus.rowIndex ?? rows.offset;
    var currentColumn = _focusedColumnIndex(columns);
    if (currentColumn < 0) currentColumn = 0;

    // In RTL the arrow keys still mean "the column to the left of this one" —
    // which, mirrored, is the next column along.
    final direction = Directionality.of(context) == TextDirection.rtl ? -1 : 1;
    final nextRow = (currentRow + rowDelta).clamp(0, total - 1);
    final nextColumn = (currentColumn + columnDelta * direction).clamp(
      0,
      columns.length - 1,
    );

    focus.moveTo(nextRow, columns[nextColumn].id);
    if (extend && _controller.selection.mode == FitGridSelectionMode.multiple) {
      _controller.selection.applyGesture(nextRow, rangeKey: true);
    }
    _controller.scrollTo(nextRow, columnId: columns[nextColumn].id);
  }

  void _jumpFocus(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
    FitGridJumpIntent intent,
  ) {
    if (columns.isEmpty) return;
    final total = widget.dataSource?.rowCount ?? _controller.data.length;
    if (total == 0) return;

    final focus = _controller.focus;
    var row = focus.rowIndex ?? rows.offset;
    var columnIndex = _focusedColumnIndex(columns);
    if (columnIndex < 0) columnIndex = 0;

    if (intent.toRowEdge) {
      row = intent.toStart ? 0 : total - 1;
    } else {
      columnIndex = intent.toStart ? 0 : columns.length - 1;
    }

    focus.moveTo(row, columns[columnIndex].id);
    if (intent.extend &&
        _controller.selection.mode == FitGridSelectionMode.multiple) {
      _controller.selection.applyGesture(row, rangeKey: true);
    }
    _controller.scrollTo(row, columnId: columns[columnIndex].id);
  }

  /// Enter, or a screen reader's activate: edit the cell if it can be edited,
  /// otherwise report it as a tap.
  void _activateCell(
    int globalRow,
    FitGridColumn<T> column,
    FitGridRowsView<T> rows,
    int localRow,
  ) {
    if (column.id == FitGrid.selectionColumnId) {
      _controller.selection.applyGesture(globalRow, toggleKey: true);
      return;
    }
    if (column.isEditable) {
      _controller.editing.begin(globalRow, column.id);
      return;
    }
    final row = rows.rowAt(localRow);
    if (row == null) return;
    widget.onRowTap?.call(row, globalRow);
    widget.onCellTap?.call(row, globalRow, column.id);
  }

  void _toggleSelectAll(bool selectAll) {
    if (selectAll) {
      _controller.selection.select(
        List<int>.generate(_controller.data.length, (i) => i),
      );
    } else {
      _controller.selection.clear();
    }
  }

  // ------------------------------------------------------------- clipboard

  /// Copies the selection — or the focused cell when nothing is selected — as
  /// tab-separated text.
  ///
  /// TSV rather than CSV because that is what a spreadsheet accepts on paste
  /// without an import dialog, and because a grid's job here is to get the
  /// numbers into the other window, not to define a file format.
  void _copy(List<FitGridColumn<T>> columns, FitGridRowsView<T> rows) {
    final copyable = <FitGridColumn<T>>[
      for (final column in columns)
        if (column.id != FitGrid.selectionColumnId) column,
    ];
    if (copyable.isEmpty) return;

    final selected = _controller.selection.sorted;
    final indices = selected.isNotEmpty
        ? selected
        : <int>[
            if (_controller.focus.rowIndex != null) _controller.focus.rowIndex!,
          ];
    if (indices.isEmpty) return;

    // A single focused cell copies that cell; a selection copies whole rows.
    // Anything else surprises somebody.
    final singleCell = selected.isEmpty;
    final focusedColumn = _focusedColumnIndex(columns);

    final buffer = StringBuffer();
    for (var i = 0; i < indices.length; i++) {
      if (i > 0) buffer.write('\n');
      final row = _rowForGlobalIndex(indices[i], rows);
      if (row == null) continue;
      if (singleCell && focusedColumn >= 0) {
        buffer.write(_escapeCell(columns[focusedColumn].copyTextFor(row)));
      } else {
        for (var c = 0; c < copyable.length; c++) {
          if (c > 0) buffer.write('\t');
          buffer.write(_escapeCell(copyable[c].copyTextFor(row)));
        }
      }
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  /// A tab or a newline inside a cell would otherwise become a column or a row
  /// on paste, silently shifting everything after it.
  static String _escapeCell(String value) {
    if (!value.contains('\t') && !value.contains('\n')) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  T? _rowForGlobalIndex(int index, FitGridRowsView<T> rows) {
    final source = widget.dataSource;
    if (source != null) return source.rowAt(index);
    final view = _controller.data.view;
    return index >= 0 && index < view.length ? view[index] : null;
  }

  // --------------------------------------------------------------- scroll

  /// Brings a cell into view. Wired to [FitGridController.scrollTo].
  void _reveal(int rowIndex, String? columnId, double padding) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return;

    final local = rowIndex - _resolveRows(widget.dataSource).offset;
    final columnIndex = columnId == null
        ? -1
        : render.columnLayout.indexOf(columnId);
    final (dy, dx) = render.revealOffsetsFor(
      local,
      columnIndex,
      padding: padding,
    );

    if (dy != null && _verticalController.hasClients) {
      _verticalController.jumpTo(dy);
    }
    if (dx != null && _horizontalController.hasClients) {
      _horizontalController.jumpTo(dx);
    }
  }

  // ---------------------------------------------------------------- editing

  /// The cell an editor covers, in this section's own indices, or (-1, -1).
  (int, int) _editingCellIn(
    List<FitGridColumn<T>> columns,
    FitGridController<T> controller,
    int pageOffset,
    int pageLength,
  ) {
    final editing = controller.editing;
    return _localCell(
      columns,
      editing.rowIndex,
      editing.columnId,
      pageOffset,
      pageLength,
    );
  }

  (int, int) _focusedCellIn(
    List<FitGridColumn<T>> columns,
    int pageOffset,
    int pageLength,
  ) {
    if (!widget.keyboardNavigation) return (-1, -1);
    final focus = _controller.focus;
    return _localCell(
      columns,
      focus.rowIndex,
      focus.columnId,
      pageOffset,
      pageLength,
    );
  }

  (int, int) _localCell(
    List<FitGridColumn<T>> columns,
    int? globalRow,
    String? columnId,
    int pageOffset,
    int pageLength,
  ) {
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
    required FitGridRowsView<T> rows,
    required FitGridThemeData theme,
  }) {
    final controller = _controller;
    final (localRow, columnIndex) = _editingCellIn(
      columns,
      controller,
      rows.offset,
      rows.length,
    );
    if (localRow < 0) return null;

    final column = columns[columnIndex];
    final editor = column.editor;
    if (editor == null) return null;

    final row = rows.rowAt(localRow);
    if (row == null) return null;
    final globalRow = rows.globalIndex(localRow);

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
        onNext: () => _editNext(columns, columnIndex, globalRow, rows),
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
    FitGridRowsView<T> rows,
  ) {
    for (var i = fromColumn + 1; i < columns.length; i++) {
      if (columns[i].isEditable) {
        return _controller.editing.begin(globalRow, columns[i].id);
      }
    }
    final nextLocal = globalRow - rows.offset + 1;
    if (nextLocal >= rows.length) return;
    for (final column in columns) {
      if (column.isEditable) {
        return _controller.editing.begin(
          rows.globalIndex(nextLocal),
          column.id,
        );
      }
    }
  }

  /// Turns a tap into an editor, if it landed on an editable cell.
  void _beginEdit(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final hit = _cellAt(globalPosition, columns, rows);
    if (hit == null) return;
    final (localRow, columnIndex) = hit;
    final globalRow = rows.globalIndex(localRow);
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

  // ---------------------------------------------------------------- paging

  /// The slice of [rows] currently on screen.
  ///
  /// Memoized on the source list, the page and the page size so the same view
  /// object comes back between builds: every downstream cache — the column
  /// layout, the row metrics, the painted cell specs — is keyed on its
  /// identity, and a fresh wrapper each build would throw all three away on
  /// every scroll frame.
  FitGridRowsView<T> _pageOf(List<T> rows, FitGridPaginationState pagination) {
    final key = Object.hash(
      identityHashCode(rows),
      widget.paginated && pagination.enabled,
      pagination.pageIndex,
      pagination.pageSize,
      rows.length,
    );
    final cached = _page;
    if (cached != null && _pageKey == key) return cached;

    final FitGridRowsView<T> view;
    if (!widget.paginated || !pagination.enabled) {
      view = FitGridRowsView<T>.of(rows);
    } else {
      final start = math.min(pagination.firstRowIndex, rows.length);
      final length = math.min(pagination.pageSize, rows.length - start);
      view = FitGridRowsView<T>(
        length: length,
        offset: start,
        rowAt: (index) =>
            index < 0 || index >= length ? null : rows[start + index],
        loaded: rows,
        identity: _PageIdentity(rows, start, length),
      );
    }
    _page = view;
    _pageKey = key;
    return view;
  }

  // --------------------------------------------------------------- tooltip

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
    int row,
    int column,
  ) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return _clearTooltip();

    if (columns[column].overflow != FitGridOverflow.tooltipOnTruncate ||
        !render.isTruncated(row, column)) {
      return _clearTooltip();
    }

    final current = _tooltip;
    if (current != null && current.row == row && current.column == column) {
      return;
    }

    final local = render.globalToLocal(globalPosition);
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

  // --------------------------------------------------------------- sizing

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
      rows.length,
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
    required FitGridRowsView<T> rows,
    required FitGridColumnLayout layout,
    required FitGridThemeData theme,
    required TextDirection textDirection,
    required TextScaler textScaler,
  }) {
    final key = Object.hash(
      identityHashCode(columns),
      rows.identity,
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

  Widget _defaultEmptyState(
    FitGridThemeData theme,
    FitGridDataSource<T>? source,
  ) {
    if (source != null && source.isLoading) {
      return widget.loadingState ??
          const Center(child: CircularProgressIndicator());
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(
          source?.error != null ? 'Could not load rows' : 'No rows',
          style: theme.cellTextStyle.copyWith(
            color: theme.placeholderForeground,
          ),
        ),
      ),
    );
  }
}

/// Cache key for a page of an in-memory list.
///
/// A record over the source list's identity and the window, so the same page
/// compares equal across builds while any change to either invalidates it.
@immutable
class _PageIdentity {
  const _PageIdentity(this.source, this.offset, this.length);

  final Object source;
  final int offset;
  final int length;

  @override
  bool operator ==(Object other) =>
      other is _PageIdentity &&
      identical(other.source, source) &&
      other.offset == offset &&
      other.length == length;

  @override
  int get hashCode => Object.hash(identityHashCode(source), offset, length);
}

/// Cache key for a data source's window. The revision is what moves; the source
/// itself is one long-lived object and would never signal anything.
@immutable
class _SourceIdentity {
  const _SourceIdentity(this.source, this.revision);

  final Object source;
  final int revision;

  @override
  bool operator ==(Object other) =>
      other is _SourceIdentity &&
      identical(other.source, source) &&
      other.revision == revision;

  @override
  int get hashCode => Object.hash(identityHashCode(source), revision);
}

/// The header checkbox of the built-in selection column.
class _SelectAllBox extends StatelessWidget {
  const _SelectAllBox({
    required this.selection,
    required this.total,
    required this.theme,
    required this.onChanged,
  });

  final FitGridSelectionState selection;
  final int total;
  final FitGridThemeData theme;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final all = total > 0 && selection.length >= total;
    final some = selection.isNotEmpty && !all;

    return Center(
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        iconSize: theme.sortIconSize,
        visualDensity: VisualDensity.compact,
        tooltip: all ? 'Clear selection' : 'Select all',
        onPressed: total == 0 ? null : () => onChanged(!all),
        icon: Icon(
          all
              ? theme.checkboxCheckedIcon
              : some
              ? theme.checkboxIndeterminateIcon
              : theme.checkboxIcon,
          color: selection.isEmpty
              ? theme.placeholderForeground
              : theme.focusOutline,
        ),
      ),
    );
  }
}
