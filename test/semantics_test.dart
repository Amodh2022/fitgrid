import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'dart:ui' show Tristate;

import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Every node in the tree, flattened, so a test can ask what a screen reader
/// would actually be handed.
List<SemanticsNode> flatten(SemanticsNode root) {
  final all = <SemanticsNode>[];
  void visit(SemanticsNode node) {
    all.add(node);
    node.visitChildren((child) {
      visit(child);
      return true;
    });
  }

  visit(root);
  return all;
}

/// The grid's semantics tree, so a test can ask what a screen reader would be
/// handed rather than what the widgets intended.
List<SemanticsNode> tree(WidgetTester tester) =>
    flatten(tester.getSemantics(find.byType(FitGrid<Employee>)));

void main() {
  testWidgets('painted cells reach the accessibility tree', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(5), columns: columns())),
    );
    await tester.pumpAndSettle();

    final nodes = tree(tester);
    final roles = nodes.map((n) => n.getSemanticsData().role).toSet();

    expect(roles, contains(SemanticsRole.table));
    expect(roles, contains(SemanticsRole.row));
    expect(roles, contains(SemanticsRole.cell));

    final labels = nodes
        .where((n) => n.getSemanticsData().role == SemanticsRole.cell)
        .map((n) => n.getSemanticsData().label)
        .toList();
    // The column's name comes with the value, or a cell read on its own says
    // nothing about which column it is in.
    expect(labels, contains('Name, Person 0'));
    expect(labels, contains('Salary, 50000'));
    handle.dispose();
  });

  testWidgets('the tree is bounded by the viewport, not the dataset', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      host(
        FitGrid<Employee>(rows: makeRows(20000), columns: columns()),
        size: const Size(800, 400),
      ),
    );
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 20000);
    // Rows plus cells for the window only. Anything near the dataset size means
    // the accessibility tree has quietly undone virtualization.
    expect(fitGridSemanticsNodeCount(), lessThan(200));
    handle.dispose();
  });

  testWidgets('a selected row announces itself as selected', (tester) async {
    final handle = tester.ensureSemantics();

    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    controller.selection
      ..mode = FitGridSelectionMode.multiple
      ..select(<int>[2]);

    await tester.pumpWidget(host(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    final rows = tree(
      tester,
    ).where((n) => n.getSemanticsData().role == SemanticsRole.row).toList();

    expect(
      rows.where(
        (n) =>
            n.getSemanticsData().flagsCollection.isSelected == Tristate.isTrue,
      ),
      hasLength(1),
    );
    handle.dispose();
  });

  testWidgets('semanticValue overrides the painted text for a reader', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(3),
          columns: <FitGridColumn<Employee>>[
            FitGridColumn<Employee>(
              id: 'age',
              label: 'Updated',
              value: (e) => '3m',
              semanticValue: (e) => '3 minutes ago',
            ),
          ],
        ),
      ),
    );

    expect(fitGridCellText(row: 0, column: 0), '3m');
    expect(fitGridCellSpec(row: 0, column: 0).semanticLabel, '3 minutes ago');
  });

  testWidgets('headers are announced as headers', (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(3), columns: columns())),
    );
    await tester.pumpAndSettle();

    expect(
      tree(tester)
          .where((n) => n.getSemanticsData().flagsCollection.isHeader)
          .map((n) => n.getSemanticsData().label),
      containsAll(<String>['Name', 'Role', 'Salary']),
    );
    handle.dispose();
  });
}
