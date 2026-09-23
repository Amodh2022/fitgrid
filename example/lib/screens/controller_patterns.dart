import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Driving the grid through its controller instead of rebuilding it, with a
/// counter that proves the page around the grid does not rebuild.
class ControllerPatternsScreen extends StatefulWidget {
  const ControllerPatternsScreen({super.key});

  @override
  State<ControllerPatternsScreen> createState() =>
      _ControllerPatternsScreenState();
}

class _ControllerPatternsScreenState extends State<ControllerPatternsScreen> {
  late final FitGridController<Employee> _controller =
      FitGridController<Employee>(
        rows: generateEmployees(100000),
        selectionMode: FitGridSelectionMode.multiple,
        columns: [
          FitGridColumn<Employee>(
            id: 'id',
            label: 'ID',
            value: (e) => e.id.toString(),
            width: const FitGridColumnWidth.fixed(80),
            alignment: FitGridAlignment.end,
            sortable: true,
            comparator: (a, b) => a.id.compareTo(b.id),
            // Ids are not worth searching; leaving them out makes the search
            // cheaper and the matches more useful.
            searchable: false,
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
          ),
          FitGridColumn<Employee>(
            id: 'salary',
            label: 'Salary',
            value: (e) => e.salaryText,
            alignment: FitGridAlignment.end,
            sortable: true,
            comparator: (a, b) => a.salary.compareTo(b.salary),
            searchable: false,
          ),
          FitGridColumn<Employee>(
            id: 'note',
            label: 'Note',
            value: (e) => e.note,
            width: const FitGridColumnWidth.auto(max: 260),
            overflow: FitGridOverflow.tooltipOnTruncate,
          ),
        ],
      );

  int _builds = 0;
  bool _highEarners = false;
  bool _hideNotes = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setHighEarners(bool value) {
    // A column filter lives in the controller. The grid re-derives its row
    // view; nothing is re-measured and this widget does not rebuild. The
    // setState below only repaints the chip.
    _controller.filter.setColumnFilter(
      'salary',
      value ? (e) => e.salary > 150000 : null,
    );
    setState(() => _highEarners = value);
  }

  void _setHideNotes(bool value) {
    _controller.columns.setVisible('note', !value);
    setState(() => _hideNotes = value);
  }

  @override
  Widget build(BuildContext context) {
    _builds++;
    return DemoPage(
      title: 'Controller patterns',
      notes: const [
        DemoNote(
          'The counter shows how often this page has rebuilt. Type in the '
          'search box, sort, select: it only moves when you flip a chip, and '
          'then only because the chip itself needs repainting.',
        ),
        DemoNote.recommended(
          'Hold a FitGridController in your State and change the grid through '
          'it. Each part (data, filter, columns, selection, grouping, '
          'pagination) is its own ChangeNotifier, so only what changed is '
          're-derived.',
          code:
              "controller.filter.query = text;                  // search\n"
              "controller.filter.setColumnFilter('salary', (e) => e.salary > 150000);\n"
              "controller.columns.setVisible('note', false);\n"
              "controller.toggleSort('salary');\n"
              'controller.selection.selectRange(0, 9);\n'
              'controller.scrollTo(5000);',
        ),
        DemoNote.recommended(
          'Listen to just the part you display. A ListenableBuilder on '
          'controller.selection rebuilds a badge, not the page.',
          code:
              'ListenableBuilder(\n'
              '  listenable: controller.selection,\n'
              "  builder: (_, __) => Text('\${controller.selection.length} selected'),\n"
              ')',
        ),
        DemoNote.avoid(
          'Filtering in build() and passing the result as rows:. That makes a '
          'new list on every rebuild, which the grid has to copy and lay out '
          'again. Selected indices then point into a different list.',
          code:
              '// avoid\n'
              'FitGrid(rows: all.where((e) => e.name.contains(q)).toList(), ...)',
        ),
        DemoNote.avoid(
          'Declaring columns inside build(). Keep them in State or a static '
          'final, and hand the grid a new list only when a column really '
          'changes.',
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
                hintText: 'Search name, dept, note',
                border: OutlineInputBorder(),
              ),
              // Straight into the controller: no setState anywhere.
              onChanged: (q) => _controller.filter.query = q,
            ),
          ),
          FilterChip(
            label: const Text('Salary > 150k'),
            selected: _highEarners,
            onSelected: _setHighEarners,
          ),
          FilterChip(
            label: const Text('Hide notes'),
            selected: _hideNotes,
            onSelected: _setHideNotes,
          ),
          OutlinedButton(
            onPressed: () => _controller.toggleSort('salary'),
            child: const Text('Sort by salary'),
          ),
          OutlinedButton(
            onPressed: () => _controller.selection.selectRange(0, 9),
            child: const Text('Select first 10'),
          ),
          OutlinedButton(
            onPressed: () => _controller.scrollTo(5000, columnId: 'note'),
            child: const Text('Scroll to row 5001'),
          ),
          StatChip(label: 'Page builds', value: '$_builds'),
          ListenableBuilder(
            listenable: Listenable.merge([
              _controller.selection,
              _controller.data,
            ]),
            builder: (context, _) => StatChip(
              label: 'Showing',
              value:
                  '${_controller.data.length} rows · '
                  '${_controller.selection.length} selected',
            ),
          ),
        ],
      ),
      child: FitGrid<Employee>(
        controller: _controller,
        rowHeight: const FitGridRowHeight.fixed(40),
        showSelectionColumn: true,
      ),
    );
  }
}
