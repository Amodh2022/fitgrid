import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// A grid that behaves like a spreadsheet: select a block of cells, copy it,
/// paste into it, drag its corner to fill, and undo any of it.
class SpreadsheetScreen extends StatefulWidget {
  const SpreadsheetScreen({super.key});

  @override
  State<SpreadsheetScreen> createState() => _SpreadsheetScreenState();
}

class _SpreadsheetScreenState extends State<SpreadsheetScreen> {
  List<Employee> _rows = generateEmployees(2000);

  late final FitGridController<Employee> _controller =
      FitGridController<Employee>(rows: _rows, columns: _columns());

  /// Writes an edit back by id. The grid never touches the rows itself, and
  /// under a sort the index it hands over is a position in the sorted view,
  /// so the row's own identity is the safe thing to find it by.
  void _write(Employee row, Employee Function(Employee) change) {
    _rows = <Employee>[for (final e in _rows) e.id == row.id ? change(e) : e];
    _controller.data.rows = _rows;
  }

  List<FitGridColumn<Employee>> _columns() => [
    FitGridColumn<Employee>(
      id: 'id',
      label: 'ID',
      value: (e) => '${e.id}',
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.id.compareTo(b.id),
    ),
    FitGridColumn<Employee>(
      id: 'name',
      label: 'Name',
      value: (e) => e.name,
      sortable: true,
      editor: FitGridEditor<Employee>(
        validator: (_, v) => v.trim().isEmpty ? 'A name is required' : null,
        onCommit: (row, _, v) => _write(row, (e) => e.copyWith(name: v)),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'role',
      label: 'Role',
      value: (e) => e.role,
      sortable: true,
      width: const FitGridColumnWidth.auto(max: 220),
      editor: FitGridEditor<Employee>(
        onCommit: (row, _, v) => _write(row, (e) => e.copyWith(role: v)),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'salary',
      label: 'Salary',
      value: (e) => e.salaryText,
      // Copy, paste, fill and undo all work in the raw number, not "$72,000".
      copyValue: (e) => '${e.salary}',
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.salary.compareTo(b.salary),
      editor: FitGridEditor<Employee>(
        initialText: (e) => '${e.salary}',
        keyboardType: TextInputType.number,
        validator: (_, v) => int.tryParse(v.replaceAll(',', '')) == null
            ? 'Enter a number'
            : null,
        onCommit: (row, _, v) => _write(
          row,
          (e) => e.copyWith(salary: int.parse(v.replaceAll(',', ''))),
        ),
      ),
    ),
    FitGridColumn<Employee>(
      id: 'department',
      label: 'Department',
      value: (e) => e.department,
      sortable: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Spreadsheet editing',
      notes: const [
        DemoNote(
          'Drag with the mouse, Shift+click, or Shift+arrow keys to select a '
          'block. Ctrl+C copies it as a block; Ctrl+V pastes one from its '
          'top-left cell, or fills the block with a single copied value. '
          'Delete clears it. Drag the square on the block\'s corner to fill: '
          '1, 2 continues to 3, 4; "Item 1" to "Item 2"; anything else repeats.',
        ),
        DemoNote(
          'Shift+click a second sortable header to sort by it within the first; '
          'each sorted header shows its priority.',
        ),
        DemoNote.recommended(
          'Write one correct onCommit. Paste, Delete, the fill handle and undo '
          'all go through it — and through the validator — so the rules for '
          'typing a value are the rules for every other way a value arrives.',
          code:
              'editor: FitGridEditor(\n'
              '  initialText: (e) => "\${e.salary}",   // edit the raw number\n'
              '  validator: (_, v) => int.tryParse(v) == null ? "Number" : null,\n'
              '  onCommit: (row, index, v) => write(row.id, salary: int.parse(v)),\n'
              ')',
        ),
        DemoNote.avoid(
          'Writing back by position when the grid can be sorted. The index '
          'is into the rows as displayed; find the row by its id.',
          code:
              '// avoid under a sort\nrows[index] = rows[index].copyWith(...)',
        ),
        DemoNote(
          'Ctrl+Z undoes, Ctrl+Shift+Z or Ctrl+Y redoes. A paste of a hundred '
          'cells is one step. The buttons above call controller.undo() and '
          'redo().',
        ),
      ],
      controls: ListenableBuilder(
        listenable: _controller.history,
        builder: (context, _) => Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.tonalIcon(
              onPressed: _controller.history.canUndo ? _controller.undo : null,
              icon: const Icon(Icons.undo),
              label: const Text('Undo'),
            ),
            FilledButton.tonalIcon(
              onPressed: _controller.history.canRedo ? _controller.redo : null,
              icon: const Icon(Icons.redo),
              label: const Text('Redo'),
            ),
            StatChip(
              label: 'Undo steps',
              value: '${_controller.history.undoDepth}',
            ),
            ListenableBuilder(
              listenable: _controller.range,
              builder: (context, _) {
                final range = _controller.range.range;
                return StatChip(
                  label: 'Range',
                  value: range == null
                      ? 'none'
                      : '${range.rowCount} rows, '
                            '${range.anchorColumnId} → ${range.extentColumnId}',
                );
              },
            ),
          ],
        ),
      ),
      child: FitGrid<Employee>(
        controller: _controller,
        cellSelection: true,
        autofocus: true,
        rowKey: (e) => e.id,
      ),
    );
  }
}
