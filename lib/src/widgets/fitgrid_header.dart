import 'dart:math' as math;

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
    this.onResize,
    this.onAutoSize,
    super.key,
  });

  final List<FitGridColumn<T>> columns;
  final FitGridColumnLayout layout;
  final FitGridThemeData theme;
  final double horizontalOffset;
  final String? sortColumnId;
  final FitGridSortDirection sortDirection;
  final ValueChanged<String>? onSort;

  /// Called with a column id and the width the user has dragged it to. The
  /// width is raw: the sizer still clamps it against the column's own policy,
  /// so a drag cannot push a column past bounds it declared.
  final void Function(String columnId, double width)? onResize;

  /// Called when the user double-clicks a resize handle, asking for the column
  /// to size itself again.
  final ValueChanged<String>? onAutoSize;

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
              // The handles are a sibling layer rather than children of the
              // cells: a handle straddles the divider, so half of it belongs to
              // the next column along, and a child cannot be hit outside its
              // parent's box.
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Row(
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
                  for (var i = 0; i < columns.length; i++)
                    if (_canResize(columns[i]))
                      Positioned.directional(
                        textDirection: textDirection,
                        // Offsets are measured from the leading edge, which is
                        // the right one in RTL — so this is the same sum in
                        // both directions.
                        start: layout.offsets[i + 1] - _targetWidth(i) / 2,
                        top: 0,
                        bottom: 0,
                        width: _targetWidth(i),
                        child: _ResizeHandle(
                          theme: theme,
                          textDirection: textDirection,
                          startWidth: layout.widths[i],
                          onResize: (width) => onResize!(columns[i].id, width),
                          onAutoSize: onAutoSize == null
                              ? null
                              : () => onAutoSize!(columns[i].id),
                        ),
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

  bool _canResize(FitGridColumn<T> column) =>
      onResize != null && column.resizable && !column.width.isPinned;

  /// Hit width of the handle on the trailing edge of column [i].
  ///
  /// A finger is much wider than a divider, so the target is far wider than the
  /// grip drawn on it. It cannot simply be as wide as it likes, though: the
  /// strip straddles two columns, and a target wide enough to cover a narrow
  /// column entirely would eat that column's own header tap. So it gives up
  /// half of whichever neighbour is narrower, and no more.
  double _targetWidth(int i) {
    final here = layout.widths[i];
    final next = i + 1 < layout.length ? layout.widths[i + 1] : here;
    final room = math.min(here, next);
    return math.max(
      theme.resizeHandleWidth,
      math.min(theme.resizeTouchTargetWidth, room),
    );
  }
}

/// The grab area straddling a column's trailing divider.
///
/// Drag it to set the column's width; double-click it to hand the column back
/// to its own width policy, which for the `auto` columns this package is built
/// around means measuring the content again.
///
/// The drag is tracked against the width the column started at rather than read
/// back from the layout each frame. Reading it back would compound rounding,
/// and worse, would stall the moment the column hit a clamp: the pointer would
/// keep moving while the width did not, and the two would never agree again.
class _ResizeHandle extends StatefulWidget {
  const _ResizeHandle({
    required this.theme,
    required this.textDirection,
    required this.startWidth,
    required this.onResize,
    required this.onAutoSize,
  });

  final FitGridThemeData theme;
  final TextDirection textDirection;
  final double startWidth;
  final ValueChanged<double> onResize;
  final VoidCallback? onAutoSize;

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;
  bool _dragging = false;
  double _width = 0.0;

  @override
  Widget build(BuildContext context) {
    final active = _hovered || _dragging;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTap: widget.onAutoSize,
        onHorizontalDragStart: (_) => setState(() {
          _dragging = true;
          _width = widget.startWidth;
        }),
        onHorizontalDragUpdate: (details) {
          // In RTL a column grows as the pointer moves left, so the gesture's
          // dx means the opposite thing. Flipping it here keeps everything
          // downstream in plain widths.
          final delta = widget.textDirection == TextDirection.rtl
              ? -details.delta.dx
              : details.delta.dx;
          _width = math.max(widget.theme.minColumnWidth, _width + delta);
          widget.onResize(_width);
        },
        onHorizontalDragEnd: (_) => setState(() => _dragging = false),
        onHorizontalDragCancel: () => setState(() => _dragging = false),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // The bar only shows while the handle is engaged. A permanent one
            // would compete with the column divider it sits on.
            if (active)
              Positioned.fill(
                child: Center(
                  child: SizedBox(
                    width: widget.theme.dividerThickness * 2,
                    child: ColoredBox(color: widget.theme.focusOutline),
                  ),
                ),
              ),
            // The grip itself is always drawn, quietly, so the column is
            // visibly draggable before the pointer arrives — and so a touch
            // user, who has no hover state and no cursor to change, can see
            // that the divider does something.
            //
            // The glyph is centred on the divider and sized independently of
            // the strip it hangs in: the strip is a finger-sized hit target,
            // and drawing a grip that wide would look like a smudge.
            OverflowBox(
              maxWidth: widget.theme.sortIconSize,
              child: Icon(
                widget.theme.resizeGripIcon,
                size: widget.theme.sortIconSize,
                color: active
                    ? widget.theme.focusOutline
                    : widget.theme.sortIconColor.withValues(alpha: 0.28),
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

  /// Gap between the label and the sort icon.
  static const double _sortGap = 4.0;

  /// Label width worth keeping. Below this the icon is dropped, because a
  /// header showing two ellipsized characters and an arrow says less than one
  /// showing four characters.
  static const double _minLabelWidth = 16.0;

  @override
  Widget build(BuildContext context) {
    final alignment = switch (column.effectiveHeaderAlignment) {
      FitGridAlignment.start => MainAxisAlignment.start,
      FitGridAlignment.center => MainAxisAlignment.center,
      FitGridAlignment.end => MainAxisAlignment.end,
    };

    // The label flexes but the sort icon does not, so a column squeezed
    // narrower than the icon plus its gap would overflow the row. The icon is
    // dropped rather than allowed to overflow: a header cell that has run out
    // of room should lose its affordance, not paint over the column beside it.
    //
    // The measurement has to happen inside the padding, which is why this is a
    // LayoutBuilder rather than arithmetic on `width` — `effectiveHeaderPadding`
    // can be overridden per theme, and a narrow column may have none of its
    // width left by the time the padding has taken its share.
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        final affordance = theme.sortIconSize + _sortGap;
        final showSort =
            column.sortable &&
            constraints.maxWidth >= affordance + _minLabelWidth;

        return Row(
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
            if (showSort) ...[
              const SizedBox(width: _sortGap),
              Icon(
                switch (direction) {
                  FitGridSortDirection.ascending => Icons.arrow_upward_rounded,
                  FitGridSortDirection.descending =>
                    Icons.arrow_downward_rounded,
                  FitGridSortDirection.none => Icons.unfold_more_rounded,
                },
                size: theme.sortIconSize,
                // An unsorted column still shows an affordance, but a quiet
                // one — otherwise the icons read as noise across a wide header.
                color: direction == FitGridSortDirection.none
                    ? theme.sortIconColor.withValues(alpha: 0.35)
                    : theme.sortIconColor,
              ),
            ],
          ],
        );
      },
    );

    if (column.headerBuilder != null) {
      content = Builder(builder: column.headerBuilder!);
    }

    if (column.tooltip != null) {
      content = Tooltip(message: column.tooltip!, child: content);
    }

    return SizedBox(
      width: width,
      child: ClipRect(
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
            child: Padding(
              padding: theme.effectiveHeaderPadding,
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}
