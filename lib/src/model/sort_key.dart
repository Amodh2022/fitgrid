import 'package:flutter/foundation.dart';

import 'enums.dart';

/// One level of a sort: a column and which way it runs.
///
/// A grid sorted by several columns holds these in priority order. The first
/// decides, the second breaks its ties, and so on — the order a spreadsheet's
/// "sort by, then by" dialog produces.
@immutable
class FitGridSortKey {
  const FitGridSortKey(this.columnId, this.direction);

  final String columnId;

  /// Never [FitGridSortDirection.none] in a live sort: a column that is not
  /// sorted is simply not in the list.
  final FitGridSortDirection direction;

  bool get descending => direction == FitGridSortDirection.descending;

  @override
  bool operator ==(Object other) =>
      other is FitGridSortKey &&
      other.columnId == columnId &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(columnId, direction);

  @override
  String toString() => 'FitGridSortKey($columnId, ${direction.name})';
}
