import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Every column-width policy side by side, and the three ways to size rows,
/// with the frame time each change costs shown live.
class SizingScreen extends StatefulWidget {
  const SizingScreen({super.key});

  @override
  State<SizingScreen> createState() => _SizingScreenState();
}

enum _RowMode { fixed, uniform, wrapping }

class _SizingScreenState extends State<SizingScreen> {
  static const _counts = [1000, 10000, 100000];

  int _count = 10000;
  late List<Employee> _rows = generateEmployees(_count);
  _RowMode _rowMode = _RowMode.fixed;
  bool _measureAll = false;
  late List<FitGridColumn<Employee>> _columns = _buildColumns();
  Duration? _lastFrame;

  /// Rebuilt only when a setting that lives on a column changes, never in
  /// build(), so the grid keeps its measured layout between frames.
  List<FitGridColumn<Employee>> _buildColumns() => [
    FitGridColumn<Employee>(
      id: 'id',
      label: 'fixed(80)',
      value: (e) => e.id.toString(),
      // Known width: never measured at all. The cheapest policy there is.
      width: const FitGridColumnWidth.fixed(80),
      alignment: FitGridAlignment.end,
    ),
    FitGridColumn<Employee>(
      id: 'dept',
      label: 'fitHeader()',
      value: (e) => e.department.substring(0, 3),
      // Values are never wider than the header, so size to the header only.
      width: const FitGridColumnWidth.fitHeader(min: 64),
    ),
    FitGridColumn<Employee>(
      id: 'name',
      label: 'auto()',
      value: (e) => e.name,
      // Samples the longest candidates by character count, then measures only
      // those. Cost does not grow with the row count.
      width: const FitGridColumnWidth.auto(),
    ),
    FitGridColumn<Employee>(
      id: 'role',
      label: 'auto(max: 180)',
      value: (e) => e.role,
      // A cap stops one long value from widening the whole column.
      width: const FitGridColumnWidth.auto(max: 180),
      overflow: FitGridOverflow.tooltipOnTruncate,
    ),
    FitGridColumn<Employee>(
      id: 'note',
      label: _measureAll ? 'auto(measureAllRows)' : 'auto(max: 260)',
      value: (e) => e.note,
      // measureAllRows is exact but touches every row. It is spread over
      // several frames, but it still does the work.
      width: FitGridColumnWidth.auto(max: 260, measureAllRows: _measureAll),
      overflow: FitGridOverflow.tooltipOnTruncate,
      // Only a column that can wrap gives content-sized rows anything to
      // measure. With maxLines: 1 everywhere, contentSized costs nothing.
      maxLines: _rowMode == _RowMode.wrapping ? 3 : 1,
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'flex(1)',
      value: (e) => e.salaryText,
      // Takes whatever width is left over, so it is never measured either.
      width: const FitGridColumnWidth.flex(1, min: 100),
      alignment: FitGridAlignment.end,
    ),
  ];

  FitGridRowHeight? get _rowHeight => switch (_rowMode) {
    _RowMode.fixed => const FitGridRowHeight.fixed(40),
    // Content-sized with nothing that wraps: resolves to one uniform height.
    _RowMode.uniform => const FitGridRowHeight.contentSized(min: 36),
    _RowMode.wrapping => const FitGridRowHeight.contentSized(min: 36, max: 96),
  };

  /// Applies [change] and reports how long the next frame took, which covers
  /// everything the grid did in response: measurement, layout and paint.
  void _timed(VoidCallback change) {
    final watch = Stopwatch()..start();
    setState(change);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _lastFrame = watch.elapsed);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Column widths & row heights',
      notes: const [
        DemoNote(
          'Each header names the width policy of its column. Switch the row '
          'count and the row mode: the readout shows how long the grid took to '
          'respond.',
        ),
        DemoNote.recommended(
          'Pick the cheapest policy that is still right. fixed and flex are '
          'never measured. fitHeader measures one string. auto measures a '
          'small sample, whatever the row count.',
          code:
              "FitGridColumnWidth.fixed(80)          // ids, dates, icons\n"
              "FitGridColumnWidth.fitHeader(min: 64) // short codes\n"
              "FitGridColumnWidth.auto(max: 260)     // names, free text\n"
              "FitGridColumnWidth.flex(1, min: 100)  // soak up the rest",
        ),
        DemoNote.recommended(
          'Use FitGridRowHeight.fixed for large data. Row offsets become '
          'arithmetic, and the scrollbar is right from the first frame.',
          code: 'rowHeight: const FitGridRowHeight.fixed(40)',
        ),
        DemoNote.recommended(
          'Wrapping text needs both halves: maxLines on the column and '
          'contentSized on the grid. Clamp the column width (max:) so the wrap '
          'point stays stable.',
          code:
              'FitGridColumn(maxLines: 3,\n'
              '  width: FitGridColumnWidth.auto(max: 260), ...)\n'
              'FitGrid(rowHeight: FitGridRowHeight.contentSized(max: 96))',
        ),
        DemoNote.avoid(
          'Wrapping rows over 100k rows. The scrollbar cannot be right until '
          "every row's height is known, so that cost is real. Try it here and "
          'watch the readout.',
        ),
        DemoNote.avoid(
          'measureAllRows on long free-text columns, unless an exact width '
          'matters more than time. The default sample is almost always right.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<int>(
            segments: [
              for (final c in _counts)
                ButtonSegment(value: c, label: Text('${c ~/ 1000}k rows')),
            ],
            selected: {_count},
            showSelectedIcon: false,
            onSelectionChanged: (s) {
              // Generated before the stopwatch starts: the readout is for the
              // grid, not for this demo's fake data.
              final rows = generateEmployees(s.first);
              _timed(() {
                _count = s.first;
                _rows = rows;
              });
            },
          ),
          SegmentedButton<_RowMode>(
            segments: const [
              ButtonSegment(value: _RowMode.fixed, label: Text('fixed(40)')),
              ButtonSegment(
                value: _RowMode.uniform,
                label: Text('contentSized, no wrap'),
              ),
              ButtonSegment(
                value: _RowMode.wrapping,
                label: Text('contentSized + wrap'),
              ),
            ],
            selected: {_rowMode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => _timed(() {
              _rowMode = s.first;
              _columns = _buildColumns();
            }),
          ),
          FilterChip(
            label: const Text('Note: measureAllRows'),
            selected: _measureAll,
            onSelected: (v) => _timed(() {
              _measureAll = v;
              _columns = _buildColumns();
            }),
          ),
          StatChip(
            label: 'Last change took',
            value: _lastFrame == null
                ? '—'
                : '${(_lastFrame!.inMicroseconds / 1000).toStringAsFixed(1)} ms',
          ),
        ],
      ),
      child: FitGrid<Employee>(
        rows: _rows,
        columns: _columns,
        rowHeight: _rowHeight,
        stretchColumnsToFill: true,
      ),
    );
  }
}
