import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Three pagers over one controller: the built-in one, the built-in one
/// reworded, and one written from scratch — plus driving pages from outside.
class PaginationScreen extends StatefulWidget {
  const PaginationScreen({super.key});

  @override
  State<PaginationScreen> createState() => _PaginationScreenState();
}

enum _PagerStyle { builtIn, relabelled, numbered }

class _PaginationScreenState extends State<PaginationScreen> {
  // The controller holds the pagination state, so buttons outside the grid
  // can drive it and a custom pager can read it.
  late final FitGridController<Employee> _controller =
      FitGridController<Employee>(
          rows: generateEmployees(1000),
          columns: [
            FitGridColumn<Employee>(
              id: 'id',
              label: 'ID',
              value: (e) => e.id.toString(),
              width: const FitGridColumnWidth.fixed(72),
              alignment: FitGridAlignment.end,
            ),
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
              sortable: true,
            ),
            FitGridColumn<Employee>(
              id: 'role',
              label: 'Role',
              value: (e) => e.role,
              sortable: true,
            ),
            FitGridColumn<Employee>(
              id: 'salary',
              label: 'Salary',
              value: (e) => e.salaryText,
              alignment: FitGridAlignment.end,
              sortable: true,
              comparator: (a, b) => a.salary.compareTo(b.salary),
            ),
          ],
        )
        // Paging is configured on the controller, which owns it, rather than
        // through FitGrid(pageSize:). The grid would otherwise push its props
        // into the controller as it mounts, and anything outside the grid that
        // listens to the pagination (the page readout above) would be notified
        // in the middle of a build.
        ..pagination.enabled = true
        ..pagination.pageSize = 25;

  _PagerStyle _style = _PagerStyle.builtIn;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget Function(BuildContext, FitGridPaginationState)? get _pagerBuilder =>
      switch (_style) {
        // Null keeps the default pager.
        _PagerStyle.builtIn => null,
        // The default pager, reworded and without the page-size menu.
        _PagerStyle.relabelled => (context, pagination) => FitGridPager(
          pagination: pagination,
          theme: FitGridTheme.of(context),
          showPageSizeSelector: false,
          label: (first, last, total) =>
              'Showing $first to $last of $total people',
        ),
        _PagerStyle.numbered => (context, pagination) => _NumberedPager(
          pagination: pagination,
        ),
      };

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Pagination',
      notes: const [
        DemoNote(
          'A page is a read-only window onto the same list. Nothing is copied '
          'per page. Column widths are measured over the whole dataset, so they '
          'do not jump when you turn a page.',
        ),
        DemoNote.recommended(
          'Pass a controller when anything outside the grid needs the page: '
          'your own buttons, a URL, a custom pager.',
          code:
              'controller.pagination.next();\n'
              'controller.pagination.pageSize = 50;\n'
              'controller.scrollTo(603); // turns to the page, then scrolls',
        ),
        DemoNote.recommended(
          'To reword the built-in pager, return it from pagerBuilder with a '
          'label. To redesign it, return your own widget that reads the same '
          'state.',
          code:
              'pagerBuilder: (context, p) => FitGridPager(\n'
              '  pagination: p, theme: FitGridTheme.of(context),\n'
              "  label: (first, last, total) => '\$first–\$last of \$total',\n"
              '  showPageSizeSelector: false),',
        ),
        DemoNote(
          'Row indices stay global. Select a row, turn the page and come back: '
          'the selection is still on the same person.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<_PagerStyle>(
            segments: const [
              ButtonSegment(
                value: _PagerStyle.builtIn,
                label: Text('Built-in'),
              ),
              ButtonSegment(
                value: _PagerStyle.relabelled,
                label: Text('Built-in, reworded'),
              ),
              ButtonSegment(
                value: _PagerStyle.numbered,
                label: Text('Custom numbered'),
              ),
            ],
            selected: {_style},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _style = s.first),
          ),
          OutlinedButton(
            onPressed: () => _controller.scrollTo(603),
            child: const Text('Jump to row 604'),
          ),
          OutlinedButton(
            onPressed: () => _controller.pagination.last(),
            child: const Text('Last page'),
          ),
          // Rebuilds with the pager, and nothing else on the page does.
          ListenableBuilder(
            listenable: _controller.pagination,
            builder: (context, _) => StatChip(
              label: 'Page',
              value:
                  '${_controller.pagination.pageIndex + 1} / '
                  '${_controller.pagination.pageCount}',
            ),
          ),
        ],
      ),
      child: FitGrid<Employee>(
        controller: _controller,
        paginated: true,
        selectionMode: FitGridSelectionMode.multiple,
        pagerBuilder: _pagerBuilder,
      ),
    );
  }
}

/// Numbered pages with ellipses, built only from [FitGridPaginationState].
class _NumberedPager extends StatelessWidget {
  const _NumberedPager({required this.pagination});

  final FitGridPaginationState pagination;

  /// 1 … 4 5 [6] 7 8 … 40
  List<int?> _pages() {
    final count = pagination.pageCount;
    final current = pagination.pageIndex;
    if (count <= 7) return [for (var i = 0; i < count; i++) i];
    final around = {
      0,
      count - 1,
      for (var i = current - 2; i <= current + 2; i++)
        if (i > 0 && i < count - 1) i,
    }.toList()..sort();
    final result = <int?>[];
    for (final page in around) {
      if (result.isNotEmpty && page - result.last! > 1) result.add(null);
      result.add(page);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = pagination;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: p.hasPrevious ? p.previous : null,
            icon: const Icon(Icons.chevron_left),
          ),
          for (final page in _pages())
            page == null
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Text('…'),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: page == p.pageIndex
                        ? FilledButton(
                            onPressed: null,
                            style: FilledButton.styleFrom(
                              disabledBackgroundColor: scheme.primary,
                              disabledForegroundColor: scheme.onPrimary,
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('${page + 1}'),
                          )
                        : TextButton(
                            onPressed: () => p.pageIndex = page,
                            style: TextButton.styleFrom(
                              minimumSize: const Size(40, 40),
                              padding: EdgeInsets.zero,
                            ),
                            child: Text('${page + 1}'),
                          ),
                  ),
          IconButton(
            onPressed: p.hasNext ? p.next : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
