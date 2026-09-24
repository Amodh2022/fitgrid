import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../model/enums.dart';
import '../model/fitgrid_column.dart';
import '../sizing/column_layout.dart';
import '../theme/fitgrid_theme.dart';

/// The aggregate row under the grid.
///
/// One row, so it is widgets — the same trade the header makes. It follows the
/// body's band geometry so a pinned column's total stays under that column
/// while the rest scrolls, which is the only arrangement that reads as a total
/// rather than as a second set of values.
///
/// Aggregates are computed over the rows the grid is actually showing, filter
/// and all. A total that ignored the filter would be a different number from
/// the one the user can add up on screen, and they would be right to trust
/// theirs.
class FitGridFooter<T> extends StatelessWidget {
  const FitGridFooter({
    required this.columns,
    required this.layout,
    required this.theme,
    required this.horizontalOffset,
    required this.rows,
    super.key,
  });

  final List<FitGridColumn<T>> columns;
  final FitGridColumnLayout layout;
  final FitGridThemeData theme;
  final double horizontalOffset;

  /// The rows being aggregated — the filtered view, not the page.
  final List<T> rows;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return SizedBox(
      height: theme.effectiveHeaderHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxWidth;
          final leading = layout.leadingFrozenWidth;
          final trailing = layout.trailingFrozenWidth;

          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: theme.headerBackground),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Container(
                    height: theme.dividerThickness,
                    color: theme.border,
                  ),
                ),
                Positioned.directional(
                  textDirection: textDirection,
                  start: leading,
                  top: 0,
                  bottom: 0,
                  width: math.max(0.0, viewport - leading - trailing),
                  child: ClipRect(
                    child: _band(
                      textDirection,
                      layout.leadingFrozenCount,
                      layout.trailingFrozenStart,
                      leading + horizontalOffset,
                    ),
                  ),
                ),
                if (layout.leadingFrozenCount > 0)
                  Positioned.directional(
                    textDirection: textDirection,
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: leading,
                    child: _band(
                      textDirection,
                      0,
                      layout.leadingFrozenCount,
                      0,
                    ),
                  ),
                if (layout.trailingFrozenStart < layout.length)
                  Positioned.directional(
                    textDirection: textDirection,
                    start: viewport - trailing,
                    top: 0,
                    bottom: 0,
                    width: trailing,
                    child: _band(
                      textDirection,
                      layout.trailingFrozenStart,
                      layout.length,
                      layout.offsets[layout.trailingFrozenStart],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _band(
    TextDirection textDirection,
    int firstColumn,
    int lastColumn,
    double origin,
  ) {
    if (lastColumn <= firstColumn) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = firstColumn; i < lastColumn; i++)
          Positioned.directional(
            textDirection: textDirection,
            start: layout.offsets[i] - origin,
            top: 0,
            bottom: 0,
            width: layout.widths[i],
            child: _cell(columns[i]),
          ),
      ],
    );
  }

  Widget _cell(FitGridColumn<T> column) {
    final aggregate = column.aggregate;
    if (aggregate == null) return const SizedBox.shrink();
    final label = column.footerLabel;
    final value = aggregate(rows);

    return Padding(
      padding: theme.effectiveHeaderPadding,
      child: Row(
        mainAxisAlignment: switch (column.alignment) {
          FitGridAlignment.start => MainAxisAlignment.start,
          FitGridAlignment.center => MainAxisAlignment.center,
          FitGridAlignment.end => MainAxisAlignment.end,
        },
        children: [
          // One paragraph, label and value together: it takes the width it
          // needs and ellipsizes only at the end, only when the column really
          // is too narrow. Two Flexibles would split the room in half and cut
          // a long total off while space sat unused beside a short label.
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  if (label != null)
                    TextSpan(
                      text: '$label  ',
                      style: theme.headerTextStyle.copyWith(
                        color: theme.placeholderForeground,
                      ),
                    ),
                  TextSpan(text: value, style: theme.headerTextStyle),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
