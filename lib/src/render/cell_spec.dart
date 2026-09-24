import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../model/enums.dart';

/// Which painted chart a cell carries.
enum FitGridVisualKind { bar, progress, sparkline }

/// A chart painted into a cell, already reduced to geometry: fractions of the
/// cell's content box, so the render layer needs nothing but the box to draw
/// it and the spec compares cheaply.
@immutable
class FitGridCellVisualSpec {
  /// A bar spanning [from] to [to] across the cell — from the zero line to
  /// the value, so a negative value extends the other way.
  const FitGridCellVisualSpec.bar({
    required this.from,
    required this.to,
    this.negative = false,
    this.color,
  }) : kind = FitGridVisualKind.bar,
       points = const <double>[],
       filled = false;

  /// A progress track, filled to [to].
  const FitGridCellVisualSpec.progress({required this.to, this.color})
    : kind = FitGridVisualKind.progress,
      from = 0,
      negative = false,
      points = const <double>[],
      filled = false;

  /// A line through [points], each 0 at the bottom of the cell and 1 at the
  /// top, spaced evenly across it.
  const FitGridCellVisualSpec.sparkline({
    required this.points,
    this.filled = false,
    this.color,
  }) : kind = FitGridVisualKind.sparkline,
       from = 0,
       to = 0,
       negative = false;

  final FitGridVisualKind kind;
  final double from;
  final double to;
  final bool negative;
  final List<double> points;
  final bool filled;

  /// Null follows the theme's chart colour.
  final Color? color;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FitGridCellVisualSpec &&
          other.kind == kind &&
          other.from == from &&
          other.to == to &&
          other.negative == negative &&
          other.filled == filled &&
          other.color == color &&
          listEquals(other.points, points);

  @override
  int get hashCode => Object.hash(
    kind,
    from,
    to,
    negative,
    filled,
    color,
    Object.hashAll(points),
  );
}

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
    this.placeholder = false,
    this.visual,
  });

  /// A skeleton bar standing in for content that is on its way — a row a data
  /// source is still fetching, or the rows below the end while more load.
  ///
  /// Painted as a rounded bar rather than left blank, because a blank row
  /// reads as "nothing here" while a bar reads as "something coming".
  static const FitGridCellSpec loading = FitGridCellSpec(
    text: '',
    style: TextStyle(),
    alignment: FitGridAlignment.start,
    overflow: FitGridOverflow.clip,
    placeholder: true,
    semanticLabel: 'Loading',
  );

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

  /// Whether this cell paints a skeleton bar instead of text.
  final bool placeholder;

  /// A chart painted beneath the text, or null.
  final FitGridCellVisualSpec? visual;

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
          other.placeholder == placeholder &&
          other.visual == visual &&
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
    placeholder,
    visual,
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
