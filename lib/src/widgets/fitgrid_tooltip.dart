import 'package:flutter/widgets.dart';

import '../theme/fitgrid_theme.dart';

/// A cell the pointer is over whose text did not fit.
@immutable
class FitGridTooltipTarget {
  const FitGridTooltipTarget({
    required this.row,
    required this.column,
    required this.text,
    required this.anchor,
  });

  final int row;
  final int column;
  final String text;

  /// Where to hang the tooltip, in the grid's local coordinates.
  final Offset anchor;

  bool sameCell(FitGridTooltipTarget? other) =>
      other != null && other.row == row && other.column == column;
}

/// The floating label shown over a truncated cell.
///
/// Worth having as its own widget only because of where the information comes
/// from. In a widget-per-cell table, knowing that a cell clipped means laying
/// its text out a second time, so tables there either show a tooltip on every
/// cell or none. Here the render layer already recorded it while painting, so
/// the tooltip appears on exactly the cells that lost text and nowhere else.
class FitGridTooltip extends StatelessWidget {
  const FitGridTooltip({
    required this.target,
    required this.theme,
    required this.bounds,
    super.key,
  });

  final FitGridTooltipTarget target;
  final FitGridThemeData theme;

  /// The grid's own box, so the label can be kept inside it.
  final Size bounds;

  static const double _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final label = DecoratedBox(
      decoration: BoxDecoration(
        color: theme.tooltipBackground,
        borderRadius: theme.tooltipBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          target.text,
          style: theme.cellTextStyle.copyWith(color: theme.tooltipForeground),
        ),
      ),
    );

    return Positioned(
      // Clamped so a tooltip near the right edge folds back inside rather than
      // being clipped away by the grid's own rounded corners.
      left: target.anchor.dx.clamp(
        0.0,
        (bounds.width - theme.tooltipMaxWidth).clamp(0.0, double.infinity),
      ),
      top: (target.anchor.dy + _gap).clamp(0.0, bounds.height),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: theme.tooltipMaxWidth),
        child: label,
      ),
    );
  }
}
