import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

enum _RowsBy { department, role }

enum _ColumnsBy { none, startYear }

enum _Measure { payroll, averagePay, headcount }

/// 20,000 employees summarised by a pivot, and the result exported.
class PivotExportScreen extends StatefulWidget {
  const PivotExportScreen({super.key});

  @override
  State<PivotExportScreen> createState() => _PivotExportScreenState();
}

class _PivotExportScreenState extends State<PivotExportScreen> {
  static final List<Employee> _source = generateEmployees(20000);

  _RowsBy _rowsBy = _RowsBy.department;
  _ColumnsBy _columnsBy = _ColumnsBy.startYear;
  _Measure _measure = _Measure.payroll;
  late FitGridPivotResult _pivot = _build();

  static String _thousands(num v) =>
      '\$${(v / 1000).round().toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}k';

  FitGridPivotResult _build() {
    final rows = switch (_rowsBy) {
      _RowsBy.department => FitGridPivotDimension<Employee>(
        id: 'department',
        label: 'Department',
        keyOf: (e) => e.department,
      ),
      _RowsBy.role => FitGridPivotDimension<Employee>(
        id: 'role',
        label: 'Role',
        keyOf: (e) => e.role,
      ),
    };
    final value = switch (_measure) {
      _Measure.payroll => FitGridPivotValue<Employee>(
        id: 'payroll',
        label: 'Payroll',
        valueOf: (e) => e.salary,
        format: _thousands,
      ),
      _Measure.averagePay => FitGridPivotValue<Employee>(
        id: 'average',
        label: 'Average pay',
        valueOf: (e) => e.salary,
        aggregation: FitGridAggregation.average,
        format: _thousands,
      ),
      _Measure.headcount => const FitGridPivotValue<Employee>.count(
        label: 'Headcount',
      ),
    };
    return fitGridPivot<Employee>(
      _source,
      rows: [rows],
      columns: _columnsBy == _ColumnsBy.startYear
          ? FitGridPivotDimension<Employee>(
              id: 'year',
              label: 'Started',
              keyOf: (e) => e.startedOn.year,
            )
          : null,
      values: [value],
    );
  }

  void _update(VoidCallback change) {
    setState(() {
      change();
      _pivot = _build();
    });
  }

  FitGridExportData get _export => buildFitGridExport<FitGridPivotRow>(
    columns: _pivot.columns,
    rows: _pivot.rows,
  );

  Future<void> _copyCsv() async {
    await Clipboard.setData(ClipboardData(text: fitGridToCsv(_export)));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to the clipboard')),
    );
  }

  void _makeWorkbook() {
    final bytes = fitGridToXlsx(_export, sheetName: 'Pivot');
    // Saving is the platform's business — a file on desktop, a download on
    // the web, a share sheet on a phone — so the example stops at the bytes.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Workbook ready: ${(bytes.length / 1024).toStringAsFixed(1)} KB. '
          'Hand the bytes to your file saver of choice.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Pivot & export',
      notes: const [
        DemoNote(
          'fitGridPivot buckets 20,000 rows by the dimensions you pick and '
          'returns ordinary rows and columns — so the result sorts (tap a '
          'header), totals in the footer, and exports like any other grid.',
        ),
        DemoNote.recommended(
          'Build the pivot when its inputs change, not in build: it is a pass '
          'over every source row.',
          code:
              'final pivot = fitGridPivot<Employee>(\n'
              '  employees,\n'
              '  rows: [FitGridPivotDimension(id: "dept", label: "Department",\n'
              '      keyOf: (e) => e.department)],\n'
              '  columns: FitGridPivotDimension(id: "year", label: "Started",\n'
              '      keyOf: (e) => e.startedOn.year),\n'
              '  values: [FitGridPivotValue(id: "pay", label: "Payroll",\n'
              '      valueOf: (e) => e.salary)],\n'
              ');\n'
              'FitGrid<FitGridPivotRow>(rows: pivot.rows, columns: pivot.columns);',
        ),
        DemoNote(
          'Totals come from the source rows, so "Average pay" in the footer is '
          'the true average, not an average of the averages above it.',
        ),
        DemoNote(
          'fitGridToXlsx writes an Excel workbook in pure Dart — bold frozen '
          'header, numbers as numbers — with no dependency and on the web too.',
          code: 'final bytes = fitGridToXlsx(controller.export(), sheetName: "Pivot");',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<_RowsBy>(
            segments: const [
              ButtonSegment(
                value: _RowsBy.department,
                label: Text('By department'),
              ),
              ButtonSegment(value: _RowsBy.role, label: Text('By role')),
            ],
            selected: {_rowsBy},
            onSelectionChanged: (s) => _update(() => _rowsBy = s.single),
          ),
          SegmentedButton<_Measure>(
            segments: const [
              ButtonSegment(value: _Measure.payroll, label: Text('Payroll')),
              ButtonSegment(value: _Measure.averagePay, label: Text('Average')),
              ButtonSegment(
                value: _Measure.headcount,
                label: Text('Headcount'),
              ),
            ],
            selected: {_measure},
            onSelectionChanged: (s) => _update(() => _measure = s.single),
          ),
          FilterChip(
            label: const Text('Columns by start year'),
            selected: _columnsBy == _ColumnsBy.startYear,
            onSelected: (v) => _update(
              () => _columnsBy = v ? _ColumnsBy.startYear : _ColumnsBy.none,
            ),
          ),
          FilledButton.tonalIcon(
            onPressed: _copyCsv,
            icon: const Icon(Icons.copy),
            label: const Text('Copy CSV'),
          ),
          FilledButton.tonalIcon(
            onPressed: _makeWorkbook,
            icon: const Icon(Icons.table_view),
            label: const Text('Make .xlsx'),
          ),
        ],
      ),
      child: FitGrid<FitGridPivotRow>(
        // Keyed on the shape, so a new set of generated columns starts fresh.
        key: ValueKey((_rowsBy, _columnsBy, _measure)),
        rows: _pivot.rows,
        columns: _pivot.columns,
      ),
    );
  }
}
