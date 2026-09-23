import 'package:flutter/foundation.dart';

import '../model/enums.dart';
import '../export/fitgrid_export.dart';
import '../model/fitgrid_column.dart';
import '../model/sort_key.dart';
import '../sizing/column_order.dart';
import 'fitgrid_details.dart';
import 'fitgrid_editing.dart';
import 'fitgrid_filter.dart';
import 'fitgrid_focus.dart';
import 'fitgrid_grouping.dart';
import 'fitgrid_pagination.dart';
import 'fitgrid_range.dart';
import 'fitgrid_saved_state.dart';

/// Rows, and the ordering applied to them.
///
/// [view] is the list the grid actually renders: [rows] with the active sort
/// applied. It is recomputed when the rows or the sort change and cached in
/// between, because the render layer asks for row *i* many times per frame.
class FitGridDataState<T> extends ChangeNotifier {
  FitGridDataState({List<T> rows = const []}) : _rows = List<T>.of(rows);

  List<T> _rows;
  List<T>? _view;
  FitGridRowPredicate<T>? _filter;

  /// The rows as supplied, in their original order.
  List<T> get rows => List<T>.unmodifiable(_rows);

  set rows(List<T> value) {
    _rows = List<T>.of(value);
    _view = null;
    notifyListeners();
  }

  /// Narrows the rows before they are sorted, or null to keep all of them.
  ///
  /// Set by the controller from the filter state rather than by a host
  /// directly, so that "what is on screen" has exactly one derivation.
  FitGridRowPredicate<T>? get filter => _filter;
  set filter(FitGridRowPredicate<T>? value) {
    if (identical(_filter, value)) return;
    _filter = value;
    _view = null;
    notifyListeners();
  }

  List<FitGridSortKey> _sortKeys = const <FitGridSortKey>[];
  List<Comparator<T>> _comparators = <Comparator<T>>[];

  /// The active sort, highest priority first. Empty when unsorted.
  List<FitGridSortKey> get sortKeys => _sortKeys;

  /// Id of the column deciding the order, or null when unsorted. With several
  /// sort keys this is the first of them.
  String? get sortColumnId =>
      _sortKeys.isEmpty ? null : _sortKeys.first.columnId;

  /// Direction of the primary sort key.
  FitGridSortDirection get sortDirection =>
      _sortKeys.isEmpty ? FitGridSortDirection.none : _sortKeys.first.direction;

  /// The direction [columnId] is sorted in, whatever its priority.
  FitGridSortDirection directionOf(String columnId) {
    for (final key in _sortKeys) {
      if (key.columnId == columnId) return key.direction;
    }
    return FitGridSortDirection.none;
  }

  /// Where [columnId] sits in the sort, from 0, or -1 when it is not sorted.
  int sortPriorityOf(String columnId) =>
      _sortKeys.indexWhere((key) => key.columnId == columnId);

  /// The rows in display order.
  List<T> get view => _view ??= _buildView();

  int get length => view.length;

  T operator [](int index) => view[index];

  /// Sorts by one column, replacing any other sort. Passing
  /// [FitGridSortDirection.none] clears it and returns the rows to their
  /// original order — which is why the unsorted list is kept rather than
  /// sorted in place.
  void sort(
    String columnId,
    FitGridSortDirection direction,
    Comparator<T> comparator,
  ) {
    if (direction == FitGridSortDirection.none) {
      sortBy(const <FitGridSortKey>[], const []);
    } else {
      sortBy(
        <FitGridSortKey>[FitGridSortKey(columnId, direction)],
        [comparator],
      );
    }
  }

  /// Sorts by several columns at once, [keys] in priority order and
  /// [comparators] parallel to them.
  ///
  /// Ties on every key keep their original relative order: the sort is
  /// stable, so "by department, then by name" never shuffles two people with
  /// the same name in the same department.
  void sortBy(List<FitGridSortKey> keys, List<Comparator<T>> comparators) {
    assert(keys.length == comparators.length);
    assert(
      keys.every((key) => key.direction != FitGridSortDirection.none),
      'An unsorted column is left out of the keys, not given `none`.',
    );
    _sortKeys = List<FitGridSortKey>.unmodifiable(keys);
    _comparators = List<Comparator<T>>.of(comparators);
    _view = null;
    notifyListeners();
  }

