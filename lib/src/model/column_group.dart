import 'package:flutter/foundation.dart';

/// A band in the header spanning several columns — "Q1" over January,
/// February and March.
///
/// Membership is by column id, so a group follows its columns wherever the
/// user drags them. When a drag or a pin splits a group's columns apart, each
/// contiguous run gets its own band with the same label rather than one band
/// stretched over columns that are not its own.
@immutable
class FitGridColumnGroup {
  const FitGridColumnGroup({
    required this.id,
    required this.label,
    required this.columnIds,
    this.tooltip,
  });

  /// Stable identity, for keys and semantics.
  final String id;

  final String label;

  /// The columns under this band. A column belongs to at most one group; if
  /// two groups claim it, the first one listed wins.
  final List<String> columnIds;

  final String? tooltip;

  @override
  bool operator ==(Object other) =>
      other is FitGridColumnGroup &&
      other.id == id &&
      other.label == label &&
      other.tooltip == tooltip &&
      listEquals(other.columnIds, columnIds);

  @override
  int get hashCode =>
      Object.hash(id, label, tooltip, Object.hashAll(columnIds));
}
