import 'dart:async';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Real widgets inside cells — an avatar, a status pill, a switch and action
/// buttons — over 100,000 rows, with a live count proving only the rows on
/// screen have any.
class WidgetCellsScreen extends StatefulWidget {
  const WidgetCellsScreen({super.key});

  @override
  State<WidgetCellsScreen> createState() => _WidgetCellsScreenState();
}

/// How many widget cells exist right now. Incremented and decremented by the
/// cells themselves, read on a timer — a counter that notified would ask for a
/// rebuild in the middle of the grid's layout, which is where cells are built.
int _liveCells = 0;

class _WidgetCellsScreenState extends State<WidgetCellsScreen> {
  late final FitGridController<Employee> _controller =
      FitGridController<Employee>(
        rows: generateEmployees(100000),
        selectionMode: FitGridSelectionMode.multiple,
        columns: _columns(),
      );

  /// Which rows are "active". Keyed by id, not by index, so it survives sorts.
  final Set<int> _active = <int>{};
  late final Timer _poll;
  int _shownLive = 0;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_shownLive != _liveCells) setState(() => _shownLive = _liveCells);
    });
  }

  @override
  void dispose() {
    _poll.cancel();
    _controller.dispose();
    super.dispose();
  }

  List<FitGridColumn<Employee>> _columns() => [
    FitGridColumn<Employee>(
      id: 'avatar',
      label: '',
      // Still used for search, copy, export and screen readers.
      value: (e) => e.name,
      // Widget widths are not measured: say how wide the column is.
      width: const FitGridColumnWidth.fixed(56),
      alignment: FitGridAlignment.center,
      searchable: false,
      resizable: false,
      cellBuilder: (context, e, _) => _Counted(child: _Avatar(name: e.name)),
    ),
    FitGridColumn<Employee>(
      id: 'name',
      label: 'Name',
      value: (e) => e.name,
      sortable: true,
    ),
    FitGridColumn<Employee>(
      id: 'department',
      label: 'Department',
      value: (e) => e.department,
      sortable: true,
      width: const FitGridColumnWidth.fixed(140),
      // Passive: no gestures, so tapping the pill still selects the row.
      cellBuilder: (context, e, _) =>
          _Counted(child: _Pill(label: e.department)),
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'Salary',
      value: (e) => e.salaryText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
    ),
    FitGridColumn<Employee>(
      id: 'active',
      label: 'Active',
      value: (e) => _active.contains(e.id) ? 'Yes' : 'No',
      width: const FitGridColumnWidth.fixed(88),
      alignment: FitGridAlignment.center,
      searchable: false,
      // Interactive: the switch owns its tap, so toggling it does not select
      // the row.
      cellBuilder: (context, e, _) => _Counted(
        child: Switch(
          value: _active.contains(e.id),
          // A plain setState is enough: rebuilding the grid rebuilds the widget
          // cells on screen, and only those.
          onChanged: (on) =>
              setState(() => on ? _active.add(e.id) : _active.remove(e.id)),
        ),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'actions',
      label: 'Actions',
      value: (e) => '',
      // Two compact 40-pixel buttons plus the cell padding either side.
      width: const FitGridColumnWidth.fixed(120),
      alignment: FitGridAlignment.center,
      searchable: false,
      freeze: FitGridFreeze.end,
      cellBuilder: (context, e, _) => _Counted(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Edit',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.edit_outlined, size: 18),
              onPressed: () => _say('Edit ${e.name}'),
            ),
            IconButton(
              tooltip: 'Delete',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.delete_outline, size: 18),
              onPressed: () => _say('Delete ${e.name}'),
            ),
          ],
        ),
      ),
    ),
  ];

  void _say(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Widget cells',
      notes: const [
        DemoNote(
          'The avatar, pill, switch and buttons are real widgets. The grid '
          'builds them during layout for the rows on screen only, and drops '
          'them as they scroll away. Scroll fast: the live count stays at about '
          'one screenful.',
        ),
        DemoNote.recommended(
          'Use cellBuilder for the few columns that need interaction or '
          'custom chrome. Keep value meaningful: it still drives search, sort, '
          'copy, export and what a screen reader says.',
          code:
              'FitGridColumn<Employee>(\n'
              "  id: 'actions', label: 'Actions',\n"
              "  value: (e) => '',\n"
              '  width: const FitGridColumnWidth.fixed(120), // not measured\n'
              '  cellBuilder: (context, e, index) => IconButton(\n'
              '    icon: const Icon(Icons.edit), onPressed: () => edit(e)),\n'
              ')',
        ),
        DemoNote.recommended(
          'Give builder columns a fixed or fitHeader width. Widgets are not '
          'measured the way painted text is.',
        ),
        DemoNote(
          'Taps: a widget that handles taps itself (a Switch or IconButton) '
          'keeps them, and the row is not selected. A passive widget (an avatar '
          'or pill) lets the tap select the row like painted text does.',
        ),
        DemoNote.avoid(
          'Using cellBuilder just to colour or bold text. rowColor, cellStyle '
          'and icon do that painted, at no per-cell widget cost.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 220,
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search',
                border: OutlineInputBorder(),
              ),
              onChanged: (q) => _controller.filter.query = q,
            ),
          ),
          StatChip(label: 'Rows', value: '100,000'),
          StatChip(label: 'Widget cells alive', value: '$_shownLive'),
          StatChip(label: 'Active', value: '${_active.length}'),
        ],
      ),
      child: FitGrid<Employee>(
        controller: _controller,
        rowHeight: const FitGridRowHeight.fixed(48),
        showSelectionColumn: true,
      ),
    );
  }
}

/// Counts itself in and out of [_liveCells], which is the whole point of the
/// demo's readout.
class _Counted extends StatefulWidget {
  const _Counted({required this.child});

  final Widget child;

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  void initState() {
    super.initState();
    _liveCells++;
  }

  @override
  void dispose() {
    _liveCells--;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  static const _palette = [
    Color(0xFF5B8DEF),
    Color(0xFFE5835C),
    Color(0xFF4CAF8E),
    Color(0xFFB57EDC),
    Color(0xFFE0A100),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.split(' ');
    final initials = parts.map((p) => p.isEmpty ? '' : p[0]).take(2).join();
    return CircleAvatar(
      radius: 15,
      backgroundColor: _palette[name.hashCode.abs() % _palette.length],
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, color: scheme.onSecondaryContainer),
      ),
    );
  }
}
