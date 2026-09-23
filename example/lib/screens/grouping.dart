import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// Grouping one or two levels deep over a flat list, and a real hierarchy as
/// tree rows — both through the controller, with no extra widgets per header.
class GroupingScreen extends StatefulWidget {
  const GroupingScreen({super.key});

  @override
  State<GroupingScreen> createState() => _GroupingScreenState();
}

enum _Mode { flat, byDepartment, byDepartmentAndRole, tree }

class _GroupingScreenState extends State<GroupingScreen> {
  _Mode _mode = _Mode.byDepartment;

  late final FitGridController<Employee> _flat = FitGridController<Employee>(
    rows: generateEmployees(20000),
    columns: [
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
      ),
      FitGridColumn<Employee>(id: 'role', label: 'Role', value: (e) => e.role),
      FitGridColumn<Employee>(
        id: 'salary',
        label: 'Salary',
        value: (e) => e.salaryText,
        alignment: FitGridAlignment.end,
        sortable: true,
        comparator: (a, b) => a.salary.compareTo(b.salary),
        // Computed over the rows that pass the filter, not the whole list.
        footerLabel: 'Total',
        aggregate: (rows) =>
            '\$${rows.fold<int>(0, (sum, e) => sum + e.salary)}',
      ),
    ],
  );

  late final FitGridController<OrgNode> _tree = FitGridController<OrgNode>(
    rows: buildOrgChart(),
    columns: [
      FitGridColumn<OrgNode>(
        id: 'name',
        label: 'Name',
        value: (n) => n.name,
        width: const FitGridColumnWidth.auto(min: 220),
      ),
      FitGridColumn<OrgNode>(
        id: 'title',
        label: 'Title',
        value: (n) => n.title,
      ),
      FitGridColumn<OrgNode>(
        id: 'reports',
        label: 'Team size',
        value: (n) => n.teamSize == 0 ? '' : n.teamSize.toString(),
        alignment: FitGridAlignment.end,
        width: const FitGridColumnWidth.fitHeader(),
      ),
    ],
  )..grouping.tree = FitGridTree<OrgNode>(childrenOf: (n) => n.reports);

  @override
  void initState() {
    super.initState();
    _applyMode();
  }

  @override
  void dispose() {
    _flat.dispose();
    _tree.dispose();
    super.dispose();
  }

  void _applyMode() {
    _flat.grouping.groups = switch (_mode) {
      _Mode.flat || _Mode.tree => const [],
      _Mode.byDepartment => [
        FitGridGroup<Employee>(
          keyOf: (e) => e.department,
          // The label runs once per group, not once per row.
          label: (key, rows) =>
              '$key · ${rows.length} people · avg '
              '\$${rows.fold<int>(0, (s, e) => s + e.salary) ~/ rows.length}',
        ),
      ],
      _Mode.byDepartmentAndRole => [
        FitGridGroup<Employee>(keyOf: (e) => e.department),
        FitGridGroup<Employee>(keyOf: (e) => e.role, initiallyExpanded: false),
      ],
    };
  }

  FitGridGroupingState<Object?> get _grouping =>
      _mode == _Mode.tree ? _tree.grouping : _flat.grouping;

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Grouping & tree rows',
      notes: const [
        DemoNote(
          'Groups and trees both flatten to the same list of display lines. A '
          'group header is one painted cell spanning the row, and a collapsed '
          'group costs its header and nothing else.',
        ),
        DemoNote.recommended(
          'Group through the controller. The rows stay one flat list, and you '
          'never build a nested structure yourself.',
          code:
              'controller.grouping.groups = [\n'
              '  FitGridGroup(keyOf: (e) => e.department),\n'
              '  FitGridGroup(keyOf: (e) => e.role, initiallyExpanded: false),\n'
              '];',
        ),
        DemoNote.recommended(
          'For data that is already a hierarchy, pass the roots as rows and say '
          'how to find children.',
          code:
              'controller.grouping.tree =\n'
              '    FitGridTree(childrenOf: (node) => node.reports);',
        ),
        DemoNote.recommended(
          'Use expandAll() and collapseAll() rather than toggling each key. '
          'They cover groups that have not appeared yet.',
        ),
        DemoNote(
          'Row indices stay global. Collapsing a group does not renumber the '
          'rows below it, so selection and editing keep working.',
        ),
      ],
      controls: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SegmentedButton<_Mode>(
            segments: const [
              ButtonSegment(value: _Mode.flat, label: Text('Flat')),
              ButtonSegment(
                value: _Mode.byDepartment,
                label: Text('By department'),
              ),
              ButtonSegment(
                value: _Mode.byDepartmentAndRole,
                label: Text('Department → role'),
              ),
              ButtonSegment(value: _Mode.tree, label: Text('Org tree')),
            ],
            selected: {_mode},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _mode = s.first;
              _applyMode();
            }),
          ),
          OutlinedButton.icon(
            onPressed: _mode == _Mode.flat ? null : () => _grouping.expandAll(),
            icon: const Icon(Icons.unfold_more, size: 18),
            label: const Text('Expand all'),
          ),
          OutlinedButton.icon(
            onPressed: _mode == _Mode.flat
                ? null
                : () => _grouping.collapseAll(),
            icon: const Icon(Icons.unfold_less, size: 18),
            label: const Text('Collapse all'),
          ),
        ],
      ),
      child: _mode == _Mode.tree
          ? FitGrid<OrgNode>(key: const ValueKey('tree'), controller: _tree)
          : FitGrid<Employee>(
              key: const ValueKey('flat'),
              controller: _flat,
              rowHeight: const FitGridRowHeight.fixed(40),
            ),
    );
  }
}

/// A node in a reporting line. The tree is the data's own shape; the grid only
/// needs to be told how to walk it.
class OrgNode {
  const OrgNode(this.name, this.title, [this.reports = const []]);

  final String name;
  final String title;
  final List<OrgNode> reports;

  int get teamSize =>
      reports.fold<int>(reports.length, (sum, r) => sum + r.teamSize);
}

List<OrgNode> buildOrgChart() {
  final people = generateEmployees(400);
  var next = 0;
  OrgNode person(String title, [List<OrgNode> reports = const []]) =>
      OrgNode(people[next++ % people.length].name, title, reports);

  List<OrgNode> team(String lead, String member, int size) => [
    for (var i = 0; i < size; i++) person(i == 0 ? lead : member),
  ];

  return [
    person('Chief Executive Officer', [
      person('VP Engineering', [
        person('Director, Platform', [
          person('Engineering Manager', team('Staff Engineer', 'Engineer', 6)),
          person('Engineering Manager', team('Staff Engineer', 'SRE', 5)),
        ]),
        person('Director, Product Engineering', [
          person('Engineering Manager', team('Tech Lead', 'Engineer', 7)),
          person('Design Manager', team('Lead Designer', 'Designer', 4)),
        ]),
      ]),
      person('VP Finance', [
        person('Controller', team('Senior Accountant', 'Accountant', 4)),
        person('Head of FP&A', team('Lead Analyst', 'Analyst', 3)),
      ]),
      person('VP Support', [
        for (var i = 0; i < 3; i++)
          person('Support Lead', team('Senior Agent', 'Agent', 5)),
      ]),
    ]),
  ];
}
