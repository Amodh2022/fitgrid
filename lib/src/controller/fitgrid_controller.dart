import 'package:flutter/foundation.dart';

import '../model/enums.dart';
import '../model/fitgrid_column.dart';

/// Rows, and the ordering applied to them.
///
/// [view] is the list the grid actually renders: [rows] with the active sort
/// applied. It is recomputed when the rows or the sort change and cached in
/// between, because the render layer asks for row *i* many times per frame.
class FitGridDataState<T> extends ChangeNotifier {
  FitGridDataState({List<T> rows = const []}) : _rows = List<T>.of(rows);

  List<T> _rows;
  List<T>? _view;

  /// The rows as supplied, in their original order.
  List<T> get rows => List<T>.unmodifiable(_rows);

  set rows(List<T> value) {
    _rows = List<T>.of(value);
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
    final comparator = _comparator;
    if (comparator == null) return _rows;
    final sorted = List<T>.of(_rows);
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
  final Map<String, double> _widthOverrides = <String, double>{};

  List<FitGridColumn<T>> get columns =>
      List<FitGridColumn<T>>.unmodifiable(_columns);

  set columns(List<FitGridColumn<T>> value) {
    _columns = List<FitGridColumn<T>>.of(value);
    // Widths for columns that no longer exist would otherwise pin memory and
    // silently reapply if an id came back.
    _widthOverrides.removeWhere(
      (id, _) => !_columns.any((column) => column.id == id),
    );
    notifyListeners();
  }

  /// Visible columns in display order — what the sizer and renderer see.
  List<FitGridColumn<T>> get visible => <FitGridColumn<T>>[
    for (final c in _columns)
      if (c.visible) c,
  ];

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

  /// Returns a column to its declared width policy — what a double-click on the
  /// resize handle does, re-fitting it to its content.
  void clearWidth(String id) {
    if (_widthOverrides.remove(id) == null) return;
    notifyListeners();
  }

  void clearAllWidths() {
    if (_widthOverrides.isEmpty) return;
    _widthOverrides.clear();
    notifyListeners();
  }

  void setVisible(String id, bool visible) {
    final index = _columns.indexWhere((column) => column.id == id);
    if (index < 0 || _columns[index].visible == visible) return;
    _columns[index] = _columns[index].copyWith(visible: visible);
    notifyListeners();
  }

  /// Moves a column within the display order.
  void move(int from, int to) {
    if (from == to || from < 0 || from >= _columns.length) return;
    final column = _columns.removeAt(from);
    _columns.insert(to.clamp(0, _columns.length), column);
    notifyListeners();
  }
}

/// Which rows are selected.
class FitGridSelectionState extends ChangeNotifier {
  final Set<int> _selected = <int>{};

  Set<int> get selected => Set<int>.unmodifiable(_selected);

  bool get isEmpty => _selected.isEmpty;

  int get length => _selected.length;

  bool contains(int rowIndex) => _selected.contains(rowIndex);

  void toggle(int rowIndex) {
    if (!_selected.remove(rowIndex)) _selected.add(rowIndex);
    notifyListeners();
  }

  void select(Iterable<int> rowIndices, {bool replace = true}) {
    if (replace) _selected.clear();
    _selected.addAll(rowIndices);
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
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
  }) : data = FitGridDataState<T>(rows: rows),
       columns = FitGridColumnState<T>(columns: columns);

  /// Rows and their ordering.
  final FitGridDataState<T> data;

  /// Column order, visibility and widths.
  final FitGridColumnState<T> columns;

  /// Selected rows.
  final FitGridSelectionState selection = FitGridSelectionState();

  /// Cycles the sort on a column: ascending, descending, unsorted.
  void toggleSort(String columnId) {
    final column = columns.byId(columnId);
    if (column == null || !column.sortable) return;
    data.sort(columnId, data.nextDirectionFor(columnId), column.compare);
  }

  void dispose() {
    data.dispose();
    columns.dispose();
    selection.dispose();
  }
}
