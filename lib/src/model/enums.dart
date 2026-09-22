/// Horizontal placement of a cell's content within its column.
enum FitGridAlignment { start, center, end }

/// What a cell does when its text is wider than the column.
///
/// The grid paints its own text, so it always knows whether a given cell
/// actually overflowed. That is what makes [tooltipOnTruncate] cheap here and
/// awkward in a widget-per-cell table, where detecting truncation means laying
/// the text out a second time.
enum FitGridOverflow {
  /// Clip at the column edge with a trailing ellipsis.
  ellipsis,

  /// Clip at the column edge with a soft alpha fade.
  fade,

  /// Hard clip, no affordance.
  clip,

  /// Ellipsize, and show a tooltip with the full text on hover — but only for
  /// the cells that were actually truncated.
  tooltipOnTruncate,
}

/// Which edge, if any, a column is pinned to while the body scrolls sideways.
enum FitGridFreeze { none, start, end }

/// Vertical rhythm. Scales row height and cell padding together.
enum FitGridDensity { compact, standard, comfortable }

/// Sort state of a single column. Sorting is tri-state: the third tap on a
/// header clears the sort rather than cycling back to ascending.
enum FitGridSortDirection { ascending, descending, none }
