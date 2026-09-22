import 'package:flutter/widgets.dart';

import '../model/enums.dart';

/// Everything the render layer needs to paint one text cell.
///
/// Resolved at build time, because painting happens where there is no
/// `BuildContext` to look anything up. Cheap value equality matters: it decides
/// whether a cached `TextPainter` can be reused or has to be laid out again.
@immutable
class FitGridCellSpec {
  const FitGridCellSpec({
    required this.text,
    required this.style,
    required this.alignment,
    required this.overflow,
    this.maxLines = 1,
  });

  final String text;
  final TextStyle style;
  final FitGridAlignment alignment;
  final FitGridOverflow overflow;

  /// Line budget for this cell, or null for as many lines as it takes. Part of
  /// the spec rather than the column config because it changes what the cached
  /// painter laid out, and so has to take part in the equality check below.
  final int? maxLines;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridCellSpec &&
          other.text == text &&
          other.style == style &&
          other.alignment == alignment &&
          other.overflow == overflow &&
          other.maxLines == maxLines;

  @override
  int get hashCode => Object.hash(text, style, alignment, overflow, maxLines);

  @override
  String toString() => 'FitGridCellSpec("$text")';
}

/// Static per-column paint configuration, parallel to a
/// [FitGridColumnLayout]'s columns.
@immutable
class FitGridPaintColumn {
  const FitGridPaintColumn({
    required this.alignment,
    required this.overflow,
    required this.isWidgetColumn,
  });

  final FitGridAlignment alignment;
  final FitGridOverflow overflow;

  /// Whether this column's cells are real widgets in the overlay layer rather
  /// than painted text. Widget columns are skipped entirely by the text pass.
  final bool isWidgetColumn;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridPaintColumn &&
          other.alignment == alignment &&
          other.overflow == overflow &&
          other.isWidgetColumn == isWidgetColumn;

  @override
  int get hashCode => Object.hash(alignment, overflow, isWidgetColumn);
}