  /// The next state in the tri-state cycle for [columnId]: ascending, then
  /// descending, then unsorted.
  FitGridSortDirection nextDirectionFor(String columnId) {
    return switch (directionOf(columnId)) {
      FitGridSortDirection.ascending => FitGridSortDirection.descending,
      FitGridSortDirection.descending => FitGridSortDirection.none,
      FitGridSortDirection.none => FitGridSortDirection.ascending,
    };
  }

  /// Moves the row at [from] so that it ends up at [to], both indices into
  /// [rows] — the supplied order, not the view.
  void moveRow(int from, int to) {
    if (from == to || from < 0 || from >= _rows.length) return;
    final row = _rows.removeAt(from);
    _rows.insert(to.clamp(0, _rows.length), row);
    _view = null;
    notifyListeners();
  }

  List<T> _buildView() {
    final filter = _filter;
    // An unfiltered, unsorted grid hands back the original list rather than a
    // copy of it: downstream caches are keyed on its identity, so copying here
    // would invalidate the column measurement on every build.
    if (filter == null && _sortKeys.isEmpty) return _rows;
    final base = filter == null
        ? _rows
        : <T>[
            for (final row in _rows)
              if (filter(row)) row,
          ];
    if (_sortKeys.isEmpty) return base;
    return _stableSort(base);
  }

  /// Dart's `List.sort` is not stable, and a multi-key sort leans on
  /// stability for its last tie-break: rows equal on every key should stay in
  /// the order they were supplied. So the original position is the final key.
  List<T> _stableSort(List<T> base) {
    final keys = _sortKeys;
    final comparators = _comparators;
    final order = List<int>.generate(base.length, (i) => i);
    order.sort((a, b) {
      for (var k = 0; k < keys.length; k++) {
        final result = comparators[k](base[a], base[b]);
        if (result != 0) return keys[k].descending ? -result : result;
      }
      return a - b;
    });
    return <T>[for (final i in order) base[i]];
  }
}

/// Column order, visibility and user-applied widths.
///
/// Deliberately separate from [FitGridDataState]: dragging a column wider must
/// not invalidate the row view, and sorting must not re-measure widths. That
/// separation is the whole reason the controller is a cluster of small
/// notifiers rather than one object with a single `notifyListeners`.
class FitGridColumnState<T> extends ChangeNotifier {
  FitGridColumnState({List<FitGridColumn<T>> columns = const []})
    : _columns = List<FitGridColumn<T>>.of(columns);

  List<FitGridColumn<T>> _columns;
  List<FitGridColumn<T>>? _visible;
  List<FitGridColumn<T>>? _unmodifiable;
  final Map<String, double> _widthOverrides = <String, double>{};

  List<FitGridColumn<T>> get columns =>
      _unmodifiable ??= List<FitGridColumn<T>>.unmodifiable(_columns);

  set columns(List<FitGridColumn<T>> value) {
    _columns = List<FitGridColumn<T>>.of(value);
    _invalidate();
    // Widths for columns that no longer exist would otherwise pin memory and
    // silently reapply if an id came back.
    _widthOverrides.removeWhere(
      (id, _) => !_columns.any((column) => column.id == id),
    );
    notifyListeners();
  }

  /// Visible columns in display order — what the sizer and renderer see.
  ///
  /// Pinned columns are pulled to the edges here rather than downstream, so
  /// there is exactly one answer to "what is column 3" across the sizer, the
  /// renderer, the header and the keyboard.
  ///
  /// Cached, and not defensively copied: this is read on every build of a
  /// scrolling grid, and rebuilding it each time showed up before it was
  /// anything else's problem.
  List<FitGridColumn<T>> get visible => _visible ??=
      List<FitGridColumn<T>>.unmodifiable(fitGridVisibleColumns(_columns));

  void _invalidate() {
    _visible = null;
    _unmodifiable = null;
  }

  /// Widths the user has dragged columns to, keyed by column id.
  Map<String, double> get widthOverrides =>
      Map<String, double>.unmodifiable(_widthOverrides);

  FitGridColumn<T>? byId(String id) {
    for (final column in _columns) {
      if (column.id == id) return column;
    }
    return null;
  }

  /// Pins a column to an explicit width, as a resize drag does.
  void setWidth(String id, double width) {
    if (_widthOverrides[id] == width) return;
    _widthOverrides[id] = width;
    notifyListeners();
  }

