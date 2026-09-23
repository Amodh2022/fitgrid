import 'package:flutter/foundation.dart';

import '../model/enums.dart';

/// The resolved horizontal geometry of a grid: which columns are visible, how
/// wide each one is, where each one starts, and which of them are pinned to an
/// edge instead of scrolling.
///
/// [offsets] is a prefix sum with one extra trailing entry, so the span of
/// column `i` is `offsets[i]..offsets[i + 1]` and `offsets.last` is the total
/// content width. Keeping it precomputed is what lets the render layer binary
/// search for the first visible column instead of walking from zero on every
/// paint.
///
/// Frozen columns are not a separate structure. The visible columns arrive
/// already partitioned — leading-pinned, then scrolling, then trailing-pinned —
/// so the three bands are contiguous index ranges over the same arrays, and
/// every offset below is still one subtraction. Anything else would mean three
/// parallel layouts that have to be kept in agreement.
@immutable
class FitGridColumnLayout {
  FitGridColumnLayout({
    required this.ids,
    required this.widths,
    List<FitGridFreeze>? freezes,
  }) : assert(ids.length == widths.length),
       assert(freezes == null || freezes.length == ids.length),
       freezes =
           freezes ??
           List<FitGridFreeze>.filled(ids.length, FitGridFreeze.none),
       offsets = _prefixSums(widths),
       leadingFrozenCount = _countLeading(freezes),
       trailingFrozenStart = _trailingStart(freezes, ids.length);

  const FitGridColumnLayout._(
    this.ids,
    this.widths,
    this.offsets,
    this.freezes,
    this.leadingFrozenCount,
    this.trailingFrozenStart,
  );

  /// An empty layout, for a grid with no visible columns.
  static const FitGridColumnLayout empty = FitGridColumnLayout._(
    <String>[],
    <double>[],
    <double>[0.0],
    <FitGridFreeze>[],
    0,
    0,
  );

  /// Ids of the visible columns, in display order.
  final List<String> ids;

  /// Resolved width of each visible column, parallel to [ids].
  final List<double> widths;

  /// Prefix sums of [widths], length `widths.length + 1`.
  final List<double> offsets;

  /// Freeze state of each visible column, parallel to [ids]. Sorted: every
  /// [FitGridFreeze.start] precedes every [FitGridFreeze.none], which precedes
  /// every [FitGridFreeze.end].
  final List<FitGridFreeze> freezes;

  /// How many columns are pinned to the leading edge. They occupy
  /// `0..leadingFrozenCount`.
  final int leadingFrozenCount;

  /// Index of the first column pinned to the trailing edge, or [length] when
  /// none are. They occupy `trailingFrozenStart..length`.
  final int trailingFrozenStart;

  /// Total width of all visible columns.
  double get totalWidth => offsets.last;

  int get length => ids.length;

  bool get isEmpty => ids.isEmpty;

  /// Whether any column is pinned. The render layer takes a markedly cheaper
  /// path when nothing is, which is the common case.
  bool get hasFrozenColumns =>
      leadingFrozenCount > 0 || trailingFrozenStart < length;

  /// Screen width taken by the leading pinned band.
  double get leadingFrozenWidth => offsets[leadingFrozenCount];

  /// Screen width taken by the trailing pinned band.
  double get trailingFrozenWidth => totalWidth - offsets[trailingFrozenStart];

  /// Content width of the columns that actually scroll.
  double get scrollableWidth =>
      offsets[trailingFrozenStart] - offsets[leadingFrozenCount];

  /// Whether column [index] scrolls rather than being pinned.
  bool scrolls(int index) =>
      index >= leadingFrozenCount && index < trailingFrozenStart;

  double widthOf(String id) {
    final index = ids.indexOf(id);
    return index < 0 ? 0.0 : widths[index];
  }

  int indexOf(String id) => ids.indexOf(id);

  /// Index of the first column whose trailing edge is past [x] in content
  /// space, or [length] when [x] is past the end. Binary search over [offsets].
  int columnAtOffset(double x) {
    if (length == 0) return 0;
    if (x <= 0) return 0;
    if (x >= totalWidth) return length;
    var low = 0;
    var high = length - 1;
    while (low < high) {
      final mid = (low + high) >> 1;
      if (offsets[mid + 1] <= x) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// [columnAtOffset] confined to the scrolling band, which is what the render
  /// layer wants when it maps a pointer that missed both pinned bands.
  int scrollableColumnAtOffset(double x) {
    if (trailingFrozenStart <= leadingFrozenCount) return -1;
    final index = columnAtOffset(x);
    if (index < leadingFrozenCount || index >= trailingFrozenStart) return -1;
    return index;
  }

  static int _countLeading(List<FitGridFreeze>? freezes) {
    if (freezes == null) return 0;
    var count = 0;
    while (count < freezes.length && freezes[count] == FitGridFreeze.start) {
      count++;
    }
    return count;
  }

  static int _trailingStart(List<FitGridFreeze>? freezes, int length) {
    if (freezes == null) return length;
    var start = length;
    while (start > 0 && freezes[start - 1] == FitGridFreeze.end) {
      start--;
    }
    return start;
  }

  static List<double> _prefixSums(List<double> widths) {
    final sums = List<double>.filled(widths.length + 1, 0.0);
    var running = 0.0;
    for (var i = 0; i < widths.length; i++) {
      running += widths[i];
      sums[i + 1] = running;
    }
    return sums;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridColumnLayout &&
          listEquals(other.ids, ids) &&
          listEquals(other.widths, widths) &&
          listEquals(other.freezes, freezes);

  @override
  int get hashCode => Object.hash(
    Object.hashAll(ids),
    Object.hashAll(widths),
    Object.hashAll(freezes),
  );

  @override
  String toString() =>
      'FitGridColumnLayout(${ids.length} columns, '
      '${totalWidth.toStringAsFixed(1)}px'
      '${hasFrozenColumns ? ', $leadingFrozenCount+${length - trailingFrozenStart} frozen' : ''})';
}
