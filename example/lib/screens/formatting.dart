import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Conditional formatting done the painted way: row colours, cell styles and
/// glyphs, each switchable, over 50,000 rows.
class FormattingScreen extends StatefulWidget {
  const FormattingScreen({super.key});

  @override
  State<FormattingScreen> createState() => _FormattingScreenState();
}

class _FormattingScreenState extends State<FormattingScreen> {
  final List<Employee> _rows = generateEmployees(50000);
  bool _rowRule = true;
  bool _cellRule = true;
  bool _iconRule = true;
  late List<FitGridColumn<Employee>> _columns = _buildColumns();

  // Styles made once and shared. The callbacks below hand back one of these,
  // so formatting allocates nothing per cell however often the grid paints.
  static const _highPay = TextStyle(
    fontWeight: FontWeight.w700,
    color: Color(0xFF1B7F3B),
  );
  static const _lowPay = TextStyle(color: Color(0xFFB3261E));

  List<FitGridColumn<Employee>> _buildColumns() => [
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
      width: const FitGridColumnWidth.auto(max: 220),
    ),
    FitGridColumn<Employee>(
      id: 'tenure',
      label: 'Started',
      value: (e) => e.startedOnText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.startedOn.compareTo(b.startedOn),
      // A glyph painted beside the text by the same painter, not an Icon.
      icon: _iconRule
          ? (e, _) => e.startedOn.year <= 2016 ? Icons.star_rounded : null
          : null,
      iconColor: (e, _) => const Color(0xFFE0A100),
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'Salary',
      value: (e) => e.salaryText,
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
      cellStyle: _cellRule
          ? (e, _) => e.salary >= 180000
                ? _highPay
                : e.salary < 60000
                ? _lowPay
                : null
          : null,
    ),
  ];

  void _rebuildColumns() => setState(() => _columns = _buildColumns());

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Resolved once per build, not inside the callback per row.
    final internColor = scheme.tertiaryContainer.withValues(alpha: 0.45);

    return DemoPage(
      title: 'Conditional formatting',
      notes: const [
        DemoNote(
          'Every rule here goes to the paint pass. Colouring a thousand rows '
          'costs a thousand drawRect calls, not a thousand Containers, and only '
          'rows on screen are ever asked.',
        ),
        DemoNote.recommended(
          'Use rowColor for whole rows, cellStyle for one cell, and '
          'icon/iconColor for status glyphs.',
          code:
              "rowColor: (e, i) => e.role == 'Intern' ? internColor : null,\n"
              'FitGridColumn(cellStyle: (e, i) => e.salary > 180000 ? highPay : null)\n'
              'FitGridColumn(icon: (e, i) => e.veteran ? Icons.star : null)',
        ),
        DemoNote.recommended(
          'Keep the callbacks cheap and pure. Return shared const styles and '
          'colours resolved outside the callback. They run on every paint of '
          'every visible cell.',
        ),
        DemoNote.avoid(
          'Reaching for cellBuilder just to colour or bold text. It works, but '
          'every visible cell becomes a widget. Keep cellBuilder for the '
          'columns that need interaction; see the Widget cells example.',
          code:
              '// avoid, for colour alone\n'
              'cellBuilder: (ctx, e, i) => Text(e.salaryText,\n'
              '    style: TextStyle(color: Colors.red)),',
        ),
        DemoNote(
          'Select a formatted row: selection wins over rowColor, so a choice '
          'the user just made is never hidden by a rule.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilterChip(
            label: const Text('rowColor: interns'),
            selected: _rowRule,
            onSelected: (v) => setState(() => _rowRule = v),
          ),
          FilterChip(
            label: const Text('cellStyle: salary bands'),
            selected: _cellRule,
            onSelected: (v) {
              _cellRule = v;
              _rebuildColumns();
            },
          ),
          FilterChip(
            label: const Text('icon: started before 2017'),
            selected: _iconRule,
            onSelected: (v) {
              _iconRule = v;
              _rebuildColumns();
            },
          ),
        ],
      ),
      child: FitGrid<Employee>(
        rows: _rows,
        columns: _columns,
        rowHeight: const FitGridRowHeight.fixed(40),
        selectionMode: FitGridSelectionMode.multiple,
        rowColor: _rowRule
            ? (e, _) => e.role == 'Intern' ? internColor : null
            : null,
      ),
    );
  }
}