  /// Returns a column to its declared width policy — what a double-click on
  /// the resize handle does, re-fitting an `auto` column to its content.
  ///
  /// Dropping the override rather than measuring here and pinning the result is
  /// the whole trick: measurement needs a theme, a text direction and a text
  /// scaler, none of which a `ChangeNotifier` has any business knowing about.
  /// The sizer already does it on the next build, and a column left to its
  /// policy keeps re-fitting as the data changes instead of freezing at
  /// whatever it measured the day it was double-clicked.
  void autoSize(String id) => clearWidth(id);

  /// Hands every column back to its width policy. What the user gets from
  /// double-clicking each divider in turn.
  void autoSizeAll() => clearAllWidths();

  /// Drops a column's user-applied width. See [autoSize], which is the same
  /// operation named for what people use it for.
  void clearWidth(String id) {
    if (_widthOverrides.remove(id) == null) return;
    notifyListeners();
  }

  void clearAllWidths() {
    if (_widthOverrides.isEmpty) return;
    _widthOverrides.clear();
    notifyListeners();
  }

  /// Whether a column is currently pinned to a user-applied width rather than
  /// following its policy.
  bool isResized(String id) => _widthOverrides.containsKey(id);

  void setVisible(String id, bool visible) {
    final index = _columns.indexWhere((column) => column.id == id);
    if (index < 0 || _columns[index].visible == visible) return;
    _columns[index] = _columns[index].copyWith(visible: visible);
    _invalidate();
    notifyListeners();
  }

  /// Makes every column visible again.
  void showAll() {
    var changed = false;
    for (var i = 0; i < _columns.length; i++) {
      if (_columns[i].visible) continue;
      _columns[i] = _columns[i].copyWith(visible: true);
      changed = true;
    }
    if (!changed) return;
    _invalidate();
    notifyListeners();
  }

  /// Pins a column to an edge, or unpins it with [FitGridFreeze.none].
  ///
  /// The column keeps its place in the declared order, so unpinning puts it
  /// back where it came from rather than leaving it at the edge.
  void setFreeze(String id, FitGridFreeze freeze) {
    final index = _columns.indexWhere((column) => column.id == id);
    if (index < 0 || _columns[index].freeze == freeze) return;
    _columns[index] = _columns[index].copyWith(freeze: freeze);
    _invalidate();
    notifyListeners();
  }

  /// Applies a saved layout in one step — one rebuild, one re-measure —
  /// rather than a notification per column.
  ///
  /// Ids that no longer exist are ignored. Columns the saved [order] does not
  /// mention keep the position they were declared in, and the mentioned ones
  /// are arranged among the remaining places in the saved order: a column
  /// added in an app update appears where its author put it rather than
  /// tacked on the end.
  void applyLayout({
    List<String> order = const <String>[],
    Set<String>? hidden,
    Map<String, FitGridFreeze> freezes = const <String, FitGridFreeze>{},
    Map<String, double>? widths,
  }) {
    final known = <String>{for (final column in _columns) column.id};
    final ranked = <String>[
      for (final id in order)
        if (known.contains(id)) id,
    ];
    if (ranked.length > 1) {
      final rank = <String, int>{
        for (var i = 0; i < ranked.length; i++) ranked[i]: i,
      };
      final slots = <int>[
        for (var i = 0; i < _columns.length; i++)
          if (rank.containsKey(_columns[i].id)) i,
      ];
      final moving = <FitGridColumn<T>>[for (final i in slots) _columns[i]]
        ..sort((a, b) => rank[a.id]!.compareTo(rank[b.id]!));
      for (var k = 0; k < slots.length; k++) {
        _columns[slots[k]] = moving[k];
      }
    }
    for (var i = 0; i < _columns.length; i++) {
      final column = _columns[i];
      final visible = hidden == null
          ? column.visible
          : !hidden.contains(column.id);
      final freeze = freezes[column.id] ?? column.freeze;
      if (visible != column.visible || freeze != column.freeze) {
        _columns[i] = column.copyWith(visible: visible, freeze: freeze);
      }
    }
    if (widths != null) {
      _widthOverrides
        ..clear()
        ..addEntries(
          widths.entries.where((entry) => known.contains(entry.key)),
        );
    }
    _invalidate();
    notifyListeners();
  }

  /// Moves a column within the display order.
  void move(int from, int to) {
    if (from == to || from < 0 || from >= _columns.length) return;
    final column = _columns.removeAt(from);
    _columns.insert(to.clamp(0, _columns.length), column);
    _invalidate();
    notifyListeners();
  }
}

