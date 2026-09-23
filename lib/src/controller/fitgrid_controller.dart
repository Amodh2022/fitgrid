import 'package:flutter/foundation.dart';

import '../model/enums.dart';
import '../model/fitgrid_column.dart';
import '../sizing/column_order.dart';
import 'fitgrid_editing.dart';
import 'fitgrid_filter.dart';
import 'fitgrid_focus.dart';
import 'fitgrid_grouping.dart';
import 'fitgrid_pagination.dart';

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

  String? _sortColumnId;

  /// Id of the column currently ordering the grid, or null when unsorted.
  String? get sortColumnId => _sortColumnId;

  FitGridSortDirection _sortDirection = FitGridSortDirection.none;
  FitGridSortDirection get sortDirection => _sortDirection;

  Comparator<T>? _comparator;

  /// The rows in display order.
  List<T> get view => _view ??= _buildView();

  int get length => view.length;

  T operator [](int index) => view[index];

  /// Applies a sort. Passing [FitGridSortDirection.none] clears it and returns
  /// the rows to their original order — which is why the unsorted list is kept
  /// rather than sorted in place.
  void sort(
    String columnId,
    FitGridSortDirection direction,
    Comparator<T> comparator,
  ) {
    _sortColumnId = direction == FitGridSortDirection.none ? null : columnId;
    _sortDirection = direction;
    _comparator = direction == FitGridSortDirection.none ? null : comparator;
    _view = null;
    notifyListeners();
  }

  /// The next state in the tri-state cycle for [columnId]: ascending, then
  /// descending, then unsorted.
  FitGridSortDirection nextDirectionFor(String columnId) {
    if (_sortColumnId != columnId) return FitGridSortDirection.ascending;
    return switch (_sortDirection) {
      FitGridSortDirection.ascending => FitGridSortDirection.descending,
      FitGridSortDirection.descending => FitGridSortDirection.none,
      FitGridSortDirection.none => FitGridSortDirection.ascending,
    };
  }

  List<T> _buildView() {
    final filter = _filter;
    final comparator = _comparator;
    // An unfiltered, unsorted grid hands back the original list rather than a
    // copy of it: downstream caches are keyed on its identity, so copying here
    // would invalidate the column measurement on every build.
    if (filter == null && comparator == null) return _rows;
    final base = filter == null
        ? _rows
        : <T>[
            for (final row in _rows)
              if (filter(row)) row,
          ];
    if (comparator == null) return base;
    final sorted = List<T>.of(base);
    final sign = _sortDirection == FitGridSortDirection.descending ? -1 : 1;
    sorted.sort((a, b) => sign * comparator(a, b));
    return sorted;
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
    if (rowIndex < 0 || rowIndex >= data.length) return;
    if (pagination.enabled) pagination.revealRow(rowIndex);
    _reveal?.call(rowIndex, columnId, padding);
  }

  /// Cycles the sort on a column: ascending, descending, unsorted.
  void toggleSort(String columnId) {
    final column = columns.byId(columnId);
    if (column == null || !column.sortable) return;
    data.sort(columnId, data.nextDirectionFor(columnId), column.compare);
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
  }
}
