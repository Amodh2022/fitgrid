import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class Node {
  const Node(this.name, [this.children = const <Node>[]]);
  final String name;
  final List<Node> children;
}

FitGridController<Employee> grouped({bool expanded = true}) {
  final controller = FitGridController<Employee>(
    rows: makeRows(10),
    columns: columns(),
  );
  controller.grouping.groups = <FitGridGroup<Employee>>[
    FitGridGroup<Employee>(keyOf: (e) => e.role, initiallyExpanded: expanded),
  ];
  return controller;
}

void main() {
  testWidgets('grouping inserts a header per group', (tester) async {
    final controller = grouped();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    // Ten rows in two groups, both open: 2 headers + 10 rows.
    expect(fitGridRowCount(), 12);
    expect(fitGridCellText(row: 0, column: 0), 'Engineer (5)');
    expect(fitGridCellText(row: 1, column: 0), 'Person 0');
  });

  testWidgets('a collapsed group costs its header and nothing else', (
    tester,
  ) async {
    final controller = grouped(expanded: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 2);
    expect(fitGridCellText(row: 0, column: 0), 'Engineer (5)');
    expect(fitGridCellText(row: 1, column: 0), 'Designer (5)');
  });

  testWidgets('a header spans the whole row', (tester) async {
    final controller = grouped();
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    // The label lives in column 0 and the rest of the header row is covered,
    // so nothing else paints there.
    expect(fitGridCellText(row: 0, column: 1), '');
    expect(fitGridCellSpec(row: 0, column: 0).icon, isNotNull);
  });

  testWidgets('tapping a header opens and closes it', (tester) async {
    final controller = grouped(expanded: false);
    addTearDown(controller.dispose);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();
    expect(fitGridRowCount(), 2);

    final section = fitGridSection();
    final origin = section.localToGlobal(Offset.zero);
    await tester.tapAt(origin + Offset(60, section.rowHeightAt(0) / 2));
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 7);
  });

  testWidgets('row indices stay global across a collapsed group', (
    tester,
  ) async {
    final controller = grouped();
    addTearDown(controller.dispose);
    controller.selection.mode = FitGridSelectionMode.multiple;

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    // Line 1 on screen is the first Engineer, which is row 0 of the data —
    // not row 1, which is where a naive offset would have put it.
    final section = fitGridSection();
    final origin = section.localToGlobal(Offset.zero);
    await tester.tapAt(
      origin + Offset(60, section.rowOffsetAt(1) + section.rowHeightAt(1) / 2),
    );
    await tester.pumpAndSettle();

    expect(controller.selection.selected, <int>{0});
  });

  testWidgets('nested groups indent and scope their keys', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(20),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
      FitGridGroup<Employee>(keyOf: (e) => e.salary.isEven ? 'even' : 'odd'),
    ];

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    expect(fitGridCellText(row: 0, column: 0), 'Engineer (10)');
    expect(fitGridCellText(row: 1, column: 0), 'even (10)');

    // Collapsing "even" under Engineer must not touch a group of the same name
    // under Designer, which is what scoping the key by its parent buys.
    final section = fitGridSection();
    final origin = section.localToGlobal(Offset.zero);
    await tester.tapAt(
      origin + Offset(80, section.rowOffsetAt(1) + section.rowHeightAt(1) / 2),
    );
    await tester.pumpAndSettle();

    expect(fitGridCellText(row: 2, column: 0), 'Designer (10)');
    expect(fitGridCellText(row: 3, column: 0), 'odd (10)');
  });

  testWidgets('a tree nests rows without inventing headers', (tester) async {
    final controller = FitGridController<Node>(
      rows: const <Node>[
        Node('root', <Node>[Node('child a'), Node('child b')]),
        Node('leaf'),
      ],
      columns: <FitGridColumn<Node>>[
        FitGridColumn<Node>(id: 'name', label: 'Name', value: (n) => n.name),
      ],
    );
    addTearDown(controller.dispose);
    controller.grouping.tree = FitGridTree<Node>(
      childrenOf: (n) => n.children,
      initiallyExpanded: true,
    );

    await tester.pumpWidget(host(FitGrid<Node>(controller: controller)));
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 4);
    expect(fitGridRowText(0).first, 'root');
    expect(fitGridRowText(1).first, 'child a');
    // The parent carries a disclosure glyph; the leaf does not.
    expect(fitGridCellSpec(row: 0, column: 0).icon, isNotNull);
    expect(fitGridCellSpec(row: 1, column: 0).icon, isNull);
  });

  test('expandAll and collapseAll override the per-group policy', () {
    final grouping = FitGridGroupingState<Employee>();
    addTearDown(grouping.dispose);
    grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role, initiallyExpanded: false),
    ];

    expect(grouping.isExpanded('Engineer'), isFalse);
    grouping.expandAll();
    // Including keys nobody has ever seen, which a set of open keys could not
    // express.
    expect(grouping.isExpanded('brand new'), isTrue);

    grouping.collapseAll();
    expect(grouping.isExpanded('brand new'), isFalse);

    grouping.reset();
    expect(grouping.isExpanded('Engineer'), isFalse);
  });
}
