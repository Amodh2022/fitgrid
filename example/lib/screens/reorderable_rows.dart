import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../shared/demo_page.dart';

class Task {
  const Task(this.title, this.owner, this.estimate);
  final String title;
  final String owner;
  final int estimate;
}

const _backlog = <Task>[
  Task('Ship the xlsx exporter', 'Priya', 3),
  Task('Write the migration guide', 'Wei', 2),
  Task('Fix focus after a paste', 'Amodh', 1),
  Task('Benchmark a million rows on web', 'Ingrid', 5),
  Task('Accessibility audit', 'Olusegun', 3),
  Task('Dark theme contrast pass', 'Mei', 2),
  Task('Tree rows: lazy children', 'Fatima', 8),
  Task('Pivot designer spike', 'Raj', 5),
  Task('Pager localisation', 'Ana', 1),
  Task('Update the screenshots', 'Jo', 1),
];

/// A backlog whose order is the point: drag rows by their handles.
class ReorderableRowsScreen extends StatefulWidget {
  const ReorderableRowsScreen({super.key});

  @override
  State<ReorderableRowsScreen> createState() => _ReorderableRowsScreenState();
}

class _ReorderableRowsScreenState extends State<ReorderableRowsScreen> {
  List<Task> _tasks = List<Task>.of(_backlog);
  String _lastMove = '—';

  late final List<FitGridColumn<Task>> _columns = [
    FitGridColumn<Task>(
      id: 'rank',
      label: '#',
      // The rank is the row's position, so it renumbers as rows move.
      value: (t) => '${_tasks.indexOf(t) + 1}',
      alignment: FitGridAlignment.end,
      width: const FitGridColumnWidth.fixed(56),
    ),
    FitGridColumn<Task>(
      id: 'title',
      label: 'Task',
      value: (t) => t.title,
      sortable: true,
    ),
    FitGridColumn<Task>(
      id: 'owner',
      label: 'Owner',
      value: (t) => t.owner,
      sortable: true,
    ),
    FitGridColumn<Task>(
      id: 'estimate',
      label: 'Days',
      value: (t) => '${t.estimate}',
      alignment: FitGridAlignment.end,
      sortable: true,
      comparator: (a, b) => a.estimate.compareTo(b.estimate),
    ),
  ];

  void _move(int from, int to) {
    setState(() {
      final tasks = List<Task>.of(_tasks);
      final task = tasks.removeAt(from);
      tasks.insert(to, task);
      _tasks = tasks;
      _lastMove = '"${task.title}" ${from + 1} → ${to + 1}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Reorderable rows',
      notes: const [
        DemoNote(
          'Drag a row by its handle, or focus a row and press Alt+Up / '
          'Alt+Down. A drag anywhere else still scrolls.',
        ),
        DemoNote.recommended(
          'When your app owns the list, handle onRowReorder and move the row '
          'yourself; indices are into the rows as displayed.',
          code:
              'FitGrid<Task>(\n'
              '  rows: tasks,\n'
              '  reorderableRows: true,\n'
              '  onRowReorder: (from, to) => setState(() {\n'
              '    tasks.insert(to, tasks.removeAt(from));\n'
              '  }),\n'
              ')',
        ),
        DemoNote(
          'Sort by a column and the handles dim: while sorted, the order on '
          'screen belongs to the sort, not to the rows. Clear the sort to '
          'move rows again.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          StatChip(label: 'Last move', value: _lastMove),
          TextButton(
            onPressed: () => setState(() => _tasks = List<Task>.of(_backlog)),
            child: const Text('Reset order'),
          ),
        ],
      ),
      child: FitGrid<Task>(
        rows: _tasks,
        columns: _columns,
        reorderableRows: true,
        onRowReorder: _move,
        autofocus: true,
      ),
    );
  }
}
