import 'package:flutter/foundation.dart';
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
    this.icon,
    this.iconColor,
    this.iconSize,
    this.highlights = const <int>[],
    this.semanticLabel,
  });

  /// A blank cell. Handed out for rows a [FitGridDataSource] has not delivered
  /// yet, where there is nothing to paint but the geometry still has to exist.
  static const FitGridCellSpec empty = FitGridCellSpec(
    text: '',
    style: TextStyle(),
    alignment: FitGridAlignment.start,
    overflow: FitGridOverflow.clip,
  );

  final String text;
  final TextStyle style;
  final FitGridAlignment alignment;
  final FitGridOverflow overflow;

  /// Line budget for this cell, or null for as many lines as it takes. Part of
  /// the spec rather than the column config because it changes what the cached
  /// painter laid out, and so has to take part in the equality check below.
  final int? maxLines;

  /// A glyph painted before the text, sharing the cell's single painter.
  ///
  /// An icon is a character in a font, so painting one costs what painting a
  /// letter costs. That is the whole reason it lives here instead of forcing
  /// the column into the widget overlay: a status dot or a checkbox should not
  /// turn a painted column into ten thousand `Icon` widgets.
  final IconData? icon;
  final Color? iconColor;
  final double? iconSize;

  /// Ranges of [text] to paint a highlight behind, as flat `start, end` pairs
  /// in UTF-16 offsets.
  ///
  /// Flat rather than a list of objects because this is compared on every
  /// build of a grid being typed into, and a list of two ints compares in two
  /// comparisons.
  final List<int> highlights;

  /// What a screen reader announces for this cell, when that should differ
  /// from the painted text — a raw timestamp painted as "3m ago", say.
  final String? semanticLabel;

  bool get hasHighlights => highlights.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridCellSpec &&
          other.text == text &&
          other.style == style &&
          other.alignment == alignment &&
          other.overflow == overflow &&
          other.maxLines == maxLines &&
          other.icon == icon &&
          other.iconColor == iconColor &&
          other.iconSize == iconSize &&
          other.semanticLabel == semanticLabel &&
          listEquals(other.highlights, highlights);

  @override
  int get hashCode => Object.hash(
    text,
    style,
    alignment,
    overflow,
    maxLines,
    icon,
    iconColor,
    iconSize,
    semanticLabel,
    Object.hashAll(highlights),
  );

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
    this.freeze = FitGridFreeze.none,
    this.label = '',
  });

  final FitGridAlignment alignment;
  final FitGridOverflow overflow;

  /// Whether this column's cells are real widgets in the overlay layer rather
  /// than painted text. Widget columns are skipped entirely by the text pass.
  final bool isWidgetColumn;

  /// Whether the column is pinned to an edge.
  final FitGridFreeze freeze;

  /// The column's header text. Carried into the render layer only so the
  /// semantics tree can name a cell's column without a `BuildContext`.
  final String label;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridPaintColumn &&
          other.alignment == alignment &&
          other.overflow == overflow &&
          other.isWidgetColumn == isWidgetColumn &&
          other.freeze == freeze &&
          other.label == label;

  @override
  int get hashCode =>
      Object.hash(alignment, overflow, isWidgetColumn, freeze, label);
}
