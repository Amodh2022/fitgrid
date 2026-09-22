import 'package:fitgrid/fitgrid.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'employee.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatefulWidget {
  const ExampleApp({super.key});

  @override
  State<ExampleApp> createState() => _ExampleAppState();
}

class _ExampleAppState extends State<ExampleApp> {
  ThemeMode _themeMode = ThemeMode.light;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'fitgrid',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3B6EA5),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF3B6EA5),
      ),
      home: ExamplePage(
        themeMode: _themeMode,
        onThemeModeChanged: (mode) => setState(() => _themeMode = mode),
      ),
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({
    required this.themeMode,
    required this.onThemeModeChanged,
    super.key,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<ExamplePage> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  static const _rowCounts = [100, 1000, 10000, 100000];

  late FitGridController<Employee> _controller;
  int _rowCount = 1000;
  FitGridDensity _density = FitGridDensity.standard;
  bool _striped = true;
  bool _stretch = true;
  bool _rtl = false;
  bool _wrapNotes = false;
  bool _paginated = false;

  @override
  void initState() {
    super.initState();
    _controller = FitGridController<Employee>(
      rows: generateEmployees(_rowCount),
      columns: _columns(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<FitGridColumn<Employee>> _columns() => <FitGridColumn<Employee>>[
    FitGridColumn<Employee>(
      id: 'id',
      label: 'ID',
      value: (e) => e.id.toString(),
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.id.compareTo(b.id),
      // Ids are uniform, so there is nothing to measure — say so explicitly
      // rather than paying for a measurement that always agrees.
      width: const FitGridColumnWidth.fitHeader(min: 72),
    ),
    FitGridColumn<Employee>(
      id: 'name',
      label: 'Name',
      value: (e) => e.name,
      sortable: true,
      // Double-click a cell to edit it. Exactly one editor widget exists, and
      // only while it is open — the rest of the column stays painted.
      editor: FitGridEditor<Employee>(
        validator: (row, value) =>
            value.trim().isEmpty ? 'Name cannot be empty' : null,
        onCommit: (row, index, value) =>
            _applyEdit(index, row.copyWith(name: value.trim())),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'department',
      label: 'Department',
      value: (e) => e.department,
      sortable: true,
    ),
    FitGridColumn<Employee>(
      id: 'role',
      label: 'Role',
      value: (e) => e.role,
      sortable: true,
      editor: FitGridEditor<Employee>(
        onCommit: (row, index, value) =>
            _applyEdit(index, row.copyWith(role: value.trim())),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'Salary',
      value: (e) => e.salaryText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
      editor: FitGridEditor<Employee>(
        // The cell paints a formatted string; the editor should not make the
        // user retype the currency symbol and the separators.
        initialText: (row) => row.salary.toString(),
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        validator: (row, value) =>
            int.tryParse(value) == null ? 'Enter a whole number' : null,
        onCommit: (row, index, value) =>
            _applyEdit(index, row.copyWith(salary: int.parse(value))),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'started',
      label: 'Started',
      value: (e) => e.startedOnText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.startedOn.compareTo(b.startedOn),
    ),
    FitGridColumn<Employee>(
      id: 'note',
      label: 'Note',
      value: (e) => e.note,
      // Long free text would otherwise dominate the whole grid. The `max` is
      // also what gives the wrapping mode below something to wrap against: an
      // unclamped `auto` column just widens until the text fits on one line.
      width: const FitGridColumnWidth.auto(max: 280),
      overflow: FitGridOverflow.tooltipOnTruncate,
      maxLines: _wrapNotes ? 3 : 1,
    ),
  ];

  /// Lets the note column wrap, and asks rows to size themselves to it.
  ///
  /// Both halves are needed: `maxLines` alone has no room to spend under a
  /// uniform row height, and `contentSized` alone has nothing to measure when
  /// every cell is one line.
  void _setWrapNotes(bool value) {
    setState(() => _wrapNotes = value);
    _controller.columns.columns = _columns();
  }

  /// The grid never mutates your rows, so applying an edit is the host's job.
  /// [index] is into the full row list, which is what makes this correct while
  /// the grid is sorted or paginated.
  void _applyEdit(int index, Employee updated) {
    final rows = List<Employee>.of(_controller.data.rows);
    // `data.rows` is the unsorted list; the index the grid reports is into the
    // sorted view, so find the row by identity rather than trusting position.
    final original = _controller.data.view[index];
    final at = rows.indexOf(original);
    if (at < 0) return;
    rows[at] = updated;
    _controller.data.rows = rows;
  }

  void _setRowCount(int count) {
    setState(() => _rowCount = count);
    _controller.data.rows = generateEmployees(count);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('fitgrid'),
          actions: [
            IconButton(
              tooltip: 'Toggle brightness',
              icon: Icon(
                widget.themeMode == ThemeMode.dark
                    ? Icons.light_mode_outlined
                    : Icons.dark_mode_outlined,
              ),
              onPressed: () => widget.onThemeModeChanged(
                widget.themeMode == ThemeMode.dark
                    ? ThemeMode.light
                    : ThemeMode.dark,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _Controls(
              rowCount: _rowCount,
              rowCounts: _rowCounts,
              onRowCount: _setRowCount,
              density: _density,
              onDensity: (d) => setState(() => _density = d),
              striped: _striped,
              onStriped: (v) => setState(() => _striped = v),
              stretch: _stretch,
              onStretch: (v) => setState(() => _stretch = v),
              rtl: _rtl,
              onRtl: (v) => setState(() => _rtl = v),
              wrapNotes: _wrapNotes,
              onWrapNotes: _setWrapNotes,
              // Drag a header divider to resize a column, or double-click it to
              // re-fit that one. This does the same to all of them at once.
              onResetWidths: _controller.columns.autoSizeAll,
              paginated: _paginated,
              onPaginated: (v) => setState(() => _paginated = v),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FitGrid<Employee>(
                  controller: _controller,
                  theme: FitGridThemeData.fromTheme(theme, density: _density),
                  striped: _striped,
                  stretchColumnsToFill: _stretch,
                  rowHeight: _wrapNotes
                      ? const FitGridRowHeight.contentSized(min: 40, max: 120)
                      : null,
                  paginated: _paginated,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.rowCount,
    required this.rowCounts,
    required this.onRowCount,
    required this.density,
    required this.onDensity,
    required this.striped,
    required this.onStriped,
    required this.stretch,
    required this.onStretch,
    required this.rtl,
    required this.onRtl,
    required this.wrapNotes,
    required this.onWrapNotes,
    required this.onResetWidths,
    required this.paginated,
    required this.onPaginated,
  });

  final int rowCount;
  final List<int> rowCounts;
  final ValueChanged<int> onRowCount;
  final FitGridDensity density;
  final ValueChanged<FitGridDensity> onDensity;
  final bool striped;
  final ValueChanged<bool> onStriped;
  final bool stretch;
  final ValueChanged<bool> onStretch;
  final bool rtl;
  final ValueChanged<bool> onRtl;
  final bool wrapNotes;
  final ValueChanged<bool> onWrapNotes;
  final VoidCallback onResetWidths;
  final bool paginated;
  final ValueChanged<bool> onPaginated;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<int>(
            segments: [
              for (final count in rowCounts)
                ButtonSegment<int>(
                  value: count,
                  label: Text(count >= 1000 ? '${count ~/ 1000}k' : '$count'),
                ),
            ],
            selected: {rowCount},
            onSelectionChanged: (s) => onRowCount(s.first),
            showSelectedIcon: false,
          ),
          SegmentedButton<FitGridDensity>(
            segments: const [
              ButtonSegment(
                value: FitGridDensity.compact,
                label: Text('Compact'),
              ),
              ButtonSegment(
                value: FitGridDensity.standard,
                label: Text('Standard'),
              ),
              ButtonSegment(
                value: FitGridDensity.comfortable,
                label: Text('Comfortable'),
              ),
            ],
            selected: {density},
            onSelectionChanged: (s) => onDensity(s.first),
            showSelectedIcon: false,
          ),
          FilterChip(
            label: const Text('Striped'),
            selected: striped,
            onSelected: onStriped,
          ),
          FilterChip(
            label: const Text('Stretch columns'),
            selected: stretch,
            onSelected: onStretch,
          ),
          FilterChip(
            label: const Text('RTL'),
            selected: rtl,
            onSelected: onRtl,
          ),
          FilterChip(
            label: const Text('Wrap notes'),
            selected: wrapNotes,
            onSelected: onWrapNotes,
          ),
          FilterChip(
            label: const Text('Paginate'),
            selected: paginated,
            onSelected: onPaginated,
          ),
          OutlinedButton.icon(
            onPressed: onResetWidths,
            icon: const Icon(Icons.straighten_outlined, size: 18),
            label: const Text('Re-fit columns'),
          ),
        ],
      ),
    );
  }
}
