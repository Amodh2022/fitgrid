import 'dart:collection';

import 'package:flutter/foundation.dart';

import 'enums.dart';

/// What the grid asks a [FitGridAsyncDataSource] for.
@immutable
class FitGridPageRequest {
  const FitGridPageRequest({
    required this.offset,
    required this.limit,
    this.sortColumnId,
    this.sortDirection = FitGridSortDirection.none,
    this.query = '',
  });

  /// Index of the first row wanted, into the full result set.
  final int offset;

  /// How many rows are wanted.
  final int limit;

  /// The column the grid is sorted by, or null. Sorting is the source's job
  /// here, not the grid's: sorting a window of fifty rows out of a million
  /// would produce an order that changes every time the user scrolls.
  final String? sortColumnId;
  final FitGridSortDirection sortDirection;

  /// The active search text, or empty.
  final String query;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridPageRequest &&
          other.offset == offset &&
          other.limit == limit &&
          other.sortColumnId == sortColumnId &&
          other.sortDirection == sortDirection &&
          other.query == query;

  @override
  int get hashCode =>
      Object.hash(offset, limit, sortColumnId, sortDirection, query);

  @override
  String toString() => 'FitGridPageRequest($offset..${offset + limit})';
}

/// What the source hands back.
@immutable
class FitGridPageResult<T> {
  const FitGridPageResult({required this.rows, this.totalCount});

  final List<T> rows;

  /// How many rows match in total, if the backend will say. Null leaves the
  /// count as it was, which is what an endpoint that only ever returns "here
  /// are the next twenty" forces — and the grid then grows its scrollbar as
  /// pages arrive rather than pretending to know the end.
  final int? totalCount;
}

/// Rows the grid does not hold.
///
/// The in-memory path stays the default and stays simple; this exists because a
/// grid whose whole argument is "it does not cost anything per row" should not
/// fall over at the point where the rows stop fitting in memory.
///
/// Sorting and filtering belong to the source, not to the grid, whenever one is
/// attached. The grid will not reorder a window: that is the bug where page two
/// is sorted and page three is not.
abstract class FitGridDataSource<T> extends ChangeNotifier {
  /// How many rows there are in total, as far as anyone currently knows.
  int get rowCount;

  /// The row at a global index, or null when it has not loaded.
  T? rowAt(int index);

  /// Tells the source which rows are on screen. Called during build, so it must
  /// be cheap and must not notify synchronously.
  void loadWindow(int first, int last) {}

  /// Passes the grid's sort on. A source that sorts on the server should drop
  /// its cache and refetch.
  void sortBy(String? columnId, FitGridSortDirection direction) {}

  /// Passes the grid's search text on.
  void search(String query) {}

  /// Whether a fetch is outstanding. Drives the grid's loading affordance.
  bool get isLoading => false;

  /// The last error, if the most recent fetch failed.
  Object? get error => null;

  /// Discards everything and starts again.
  void refresh() {}
}

/// A [FitGridDataSource] that fetches fixed-size pages through a callback and
/// caches the ones it has.
///
/// The cache is bounded and evicted furthest-from-the-window first, so scrolling
/// through a million rows costs a bounded amount of memory rather than an
/// ever-growing one — the same discipline the painter cache follows, applied one
/// layer up.
class FitGridAsyncDataSource<T> extends FitGridDataSource<T> {
  FitGridAsyncDataSource({
    required this.fetch,
    this.pageSize = 100,
    this.maxCachedPages = 24,
    int initialRowCount = 0,
  }) : assert(pageSize > 0),
       assert(maxCachedPages > 0),
       _rowCount = initialRowCount;

  /// Fetches one page. Called at most once per page per generation.
  final Future<FitGridPageResult<T>> Function(FitGridPageRequest request) fetch;

  final int pageSize;

  /// How many pages to keep. Beyond this the pages furthest from the viewport
  /// are dropped.
  final int maxCachedPages;

  final Map<int, List<T>> _pages = <int, List<T>>{};
  final Set<int> _inFlight = <int>{};
  final Queue<int> _recency = Queue<int>();

  int _rowCount;
  int _generation = 0;
  Object? _error;
  String? _sortColumnId;
  FitGridSortDirection _sortDirection = FitGridSortDirection.none;
  String _query = '';

  @override
  int get rowCount => _rowCount;

  @override
  bool get isLoading => _inFlight.isNotEmpty;

  @override
  Object? get error => _error;

  /// How many pages are resident. Observable so a test can prove the cache
  /// stays bounded while scrolling.
  int get cachedPageCount => _pages.length;

  @override
  T? rowAt(int index) {
    if (index < 0 || index >= _rowCount) return null;
    final page = _pages[index ~/ pageSize];
    if (page == null) return null;
    final within = index % pageSize;
    return within < page.length ? page[within] : null;
  }

  @override
  void loadWindow(int first, int last) {
    if (last < first) return;
    final from = (first ~/ pageSize).clamp(0, 1 << 30);
    final to = (last ~/ pageSize).clamp(0, 1 << 30);
    for (var page = from; page <= to; page++) {
      _touch(page);
      _request(page);
    }
    _evict(from, to);
  }

  @override
  void sortBy(String? columnId, FitGridSortDirection direction) {
    if (_sortColumnId == columnId && _sortDirection == direction) return;
    _sortColumnId = columnId;
    _sortDirection = direction;
    _invalidate();
  }

  @override
  void search(String query) {
    if (_query == query) return;
    _query = query;
    // A different query is a different result set, so the row count is no
    // longer trustworthy either. Keeping it would leave the scrollbar claiming
    // rows the backend will never return.
    _rowCount = 0;
    _invalidate();
  }

  @override
  void refresh() => _invalidate();

  void _invalidate() {
    _generation++;
    _pages.clear();
    _recency.clear();
    _inFlight.clear();
    _error = null;
    notifyListeners();
  }

  void _touch(int page) {
    _recency
      ..remove(page)
      ..addLast(page);
  }

  void _evict(int keepFrom, int keepTo) {
    while (_pages.length > maxCachedPages && _recency.isNotEmpty) {
      final oldest = _recency.removeFirst();
      if (oldest >= keepFrom && oldest <= keepTo) {
        _recency.addLast(oldest);
        // Everything left is inside the window; there is nothing safe to drop.
        if (_recency.length <= keepTo - keepFrom + 1) break;
        continue;
      }
      _pages.remove(oldest);
    }
  }

  void _request(int page) {
    if (_pages.containsKey(page) || _inFlight.contains(page)) return;
    final generation = _generation;
    _inFlight.add(page);

    fetch(
          FitGridPageRequest(
            offset: page * pageSize,
            limit: pageSize,
            sortColumnId: _sortColumnId,
            sortDirection: _sortDirection,
            query: _query,
          ),
        )
        .then((result) {
          // A sort or a search that landed while this was in flight makes the
          // answer wrong, not late. Dropping it is the only correct move.
          if (generation != _generation) return;
          _pages[page] = result.rows;
          _touch(page);
          if (result.totalCount != null) {
            _rowCount = result.totalCount!;
          } else {
            // No count from the backend: grow to cover what has arrived, and
            // assume there is more while pages keep coming back full.
            final seen = page * pageSize + result.rows.length;
            _rowCount = result.rows.length < pageSize
                ? seen
                : (_rowCount > seen ? _rowCount : seen + 1);
          }
          _error = null;
        })
        .catchError((Object error) {
          if (generation != _generation) return;
          _error = error;
        })
        .whenComplete(() {
          if (generation != _generation) return;
          _inFlight.remove(page);
          notifyListeners();
        });
  }
}