/// Which rows are selected, and how many may be.
///
/// Indices are into the full row list, never into the page: a selection that
/// reattached to whatever now sits in position 3 after a page turn is worse
/// than no selection at all.
class FitGridSelectionState extends ChangeNotifier {
  final Set<int> _selected = <int>{};

  int _revision = 0;

  /// Bumped on every change. The grid folds it into the cache key for painted
  /// cells, because a checkbox glyph is part of a cell's spec and a `Set` has
  /// no cheap identity to compare instead.
  int get revision => _revision;

  @override
  void notifyListeners() {
    _revision++;
    super.notifyListeners();
  }

  FitGridSelectionMode _mode = FitGridSelectionMode.none;

  /// Whether, and how many, rows the user may select by pointer or keyboard.
  /// Programmatic selection is not gated by this — a host that sets a
  /// selection has said what it wants.
  FitGridSelectionMode get mode => _mode;
  set mode(FitGridSelectionMode value) {
    if (_mode == value) return;
    _mode = value;
    if (value == FitGridSelectionMode.none) {
      _selected.clear();
      _anchor = null;
    } else if (value == FitGridSelectionMode.single && _selected.length > 1) {
      final keep = _selected.last;
      _selected
        ..clear()
        ..add(keep);
    }
    notifyListeners();
  }

  /// Where the last plain click landed. Shift-click extends from here, which is
  /// what makes a range selection feel like one in every other table.
  int? _anchor;
  int? get anchor => _anchor;

  Set<int> get selected => Set<int>.unmodifiable(_selected);

  /// The selected indices in ascending order — the order a copy or an export
  /// has to emit them in.
  List<int> get sorted => _selected.toList()..sort();

  bool get isEmpty => _selected.isEmpty;

  bool get isNotEmpty => _selected.isNotEmpty;

  int get length => _selected.length;

  bool contains(int rowIndex) => _selected.contains(rowIndex);

  void toggle(int rowIndex) {
    if (!_selected.remove(rowIndex)) _selected.add(rowIndex);
    _anchor = rowIndex;
    notifyListeners();
  }

  void select(Iterable<int> rowIndices, {bool replace = true}) {
    if (replace) _selected.clear();
    _selected.addAll(rowIndices);
    _anchor = _selected.isEmpty ? null : _selected.last;
    notifyListeners();
  }

  /// Selects everything between [from] and [to] inclusive, in either order.
  void selectRange(int from, int to, {bool replace = true}) {
    if (replace) _selected.clear();
    final low = from < to ? from : to;
    final high = from < to ? to : from;
    for (var i = low; i <= high; i++) {
      _selected.add(i);
    }
    _anchor = from;
    notifyListeners();
  }

  /// Applies a pointer or keyboard selection gesture, honouring [mode] and the
  /// modifier keys.
  ///
  /// The three behaviours — replace, toggle, extend — are the ones every
  /// desktop table has, and putting them here rather than in the gesture
  /// handler is what lets the keyboard reuse them without reimplementing the
  /// anchor logic.
  void applyGesture(
    int rowIndex, {
    bool toggleKey = false,
    bool rangeKey = false,
  }) {
    switch (_mode) {
      case FitGridSelectionMode.none:
        return;
      case FitGridSelectionMode.single:
        if (toggleKey && _selected.contains(rowIndex)) {
          clear();
        } else {
          select(<int>[rowIndex]);
        }
      case FitGridSelectionMode.multiple:
        if (rangeKey && _anchor != null) {
          final anchor = _anchor!;
          selectRange(anchor, rowIndex, replace: !toggleKey);
          _anchor = anchor;
        } else if (toggleKey) {
          toggle(rowIndex);
        } else {
          select(<int>[rowIndex]);
        }
    }
  }

  void clear() {
    if (_selected.isEmpty && _anchor == null) return;
    _selected.clear();
    _anchor = null;
    notifyListeners();
  }
}

