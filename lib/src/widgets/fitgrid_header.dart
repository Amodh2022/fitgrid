import 'package:flutter/material.dart';

import '../model/enums.dart';
import '../model/fitgrid_column.dart';
import '../sizing/column_layout.dart';
import '../theme/fitgrid_theme.dart';

/// The pinned header row.
///
/// Built from real widgets, unlike the body. That is not an inconsistency: the
/// header is one row, so the widget cost is a rounding error, and it is the
/// part of the grid that needs tap targets, hover states, drag handles and
/// tooltips — everything widgets are good at. Spend widgets where they buy
/// something.
class FitGridHeader<T> extends StatelessWidget {
  const FitGridHeader({
    required this.columns,
    required this.layout,
    required this.theme,
    required this.horizontalOffset,
    required this.sortColumnId,
    required this.sortDirection,
    required this.onSort,
    super.key,
  });

  final List<FitGridColumn<T>> columns;
  final FitGridColumnLayout layout;
  final FitGridThemeData theme;
  final double horizontalOffset;
  final String? sortColumnId;
  final FitGridSortDirection sortDirection;
  final ValueChanged<String>? onSort;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return SizedBox(
      height: theme.effectiveHeaderHeight,
      child: ClipRect(
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: theme.headerBackground)),
            Positioned.directional(
              textDirection: textDirection,
              start: -horizontalOffset,
              top: 0,
              bottom: 0,
              width: layout.totalWidth,
              child: Row(
                children: [
                  for (var i = 0; i < columns.length; i++)
                    _HeaderCell<T>(
                      column: columns[i],
                      width: layout.widths[i],
                      theme: theme,
                      isLast: i == columns.length - 1,
                      direction: columns[i].id == sortColumnId
                          ? sortDirection
                          : FitGridSortDirection.none,
                      onTap: columns[i].sortable && onSort != null
                          ? () => onSort!(columns[i].id)
                          : null,
                    ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                height: theme.dividerThickness,
                color: theme.border,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell<T> extends StatelessWidget {
  const _HeaderCell({
    required this.column,
    required this.width,
    required this.theme,
    required this.isLast,
    required this.direction,
    required this.onTap,
  });

  final FitGridColumn<T> column;
  final double width;
  final FitGridThemeData theme;
  final bool isLast;
  final FitGridSortDirection direction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (column.effectiveHeaderAlignment) {
      FitGridAlignment.start => MainAxisAlignment.start,
      FitGridAlignment.center => MainAxisAlignment.center,
      FitGridAlignment.end => MainAxisAlignment.end,
    };

    Widget content = Row(
      mainAxisAlignment: alignment,
      children: [
        Flexible(
          child: Text(
            column.label,
            style: theme.headerTextStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (column.sortable) ...[
          const SizedBox(width: 4),
          Icon(
            switch (direction) {
              FitGridSortDirection.ascending => Icons.arrow_upward_rounded,
              FitGridSortDirection.descending => Icons.arrow_downward_rounded,
              FitGridSortDirection.none => Icons.unfold_more_rounded,
            },
            size: theme.sortIconSize,
            // An unsorted column still shows an affordance, but a quiet one —
            // otherwise the icons read as noise across a wide header.
            color: direction == FitGridSortDirection.none
                ? theme.sortIconColor.withValues(alpha: 0.35)
                : theme.sortIconColor,
          ),
        ],
      ],
    );

    if (column.headerBuilder != null) {
      content = Builder(builder: column.headerBuilder!);
    }

    if (column.tooltip != null) {
      content = Tooltip(message: column.tooltip!, child: content);
    }

    return SizedBox(
      width: width,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: isLast
              ? null
              : BorderDirectional(
                  end: BorderSide(
                    color: theme.columnDivider,
                    width: theme.dividerThickness,
                  ),
                ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: theme.effectiveHeaderPadding, child: content),
        ),
      ),
    );
  }
}
