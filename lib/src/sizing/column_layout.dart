import 'package:flutter/foundation.dart';

/// The resolved horizontal geometry of a grid: which columns are visible, how
/// wide each one is, and where each one starts.
///
/// [offsets] is a prefix sum with one extra trailing entry, so the span of
/// column `i` is `offsets[i]..offsets[i + 1]` and `offsets.last` is the total
/// content width. Keeping it precomputed is what lets the render layer binary
/// search for the first visible column instead of walking from zero on every
/// paint.
@immutable
class FitGridColumnLayout {
  FitGridColumnLayout({required this.ids, required this.widths})
    : assert(ids.length == widths.length),
      offsets = _prefixSums(widths);

  const FitGridColumnLayout._(this.ids, this.widths, this.offsets);

  /// An empty layout, for a grid with no visible columns.
  static const FitGridColumnLayout empty = FitGridColumnLayout._(
    <String>[],
    <double>[],
    <double>[0.0],
  );

  /// Ids of the visible columns, in display order.
  final List<String> ids;

  /// Resolved width of each visible column, parallel to [ids].
  final List<double> widths;

  /// Prefix sums of [widths], length `widths.length + 1`.
  final List<double> offsets;

  /// Total width of all visible columns.
  double get totalWidth => offsets.last;

  int get length => ids.length;

  bool get isEmpty => ids.isEmpty;

  double widthOf(String id) {
    final index = ids.indexOf(id);
    return index < 0 ? 0.0 : widths[index];
  }

  /// Index of the first column whose right edge is past [x], or [length] when
  /// [x] is past the end. Binary search over [offsets].
  int columnAtOffset(double x) {
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
          listEquals(other.widths, widths);

  @override
  int get hashCode => Object.hash(Object.hashAll(ids), Object.hashAll(widths));

  @override
  String toString() =>
      'FitGridColumnLayout(${ids.length} columns, ${totalWidth.toStringAsFixed(1)}px)';
}
