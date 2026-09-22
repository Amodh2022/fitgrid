import 'dart:collection';

/// One page of a list, without copying it.
///
/// `rows.sublist(start, end)` would allocate and copy a fresh list on every
/// build, and a grid rebuilds on every scroll frame. This is a window onto the
/// original: O(1) to create, no copy, and it reads through to the source.
///
/// It also keeps [offset] to hand, which is what lets the grid report a global
/// row index to `onRowTap` and keep selection stable while the user pages back
/// and forth. Page-local indices would silently reselect a different row on
/// page two.
class FitGridPageView<T> extends ListBase<T> {
  FitGridPageView(this.source, this.offset, this.length)
    : assert(offset >= 0),
      assert(length >= 0),
      assert(offset + length <= source.length);

  /// An empty page over an empty source.
  static FitGridPageView<T> empty<T>() =>
      FitGridPageView<T>(const <Never>[], 0, 0);

  final List<T> source;

  /// Index in [source] of this page's first row.
  final int offset;

  @override
  final int length;

  @override
  set length(int value) =>
      throw UnsupportedError('FitGridPageView is a read-only view');

  @override
  T operator [](int index) => source[offset + index];

  @override
  void operator []=(int index, T value) =>
      throw UnsupportedError('FitGridPageView is a read-only view');
}
