import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// The same rows and the same column definitions under two unrelated visual
/// languages, to show that every visual decision lives in the theme, the pager
/// and a few per-cell callbacks — not in a fork of the grid.
class TwoDesignsScreen extends StatefulWidget {
  const TwoDesignsScreen({super.key});

  @override
  State<TwoDesignsScreen> createState() => _TwoDesignsScreenState();
}

enum _Design { console, terminal }

class _TwoDesignsScreenState extends State<TwoDesignsScreen> {
  // Generated once. Both designs read the same list; neither copies it.
  final List<Employee> _rows = generateEmployees(2000);
  _Design _design = _Design.console;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Two designs, same data',
      notes: const [
        DemoNote(
          'Both grids below get the same rows. Everything that differs is the '
          'theme, the pager, and a couple of per-cell callbacks.',
        ),
        DemoNote.recommended(
          'Start from your app theme and override what differs. The result is '
          'a plain value, so build it once, not on every frame.',
          code:
              'final gridTheme = FitGridThemeData.fromTheme(Theme.of(context))\n'
              '    .copyWith(borderRadius: BorderRadius.zero,\n'
              '              density: FitGridDensity.compact);',
        ),
        DemoNote.recommended(
          'Theme a whole screen, or the whole app, at once by wrapping it in '
          'FitGridTheme. The terminal design does this. The console design '
          'passes theme: to one grid instead.',
          code: 'FitGridTheme(data: terminalTheme, child: FitGrid(...))',
        ),
        DemoNote.recommended(
          'Replace the pager with pagerBuilder. You get the same '
          'FitGridPaginationState the built-in one reads.',
          code:
              'pagerBuilder: (context, p) => MyPager(\n'
              '  page: p.pageIndex, pages: p.pageCount,\n'
              '  onPage: (i) => p.pageIndex = i),',
        ),
        DemoNote.avoid(
          'Wrapping the grid in a Container per row or cell to get colours. '
          'Use rowColor and cellStyle instead: they are painted, not built.',
        ),
      ],
      controls: LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= 1100
            ? const Text('Wide window: both designs side by side.')
            : SegmentedButton<_Design>(
                segments: const [
                  ButtonSegment(
                    value: _Design.console,
                    icon: Icon(Icons.dashboard_outlined),
                    label: Text('Admin console'),
                  ),
                  ButtonSegment(
                    value: _Design.terminal,
                    icon: Icon(Icons.terminal),
                    label: Text('Terminal'),
                  ),
                ],
                selected: {_design},
                onSelectionChanged: (s) => setState(() => _design = s.first),
              ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final console = _ConsoleGrid(rows: _rows);
          final terminal = _TerminalGrid(rows: _rows);
          if (constraints.maxWidth >= 1100) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: console),
                const SizedBox(width: 16),
                Expanded(child: terminal),
              ],
            );
          }
          return _design == _Design.console ? console : terminal;
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Design A: an admin console. Material 3, rounded, roomy, the built-in pager.
// ---------------------------------------------------------------------------

class _ConsoleGrid extends StatefulWidget {
  const _ConsoleGrid({required this.rows});

  final List<Employee> rows;

  @override
  State<_ConsoleGrid> createState() => _ConsoleGridState();
}

