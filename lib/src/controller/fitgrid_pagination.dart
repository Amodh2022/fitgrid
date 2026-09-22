import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Which page of the rows is on screen, and how big a page is.
///
/// Its own notifier, like everything else in the controller cluster: turning a
/// page must not re-measure columns or invalidate the sort, and sorting must
/// not reset the page size. Turning a page costs nothing but a new window onto
/// the same list — see `FitGridPageView` — so a paged grid does no more work
/// per page than an unpaged one does per scroll.
class FitGridPaginationState extends ChangeNotifier {
  FitGridPaginationState({
    bool enabled = false,
    int pageSize = 25,
    List<int> pageSizeOptions = const <int>[10, 25, 50, 100],
  }) : assert(pageSize > 0, 'pageSize must be positive'),
       _enabled = enabled,
       _pageSize = pageSize,
       _pageSizeOptions = List<int>.unmodifiable(pageSizeOptions);

  bool _enabled;

  /// Whether the grid shows one page at a time rather than scrolling the lot.
  bool get enabled => _enabled;
  set enabled(bool value) {
    if (_enabled == value) return;
    _enabled = value;
    notifyListeners();
  }

  int _pageSize;

  /// Rows per page.
  int get pageSize => _pageSize;
  set pageSize(int value) {
    assert(value > 0, 'pageSize must be positive');
    if (_pageSize == value) return;
    // Keep the first row of the current page on screen rather than jumping to
    // the top: changing the page size is a zoom, not a navigation.
    final anchor = firstRowIndex;
    _pageSize = value;
    _pageIndex = anchor ~/ value;
    _clampPage();
    notifyListeners();
  }

  /// Offered in the built-in pager's page-size menu.
  List<int> _pageSizeOptions;
  List<int> get pageSizeOptions => _pageSizeOptions;
  set pageSizeOptions(List<int> value) {
    if (listEquals(_pageSizeOptions, value)) return;
    _pageSizeOptions = List<int>.unmodifiable(value);
    notifyListeners();
  }

  int _pageIndex = 0;

  /// Zero-based index of the page on screen.
  int get pageIndex => _pageIndex;
  set pageIndex(int value) {
    final next = value.clamp(0, math.max(0, pageCount - 1)) as int;
    if (_pageIndex == next) return;
    _pageIndex = next;
    notifyListeners();
  }

  int _rowCount = 0;

  /// Total rows across every page. The grid keeps this in step with the data.
  int get rowCount => _rowCount;
  set rowCount(int value) {
    if (_rowCount == value) return;
    _rowCount = value;
    // A filter or a deletion can strip out the page the user was on.
    final before = _pageIndex;
    _clampPage();
    if (before != _pageIndex) notifyListeners();
  }

  /// Number of pages, at least one even when there are no rows — an empty grid
  /// still reads as "page 1 of 1" rather than "page 1 of 0".
  int get pageCount =>
      _rowCount <= 0 ? 1 : (_rowCount + _pageSize - 1) ~/ _pageSize;

  /// Index in the full row list of this page's first row.
  int get firstRowIndex => _pageIndex * _pageSize;

  /// Index one past this page's last row.
  int get endRowIndex => math.min(firstRowIndex + _pageSize, _rowCount);

  /// How many rows this page actually holds. The last page is usually short.
  int get rowsOnPage => math.max(0, endRowIndex - firstRowIndex);

  bool get hasPrevious => _pageIndex > 0;
  bool get hasNext => _pageIndex < pageCount - 1;

  void first() => pageIndex = 0;
  void previous() => pageIndex = _pageIndex - 1;
  void next() => pageIndex = _pageIndex + 1;
  void last() => pageIndex = pageCount - 1;

  /// Moves to whichever page holds [rowIndex] of the full list.
  void revealRow(int rowIndex) => pageIndex = rowIndex ~/ _pageSize;

  void _clampPage() {
    final max = math.max(0, pageCount - 1);
    if (_pageIndex > max) _pageIndex = max;
    if (_pageIndex < 0) _pageIndex = 0;
  }
}