/// The grid's state, in one place.
///
/// Hold one yourself to drive the grid programmatically — sort it, hide a
/// column, read the selection — or let the grid create its own and forget it
/// exists. Ownership follows the same rule as `ScrollController`: whoever
/// constructs it disposes it.
///
/// There is no state-management opinion here on purpose. This is a
/// `ChangeNotifier` cluster and nothing more, so it composes with bloc,
/// riverpod, signals or plain `setState` without any of them being a
/// dependency.
class FitGridController<T> {
  FitGridController({
    List<T> rows = const [],
    List<FitGridColumn<T>> columns = const [],
    FitGridSelectionMode selectionMode = FitGridSelectionMode.none,
  }) : data = FitGridDataState<T>(rows: rows),
       columns = FitGridColumnState<T>(columns: columns) {
    selection.mode = selectionMode;
    pagination.rowCount = rows.length;
    // The page must survive a sort but not a resize of the dataset, so the
    // pager follows the data rather than being driven from the widget.
    data.addListener(() => pagination.rowCount = data.length);
    // Filtering is derived, not stored twice: the filter state holds the user's
    // intent, and this is the one place it turns into a predicate the data
    // state can apply. Columns take part because the search reads them.
    filter.addListener(_applyFilter);
    this.columns.addListener(_applyFilter);
  }

  void _applyFilter() {
    final next = filter.buildPredicate(columns.visible);
    // A null predicate both times means nothing is filtered and nothing needs
    // re-deriving; the identity check in the setter cannot see that, because a
    // fresh closure is a fresh object every time.
    if (next == null && data.filter == null) return;
    data.filter = next;
  }

  /// Rows and their ordering.
  final FitGridDataState<T> data;

  /// Column order, visibility and widths.
  final FitGridColumnState<T> columns;

  /// Selected rows, by index into the full row list — not the page.
  final FitGridSelectionState selection = FitGridSelectionState();

  /// Which cell is open for editing, if any.
  final FitGridEditingState editing = FitGridEditingState();

  /// Which page is on screen. Inert until `FitGrid.paginated` is on, or
  /// [FitGridPaginationState.enabled] is set here.
  final FitGridPaginationState pagination = FitGridPaginationState();

  /// Which cell the keyboard is on.
  final FitGridFocusState focus = FitGridFocusState();

  /// The active search text and column filters.
  final FitGridFilterState<T> filter = FitGridFilterState<T>();

  /// Grouping levels, tree structure, and which of them are open.
  final FitGridGroupingState<T> grouping = FitGridGroupingState<T>();

  /// The selected rectangle of cells, when `FitGrid.cellSelection` is on.
  final FitGridCellRangeState range = FitGridCellRangeState();

  /// Which rows have their detail panel open, when `FitGrid.detailBuilder`
  /// is set.
  final FitGridDetailState details = FitGridDetailState();

  void Function(int rowIndex, String? columnId, double padding)? _reveal;

  /// Wires the controller to a mounted grid so [scrollTo] has something to
  /// scroll. Called by [FitGrid] as it mounts and unmounts; a host never needs
  /// to call it.
  void attachViewport(
    void Function(int rowIndex, String? columnId, double padding)? reveal,
  ) => _reveal = reveal;

  /// Brings a row — and optionally a column — into view.
  ///
  /// Takes a global row index, like everything else that speaks in rows. Under
  /// pagination it turns the page first, because a row on page seven cannot be
  /// scrolled to from page one.
  ///
  /// Does nothing when no grid is mounted, rather than throwing: a controller
  /// outlives the widget that uses it, and a host asking to scroll during a
  /// rebuild should not have to guard against that.
  void scrollTo(int rowIndex, {String? columnId, double padding = 0}) {
    if (rowIndex < 0) return;
    // No upper bound checked here: a grid backed by a [FitGridDataSource] holds
    // no rows of its own, so `data.length` would be zero and every scroll a
    // no-op. The grid clamps against the geometry it actually has.
    if (pagination.enabled) pagination.revealRow(rowIndex);
    _reveal?.call(rowIndex, columnId, padding);
  }

  /// Cycles the sort on a column: ascending, descending, unsorted.
  ///
  /// With [additive] — what Shift+click on a header does — the column is
  /// added to the existing sort as its lowest-priority key rather than
  /// replacing it, and cycling it off removes only that key. Without it the
  /// column becomes the whole sort, which is what a plain click has always
  /// meant.
  void toggleSort(String columnId, {bool additive = false}) {
    final column = columns.byId(columnId);
    if (column == null || !column.sortable) return;
    final next = data.nextDirectionFor(columnId);
    if (!additive) {
      data.sort(columnId, next, column.compare);
      return;
    }
    final keys = <FitGridSortKey>[
      for (final key in data.sortKeys)
        if (key.columnId != columnId) key,
    ];
    final at = data.sortPriorityOf(columnId);
    if (next != FitGridSortDirection.none) {
      // A key already in the sort keeps its priority as it flips direction.
      keys.insert(at < 0 ? keys.length : at, FitGridSortKey(columnId, next));
    }
    setSort(keys);
  }

