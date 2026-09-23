import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Every switch at once, over one grid — the place to try combinations the
/// focused examples keep apart.
class PlaygroundScreen extends StatefulWidget {
  const PlaygroundScreen({super.key});

  @override
  State<PlaygroundScreen> createState() => _PlaygroundScreenState();
}

class _PlaygroundScreenState extends State<PlaygroundScreen> {
  static const _rowCounts = [100, 1000, 10000, 100000];

  late FitGridController<Employee> _controller;
  int _rowCount = 1000;
  FitGridDensity _density = FitGridDensity.standard;
  bool _striped = true;
  bool _stretch = true;
  bool _rtl = false;
  bool _wrapNotes = false;
  bool _paginated = false;
  bool _freeze = false;
  bool _grouped = false;
  bool _selectable = true;

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
      // Pinned to the leading edge, so it stays put while the rest scrolls.
      freeze: _freeze ? FitGridFreeze.start : FitGridFreeze.none,
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
      // A glyph per cell, painted by the same painter as the text — not an
      // `Icon` widget per row.
      icon: (e, _) => Icons.apartment_outlined,
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
      freeze: _freeze ? FitGridFreeze.end : FitGridFreeze.none,
      // The clipboard and the export want the number, not the formatting.
      copyValue: (e) => e.salary.toString(),
      // Computed over the rows on screen, so it agrees with the search.
      footerLabel: 'Total',
      aggregate: (rows) => '\$${rows.fold<int>(0, (sum, e) => sum + e.salary)}',
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

  /// Rebuilds the columns after a flag that lives on them changes.
  void _rebuildColumns() => _controller.columns.columns = _columns();

  void _setGrouped(bool value) {
    setState(() => _grouped = value);
    _controller.grouping.groups = value
        ? <FitGridGroup<Employee>>[
            FitGridGroup<Employee>(keyOf: (e) => e.department),
          ]
        : const <FitGridGroup<Employee>>[];
  }

  /// Exports what is on screen — sort, search and column order included.
  Future<void> _export() async {
    final selected = _controller.selection.isNotEmpty;
    final csv = fitGridToCsv(_controller.export(selectedOnly: selected));
    await Clipboard.setData(ClipboardData(text: csv));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${selected ? 'Selection' : 'All rows'} copied as CSV '
          '(${csv.length} characters)',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Directionality(
      textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
      child: DemoPage(
        title: 'Playground',
        notes: const [
          DemoNote(
            'Every feature behind one set of switches. Try 100k rows with '
            'grouping, freezing and search on together: the cost still tracks '
            'the rows on screen, not the rows in the list.',
          ),
          DemoNote(
            'Double-click a Name, Role or Salary cell to edit it. Drag a header '
            'divider to resize, double-click it to re-fit, drag a header to '
            'move the column.',
          ),
          DemoNote.recommended(
            'Change what the grid shows through the controller, so the grid '
            're-derives only what changed.',
            code:
                "controller.filter.query = 'designer';   // search\n"
                'controller.grouping.groups = [...];     // grouping\n'
                'controller.columns.autoSizeAll();       // re-fit widths',
          ),
        ],
        controls: _Controls(
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
          freeze: _freeze,
          onFreeze: (v) {
            setState(() => _freeze = v);
            _rebuildColumns();
          },
          grouped: _grouped,
          onGrouped: _setGrouped,
          selectable: _selectable,
          onSelectable: (v) => setState(() => _selectable = v),
          onSearch: (q) => _controller.filter.query = q,
          onExport: _export,
          // Drag a header divider to resize a column, or double-click it to
          // re-fit that one. This does the same to all of them at once.
          onResetWidths: _controller.columns.autoSizeAll,
          paginated: _paginated,
          onPaginated: (v) => setState(() => _paginated = v),
        ),
        child: FitGrid<Employee>(
          controller: _controller,
          theme: FitGridThemeData.fromTheme(theme, density: _density),
          striped: _striped,
          stretchColumnsToFill: _stretch,
          rowHeight: _wrapNotes
              ? const FitGridRowHeight.contentSized(min: 40, max: 120)
              : null,
          paginated: _paginated,
          selectionMode: _selectable
              ? FitGridSelectionMode.multiple
              : FitGridSelectionMode.none,
          showSelectionColumn: _selectable,
          reorderableColumns: true,
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
    required this.freeze,
    required this.onFreeze,
    required this.grouped,
    required this.onGrouped,
    required this.selectable,
    required this.onSelectable,
    required this.onSearch,
    required this.onExport,
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
  final bool freeze;
  final ValueChanged<bool> onFreeze;
  final bool grouped;
  final ValueChanged<bool> onGrouped;
  final bool selectable;
  final ValueChanged<bool> onSelectable;
  final ValueChanged<String> onSearch;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Wrap(
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
        FilterChip(label: const Text('RTL'), selected: rtl, onSelected: onRtl),
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
        FilterChip(
          label: const Text('Freeze ends'),
          selected: freeze,
          onSelected: onFreeze,
        ),
        FilterChip(
          label: const Text('Group by department'),
          selected: grouped,
          onSelected: onGrouped,
        ),
        FilterChip(
          label: const Text('Selectable'),
          selected: selectable,
          onSelected: onSelectable,
        ),
        SizedBox(
          width: 220,
          child: TextField(
            decoration: const InputDecoration(
              isDense: true,
              prefixIcon: Icon(Icons.search, size: 18),
              hintText: 'Search',
              border: OutlineInputBorder(),
            ),
            onChanged: onSearch,
          ),
        ),
        OutlinedButton.icon(
          onPressed: onResetWidths,
          icon: const Icon(Icons.straighten_outlined, size: 18),
          label: const Text('Re-fit columns'),
        ),
        OutlinedButton.icon(
          onPressed: onExport,
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Copy as CSV'),
        ),
      ],
    );
  }
}
