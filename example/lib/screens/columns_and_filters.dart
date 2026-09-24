import 'dart:convert';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// The column menu, typed filters, the column chooser, header bands, and
/// saving the whole layout as JSON.
class ColumnsAndFiltersScreen extends StatefulWidget {
  const ColumnsAndFiltersScreen({super.key});

  @override
  State<ColumnsAndFiltersScreen> createState() =>
      _ColumnsAndFiltersScreenState();
}

class _ColumnsAndFiltersScreenState extends State<ColumnsAndFiltersScreen> {
  late final FitGridController<Employee> _controller =
      FitGridController<Employee>(
        rows: generateEmployees(20000),
        columns: [
          FitGridColumn<Employee>(
            id: 'name',
            label: 'Name',
            value: (e) => e.name,
            sortable: true,
            hideable: false, // a row means nothing without it
            filter: const FitGridFilterSpec.text(),
          ),
          FitGridColumn<Employee>(
            id: 'department',
            label: 'Department',
            value: (e) => e.department,
            sortable: true,
            filter: const FitGridFilterSpec.values(),
          ),
          FitGridColumn<Employee>(
            id: 'role',
            label: 'Role',
            value: (e) => e.role,
            sortable: true,
            width: const FitGridColumnWidth.auto(max: 220),
            filter: const FitGridFilterSpec.values(),
          ),
          FitGridColumn<Employee>(
            id: 'salary',
            label: 'Salary',
            value: (e) => e.salaryText,
            alignment: FitGridAlignment.end,
            sortable: true,
            comparator: (a, b) => a.salary.compareTo(b.salary),
            filter: FitGridFilterSpec.number((e) => e.salary),
          ),
          FitGridColumn<Employee>(
            id: 'started',
            label: 'Started',
            value: (e) => e.startedOnText,
            sortable: true,
            comparator: (a, b) => a.startedOn.compareTo(b.startedOn),
            filter: FitGridFilterSpec.date((e) => e.startedOn),
          ),
          FitGridColumn<Employee>(
            id: 'note',
            label: 'Note',
            value: (e) => e.note,
            width: const FitGridColumnWidth.auto(max: 260),
            overflow: FitGridOverflow.tooltipOnTruncate,
            filter: const FitGridFilterSpec.text(),
          ),
        ],
      );

  /// Where "Save layout" puts it. A real app would use shared preferences or
  /// its own backend; the point is that it is plain JSON.
  String? _saved;

  final TextEditingController _search = TextEditingController();

  /// The layout as the app declared it, taken before the user changes
  /// anything — restoring it is "reset", order and all.
  late final FitGridSavedState _initial;

  @override
  void initState() {
    super.initState();
    _initial = _controller.saveState();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    setState(() {
      _saved = const JsonEncoder.withIndent('  ')
          .convert(_controller.saveState().toJson());
    });
  }

  void _restore() {
    final saved = _saved;
    if (saved == null) return;
    _controller.restoreState(
      FitGridSavedState.fromJson(jsonDecode(saved) as Map<String, Object?>),
    );
    _search.text = _controller.filter.query;
  }

  void _reset() {
    _controller.restoreState(_initial);
    _search.text = _controller.filter.query;
  }

  Future<void> _showSaved() => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Saved layout'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: CodeBlock(_saved ?? '')),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Columns, filters & layouts',
      notes: const [
        DemoNote(
          'Every header has a menu (⋮): sort, filter, pin to either edge, size '
          'to fit, hide, and the column chooser. Department and Role filter '
          'with a checklist, Salary with number conditions, Started by date.',
        ),
        DemoNote.recommended(
          'Opt columns into filtering with a spec that says what kind of value '
          'they hold. The filter itself is data, so it reopens as it was set, '
          'saves with the layout, and reaches a server as JSON.',
          code:
              'filter: FitGridFilterSpec.number((e) => e.salary),\n'
              'filter: FitGridFilterSpec.date((e) => e.startedOn),\n'
              'filter: const FitGridFilterSpec.values(),   // a checklist',
        ),
        DemoNote(
          'The "Job" and "Pay & tenure" bands are FitGrid.columnGroups. They '
          'follow their columns through a drag, and split in two if you move a '
          'column out from between its neighbours.',
        ),
        DemoNote.recommended(
          'Save the layout when the user leaves, restore it when they return.',
          code:
              'prefs.setString("grid", jsonEncode(controller.saveState().toJson()));\n'
              'controller.restoreState(FitGridSavedState.fromJson(jsonDecode(saved)));',
        ),
        DemoNote(
          'Restoring is forgiving: a column that has since been removed is '
          'skipped, and one added since keeps the place it was declared in.',
        ),
      ],
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FitGridColumnChooser<Employee>(controller: _controller),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Search',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _controller.filter.query = v,
            ),
          ),
          FilledButton.tonal(
            onPressed: _save,
            child: const Text('Save layout'),
          ),
          FilledButton.tonal(
            onPressed: _saved == null ? null : _restore,
            child: const Text('Restore'),
          ),
          TextButton(
            onPressed: _saved == null ? null : _showSaved,
            child: const Text('Show JSON'),
          ),
          TextButton(onPressed: _reset, child: const Text('Reset')),
          ListenableBuilder(
            listenable: _controller.data,
            builder: (context, _) =>
                StatChip(label: 'Rows', value: '${_controller.data.length}'),
          ),
        ],
      ),
      child: FitGrid<Employee>(
        controller: _controller,
        showColumnMenu: true,
        reorderableColumns: true,
        columnGroups: const [
          FitGridColumnGroup(
            id: 'job',
            label: 'Job',
            columnIds: ['department', 'role'],
          ),
          FitGridColumnGroup(
            id: 'pay',
            label: 'Pay & tenure',
            columnIds: ['salary', 'started'],
          ),
        ],
      ),
    );
  }
}