  /// Replaces the whole sort, highest priority first.
  ///
  /// Keys naming a column that does not exist or is not sortable are dropped,
  /// as are repeats, so a sort restored from saved state cannot wedge the grid
  /// on a column that has since been removed.
  void setSort(List<FitGridSortKey> keys) {
    final kept = <FitGridSortKey>[];
    final comparators = <Comparator<T>>[];
    final seen = <String>{};
    for (final key in keys) {
      if (key.direction == FitGridSortDirection.none) continue;
      final column = columns.byId(key.columnId);
      if (column == null || !column.sortable || !seen.add(key.columnId)) {
        continue;
      }
      kept.add(key);
      comparators.add(column.compare);
    }
    data.sortBy(kept, comparators);
  }

  /// Removes every sort key, returning the rows to their supplied order.
  void clearSort() => data.sortBy(const <FitGridSortKey>[], <Comparator<T>>[]);

  /// The grid's contents in the shape an exporter wants.
  ///
  /// What is on screen, not what was handed in: the filter, the sort and the
  /// column order all apply, because an export that ignored them would not be
  /// the table the user is looking at. Pass [selectedOnly] to narrow it to the
  /// selection.
  ///
  /// Turn the result into a file with `fitGridToCsv`, `fitGridToTsv`, or your
  /// own writer — see [FitGridExportData] for why the formats are not in here.
  FitGridExportData export({
    bool selectedOnly = false,
    bool includeHeaders = true,
  }) => buildFitGridExport<T>(
    columns: columns.visible,
    rows: data.view,
    only: selectedOnly ? selection.selected : null,
    includeHeaders: includeHeaders,
  );

  /// A snapshot of the view — column layout, sort, filters, search and page —
  /// for the app to keep and hand back to [restoreState] later.
  ///
  /// Only structured filters are saved: a predicate set through
  /// `filter.setColumnFilter` is a closure, and there is no way to write one
  /// down.
  FitGridSavedState saveState() {
    final all = columns.columns;
    return FitGridSavedState(
      columnOrder: <String>[for (final column in all) column.id],
      hiddenColumns: <String>{
        for (final column in all)
          if (!column.visible) column.id,
      },
      frozenColumns: <String, FitGridFreeze>{
        for (final column in all) column.id: column.freeze,
      },
      columnWidths: columns.widthOverrides,
      sort: data.sortKeys,
      filters: filter.filters,
      query: filter.query,
      pageSize: pagination.enabled ? pagination.pageSize : null,
      pageIndex: pagination.enabled ? pagination.pageIndex : null,
    );
  }

  /// Puts back a view saved by [saveState].
  ///
  /// Forgiving by design: a column that has been removed since, or renamed,
  /// is skipped, and a sort or filter on it is dropped. Anything the state
  /// does not mention is left as it is.
  void restoreState(FitGridSavedState state) {
    columns.applyLayout(
      order: state.columnOrder,
      hidden: state.columnOrder.isEmpty ? null : state.hiddenColumns,
      freezes: state.frozenColumns,
      widths: state.columnWidths,
    );
    setSort(state.sort);
    filter.clearColumnFilters();
    for (final entry in state.filters.entries) {
      if (columns.byId(entry.key) != null) {
        filter.setFilter(entry.key, entry.value);
      }
    }
    filter.query = state.query;
    if (state.pageSize != null) pagination.pageSize = state.pageSize!;
    if (state.pageIndex != null) pagination.pageIndex = state.pageIndex!;
  }

  /// Moves a column so that it sits where [targetId] is now.
  ///
  /// Reordering speaks in ids rather than indices because the indices a header
  /// drag produces are into the *visible* columns, and the list being mutated
  /// includes the hidden ones.
  void moveColumnBefore(String movedId, String targetId) {
    if (movedId == targetId) return;
    final all = columns.columns;
    final from = all.indexWhere((column) => column.id == movedId);
    final to = all.indexWhere((column) => column.id == targetId);
    if (from < 0 || to < 0) return;
    columns.move(from, to);
  }

  void dispose() {
    _reveal = null;
    filter.removeListener(_applyFilter);
    columns.removeListener(_applyFilter);
    data.dispose();
    columns.dispose();
    selection.dispose();
    pagination.dispose();
    editing.dispose();
    focus.dispose();
    filter.dispose();
    grouping.dispose();
    range.dispose();
    details.dispose();
  }
}
