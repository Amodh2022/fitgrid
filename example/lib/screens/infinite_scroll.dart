import 'dart:async';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// A pretend API that serves a feed forty rows at a time, slowly, and can be
/// told to fail.
class _FeedApi {
  final List<Employee> _all = generateEmployees(600);
  bool failing = false;
  int calls = 0;

  Future<List<Employee>> after(int offset) async {
    calls++;
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (failing) throw StateError('The server is unavailable');
    return _all.skip(offset).take(40).toList();
  }

  int get total => _all.length;
}

/// Rows that arrive as the user scrolls towards the end.
class InfiniteScrollScreen extends StatefulWidget {
  const InfiniteScrollScreen({super.key});

  @override
  State<InfiniteScrollScreen> createState() => _InfiniteScrollScreenState();
}

class _InfiniteScrollScreenState extends State<InfiniteScrollScreen> {
  final _FeedApi _api = _FeedApi();
  List<Employee> _rows = const <Employee>[];
  String? _error;

  static final List<FitGridColumn<Employee>> _columns = [
    FitGridColumn<Employee>(
      id: 'id',
      label: '#',
      value: (e) => '${e.id - 999}',
      alignment: FitGridAlignment.end,
      width: const FitGridColumnWidth.fixed(72),
    ),
    FitGridColumn<Employee>(id: 'name', label: 'Name', value: (e) => e.name),
    FitGridColumn<Employee>(
      id: 'department',
      label: 'Department',
      value: (e) => e.department,
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'Salary',
      value: (e) => e.salaryText,
      alignment: FitGridAlignment.end,
    ),
  ];

  bool get _hasMore => _rows.length < _api.total;

  Future<void> _loadMore() async {
    try {
      final next = await _api.after(_rows.length);
      if (!mounted) return;
      setState(() {
        _rows = [..._rows, ...next];
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = '$error');
      // Rethrown so the grid knows the load failed and waits for the next
      // scroll rather than asking again at once.
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Infinite scroll',
      notes: const [
        DemoNote(
          'The grid asks for more when the user scrolls within ten rows of '
          'the end, shows skeleton rows while the request is out, and never '
          'has two requests out at once. A first batch too short to fill the '
          'screen keeps loading until it does.',
        ),
        DemoNote.recommended(
          'Append to your list and set hasMoreRows; the grid does the rest.',
          code:
              'FitGrid<Employee>(\n'
              '  rows: rows,\n'
              '  hasMoreRows: rows.length < total,\n'
              '  onLoadMore: () async {\n'
              '    final next = await api.after(rows.length);\n'
              '    setState(() => rows = [...rows, ...next]);\n'
              '  },\n'
              ')',
        ),
        DemoNote(
          'Turn on "Fail requests" and scroll: a failed load is not retried in '
          'a loop — the next attempt waits for the user to scroll again.',
        ),
        DemoNote.avoid(
          'onLoadMore with a server that sorts or filters. Once the server '
          'decides the order, use a FitGridDataSource, which fetches the '
          'windows the user scrolls to — see Lazy loading.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilterChip(
            label: const Text('Fail requests'),
            selected: _api.failing,
            onSelected: (v) => setState(() => _api.failing = v),
          ),
          StatChip(label: 'Loaded', value: '${_rows.length} / ${_api.total}'),
          StatChip(label: 'Requests', value: '${_api.calls}'),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      ),
      child: FitGrid<Employee>(
        rows: _rows,
        columns: _columns,
        onLoadMore: _loadMore,
        hasMoreRows: _hasMore,
        loadingRowCount: 4,
      ),
    );
  }
}
