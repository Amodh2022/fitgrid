import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../controller/fitgrid_controller.dart';
import '../controller/fitgrid_history.dart';
import '../controller/fitgrid_pagination.dart';
import '../controller/fitgrid_range.dart';
import '../export/fitgrid_export.dart';
import '../model/column_group.dart';
import '../model/column_width.dart';
import '../model/data_source.dart';
import '../model/enums.dart';
import '../model/fitgrid_column.dart';
import '../model/fill_series.dart';
import '../model/fitgrid_editor.dart';
import '../model/row_height.dart';
import '../model/row_model.dart';
import '../model/rows_view.dart';
import '../model/sort_key.dart';
import '../render/cell_spec.dart';
import '../render/render_fitgrid_section.dart';
import '../sizing/column_layout.dart';
import '../sizing/column_sizer.dart';
import '../sizing/row_metrics.dart';
import '../sizing/row_sizer.dart';
import '../theme/fitgrid_theme.dart';
import 'fitgrid_cell_editor.dart';
import 'fitgrid_column_chooser.dart';
import 'fitgrid_filter_dialog.dart';
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
    this.multiSort = true,
    this.showColumnMenu = false,
    this.columnGroups = const <FitGridColumnGroup>[],
    this.stickyGroupHeaders = true,
    this.reorderableRows = false,
    this.onRowReorder,
    this.onLoadMore,
    this.hasMoreRows = true,
    this.loadMoreThreshold = 10,
    this.loadingRowCount = 3,
    this.detailBuilder,
    this.detailRowHeight = 240.0,
    this.detailHeight,
    this.rowKey,
    this.columnMenuBuilder,
    this.paginated = false,
    this.pageSize,
    this.pagerBuilder,
    this.overscanRows = 2,
    this.editTrigger = FitGridEditTrigger.doubleTap,
    this.selectionMode,
    this.showSelectionColumn = false,
    this.onSelectionChanged,
    this.keyboardNavigation = true,
    this.autofocus = false,
    this.enableCopy = true,
    this.cellSelection = false,
    this.enablePaste = true,
    this.enableUndo = true,
    this.hoverHighlight = true,
    this.rowColor,
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
       ),
       assert(
         onLoadMore == null || (!paginated && dataSource == null),
         'onLoadMore grows the rows as the user scrolls; a pager or a data '
         'source already decides which rows are loaded.',
       );

  /// The id of the built-in selection column. Reserved: do not give a column
  /// of your own this id.
  static const String selectionColumnId = '__fitgrid_selection';

  /// The id of the built-in column that opens and closes detail panels.
  /// Reserved, like [selectionColumnId].
  static const String detailColumnId = '__fitgrid_detail';

  /// The id of the built-in drag-handle column of [reorderableRows].
  /// Reserved, like [selectionColumnId].
  static const String dragColumnId = '__fitgrid_drag';

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

  /// Whether Shift+click on a sortable header adds that column to the sort
  /// rather than replacing it. Each sorted header then shows its priority.
  ///
  /// The controller can always sort by several columns — see
  /// [FitGridController.setSort] — this only governs the gesture.
  final bool multiSort;

  /// Bands spanning several columns, drawn as a second header row above
  /// their columns' own headers — "Q1" over January to March.
  ///
  /// Membership is by column id, so a band follows its columns through a
  /// reorder, and splits into one band per run if its columns are separated.
  final List<FitGridColumnGroup> columnGroups;

  /// Whether a group's header stays pinned to the top while its rows scroll
  /// beneath it, with the headers of the groups around it stacked above, and
  /// the next group's header pushing it away.
  ///
  /// Tapping a pinned header collapses its group, as tapping it in place
  /// does. Painted, like the rows: pinning costs a few rectangles a frame.
  final bool stickyGroupHeaders;

  /// Adds a pinned drag-handle column: drag a row by its handle to move it,
  /// or press Alt+Up / Alt+Down on the focused row.
  ///
  /// Moving rows only means something when their order is the order they
  /// were given in, so dragging is off while the grid is sorted or grouped,
  /// and not available with a [dataSource]. The handles dim to say so.
  final bool reorderableRows;

  /// Called when the user moves a row, with its index before and after the
  /// move, both into the rows as displayed.
  ///
  /// When null, the grid moves the row in [FitGridController.data] itself.
  /// When set, the grid leaves the rows alone and the host reorders its own
  /// list — which a host passing [rows] must do, or the next rebuild would
  /// put them back.
  final void Function(int from, int to)? onRowReorder;

  /// Called when the user scrolls to within [loadMoreThreshold] rows of the
  /// end, to fetch the next batch — infinite scrolling.
  ///
  /// Append the new rows to the grid (or the controller) before the future
  /// completes. While it is outstanding, [loadingRowCount] skeleton rows are
  /// shown after the last row, and no second call is made. If it throws, no
  /// retry happens until the user scrolls again, so a failing endpoint is not
  /// hammered in a loop.
  ///
  /// Not for a [dataSource], which fetches its own windows, nor with
  /// [paginated].
  final Future<void> Function()? onLoadMore;

  /// Whether there is anything left for [onLoadMore] to fetch. Set it false
  /// once the last batch has arrived.
  final bool hasMoreRows;

  /// How close to the end, in rows, the user must scroll before [onLoadMore]
  /// is called.
  final int loadMoreThreshold;

  /// How many skeleton rows to show while [onLoadMore] is running.
  final int loadingRowCount;

  /// Builds the panel shown beneath a row when it is expanded — a nested grid,
  /// a form, a chart, anything.
  ///
  /// Setting it adds a pinned chevron column at the leading edge; tapping a
  /// row's chevron, or pressing Enter on it, opens and closes that row's
  /// panel. Which rows are open lives on [FitGridController.details], keyed
  /// by [rowKey].
  ///
  /// A panel is a real widget spanning the grid's full width. It is built
  /// only while its row is on screen, like a widget cell, and it takes no part
  /// in selection, editing, copy or export. Not available with a [dataSource].
  final Widget Function(BuildContext context, T row, int rowIndex)?
  detailBuilder;

  /// Height of a detail panel, when [detailHeight] does not say otherwise.
  final double detailRowHeight;

  /// Height of one row's detail panel. Null uses [detailRowHeight] for all.
  final double Function(T row, int rowIndex)? detailHeight;

  /// A stable identity for a row, for anything that must follow a row rather
  /// than an index — which detail panels are open, for one.
  ///
  /// Null uses the row object itself, which is right when rows are kept
  /// between rebuilds or compare by value, and wrong when every rebuild makes
  /// new row objects that do not: then return the row's id here.
  final Object Function(T row)? rowKey;

  /// Gives every header a menu button with the column's commands: sort,
  /// filter, pin, size to fit, hide, and the column chooser.
  ///
  /// Off by default so an existing grid does not grow a button it was not
  /// designed with.
  final bool showColumnMenu;

  /// Edits the column menu before it opens. Handed the built-in entries, so
  /// adding one item is a one-liner and removing one is a `where`; return an
  /// empty list to suppress the menu for that column.
  final List<PopupMenuEntry<void>> Function(
    BuildContext context,
    FitGridColumn<T> column,
    List<PopupMenuEntry<void>> defaults,
  )?
  columnMenuBuilder;

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
  ///
  /// Null leaves whatever the controller already holds, which matters when the
  /// controller is yours: a grid that pushed a default down here would clear a
  /// selection you had set before the first build.
  final FitGridSelectionMode? selectionMode;

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

  /// Whether the user can select a rectangle of cells — by dragging with the
  /// mouse, Shift+clicking, or Shift+arrow keys — as well as whole rows.
  ///
  /// A range copies as that rectangle, pastes into editable columns from its
  /// top-left cell, and Delete clears the editable cells in it. A handle on its
  /// corner fills neighbouring cells when dragged — continuing a series of
  /// numbers, repeating anything else (see [fitGridFillSeries]). The range
  /// lives on [FitGridController.range].
  final bool cellSelection;

  /// Whether Ctrl+V (Cmd+V) pastes tab-separated text into the grid, starting
  /// at the selected range or the focused cell. Only columns with an
  /// [FitGridColumn.editor] take values, each through its own validator and
  /// commit — the grid never writes to a row itself.
  final bool enablePaste;

  /// Whether Ctrl+Z (Cmd+Z) undoes the last edit and Ctrl+Shift+Z or Ctrl+Y
  /// redoes it. Typed edits, pastes and clears are each one step, recorded on
  /// [FitGridController.history] — which [FitGridController.undo] and
  /// [FitGridController.redo] also drive, for a toolbar button.
  ///
  /// Undo writes the old value back through the column's own commit, so the
  /// host's rows change exactly as they would for a typed edit. Not
  /// available with a [dataSource].
  final bool enableUndo;

  /// Whether the row under the pointer is highlighted. Painted, not built.
  final bool hoverHighlight;

  /// A background for a row, or null to follow the striping.
  ///
  /// Conditional formatting without a widget: the colour is handed to the paint
  /// pass, so flagging overdue rows in red costs a `drawRect` rather than a
  /// `Container` per row. The index is into the full row list.
  ///
  /// The selection colour wins where the two meet, because a selection the user
  /// made should not be hidden by a rule they wrote months ago.
  final Color? Function(T row, int rowIndex)? rowColor;

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

  /// The flattened display lines, when grouping or a tree is on. Memoized:
  /// flattening is O(rows) and a build happens on every scroll frame.
  List<FitGridDisplayRow<T>>? _display;
  Object? _displayKey;

  /// The display lines currently paged into view, and where the page starts
  /// in them — what the pinned headers are looked up in.
  List<FitGridDisplayRow<T>>? _pagedDisplay;
  int _pagedStart = 0;

  /// For each display line, the header of the group enclosing it (or -1), and
  /// for each header, the first line after its group. Computed once per
  /// flatten, so finding the pinned headers each frame is a few lookups rather
  /// than a walk back through the group.
  (Int32List, Int32List)? _groupIndex;
  Object? _groupIndexOf;

  /// The display lines with detail panels inserted. Memoized separately from
  /// [_display] so opening a panel does not re-flatten the grouping.
  List<FitGridDisplayRow<T>>? _detailed;
  Object? _detailedKey;

  /// Bumped whenever an attached data source notifies, so everything keyed on
  /// the row view re-derives when rows arrive.
  int _sourceRevision = 0;

  /// The last window the render object reported, used to tell a data source
  /// what to fetch and to decide which rows are available for measuring.
  (int, int) _window = (0, 0);

  Set<int> _lastReportedSelection = const <int>{};

  /// Whether an [FitGrid.onLoadMore] call is outstanding.
  bool _loadingMore = false;

  /// Set when the last [FitGrid.onLoadMore] failed; cleared by the next
  /// scroll, which is the only thing allowed to try again.
  bool _loadMoreFailed = false;

  FitGridRowsView<T>? _skeleton;
  Object? _skeletonKey;

  Map<String, (num, num)>? _visualRanges;
  Object? _visualRangesKey;

  @override
  void initState() {
    super.initState();
    _syncOwnedController();
    _syncPagination();
    _controller.selection.addListener(_onSelectionChanged);
    _controller.filter.addListener(_forwardFilters);
    _controller.attachViewport(_reveal);
    widget.dataSource?.addListener(_onSourceChanged);
    _lastReportedSelection = _controller.selection.selected;
    _verticalController.addListener(_onVerticalScroll);
  }

  @override
  void didUpdateWidget(FitGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.selection.removeListener(_onSelectionChanged);
      oldWidget.controller?.filter.removeListener(_forwardFilters);
      oldWidget.controller?.attachViewport(null);
      _controller.selection.addListener(_onSelectionChanged);
      _controller.filter.addListener(_forwardFilters);
      _controller.attachViewport(_reveal);
    }
    if (widget.dataSource != oldWidget.dataSource) {
      oldWidget.dataSource?.removeListener(_onSourceChanged);
      widget.dataSource?.addListener(_onSourceChanged);
      _sourceRevision++;
      _forwardFilters();
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
    if (widget.selectionMode != oldWidget.selectionMode &&
        widget.selectionMode != null) {
      _controller.selection.mode = widget.selectionMode!;
    }
    if (widget.paginated != oldWidget.paginated ||
        widget.pageSize != oldWidget.pageSize) {
      _syncPagination();
    }
    if (widget.showSelectionColumn != oldWidget.showSelectionColumn ||
        (widget.detailBuilder == null) != (oldWidget.detailBuilder == null)) {
      _displayColumnsKey = null;
    }
  }

  /// Keeps the internally-owned controller in step with the widget's own `rows`
  /// and `columns`. A caller-supplied controller is left alone — it is theirs.
  void _syncOwnedController() {
    final controller = _controller;
    if (widget.selectionMode != null) {
      controller.selection.mode = widget.selectionMode!;
    }
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

  bool _loadCheckScheduled = false;

  void _onVerticalScroll() {
    if (widget.onLoadMore == null) return;
    _loadMoreFailed = false;
    // After the frame, not now: the offset has moved but the section has not
    // laid out at it yet, so its window still describes where the user was.
    if (_loadCheckScheduled) return;
    _loadCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCheckScheduled = false;
      if (mounted) _maybeLoadMore();
    });
  }

  /// Calls [FitGrid.onLoadMore] when the window has reached the end.
  ///
  /// Asked after every build as well as on scroll, so a first batch too short
  /// to fill the viewport keeps loading until it does — otherwise there would
  /// be nothing to scroll, and so nothing to ask for more.
  void _maybeLoadMore() {
    final load = widget.onLoadMore;
    if (load == null || !widget.hasMoreRows || _loadingMore) return;
    if (_loadMoreFailed) return;
    final render = _sectionKey.currentContext?.findRenderObject();
    final int reached;
    final int total;
    if (render is RenderFitGridSection) {
      reached = render.firstVisibleRow + render.visibleRowCount;
      total = render.rowCount;
    } else {
      // No section means no rows yet: the first batch is what is missing.
      reached = 0;
      total = 0;
    }
    if (reached < total - widget.loadMoreThreshold) return;

    setState(() => _loadingMore = true);
    Future<void>.sync(
      load,
    ).catchError((Object _) => _loadMoreFailed = true).whenComplete(() {
      if (mounted) setState(() => _loadingMore = false);
    });
  }

  /// Hands the structured column filters to a data source, which filters for
  /// itself for the same reason it sorts for itself.
  void _forwardFilters() {
    widget.dataSource?.filterBy(_controller.filter.filtersJson);
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
    _controller.filter.removeListener(_forwardFilters);
    _controller.attachViewport(null);
    _sizer.dispose();
    _rowSizer.dispose();
    _verticalController
      ..removeListener(_onVerticalScroll)
      ..dispose();
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
        controller.grouping,
        controller.range,
        controller.details,
      ]),
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => _build(context, constraints),
      ),
    );
  }

  Widget _build(BuildContext context, BoxConstraints constraints) {
    final controller = _controller;
    final rowKey = widget.rowKey;
    controller.history.keyOf = rowKey == null
        ? _identityKey
        : (row) => rowKey(row as T);
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

    final canReorder = _canReorderRows;
    final visualRanges = _resolveVisualRanges(columns, measurable);
    final pinsHeaders =
        widget.stickyGroupHeaders &&
        controller.grouping.groups.isNotEmpty &&
        rowsView.displayAt != null;

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
      controller.details.revision,
      _loadingMore,
      canReorder,
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
      final line = rowsView.displayAt?.call(rowIndex);

      // A group header is one merged cell carrying a disclosure glyph. It is an
      // ordinary painted cell — the spanning and the indent are geometry, and
      // the chevron is a character — so grouping adds no widgets at all.
      if (line != null && line.isHeader) {
        if (columnIndex != 0) return blank;
        return FitGridCellSpec(
          text: line.label!,
          style: theme.groupHeaderTextStyle ?? theme.cellTextStyle,
          alignment: FitGridAlignment.start,
          overflow: FitGridOverflow.ellipsis,
          icon: line.expanded ? theme.expandedIcon : theme.collapsedIcon,
          iconColor: theme.headerForeground,
          iconSize: theme.sortIconSize,
          semanticLabel:
              '${line.label}, '
              '${line.expanded ? 'expanded' : 'collapsed'}',
        );
      }

      final row = rowsView.rowAt(rowIndex);
      // A row that exists but has not arrived — a data source mid-fetch, or a
      // skeleton row while more load — gets a placeholder bar. A detail panel
      // is covered by its widget and needs nothing.
      if (row == null) {
        return line != null && line.isDetail ? blank : FitGridCellSpec.loading;
      }
      final globalRow = rowsView.globalIndex(rowIndex);

      if (column.id == FitGrid.dragColumnId) {
        return FitGridCellSpec(
          text: '',
          style: theme.cellTextStyle,
          alignment: FitGridAlignment.center,
          overflow: FitGridOverflow.clip,
          icon: theme.rowDragHandleIcon,
          iconColor: canReorder
              ? theme.sortIconColor
              : theme.placeholderForeground.withValues(alpha: 0.3),
          iconSize: theme.sortIconSize,
          semanticLabel: canReorder
              ? 'Drag to move, or press Alt and an arrow key'
              : 'Row order is fixed while sorted or grouped',
        );
      }

      if (column.id == FitGrid.detailColumnId) {
        final open = _controller.details.isExpanded(_detailKey(row));
        return FitGridCellSpec(
          text: '',
          style: theme.cellTextStyle,
          alignment: FitGridAlignment.center,
          overflow: FitGridOverflow.clip,
          icon: open ? theme.expandedIcon : theme.collapsedIcon,
          iconColor: theme.headerForeground,
          iconSize: theme.sortIconSize,
          semanticLabel: open ? 'Details shown' : 'Details hidden',
        );
      }

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

      final visual = column.visual;
      final text = visual == null || visual.showText ? column.value(row) : '';
      final disclosure = columnIndex == 0 && (line?.expandable ?? false)
          ? (line!.expanded ? theme.expandedIcon : theme.collapsedIcon)
          : null;
      return FitGridCellSpec(
        text: text,
        style: column.cellStyle?.call(row, globalRow) ?? theme.cellTextStyle,
        alignment: column.alignment,
        overflow: column.overflow,
        maxLines: column.maxLines,
        icon: disclosure ?? column.icon?.call(row, globalRow),
        iconColor: disclosure != null
            ? theme.headerForeground
            : column.iconColor?.call(row, globalRow),
        // A chart with its text hidden still says its value to a screen
        // reader.
        semanticLabel:
            column.semanticValue?.call(row) ??
            (text.isEmpty && visual != null ? column.value(row) : null),
        visual: visual?.resolve(row, visualRanges[column.id]),
        // Matches are computed only for the columns the search actually looks
        // at, and only while there is a query — a grid with an empty search box
        // pays nothing for having one.
        highlights: column.searchable ? filter.matchesIn(text) : const <int>[],
      );
    }

    // Selection and taps speak in indices into the whole dataset, so they stay
    // meaningful when the user turns a page.
    Color? resolveRowColor(int rowIndex) {
      if (rowsView.isHeader(rowIndex)) return theme.groupHeaderBackground;
      if (rowsView.isDetail(rowIndex)) return theme.effectiveDetailBackground;
      final global = rowsView.globalIndex(rowIndex);
      if (selection.contains(global)) return theme.selectedBackground;
      final row = rowsView.rowAt(rowIndex);
      return row == null ? null : widget.rowColor?.call(row, global);
    }

    final focusedCell = _focusedCellIn(columns, rowsView);

    final wantsTooltips = columns.any(
      (column) => column.overflow == FitGridOverflow.tooltipOnTruncate,
    );

    final editorChild = _buildEditor(
      context: context,
      columns: columns,
      rows: rowsView,
      theme: theme,
    );

    // Widget cells: real widgets for the columns that asked for them, built by
    // the section during layout for the rows on screen only. Each gets the
    // same padding a painted cell does, so it lines up with the text beside it.
    final widgetColumns = <int>[
      for (var i = 0; i < columns.length; i++)
        if (columns[i].cellBuilder != null) i,
    ];
    final cellPadding = theme.effectiveCellPadding;
    Widget? buildCell(int localRow, int columnIndex) {
      if (rowsView.isControl(localRow)) return null;
      final row = rowsView.rowAt(localRow);
      if (row == null) return null;
      final global = rowsView.globalIndex(localRow);
      final column = columns[columnIndex];
      final builder = column.cellBuilder!;
      return Padding(
        padding: cellPadding,
        child: Align(
          alignment: switch (column.alignment) {
            FitGridAlignment.start => AlignmentDirectional.centerStart,
            FitGridAlignment.center => AlignmentDirectional.center,
            FitGridAlignment.end => AlignmentDirectional.centerEnd,
          },
          // A Builder, so the cell's own element is the context: a widget that
          // reads Theme.of rebuilds itself, not the grid.
          child: Builder(builder: (context) => builder(context, row, global)),
        ),
      );
    }

    // Detail panels: one full-width widget per open row on screen.
    Widget? buildDetail(int localRow) {
      final line = rowsView.displayAt?.call(localRow);
      if (line == null || !line.isDetail) return null;
      final owner = line.detailOf as T;
      final ownerIndex = line.ownerIndex!;
      return ColoredBox(
        color: theme.effectiveDetailBackground,
        child: Builder(
          builder: (context) =>
              widget.detailBuilder!(context, owner, ownerIndex),
        ),
      );
    }

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
      rowColor: resolveRowColor,
      isRowSelected: (row) => selection.contains(rowsView.globalIndex(row)),
      striped: widget.striped,
      overscanRows: widget.overscanRows,
      editingCell: _editingCellIn(columns, controller, rowsView),
      selectedRange: _localRange(columns, rowsView),
      focusedCell: focusedCell,
      hoveredRow: _rowDragFrom != null
          ? rowsView.localIndex(_rowDragFrom!)
          : widget.hoverHighlight
          ? _hoveredRow
          : -1,
      dropLine: _rowDropLine,
      fillHandleCell: _fillHandleCell(columns, rowsView),
      fillPreview: _fillPreviewRange(columns, rowsView),
      rowIndexOffset: pageOffset,
      cellSpan: rowsView.displayAt == null
          ? null
          : (row, column) =>
                column == 0 && rowsView.isHeader(row) ? columns.length : 1,
      rowIndent: rowsView.displayAt == null
          ? null
          : (row) =>
                (rowsView.displayAt!(row)?.depth ?? 0) * theme.nestingIndent,
      onCellActivate: (row, column) => _activateCell(
        rowsView.globalIndex(row),
        columns[column],
        rowsView,
        row,
      ),
      cellBuilder: widgetColumns.isEmpty ? null : buildCell,
      widgetColumns: widgetColumns,
      rowBuilder: _detailsEnabled ? buildDetail : null,
      isFullRow: rowsView.displayAt == null ? null : rowsView.isDetail,
      stickyChain: pinsHeaders ? _stickyChain : null,
      groupEnd: pinsHeaders ? _groupEndOf : null,
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
              sortKeys: controller.data.sortKeys,
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
              onColumnMenu: widget.showColumnMenu
                  ? (id, anchor) => _openColumnMenu(anchor, id)
                  : null,
              activeFilters: controller.filter.filteredColumnIds,
              columnGroups: widget.columnGroups,
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
                top: widget.showHeader
                    ? FitGridHeader.heightFor(theme, widget.columnGroups)
                    : 0,
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
    if (widget.onLoadMore != null && !_loadingMore) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _maybeLoadMore();
      });
    }
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
    final showDetails = _detailsEnabled;
    final showDrag = widget.reorderableRows && widget.dataSource == null;
    final key = Object.hash(
      identityHashCode(base),
      widget.showSelectionColumn,
      showDetails,
      showDrag,
      theme.selectionColumnWidth,
      theme.rowDragHandleWidth,
    );
    final cached = _displayColumns;
    if (cached != null && _displayColumnsKey == key) return cached;

    final resolved = widget.showSelectionColumn || showDetails || showDrag
        ? <FitGridColumn<T>>[
            if (showDrag) _dragColumn(theme),
            if (widget.showSelectionColumn) _selectionColumn(theme),
            if (showDetails) _detailColumn(theme),
            ...base,
          ]
        : base;
    _displayColumns = resolved;
    _displayColumnsKey = key;
    return resolved;
  }

  /// Whether rows can open a detail panel here.
  bool get _detailsEnabled =>
      widget.detailBuilder != null && widget.dataSource == null;

  /// The key a row's detail panel is filed under.
  Object _detailKey(T row) => widget.rowKey?.call(row) ?? row as Object;

  static bool _isSyntheticId(String id) => id.startsWith('__fitgrid');

  /// Whether a column is one the grid added — the selection checkbox, the
  /// detail chevron — rather than one of the host's. Such columns are
  /// controls, not data: they are never copied, pasted into or selected.
  static bool _isSynthetic(FitGridColumn<Object?> column) =>
      _isSyntheticId(column.id);

  FitGridColumn<T> _dragColumn(FitGridThemeData theme) => FitGridColumn<T>(
    id: FitGrid.dragColumnId,
    label: '',
    value: (_) => '',
    width: FitGridColumnWidth.fixed(theme.rowDragHandleWidth),
    alignment: FitGridAlignment.center,
    freeze: FitGridFreeze.start,
    resizable: false,
    reorderable: false,
    sortable: false,
    searchable: false,
    hideable: false,
  );

  /// Whether rows can be moved right now: they must be in the order they were
  /// given in, which a sort or a grouping has replaced with an order of its
  /// own.
  bool get _canReorderRows =>
      widget.reorderableRows &&
      widget.dataSource == null &&
      _controller.data.sortKeys.isEmpty &&
      !_controller.grouping.isActive;

  FitGridColumn<T> _detailColumn(FitGridThemeData theme) => FitGridColumn<T>(
    id: FitGrid.detailColumnId,
    label: '',
    value: (_) => '',
    width: FitGridColumnWidth.fixed(theme.selectionColumnWidth),
    alignment: FitGridAlignment.center,
    freeze: FitGridFreeze.start,
    resizable: false,
    reorderable: false,
    sortable: false,
    searchable: false,
    hideable: false,
  );

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
    final rows = _controller.data.view;
    final display = _withDetails(rows, _resolveDisplay(rows));
    final view = display == null
        ? _pageOf(rows, _controller.pagination)
        : _viewOfDisplay(rows, display, _controller.pagination);
    return _loadingMore && widget.loadingRowCount > 0
        ? _withSkeleton(view)
        : view;
  }

  /// [base] with [FitGrid.loadingRowCount] skeleton rows after its end.
  ///
  /// The extra rows exist in the geometry and nowhere else: they have no row,
  /// no index, and paint as placeholder bars.
  FitGridRowsView<T> _withSkeleton(FitGridRowsView<T> base) {
    final extra = widget.loadingRowCount;
    final key = Object.hash(base.identity, base.length, extra);
    final cached = _skeleton;
    if (cached != null && _skeletonKey == key) return cached;
    final length = base.length + extra;
    final view = FitGridRowsView<T>(
      length: length,
      offset: base.offset,
      rowAt: (i) => i < base.length ? base.rowAt(i) : null,
      displayAt: base.displayAt == null
          ? null
          : (i) => i < base.length ? base.displayAt!(i) : null,
      globalIndexOf: (i) => i < base.length ? base.globalIndex(i) : -1,
      localIndexOf: base.localIndex,
      loaded: base.loaded,
      identity: _SkeletonIdentity(base.identity, extra),
    );
    _skeleton = view;
    _skeletonKey = key;
    return view;
  }

  /// A rows view over flattened display lines.
  ///
  /// Grouping folds collapsed rows out from between the visible ones, so the
  /// mapping between "line 4 on screen" and "row 4 of the data" stops being
  /// arithmetic. Both directions are looked up here, once, so that selection,
  /// editing, focus and copy keep speaking in indices into the full row list
  /// exactly as they do on a flat grid.
  FitGridRowsView<T> _viewOfDisplay(
    List<T> rows,
    List<FitGridDisplayRow<T>> display,
    FitGridPaginationState pagination,
  ) {
    final paged = widget.paginated && pagination.enabled;
    final start = paged
        ? math.min(pagination.firstRowIndex, display.length)
        : 0;
    final length = paged
        ? math.min(pagination.pageSize, display.length - start)
        : display.length;

    _pagedDisplay = display;
    _pagedStart = start;

    final sourceToLocal = <int, int>{};
    for (var i = 0; i < length; i++) {
      final line = display[start + i];
      if (line.isData) sourceToLocal[line.sourceIndex] = i;
    }

    return FitGridRowsView<T>(
      length: length,
      offset: start,
      rowAt: (index) =>
          index < 0 || index >= length ? null : display[start + index].row,
      displayAt: (index) =>
          index < 0 || index >= length ? null : display[start + index],
      globalIndexOf: (index) => index < 0 || index >= length
          ? -1
          : display[start + index].sourceIndex,
      localIndexOf: (global) => sourceToLocal[global] ?? -1,
      loaded: rows,
      identity: _PageIdentity(display, start, length),
    );
  }

  (Int32List, Int32List) _indexGroups(List<FitGridDisplayRow<T>> display) {
    final cached = _groupIndex;
    if (cached != null && identical(_groupIndexOf, display)) return cached;
    final enclosing = Int32List(display.length)
      ..fillRange(0, display.length, -1);
    final end = Int32List(display.length)..fillRange(0, display.length, -1);
    final open = <int>[];
    for (var i = 0; i < display.length; i++) {
      final line = display[i];
      // A group runs until the next line at its own depth or shallower: every
      // open header that deep or deeper ends here. Rows sit deeper than every
      // header above them, so only a header ever closes a group.
      while (open.isNotEmpty && display[open.last].depth >= line.depth) {
        end[open.removeLast()] = i;
      }
      enclosing[i] = open.isEmpty ? -1 : open.last;
      if (line.isHeader) open.add(i);
    }
    for (final header in open) {
      end[header] = display.length;
    }
    final index = (enclosing, end);
    _groupIndex = index;
    _groupIndexOf = display;
    return index;
  }

  /// The headers to pin while local line [first] is at the top, outermost
  /// first. Headers on an earlier page are left out: they are not in this
  /// section to paint.
  List<int> _stickyChain(int first) {
    final display = _pagedDisplay;
    if (display == null) return const <int>[];
    final (enclosing, _) = _indexGroups(display);
    final at = first + _pagedStart;
    if (at < 0 || at >= display.length) return const <int>[];
    var header = display[at].isHeader ? at : enclosing[at];
    final chain = <int>[];
    while (header >= 0) {
      if (header >= _pagedStart) chain.add(header - _pagedStart);
      header = enclosing[header];
    }
    return chain.reversed.toList();
  }

  int _groupEndOf(int header) {
    final display = _pagedDisplay;
    if (display == null) return header + 1;
    final (_, end) = _indexGroups(display);
    final at = header + _pagedStart;
    if (at < 0 || at >= display.length) return header + 1;
    return end[at] - _pagedStart;
  }

  /// The display lines for the current rows, flattened through the grouping or
  /// the tree.
  ///
  /// Returns null when neither is on, which is the signal for the rest of the
  /// grid to take the plain path — a flat list should not pay for a feature it
  /// is not using.
  List<FitGridDisplayRow<T>>? _resolveDisplay(List<T> rows) {
    final grouping = _controller.grouping;
    if (!grouping.isActive) {
      _display = null;
      _displayKey = null;
      return null;
    }

    final key = Object.hash(
      identityHashCode(rows),
      rows.length,
      identityHashCode(grouping.groups),
      identityHashCode(grouping.tree),
      grouping.expansionRevision,
    );
    final cached = _display;
    if (cached != null && _displayKey == key) return cached;

    final tree = grouping.tree;
    final lines = tree != null
        ? flattenTree<T>(
            rows: rows,
            tree: tree,
            isExpanded: grouping.isExpanded,
            keyOf: (row) => identityHashCode(row),
          )
        : flattenGroups<T>(
            rows: rows,
            groups: grouping.groups,
            isExpanded: grouping.isExpanded,
          );
    _display = lines;
    _displayKey = key;
    return lines;
  }

  /// The display lines with a detail panel after every open row, or [display]
  /// untouched when no panel is open.
  ///
  /// A flat grid with a panel open takes the display-line path for as long as
  /// one is open, because that is what lets a line on screen be something
  /// other than a row. Closing the last one puts it back on the plain path.
  List<FitGridDisplayRow<T>>? _withDetails(
    List<T> rows,
    List<FitGridDisplayRow<T>>? display,
  ) {
    final details = _controller.details;
    if (!_detailsEnabled || details.isEmpty) {
      _detailed = null;
      _detailedKey = null;
      return display;
    }
    final key = Object.hash(
      identityHashCode(display ?? rows),
      rows.length,
      details.revision,
      widget.rowKey,
    );
    final cached = _detailed;
    if (cached != null && _detailedKey == key) return cached;

    final base =
        display ??
        flattenGroups<T>(rows: rows, groups: const [], isExpanded: (_) => true);
    final lines = insertDetails<T>(
      base,
      (row) => details.isExpanded(_detailKey(row)),
    );
    _detailed = lines;
    _detailedKey = key;
    return lines;
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
      if (render is! RenderFitGridSection) {
        // No section means no rows known yet: a source that starts at zero,
        // or one a search has just reset. There is no window to report, but
        // without asking for the first page it would never learn otherwise.
        if (source.rowCount == 0) source.loadWindow(0, 0);
        return;
      }
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
    // Shift+click adds the column to the sort instead of replacing it — the
    // convention every spreadsheet and desktop table shares.
    controller.toggleSort(
      columnId,
      additive: widget.multiSort && HardwareKeyboard.instance.isShiftPressed,
    );
    // A source sorts for itself; sorting a window would order page two
    // differently from page three.
    widget.dataSource?.sortByKeys(controller.data.sortKeys);
  }

  /// The built-in column menu, anchored under the button that asked for it.
  Future<void> _openColumnMenu(BuildContext anchor, String columnId) async {
    final controller = _controller;
    final column = controller.columns.byId(columnId);
    if (column == null) return;
    final theme = widget.theme ?? FitGridTheme.of(context);
    final direction = controller.data.directionOf(columnId);
    final visibleCount = controller.columns.visible.length;

    PopupMenuItem<void> item(
      String label,
      IconData? icon,
      VoidCallback? onTap,
    ) => PopupMenuItem<void>(
      enabled: onTap != null,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 28,
            child: icon == null ? null : Icon(icon, size: theme.sortIconSize),
          ),
          Flexible(child: Text(label)),
        ],
      ),
    );

    void sortTo(FitGridSortDirection to) {
      controller.setSort(
        to == FitGridSortDirection.none
            ? const <FitGridSortKey>[]
            : <FitGridSortKey>[FitGridSortKey(columnId, to)],
      );
      widget.dataSource?.sortByKeys(controller.data.sortKeys);
    }

    final defaults = <PopupMenuEntry<void>>[
      if (column.sortable) ...<PopupMenuEntry<void>>[
        item(
          'Sort ascending',
          theme.sortAscendingIcon,
          direction == FitGridSortDirection.ascending
              ? null
              : () => sortTo(FitGridSortDirection.ascending),
        ),
        item(
          'Sort descending',
          theme.sortDescendingIcon,
          direction == FitGridSortDirection.descending
              ? null
              : () => sortTo(FitGridSortDirection.descending),
        ),
        if (controller.data.sortKeys.isNotEmpty)
          item('Clear sort', null, () => sortTo(FitGridSortDirection.none)),
        const PopupMenuDivider(),
      ],
      ..._filterMenuItems(column, theme, item),
      if (column.freeze != FitGridFreeze.start)
        item(
          'Pin to start',
          null,
          () => controller.columns.setFreeze(columnId, FitGridFreeze.start),
        ),
      if (column.freeze != FitGridFreeze.end)
        item(
          'Pin to end',
          null,
          () => controller.columns.setFreeze(columnId, FitGridFreeze.end),
        ),
      if (column.freeze != FitGridFreeze.none)
        item(
          'Unpin',
          null,
          () => controller.columns.setFreeze(columnId, FitGridFreeze.none),
        ),
      if (widget.resizableColumns && column.resizable)
        item('Size to fit', null, () => controller.columns.autoSize(columnId)),
      const PopupMenuDivider(),
      if (column.hideable)
        item(
          'Hide column',
          null,
          visibleCount <= 1
              ? null
              : () => controller.columns.setVisible(columnId, false),
        ),
      item(
        'Columns…',
        Icons.view_column_outlined,
        // After the menu has closed: a dialog pushed from inside a menu item's
        // tap would be popped again by the menu's own route.
        () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) showFitGridColumnDialog<T>(context, controller);
        }),
      ),
    ];

    final entries =
        widget.columnMenuBuilder?.call(context, column, defaults) ?? defaults;
    if (entries.isEmpty || !anchor.mounted) return;

    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(
      Offset(0, box.size.height),
      ancestor: overlay,
    );
    await showMenu<void>(
      context: anchor,
      position: RelativeRect.fromRect(
        origin & box.size,
        Offset.zero & overlay.size,
      ),
      items: entries,
    );
  }

  /// The column menu's filter entries, for a column with a filter spec.
  List<PopupMenuEntry<void>> _filterMenuItems(
    FitGridColumn<T> column,
    FitGridThemeData theme,
    PopupMenuItem<void> Function(String, IconData?, VoidCallback?) item,
  ) {
    if (column.filter == null) return const <PopupMenuEntry<void>>[];
    final filter = _controller.filter;
    final active = filter.filters.containsKey(column.id);
    return <PopupMenuEntry<void>>[
      item(
        'Filter…',
        active ? theme.filterActiveIcon : theme.filterIcon,
        // After the menu has closed, for the same reason as "Columns…".
        () => WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            showFitGridFilterDialog<T>(context, _controller, column.id);
          }
        }),
      ),
      if (active)
        item('Clear filter', null, () => filter.setFilter(column.id, null)),
      const PopupMenuDivider(),
    ];
  }

  // ------------------------------------------------------------- gestures

  Widget _wrapGestures({
    required BuildContext context,
    required List<FitGridColumn<T>> columns,
    required FitGridRowsView<T> rows,
    required FitGridThemeData theme,
    required Widget child,
  }) {
    final gestures = _wrapTapGestures(
      context: context,
      columns: columns,
      rows: rows,
      child: child,
    );
    final dragsRows = widget.reorderableRows && widget.dataSource == null;
    if (!dragsRows && !widget.cellSelection) return gestures;
    return RawGestureDetector(
      gestures: <Type, GestureRecognizerFactory>{
        if (widget.cellSelection)
          _FillDragRecognizer:
              GestureRecognizerFactoryWithHandlers<_FillDragRecognizer>(
                () => _FillDragRecognizer(),
                (recognizer) => recognizer
                  ..claims = ((position) => _fillStart(position))
                  ..onUpdate = ((position) =>
                      _fillUpdate(position, columns, rows))
                  ..onEnd = (() => _fillEnd(columns, rows))
                  ..onCancel = _fillCancel,
              ),
        if (dragsRows)
          _RowDragRecognizer:
              GestureRecognizerFactoryWithHandlers<_RowDragRecognizer>(
                () => _RowDragRecognizer(),
                (recognizer) => recognizer
                  ..claims = ((position) =>
                      _rowDragStart(position, columns, rows))
                  ..onUpdate = ((position) => _rowDragUpdate(position, rows))
                  ..onEnd = (() => _rowDragEnd(rows))
                  ..onCancel = _rowDragCancel,
              ),
      },
      child: gestures,
    );
  }

  Widget _wrapTapGestures({
    required BuildContext context,
    required List<FitGridColumn<T>> columns,
    required FitGridRowsView<T> rows,
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
      child: widget.cellSelection
          ? Listener(
              onPointerDown: (event) => _rangeDragStart(event, columns, rows),
              onPointerMove: (event) => _rangeDragUpdate(event, columns, rows),
              onPointerUp: (_) => _rangeDragPointer = null,
              onPointerCancel: (_) => _rangeDragPointer = null,
              child: child,
            )
          : child,
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
    if (columns[columnIndex].cellBuilder != null &&
        _cellWidgetClaims(globalPosition)) {
      return;
    }

    // A group header is a control, not a row: it opens and closes, and it
    // takes no part in the selection or in the tap callbacks.
    final line = rows.displayAt?.call(localRow);
    if (line != null && line.isHeader) {
      _controller.grouping.toggle(line.groupKey!);
      return;
    }

    final row = rows.rowAt(localRow);
    if (row == null) return;
    final globalRow = rows.globalIndex(localRow);
    final column = columns[columnIndex];

    // The disclosure triangle of a tree parent is in the leading inset of the
    // first cell. Hitting it expands rather than selects.
    if (line != null && line.expandable && columnIndex == 0) {
      final render = _sectionKey.currentContext?.findRenderObject();
      if (render is RenderFitGridSection) {
        final local = render.globalToLocal(globalPosition);
        if (render.isWithinDisclosure(localRow, local.dx)) {
          _controller.grouping.toggle(line.groupKey!);
          return;
        }
      }
    }

    if (widget.keyboardNavigation) {
      _focusNode.requestFocus();
      _controller.focus.moveTo(globalRow, column.id);
    }

    // The chevron opens and closes the row's panel, and does nothing else: it
    // is a control, like the checkbox, not a cell.
    if (column.id == FitGrid.detailColumnId) {
      _controller.details.toggle(_detailKey(row));
      return;
    }

    final keys = HardwareKeyboard.instance;
    final toggleKey =
        keys.isControlPressed ||
        keys.isMetaPressed ||
        column.id == FitGrid.selectionColumnId;

    // Shift+click under cell selection extends the block of cells, and only
    // that: extending the row selection as well would select whole rows the
    // user only meant to take a few cells from.
    final extendsRange =
        widget.cellSelection && keys.isShiftPressed && !_isSynthetic(column);
    if (widget.cellSelection && !_isSynthetic(column)) {
      if (extendsRange) {
        _controller.range.extendTo(globalRow, column.id);
      } else {
        _controller.range.select(globalRow, column.id);
      }
    }
    if (!extendsRange) {
      _controller.selection.applyGesture(
        globalRow,
        toggleKey: toggleKey,
        rangeKey: keys.isShiftPressed,
      );
    }

    // The checkbox column is a selection control, not a cell: a tap on it
    // should not also open an editor or report a cell tap.
    if (column.id == FitGrid.selectionColumnId) return;

    if (openEditor) _beginEdit(globalPosition, columns, rows);
    widget.onRowTap?.call(row, globalRow);
    widget.onCellTap?.call(row, globalRow, column.id);
  }

  /// Where a fill drag has reached — a row into the rows as displayed and a
  /// column id — or null when no fill is under way.
  (int, String)? _fillTarget;
  bool _filling = false;

  /// The cell carrying the fill handle, in the section's own indices: the
  /// far corner of the range, when the range holds something a fill can
  /// write to.
  (int, int) _fillHandleCell(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    if (!widget.cellSelection) return (-1, -1);
    final range = _controller.range.range;
    if (range == null) return (-1, -1);
    final cols = _rangeColumns(range, columns);
    if (!cols.any((column) => column.isEditable)) return (-1, -1);
    final lastLocal = _lastLocalRow(range, rows);
    if (lastLocal < 0) return (-1, -1);
    final lastColumn = columns.indexOf(cols.last);
    return (lastLocal, lastColumn);
  }

  /// The local line of the range's lowest row, or -1 when it is not on this
  /// page.
  int _lastLocalRow(FitGridCellRange range, FitGridRowsView<T> rows) {
    if (rows.displayAt == null) return rows.localIndex(range.lastRow);
    final a = rows.localIndex(range.anchorRow);
    final b = rows.localIndex(range.extentRow);
    return a < 0 || b < 0 ? -1 : math.max(a, b);
  }

  bool _fillStart(Offset globalPosition) {
    if (!widget.cellSelection || _controller.range.range == null) return false;
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return false;
    if (!render.hitsFillHandle(render.globalToLocal(globalPosition))) {
      return false;
    }
    setState(() {
      _filling = true;
      _fillTarget = null;
    });
    return true;
  }

  void _fillUpdate(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    if (!_filling) return;
    _autoScrollForDrag(globalPosition);
    final cell = _rangeCellAt(globalPosition, columns, rows, clamp: true);
    if (cell == null || cell == _fillTarget) return;
    setState(() => _fillTarget = cell);
  }

  void _fillCancel() {
    if (!_filling && _fillTarget == null) return;
    setState(() {
      _filling = false;
      _fillTarget = null;
    });
  }

  void _fillEnd(List<FitGridColumn<T>> columns, FitGridRowsView<T> rows) {
    final range = _controller.range.range;
    final target = _fillTarget;
    _fillCancel();
    if (range == null || target == null) return;
    final plan = _planFill(range, target, columns, rows);
    if (plan == null) return;
    _applyEdits(plan.edits);
    _controller.range.range = plan.covered;
  }

  /// The block a fill would write, outlined during the drag.
  (int, int, int, int) _fillPreviewRange(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final range = _controller.range.range;
    final target = _fillTarget;
    if (!_filling || range == null || target == null) {
      return RenderFitGridSection.noRange;
    }
    final plan = _planFill(range, target, columns, rows);
    if (plan == null) return RenderFitGridSection.noRange;
    final ids = <String>[for (final column in columns) column.id];
    final c0 = ids.indexOf(plan.covered.anchorColumnId);
    final c1 = ids.indexOf(plan.covered.extentColumnId);
    final r0 = rows.localIndex(plan.covered.anchorRow);
    final r1 = rows.localIndex(plan.covered.extentRow);
    if (c0 < 0 || c1 < 0 || r0 < 0 || r1 < 0) {
      return RenderFitGridSection.noRange;
    }
    return (
      math.min(r0, r1),
      math.max(r0, r1),
      math.min(c0, c1),
      math.max(c0, c1),
    );
  }

  /// What a fill from [range] to [target] writes, and the range it leaves
  /// selected — or null when the target is inside the range.
  ///
  /// A fill runs along one axis: down or up when the target is past the
  /// range's rows, left or right when it is past its columns, and whichever
  /// it is further past when it is both.
  _FillPlan<T>? _planFill(
    FitGridCellRange range,
    (int, String) target,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final sourceRows = _rangeRows(range, rows);
    final sourceCols = _rangeColumns(range, columns);
    if (sourceRows.isEmpty || sourceCols.isEmpty) return null;

    // Everything in display order: local lines for rows, data columns for
    // columns, so grouping and hidden columns do not bend the geometry.
    final line = <int>[for (final r in sourceRows) rows.localIndex(r)];
    if (line.any((l) => l < 0)) return null;
    final dataCols = <FitGridColumn<T>>[
      for (final column in columns)
        if (!_isSynthetic(column)) column,
    ];
    final firstCol = dataCols.indexOf(sourceCols.first);
    final lastCol = dataCols.indexOf(sourceCols.last);
    final targetLine = rows.localIndex(target.$1);
    final targetCol = dataCols.indexWhere((c) => c.id == target.$2);
    if (targetLine < 0 || targetCol < 0) return null;

    final down = targetLine - line.last;
    final up = line.first - targetLine;
    final right = targetCol - lastCol;
    final left = firstCol - targetCol;
    final vertical = math.max(down, up);
    final horizontal = math.max(right, left);
    if (vertical <= 0 && horizontal <= 0) return null;

    String textOf(FitGridColumn<T> column, T row) =>
        column.editor?.initialText?.call(row) ?? column.value(row);

    final edits = <FitGridCellEdit<T>>[];
    if (vertical >= horizontal) {
      final backwards = up > down;
      // The data rows beyond the range, nearest first.
      final targets = <int>[];
      if (backwards) {
        for (var l = line.first - 1; l >= targetLine; l--) {
          if (!rows.isControl(l) && rows.rowAt(l) != null) {
            targets.add(rows.globalIndex(l));
          }
        }
      } else {
        for (var l = line.last + 1; l <= targetLine; l++) {
          if (!rows.isControl(l) && rows.rowAt(l) != null) {
            targets.add(rows.globalIndex(l));
          }
        }
      }
      if (targets.isEmpty) return null;
      for (final column in sourceCols) {
        final source = <String>[
          for (final r in sourceRows)
            if (_rowForGlobalIndex(r) case final row?) textOf(column, row),
        ];
        final values = fitGridFillSeries(
          source,
          targets.length,
          backwards: backwards,
        );
        for (var k = 0; k < targets.length; k++) {
          final row = _rowForGlobalIndex(targets[k]);
          if (row == null) continue;
          edits.add(
            FitGridCellEdit<T>(
              row: row,
              rowIndex: targets[k],
              column: column,
              value: values[k],
            ),
          );
        }
      }
      final far = targets.last;
      return _FillPlan<T>(
        edits,
        FitGridCellRange(
          anchorRow: backwards ? sourceRows.last : sourceRows.first,
          anchorColumnId: sourceCols.first.id,
          extentRow: far,
          extentColumnId: sourceCols.last.id,
        ),
      );
    }

    final backwards = left > right;
    final targetCols = backwards
        ? <FitGridColumn<T>>[
            for (var c = firstCol - 1; c >= targetCol; c--) dataCols[c],
          ]
        : <FitGridColumn<T>>[
            for (var c = lastCol + 1; c <= targetCol; c++) dataCols[c],
          ];
    for (final index in sourceRows) {
      final row = _rowForGlobalIndex(index);
      if (row == null) continue;
      final source = <String>[
        for (final column in sourceCols) textOf(column, row),
      ];
      final values = fitGridFillSeries(
        source,
        targetCols.length,
        backwards: backwards,
      );
      for (var k = 0; k < targetCols.length; k++) {
        edits.add(
          FitGridCellEdit<T>(
            row: row,
            rowIndex: index,
            column: targetCols[k],
            value: values[k],
          ),
        );
      }
    }
    return _FillPlan<T>(
      edits,
      FitGridCellRange(
        anchorRow: sourceRows.first,
        anchorColumnId: backwards ? sourceCols.last.id : sourceCols.first.id,
        extentRow: sourceRows.last,
        extentColumnId: targetCols.last.id,
      ),
    );
  }

  /// The row being dragged, by index into the rows as displayed, or null.
  int? _rowDragFrom;

  /// The line the drop indicator is drawn above, or -1.
  int _rowDropLine = -1;

  /// Starts a row drag if the press landed on a drag handle and rows can be
  /// moved. Returning false leaves the pointer to everything else — the
  /// scroll view, the taps — so a press anywhere but a handle behaves as it
  /// always did.
  bool _rowDragStart(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    if (!_canReorderRows) return false;
    final hit = _cellAt(globalPosition, columns, rows);
    if (hit == null) return false;
    final (local, column) = hit;
    if (columns[column].id != FitGrid.dragColumnId) return false;
    if (rows.rowAt(local) == null) return false;
    setState(() {
      _rowDragFrom = rows.globalIndex(local);
      _rowDropLine = local;
    });
    return true;
  }

  void _rowDragUpdate(Offset globalPosition, FitGridRowsView<T> rows) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection || _rowDragFrom == null) return;
    _autoScrollForDrag(globalPosition);
    final local = render.globalToLocal(globalPosition);
    final y = local.dy + render.verticalOffset;
    int line;
    if (y <= 0) {
      line = 0;
    } else if (y >= render.contentHeight) {
      line = rows.length;
    } else {
      line = render.rowMetrics.clampedRowAt(y);
      // The lower half of a row means "after it".
      final top = render.rowOffsetAt(line);
      if (y - top > render.rowHeightAt(line) / 2) line++;
    }
    if (line != _rowDropLine) setState(() => _rowDropLine = line);
  }

  void _rowDragEnd(FitGridRowsView<T> rows) {
    final from = _rowDragFrom;
    final line = _rowDropLine;
    _rowDragCancel();
    if (from == null || line < 0) return;
    final before = _indexBeforeLine(line, rows);
    // Dropping below its own position counts the row itself among those it
    // passes, which is one too many once it has left its old place.
    final to = before > from ? before - 1 : before;
    if (to != from) _reorderRow(from, to);
  }

  void _rowDragCancel() {
    if (_rowDragFrom == null && _rowDropLine < 0) return;
    setState(() {
      _rowDragFrom = null;
      _rowDropLine = -1;
    });
  }

  /// The index, into the rows as displayed, of the first row at or after
  /// display line [line] — the row a drop there would land in front of.
  /// Detail panels between rows are stepped over.
  int _indexBeforeLine(int line, FitGridRowsView<T> rows) {
    for (var i = line; i < rows.length; i++) {
      if (rows.rowAt(i) != null) return rows.globalIndex(i);
    }
    return _controller.data.length;
  }

  /// Moves a row and carries the selection and the focus along with it.
  void _reorderRow(int from, int to) {
    final data = _controller.data;
    final callback = widget.onRowReorder;
    if (callback != null) {
      callback(from, to);
    } else {
      final view = data.view;
      if (from < 0 || from >= view.length || to < 0 || to >= view.length) {
        return;
      }
      // Moved among the supplied rows, next to the row it was dropped on, so
      // a filter hiding rows in between does not decide where it lands.
      final all = data.rows;
      data.moveRow(all.indexOf(view[from]), all.indexOf(view[to]));
    }

    int follow(int i) {
      if (i == from) return to;
      if (from < to && i > from && i <= to) return i - 1;
      if (to < from && i >= to && i < from) return i + 1;
      return i;
    }

    final selection = _controller.selection;
    if (selection.isNotEmpty) {
      selection.select(<int>[for (final i in selection.selected) follow(i)]);
    }
    final focus = _controller.focus;
    if (focus.hasFocus) {
      focus.moveTo(follow(focus.rowIndex!), focus.columnId!);
    }
  }

  /// The pointer dragging out a range, or null.
  int? _rangeDragPointer;

  /// A mouse press starts a range. Touch is left alone: on a touch screen a
  /// drag across the grid means scroll, and taking it for a selection would
  /// leave the grid impossible to move with a finger.
  void _rangeDragStart(
    PointerDownEvent event,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    if (event.kind != PointerDeviceKind.mouse ||
        event.buttons != kPrimaryMouseButton) {
      return;
    }
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is RenderFitGridSection &&
        render.hitsFillHandle(render.globalToLocal(event.position))) {
      // The fill handle's own recognizer has this press.
      return;
    }
    final cell = _rangeCellAt(event.position, columns, rows);
    if (cell == null) return;
    _rangeDragPointer = event.pointer;
    // The anchor is set here rather than left to the tap handler: a press that
    // turns into a drag never becomes a tap, so the tap handler never runs.
    if (HardwareKeyboard.instance.isShiftPressed) {
      _controller.range.extendTo(cell.$1, cell.$2);
    } else {
      _controller.range.select(cell.$1, cell.$2);
    }
  }

  void _rangeDragUpdate(
    PointerMoveEvent event,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    if (event.pointer != _rangeDragPointer) return;
    _autoScrollForDrag(event.position);
    final cell = _rangeCellAt(event.position, columns, rows, clamp: true);
    if (cell == null) return;
    _controller.range.extendTo(cell.$1, cell.$2);
    if (widget.keyboardNavigation) {
      _controller.focus.moveTo(cell.$1, cell.$2);
    }
  }

  /// Scrolls when a drag reaches the edge of the body, so a range can be
  /// dragged past what is on screen.
  ///
  /// Driven by pointer moves rather than a timer: the range grows as fast as
  /// the pointer does and stops when it stops, which is what a spreadsheet
  /// feels like under a mouse that is being held still at the edge only
  /// briefly.
  void _autoScrollForDrag(Offset globalPosition) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return;
    final local = render.globalToLocal(globalPosition);
    const edge = 24.0;
    final size = render.size;

    void nudge(ScrollController controller, double delta) {
      if (!controller.hasClients || delta == 0) return;
      final position = controller.position;
      controller.jumpTo(
        (position.pixels + delta).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    }

    if (local.dy < edge) nudge(_verticalController, local.dy - edge);
    if (local.dy > size.height - edge) {
      nudge(_verticalController, local.dy - size.height + edge);
    }
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final logicalX = rtl ? size.width - local.dx : local.dx;
    if (logicalX < edge) nudge(_horizontalController, logicalX - edge);
    if (logicalX > size.width - edge) {
      nudge(_horizontalController, logicalX - size.width + edge);
    }
  }

  /// The cell a range may start or end at: a data row, in a data column.
  /// With [clamp], a position past the edge of the rows or columns names the
  /// nearest cell rather than nothing, so a drag that overshoots keeps going.
  (int, String)? _rangeCellAt(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows, {
    bool clamp = false,
  }) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection || rows.isEmpty) return null;
    final local = render.globalToLocal(globalPosition);
    var row = render.rowAtOffset(local.dy);
    var column = render.columnAtOffset(local.dx);
    if (clamp) {
      if (row < 0) {
        row = local.dy < 0
            ? math.max(0, render.rowAtOffset(0))
            : rows.length - 1;
      }
      if (column < 0) {
        final rtl = Directionality.of(context) == TextDirection.rtl;
        column = (local.dx < 0) != rtl ? 0 : columns.length - 1;
      }
      row = row.clamp(0, rows.length - 1);
    }
    if (row < 0 || row >= rows.length) return null;
    if (column < 0 || column >= columns.length) return null;
    if (_isSynthetic(columns[column])) {
      if (!clamp) return null;
      final firstData = columns.indexWhere((c) => !_isSynthetic(c));
      if (firstData < 0) return null;
      column = firstData;
    }
    if (rows.isControl(row)) {
      if (!clamp) return null;
      // A group header has no cells to select; step onto the nearest row.
      var probe = row;
      while (probe < rows.length && rows.isControl(probe)) {
        probe++;
      }
      if (probe >= rows.length) return null;
      row = probe;
    }
    return (rows.globalIndex(row), columns[column].id);
  }

  /// The selected range in the section's own indices, clipped to the rows on
  /// this page, or [RenderFitGridSection.noRange].
  ///
  /// A single cell is not painted as a range: it is the focused cell, and the
  /// focus ring already says so.
  (int, int, int, int) _localRange(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final range = _controller.range.range;
    if (!widget.cellSelection || range == null || range.isSingleCell) {
      return RenderFitGridSection.noRange;
    }
    final ids = <String>[for (final column in columns) column.id];
    final a = ids.indexOf(range.anchorColumnId);
    final b = ids.indexOf(range.extentColumnId);
    if (a < 0 || b < 0) return RenderFitGridSection.noRange;

    int first;
    int last;
    if (rows.displayAt == null) {
      first = math.max(range.firstRow - rows.offset, 0);
      last = math.min(range.lastRow - rows.offset, rows.length - 1);
    } else {
      final la = rows.localIndex(range.anchorRow);
      final lb = rows.localIndex(range.extentRow);
      if (la < 0 || lb < 0) return RenderFitGridSection.noRange;
      first = math.min(la, lb);
      last = math.max(la, lb);
    }
    if (first > last) return RenderFitGridSection.noRange;
    return (first, last, math.min(a, b), math.max(a, b));
  }

  /// The rows a range covers, as indices into the full row list, in display
  /// order. Group headers inside it are skipped — they are not rows.
  List<int> _rangeRows(FitGridCellRange range, FitGridRowsView<T> rows) {
    if (rows.displayAt == null) {
      return <int>[for (var i = range.firstRow; i <= range.lastRow; i++) i];
    }
    final a = rows.localIndex(range.anchorRow);
    final b = rows.localIndex(range.extentRow);
    if (a < 0 || b < 0) return const <int>[];
    return <int>[
      for (var i = math.min(a, b); i <= math.max(a, b); i++)
        if (!rows.isControl(i)) rows.globalIndex(i),
    ];
  }

  /// The data columns a range covers, in display order.
  List<FitGridColumn<T>> _rangeColumns(
    FitGridCellRange range,
    List<FitGridColumn<T>> columns,
  ) {
    final ids = range.columnIdsIn(<String>[
      for (final column in columns) column.id,
    ]);
    return <FitGridColumn<T>>[
      for (final column in columns)
        if (ids.contains(column.id) && !_isSynthetic(column)) column,
    ];
  }

  /// Whether a widget cell under [globalPosition] listens for pointers itself
  /// — a button, an InkWell, a checkbox — in which case the tap is its to
  /// handle.
  ///
  /// The grid takes taps once, for the whole section, on tap-down. A button in
  /// a cell competes for the same pointer, and without this a press held past
  /// the tap timeout would both press the button and select the row. A passive
  /// widget (an avatar, a pill) listens for nothing, so tapping it still
  /// selects the row, the same as tapping painted text.
  bool _cellWidgetClaims(Offset globalPosition) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return false;
    final result = BoxHitTestResult();
    render.hitTestChildren(
      result,
      position: render.globalToLocal(globalPosition),
    );
    return result.path.any((entry) => entry.target is RenderPointerListener);
  }

  (int, int)? _cellAt(
    Offset globalPosition,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final render = _sectionKey.currentContext?.findRenderObject();
    if (render is! RenderFitGridSection) return null;
    final local = render.globalToLocal(globalPosition);
    // A pinned header is on top of whatever row has scrolled beneath it, so
    // it takes the hit.
    final pinned = render.stickyRowAtOffset(local.dy);
    final row = pinned >= 0 ? pinned : render.rowAtOffset(local.dy);
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

  /// Whether key presses are the grid's to act on: the grid itself holds
  /// primary focus, rather than an open editor or a focusable widget inside a
  /// cell. Without this a Space typed into an editor would toggle the row's
  /// selection, and an arrow key would move the grid's focus out from under
  /// the caret.
  bool _gridHasKeyboard() => _focusNode.hasPrimaryFocus;

  Map<Type, Action<Intent>> _actions(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) => <Type, Action<Intent>>{
    FitGridMoveIntent: _GridAction<FitGridMoveIntent>(
      enabled: _gridHasKeyboard,
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
    FitGridJumpIntent: _GridAction<FitGridJumpIntent>(
      enabled: _gridHasKeyboard,
      onInvoke: (intent) {
        _jumpFocus(columns, rows, intent);
        return null;
      },
    ),
    FitGridPageIntent: _GridAction<FitGridPageIntent>(
      enabled: _gridHasKeyboard,
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
    FitGridActivateIntent: _GridAction<FitGridActivateIntent>(
      enabled: _gridHasKeyboard,
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
    FitGridToggleSelectionIntent: _GridAction<FitGridToggleSelectionIntent>(
      enabled: _gridHasKeyboard,
      onInvoke: (_) {
        final row = _controller.focus.rowIndex;
        if (row != null) {
          _controller.selection.applyGesture(row, toggleKey: true);
        }
        return null;
      },
    ),
    FitGridSelectAllIntent: _GridAction<FitGridSelectAllIntent>(
      enabled: _gridHasKeyboard,
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
    FitGridCopyIntent: _GridAction<FitGridCopyIntent>(
      enabled: _gridHasKeyboard,
      onInvoke: (_) {
        if (widget.enableCopy) _copy(columns, rows);
        return null;
      },
    ),
    FitGridDismissIntent: _GridAction<FitGridDismissIntent>(
      enabled: _gridHasKeyboard,
      onInvoke: (_) {
        if (_controller.editing.isEditing) {
          _controller.editing.cancel();
        } else if (_controller.range.isMultiCell) {
          final range = _controller.range.range!;
          _controller.range.select(range.anchorRow, range.anchorColumnId);
        } else {
          _controller.selection.clear();
        }
        return null;
      },
    ),
    FitGridMoveRowIntent: _GridAction<FitGridMoveRowIntent>(
      enabled: () => _gridHasKeyboard() && _canReorderRows,
      onInvoke: (intent) {
        final row = _controller.focus.rowIndex;
        if (row == null) return null;
        final to = (row + intent.delta).clamp(0, _controller.data.length - 1);
        if (to != row) {
          _reorderRow(row, to);
          _controller.scrollTo(to, columnId: _controller.focus.columnId);
        }
        return null;
      },
    ),
    FitGridUndoIntent: _GridAction<FitGridUndoIntent>(
      enabled: () =>
          _gridHasKeyboard() &&
          widget.enableUndo &&
          _controller.history.canUndo,
      onInvoke: (_) => _controller.undo(),
    ),
    FitGridRedoIntent: _GridAction<FitGridRedoIntent>(
      enabled: () =>
          _gridHasKeyboard() &&
          widget.enableUndo &&
          _controller.history.canRedo,
      onInvoke: (_) => _controller.redo(),
    ),
    FitGridPasteIntent: _GridAction<FitGridPasteIntent>(
      enabled: () =>
          _gridHasKeyboard() &&
          widget.enablePaste &&
          columns.any((column) => column.isEditable),
      onInvoke: (_) {
        _paste(columns, rows);
        return null;
      },
    ),
    FitGridClearCellsIntent: _GridAction<FitGridClearCellsIntent>(
      enabled: () =>
          _gridHasKeyboard() &&
          widget.cellSelection &&
          columns.any((column) => column.isEditable),
      onInvoke: (_) {
        _clearCells(columns, rows);
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

    // The first key press establishes the focus rather than moving it. Arrowing
    // down into a grid that has never been focused should land on its first
    // row, not on its second.
    if (!focus.hasFocus) {
      focus.moveTo(rows.offset, columns.first.id);
      _controller.scrollTo(rows.offset, columnId: columns.first.id);
      return;
    }

    final currentRow = focus.rowIndex!;
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
    if (widget.cellSelection) {
      _moveRange(
        columns,
        currentRow,
        columns[currentColumn].id,
        nextRow,
        columns[nextColumn].id,
        extend: extend,
      );
    } else if (extend &&
        _controller.selection.mode == FitGridSelectionMode.multiple) {
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
    final fromRow = row;
    final fromColumn = columns[columnIndex].id;

    if (intent.toRowEdge) {
      row = intent.toStart ? 0 : total - 1;
    } else {
      columnIndex = intent.toStart ? 0 : columns.length - 1;
    }

    focus.moveTo(row, columns[columnIndex].id);
    if (widget.cellSelection) {
      _moveRange(
        columns,
        fromRow,
        fromColumn,
        row,
        columns[columnIndex].id,
        extend: intent.extend,
      );
    } else if (intent.extend &&
        _controller.selection.mode == FitGridSelectionMode.multiple) {
      _controller.selection.applyGesture(row, rangeKey: true);
    }
    _controller.scrollTo(row, columnId: columns[columnIndex].id);
  }

  /// Keeps the range in step with a keyboard move: Shift extends it from where
  /// the focus was, a plain move collapses it onto the new cell.
  void _moveRange(
    List<FitGridColumn<T>> columns,
    int fromRow,
    String fromColumn,
    int toRow,
    String toColumn, {
    required bool extend,
  }) {
    if (_isSyntheticId(toColumn)) return;
    final range = _controller.range;
    if (!extend) return range.select(toRow, toColumn);
    if (!range.isActive && !_isSyntheticId(fromColumn)) {
      range.select(fromRow, fromColumn);
    }
    range.extendTo(toRow, toColumn);
  }

  /// Enter, or a screen reader's activate: edit the cell if it can be edited,
  /// otherwise report it as a tap.
  void _activateCell(
    int globalRow,
    FitGridColumn<T> column,
    FitGridRowsView<T> rows,
    int localRow,
  ) {
    final line = rows.displayAt?.call(localRow);
    if (line != null && line.expandable) {
      _controller.grouping.toggle(line.groupKey!);
      return;
    }
    if (column.id == FitGrid.selectionColumnId) {
      _controller.selection.applyGesture(globalRow, toggleKey: true);
      return;
    }
    if (column.id == FitGrid.detailColumnId) {
      final row = rows.rowAt(localRow);
      if (row != null) _controller.details.toggle(_detailKey(row));
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
    final range = _controller.range.range;
    if (widget.cellSelection && range != null && !range.isSingleCell) {
      return _copyRange(range, columns, rows);
    }
    final copyable = <FitGridColumn<T>>[
      for (final column in columns)
        if (!_isSynthetic(column)) column,
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
      final row = _rowForGlobalIndex(indices[i]);
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

  /// Copies a block of cells as a block: a spreadsheet pastes it back as the
  /// same rectangle.
  void _copyRange(
    FitGridCellRange range,
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    final cols = _rangeColumns(range, columns);
    if (cols.isEmpty) return;
    final buffer = StringBuffer();
    var first = true;
    for (final index in _rangeRows(range, rows)) {
      final row = _rowForGlobalIndex(index);
      if (row == null) continue;
      if (!first) buffer.write('\n');
      first = false;
      for (var c = 0; c < cols.length; c++) {
        if (c > 0) buffer.write('\t');
        buffer.write(_escapeCell(cols[c].copyTextFor(row)));
      }
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
  }

  /// Pastes tab-separated text into the grid.
  ///
  /// Starts at the top-left of the range, or at the focused cell, and fills
  /// rightwards and downwards through the columns as displayed. A single value
  /// pasted over a range fills every cell of it, the way a spreadsheet does.
  /// Every value goes through its column's validator and commit; a column with
  /// no editor, or a value the validator rejects, is skipped rather than
  /// stopping the paste halfway.
  Future<void> _paste(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.isEmpty || !mounted) return;
    final grid = fitGridParseDelimited(text, delimiter: '\t');
    if (grid.isEmpty) return;

    final range = widget.cellSelection ? _controller.range.range : null;
    final focus = _controller.focus;
    final startRow = range?.firstRow ?? focus.rowIndex;
    if (startRow == null) return;

    final data2 = <FitGridColumn<T>>[
      for (final column in columns)
        if (!_isSynthetic(column)) column,
    ];
    final List<FitGridColumn<T>> targetColumns;
    final List<int> targetRows;
    final fill =
        range != null &&
        !range.isSingleCell &&
        grid.length == 1 &&
        grid.first.length == 1;
    if (fill) {
      targetColumns = _rangeColumns(range, columns);
      targetRows = _rangeRows(range, rows);
    } else {
      final startColumnId = range == null
          ? focus.columnId
          : _rangeColumns(range, columns).firstOrNull?.id;
      final startColumn = data2.indexWhere((c) => c.id == startColumnId);
      if (startColumn < 0) return;
      final width = grid.fold<int>(
        0,
        (w, line) => line.length > w ? line.length : w,
      );
      targetColumns = data2.sublist(
        startColumn,
        math.min(data2.length, startColumn + width),
      );
      targetRows = _rowsFrom(startRow, grid.length, rows);
    }

    // Resolve every target row before committing anything: a commit may hand
    // the grid new rows, and under a sort the next target would then be
    // whichever row had moved into its place.
    final targets = <(T, int)>[
      for (final index in targetRows)
        if (_rowForGlobalIndex(index) case final row?) (row, index),
    ];
    final edits = <FitGridCellEdit<T>>[];
    for (var r = 0; r < targets.length; r++) {
      final line = fill ? grid.first : grid[r];
      for (var c = 0; c < targetColumns.length; c++) {
        if (!fill && c >= line.length) break;
        final value = fill ? line.first : line[c];
        final (row, index) = targets[r];
        edits.add(
          FitGridCellEdit<T>(
            row: row,
            rowIndex: index,
            column: targetColumns[c],
            value: value,
          ),
        );
      }
    }
    _applyEdits(edits);

    // Leave the pasted block selected, so it is obvious what changed and a
    // second paste or a Delete applies to the same cells.
    if (widget.cellSelection && !fill && targets.isNotEmpty) {
      _controller.range.range = FitGridCellRange(
        anchorRow: targets.first.$2,
        anchorColumnId: targetColumns.first.id,
        extentRow: targets.last.$2,
        extentColumnId: targetColumns.last.id,
      );
    }
  }

  /// [count] rows in display order starting at [start], as global indices.
  List<int> _rowsFrom(int start, int count, FitGridRowsView<T> rows) {
    if (rows.displayAt == null) {
      final total = widget.dataSource?.rowCount ?? _controller.data.length;
      return <int>[
        for (var i = start; i < math.min(total, start + count); i++) i,
      ];
    }
    final out = <int>[];
    for (var i = rows.localIndex(start); i >= 0 && i < rows.length; i++) {
      if (rows.isControl(i)) continue;
      out.add(rows.globalIndex(i));
      if (out.length == count) break;
    }
    return out;
  }

  /// Delete or Backspace over a range: empties the editable cells in it, or
  /// the focused cell when there is no range.
  void _clearCells(List<FitGridColumn<T>> columns, FitGridRowsView<T> rows) {
    final range = _controller.range.range;
    final focus = _controller.focus;
    final List<FitGridColumn<T>> cols;
    final List<int> indices;
    if (range != null) {
      cols = _rangeColumns(range, columns);
      indices = _rangeRows(range, rows);
    } else if (focus.hasFocus) {
      cols = <FitGridColumn<T>>[
        for (final column in columns)
          if (column.id == focus.columnId) column,
      ];
      indices = <int>[focus.rowIndex!];
    } else {
      return;
    }
    _applyEdits(<FitGridCellEdit<T>>[
      for (final index in indices)
        if (_rowForGlobalIndex(index) case final row?)
          for (final column in cols)
            FitGridCellEdit<T>(
              row: row,
              rowIndex: index,
              column: column,
              value: '',
            ),
    ]);
  }

  /// Applies a batch of edits through each column's validator and commit,
  /// skipping columns without an editor and values the validator rejects.
  ///
  /// The one door every programmatic change to cell values goes through —
  /// paste, clear, fill — so the rules for what may be written are the same
  /// rules a user typing into an editor is held to.
  List<FitGridCellEdit<T>> _applyEdits(List<FitGridCellEdit<T>> edits) {
    final applied = <FitGridCellEdit<T>>[];
    final changes = <FitGridCellChange>[];
    final data = _controller.data;
    // Whether a commit can move rows: under a sort or a filter, writing a value
    // may reorder the view or drop a row from it, so an index no longer names
    // the row it did when the batch was planned.
    final unstable =
        widget.dataSource == null &&
        (data.sortKeys.isNotEmpty || data.filter != null);
    for (final edit in edits) {
      final editor = edit.column.editor;
      if (editor == null) continue;
      // A host with immutable rows replaces a row on every commit, so the
      // second cell written to it must be built from the replacement or it
      // would quietly undo the first. Where indices are stable the current
      // row at that index is that replacement; where they are not, the row
      // resolved when the batch was planned is the only safe answer.
      var row = edit.row;
      if (!unstable) {
        final current = _rowForGlobalIndex(edit.rowIndex);
        if (current != null) row = current;
      }
      if (editor.validator?.call(row, edit.value) != null) continue;
      changes.add(
        FitGridCellChange(
          rowKey: _historyKey(row),
          rowIndex: edit.rowIndex,
          columnId: edit.column.id,
          before: editor.initialText?.call(row) ?? edit.column.value(row),
          after: edit.value,
        ),
      );
      editor.onCommit(row, edit.rowIndex, edit.value);
      applied.add(
        FitGridCellEdit<T>(
          row: row,
          rowIndex: edit.rowIndex,
          column: edit.column,
          value: edit.value,
        ),
      );
    }
    _record(changes);
    return applied;
  }

  /// A tab or a newline inside a cell would otherwise become a column or a row
  /// on paste, silently shifting everything after it.
  static String _escapeCell(String value) {
    if (!value.contains('\t') && !value.contains('\n')) return value;
    return '"${value.replaceAll('"', '""')}"';
  }

  T? _rowForGlobalIndex(int index) {
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

    final rows = _resolveRows(widget.dataSource);
    final local = rows.localIndex(rowIndex);
    if (local < 0) return;
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
    FitGridRowsView<T> rows,
  ) {
    final editing = controller.editing;
    return _localCell(columns, editing.rowIndex, editing.columnId, rows);
  }

  (int, int) _focusedCellIn(
    List<FitGridColumn<T>> columns,
    FitGridRowsView<T> rows,
  ) {
    if (!widget.keyboardNavigation) return (-1, -1);
    final focus = _controller.focus;
    return _localCell(columns, focus.rowIndex, focus.columnId, rows);
  }

  (int, int) _localCell(
    List<FitGridColumn<T>> columns,
    int? globalRow,
    String? columnId,
    FitGridRowsView<T> rows,
  ) {
    if (globalRow == null || columnId == null) return (-1, -1);
    final localRow = rows.localIndex(globalRow);
    if (localRow < 0) return (-1, -1);
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
    final (localRow, columnIndex) = _editingCellIn(columns, controller, rows);
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
    final before = editor.initialText?.call(row) ?? column.value(row);
    editor.onCommit(row, globalRow, value);
    _record(<FitGridCellChange>[
      FitGridCellChange(
        rowKey: _historyKey(row),
        rowIndex: globalRow,
        columnId: column.id,
        before: before,
        after: value,
      ),
    ]);
    return true;
  }

  static Object _identityKey(Object? row) => row!;

  /// A row's identity in the edit history.
  Object _historyKey(T row) => widget.rowKey?.call(row) ?? row as Object;

  void _record(List<FitGridCellChange> changes) {
    if (!widget.enableUndo || widget.dataSource != null) return;
    _controller.history.record(changes);
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
      _headerExtra(theme),
      widget.showFooter,
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
      headerExtra: _headerExtra(theme),
      // Only when the cache missed: an aggregate is a pass over the rows,
      // and the key above already changes whenever the rows do.
      footerTexts: widget.showFooter
          ? <String, (String?, String)>{
              for (final column in columns)
                if (column.aggregate != null)
                  column.id: (column.footerLabel, column.aggregate!(rows)),
            }
          : const <String, (String?, String)>{},
    );
    _layout = layout;
    // A measurement pass that ran out of budget leaves the widths provisional,
    // so the memo is not armed and the next build continues where this one
    // stopped. See `FitGridColumnSizer.measurementBudget`.
    _layoutKey = _sizer.isComplete ? key : null;
    if (!_sizer.isComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
    return layout;
  }

  /// The row heights with each detail line given its panel's height. Only
  /// reached while a panel is open, so it is O(lines) exactly when the lines
  /// are already being walked to insert the panels.
  FitGridRowMetrics _withDetailHeights(
    FitGridRowMetrics base,
    FitGridRowsView<T> rows,
  ) {
    final heights = List<double>.generate(rows.length, base.heightOf);
    var any = false;
    for (var i = 0; i < rows.length; i++) {
      final line = rows.displayAt!(i);
      if (line == null || !line.isDetail) continue;
      any = true;
      heights[i] =
          widget.detailHeight?.call(line.detailOf as T, line.ownerIndex!) ??
          widget.detailRowHeight;
    }
    return any ? FitGridRowMetrics.measured(heights) : base;
  }

  /// The data range of each column whose chart needs one, over the rows the
  /// columns are measured against. Memoized on those rows, so it is one pass
  /// per change to the data rather than one per frame.
  Map<String, (num, num)> _resolveVisualRanges(
    List<FitGridColumn<T>> columns,
    List<T> rows,
  ) {
    final wanting = <FitGridColumn<T>>[
      for (final column in columns)
        if (column.visual?.needsRange ?? false) column,
    ];
    if (wanting.isEmpty) return const <String, (num, num)>{};
    final key = Object.hash(
      identityHashCode(rows),
      rows.length,
      identityHashCode(columns),
    );
    final cached = _visualRanges;
    if (cached != null && _visualRangesKey == key) return cached;

    final ranges = <String, (num, num)>{};
    for (final column in wanting) {
      num? low;
      num? high;
      for (final row in rows) {
        final value = column.visual!.rangeValueOf(row);
        if (value == null) continue;
        if (low == null || value < low) low = value;
        if (high == null || value > high) high = value;
      }
      if (low != null && high != null) ranges[column.id] = (low, high);
    }
    _visualRanges = ranges;
    _visualRangesKey = key;
    return ranges;
  }

  /// Header room every column needs beyond its label and sort icon.
  double _headerExtra(FitGridThemeData theme) =>
      widget.showColumnMenu ? theme.sortIconSize + 4 : 0.0;

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
      widget.detailRowHeight,
    );
    final cached = _rowMetrics;
    if (cached != null && _rowMetricsKey == key) return cached;

    var metrics = _rowSizer.resolve(
      policy: widget.rowHeight,
      columns: columns,
      rows: rows,
      layout: layout,
      theme: theme,
      textDirection: textDirection,
      textScaler: textScaler,
    );
    if (_detailsEnabled &&
        !_controller.details.isEmpty &&
        rows.displayAt != null) {
      metrics = _withDetailHeights(metrics, rows);
    }
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

/// Cache key for a rows view with skeleton rows on the end.
@immutable
class _SkeletonIdentity {
  const _SkeletonIdentity(this.base, this.extra);

  final Object base;
  final int extra;

  @override
  bool operator ==(Object other) =>
      other is _SkeletonIdentity && other.base == base && other.extra == extra;

  @override
  int get hashCode => Object.hash(base, extra);
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

/// A [CallbackAction] that can decline, so a key it would otherwise take goes
/// on to whatever else is listening — the text field of an open editor, a
/// button inside a widget cell.
class _GridAction<I extends Intent> extends CallbackAction<I> {
  _GridAction({required this.enabled, required super.onInvoke});

  final bool Function() enabled;

  @override
  bool isEnabled(I intent) => enabled();
}

/// Claims a pointer the moment it lands on a row's drag handle.
///
/// The scroll view underneath would otherwise take the drag as a scroll: both
/// want vertical movement, and in the arena the first to see the slop crossed
/// wins. Claiming on pointer-down — for handle presses only — settles it
/// before the scroll view has a chance, while every other press is never
/// tracked at all and reaches the scroll view and the taps untouched.
class _RowDragRecognizer extends OneSequenceGestureRecognizer {
  /// Asked on pointer-down whether to take this pointer; starts the drag if so.
  bool Function(Offset globalPosition) claims = _never;
  void Function(Offset globalPosition) onUpdate = _ignore;
  VoidCallback onEnd = _nothing;
  VoidCallback onCancel = _nothing;

  static bool _never(Offset _) => false;
  static void _ignore(Offset _) {}
  static void _nothing() {}

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (!claims(event.position)) return;
    super.addAllowedPointer(event);
    resolve(GestureDisposition.accepted);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      onUpdate(event.position);
    } else if (event is PointerUpEvent) {
      onEnd();
      stopTrackingPointer(event.pointer);
    } else if (event is PointerCancelEvent) {
      onCancel();
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void rejectGesture(int pointer) {
    onCancel();
    super.rejectGesture(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {}

  @override
  String get debugDescription => 'fitgrid row drag';
}

/// Claims presses on the fill handle, the way [_RowDragRecognizer] claims
/// presses on a row's drag handle. A type of its own so both can sit in one
/// gesture map.
class _FillDragRecognizer extends _RowDragRecognizer {
  @override
  String get debugDescription => 'fitgrid fill drag';
}

/// The edits a fill makes and the range it leaves selected.
class _FillPlan<T> {
  const _FillPlan(this.edits, this.covered);

  final List<FitGridCellEdit<T>> edits;
  final FitGridCellRange covered;
}