class _ConsoleGridState extends State<_ConsoleGrid> {
  // Columns are declared once, in state. The grid compares `columns` and
  // `rows` by identity: a list built inside build() is a new list every
  // frame, and a new list throws the cached layout away.
  late final List<FitGridColumn<Employee>> _columns = [
    FitGridColumn<Employee>(
      id: 'name',
      label: 'Name',
      value: (e) => e.name,
      sortable: true,
      width: const FitGridColumnWidth.auto(min: 140),
    ),
    FitGridColumn<Employee>(
      id: 'department',
      label: 'Department',
      value: (e) => e.department,
      sortable: true,
      icon: (e, _) => Icons.apartment_outlined,
    ),
    FitGridColumn<Employee>(
      id: 'role',
      label: 'Role',
      value: (e) => e.role,
      sortable: true,
      width: const FitGridColumnWidth.auto(max: 220),
      overflow: FitGridOverflow.tooltipOnTruncate,
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'Salary',
      value: (e) => e.salaryText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Admin console', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Expanded(
          child: FitGrid<Employee>(
            rows: widget.rows,
            columns: _columns,
            // Straight from the app's ColorScheme, so it follows light/dark.
            theme: FitGridThemeData.fromTheme(
              theme,
              density: FitGridDensity.comfortable,
            ),
            striped: true,
            paginated: true,
            pageSize: 25,
            selectionMode: FitGridSelectionMode.multiple,
            showSelectionColumn: true,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Design B: a trading terminal. Dark whatever the app says, monospace, square,
// dense, red/green values, and a pager built from scratch.
// ---------------------------------------------------------------------------

abstract final class _Terminal {
  static const background = Color(0xFF0B0F14);
  static const header = Color(0xFF121A24);
  static const alternate = Color(0xFF0F151D);
  static const line = Color(0xFF1E2A38);
  static const text = Color(0xFFC9D1D9);
  static const dim = Color(0xFF6E7B8B);
  static const amber = Color(0xFFFFB000);
  static const green = Color(0xFF3FB950);
  static const red = Color(0xFFF85149);

  static const mono = TextStyle(
    fontFamily: 'monospace',
    fontSize: 12.5,
    color: text,
  );

  // Shared, immutable styles. A cellStyle callback that returns one of these
  // allocates nothing; one that builds a new TextStyle allocates per visible
  // cell per paint.
  static final high = mono.copyWith(color: green, fontWeight: FontWeight.w700);
  static final low = mono.copyWith(color: red);
  static final muted = mono.copyWith(color: dim);
}

class _TerminalGrid extends StatefulWidget {
  const _TerminalGrid({required this.rows});

  final List<Employee> rows;

  @override
  State<_TerminalGrid> createState() => _TerminalGridState();
}

class _TerminalGridState extends State<_TerminalGrid> {
  late final List<FitGridColumn<Employee>> _columns = [
    FitGridColumn<Employee>(
      id: 'id',
      label: 'ID',
      value: (e) => e.id.toString(),
      // Every id is four digits, so there is nothing to measure.
      width: const FitGridColumnWidth.fixed(72),
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.id.compareTo(b.id),
      cellStyle: (e, _) => _Terminal.muted,
    ),
    FitGridColumn<Employee>(
      id: 'name',
      label: 'NAME',
      value: (e) => e.name.toUpperCase(),
      sortable: true,
    ),
    FitGridColumn<Employee>(
      id: 'department',
      label: 'DESK',
      value: (e) => e.department.substring(0, 3).toUpperCase(),
      width: const FitGridColumnWidth.fitHeader(min: 56),
      sortable: true,
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'COMP',
      value: (e) => e.salary.toString(),
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
      // A painted arrow and colour, not a widget.
      icon: (e, _) => e.salary >= 150000
          ? Icons.arrow_drop_up
          : e.salary < 70000
          ? Icons.arrow_drop_down
          : null,
      iconColor: (e, _) => e.salary >= 150000 ? _Terminal.green : _Terminal.red,
      cellStyle: (e, _) => e.salary >= 150000
          ? _Terminal.high
          : e.salary < 70000
          ? _Terminal.low
          : null,
    ),
    FitGridColumn<Employee>(
      id: 'started',
      label: 'SINCE',
      value: (e) => e.startedOnText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.startedOn.compareTo(b.startedOn),
    ),
  ];

  /// Built once from a fixed dark base, so this design stays dark even when the
  /// rest of the app is light.
  late final FitGridThemeData _theme =
      FitGridThemeData.fromTheme(
        ThemeData(brightness: Brightness.dark, useMaterial3: true),
        density: FitGridDensity.compact,
      ).copyWith(
        headerBackground: _Terminal.header,
        headerForeground: _Terminal.amber,
        headerTextStyle: _Terminal.mono.copyWith(
          color: _Terminal.amber,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        rowBackground: _Terminal.background,
        alternateRowBackground: _Terminal.alternate,
        cellTextStyle: _Terminal.mono,
        rowDivider: _Terminal.line,
        columnDivider: _Terminal.line,
        border: _Terminal.line,
        hoverBackground: const Color(0xFF16202C),
        selectedBackground: _Terminal.amber.withValues(alpha: 0.18),
        focusOutline: _Terminal.amber,
        sortIconColor: _Terminal.amber,
        searchHighlight: _Terminal.amber.withValues(alpha: 0.35),
        borderRadius: BorderRadius.zero,
        sortAscendingIcon: Icons.arrow_drop_up,
        sortDescendingIcon: Icons.arrow_drop_down,
      );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Terminal',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontFamily: 'monospace'),
        ),
        const SizedBox(height: 8),
        Expanded(
          // A subtree theme: every FitGrid below this picks it up.
          child: FitGridTheme(
            data: _theme,
            child: FitGrid<Employee>(
              rows: widget.rows,
              columns: _columns,
              striped: true,
              paginated: true,
              pageSize: 40,
              selectionMode: FitGridSelectionMode.single,
              // A lapsed rule, painted as a row background: interns dimmed.
              rowColor: (e, _) =>
                  e.role == 'Intern' ? const Color(0xFF1A1410) : null,
              pagerBuilder: (context, pagination) =>
                  _TerminalPager(pagination: pagination),
            ),
          ),
        ),
      ],
    );
  }
}

/// A pager written from nothing but [FitGridPaginationState]: numbered pages
/// around the current one, first/last, and a monospace readout.
class _TerminalPager extends StatelessWidget {
  const _TerminalPager({required this.pagination});

  final FitGridPaginationState pagination;

  @override
  Widget build(BuildContext context) {
    final p = pagination;
    final current = p.pageIndex;
    final count = p.pageCount;
    // Five numbered pages centred on the current one.
    final start = (current - 2).clamp(0, (count - 5).clamp(0, count));
    final end = (start + 5).clamp(0, count);

    return Container(
      color: _Terminal.header,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Text(
            'ROWS ${p.firstRowIndex + 1}-${p.endRowIndex} / ${p.rowCount}',
            style: _Terminal.muted,
          ),
          const Spacer(),
          _key('«', p.hasPrevious ? p.first : null),
          _key('‹', p.hasPrevious ? p.previous : null),
          for (var i = start; i < end; i++)
            _key(
              (i + 1).toString().padLeft(2, '0'),
              i == current ? null : () => p.pageIndex = i,
              active: i == current,
            ),
          _key('›', p.hasNext ? p.next : null),
          _key('»', p.hasNext ? p.last : null),
        ],
      ),
    );
  }

  Widget _key(String label, VoidCallback? onTap, {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: active ? _Terminal.amber : null,
            border: Border.all(
              color: active ? _Terminal.amber : _Terminal.line,
            ),
          ),
          child: Text(
            label,
            style: _Terminal.mono.copyWith(
              color: active
                  ? _Terminal.background
                  : onTap == null
                  ? _Terminal.line
                  : _Terminal.text,
              fontWeight: active ? FontWeight.w700 : null,
            ),
          ),
        ),
      ),
    );
  }
}
