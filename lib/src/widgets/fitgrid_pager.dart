import 'package:flutter/material.dart';

import '../controller/fitgrid_pagination.dart';
import '../theme/fitgrid_theme.dart';

/// Formats the "1–25 of 1,000" label. Swap it out for another language, another
/// numeral system, or a different phrasing entirely.
typedef FitGridPageLabel = String Function(int first, int last, int total);

/// The default pager strip below the grid.
///
/// Built from ordinary widgets, and replaceable wholesale: the grid's
/// `pagerBuilder` hands you the same [FitGridPaginationState] this reads, so a
/// host that wants a different pager writes one against the same state rather
/// than fighting this one. Nothing here is privileged.
class FitGridPager extends StatelessWidget {
  const FitGridPager({
    required this.pagination,
    required this.theme,
    this.label,
    this.showPageSizeSelector = true,
    super.key,
  });

  final FitGridPaginationState pagination;
  final FitGridThemeData theme;

  /// Overrides the range readout. Defaults to `1–25 of 1,000`.
  final FitGridPageLabel? label;

  final bool showPageSizeSelector;

  String _defaultLabel(int first, int last, int total) =>
      total == 0 ? 'No rows' : '$first–$last of $total';

  @override
  Widget build(BuildContext context) {
    final first = pagination.rowsOnPage == 0 ? 0 : pagination.firstRowIndex + 1;
    final last = pagination.endRowIndex;
    final text = (label ?? _defaultLabel)(first, last, pagination.rowCount);

    return Container(
      height: theme.effectiveHeaderHeight,
      padding: EdgeInsets.symmetric(
        horizontal: theme.effectiveHeaderPadding.horizontal / 2,
      ),
      decoration: BoxDecoration(
        color: theme.headerBackground,
        border: Border(
          top: BorderSide(color: theme.border, width: theme.dividerThickness),
        ),
      ),
      child: Row(
        children: [
          if (showPageSizeSelector) ...[
            Text('Rows', style: theme.cellTextStyle),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: pagination.pageSize,
              underline: const SizedBox.shrink(),
              isDense: true,
              style: theme.cellTextStyle,
              items: [
                for (final size in pagination.pageSizeOptions)
                  DropdownMenuItem<int>(value: size, child: Text('$size')),
              ],
              onChanged: (value) {
                if (value != null) pagination.pageSize = value;
              },
            ),
          ],
          const Spacer(),
          Text(text, style: theme.cellTextStyle),
          const SizedBox(width: 12),
          _PagerButton(
            icon: Icons.first_page_rounded,
            tooltip: 'First page',
            onPressed: pagination.hasPrevious ? pagination.first : null,
            theme: theme,
          ),
          _PagerButton(
            icon: Icons.chevron_left_rounded,
            tooltip: 'Previous page',
            onPressed: pagination.hasPrevious ? pagination.previous : null,
            theme: theme,
          ),
          _PagerButton(
            icon: Icons.chevron_right_rounded,
            tooltip: 'Next page',
            onPressed: pagination.hasNext ? pagination.next : null,
            theme: theme,
          ),
          _PagerButton(
            icon: Icons.last_page_rounded,
            tooltip: 'Last page',
            onPressed: pagination.hasNext ? pagination.last : null,
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _PagerButton extends StatelessWidget {
  const _PagerButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.theme,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final FitGridThemeData theme;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: theme.sortIconSize + 2),
      tooltip: tooltip,
      onPressed: onPressed,
      visualDensity: VisualDensity.compact,
      color: theme.sortIconColor,
      disabledColor: theme.placeholderForeground,
    );
  }
}
