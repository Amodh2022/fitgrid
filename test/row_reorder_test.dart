import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

Offset cellCentre(WidgetTester tester, int row, int column) {
  final section = fitGridSection();
  final origin = tester.getTopLeft(find.byType(FitGridSection));
  return origin +
      Offset(
        section.debugColumnLeft(column) +
            section.columnLayout.widths[column] / 2,
        section.rowOffsetAt(row) -
            section.verticalOffset +
            section.rowHeightAt(row) / 2,
      );
}

List<String> names(FitGridController<Employee> controller) => <String>[
  for (final row in controller.data.view) row.name,
];

void main() {
  late FitGridController<Employee> controller;

  setUp(() {
    controller = FitGridController<Employee>(
      rows: makeRows(20),
      columns: columns(),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> pump(
    WidgetTester tester, {
    void Function(int, int)? onRowReorder,
  }) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          reorderableRows: true,
          onRowReorder: onRowReorder,
          selectionMode: FitGridSelectionMode.multiple,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags row [from]'s handle to the upper part of row [onto].
  Future<void> dragRow(WidgetTester tester, int from, int onto) async {
    final start = cellCentre(tester, from, 0);
    final section = fitGridSection();
    final target =
        cellCentre(tester, onto, 0) - Offset(0, section.rowHeightAt(onto) / 4);
    final gesture = await tester.startGesture(start);
    await tester.pump();
    for (var i = 1; i <= 5; i++) {
      await gesture.moveTo(Offset.lerp(start, target, i / 5)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a handle column is added, pinned first', (tester) async {
    await pump(tester);
    expect(fitGridSection().columnLayout.leadingFrozenCount, 1);
    expect(fitGridCellSpec(row: 0, column: 0).icon, Icons.drag_indicator);
    expect(fitGridCellText(row: 0, column: 1), 'Person 0');
  });

  testWidgets('dragging a handle down moves the row, not the scroll', (
    tester,
  ) async {
    await pump(tester);
    await dragRow(tester, 1, 4); // onto the top of row 4: lands before it
    expect(names(controller).take(5), <String>[
      'Person 0',
      'Person 2',
      'Person 3',
      'Person 1',
      'Person 4',
    ]);
    expect(fitGridSection().verticalOffset, 0);
    expect(fitGridSection().dropLine, -1);
  });

  testWidgets('dragging up moves the row up', (tester) async {
    await pump(tester);
    await dragRow(tester, 5, 1);
    expect(names(controller).take(3), <String>[
      'Person 0',
      'Person 5',
      'Person 1',
    ]);
  });

  testWidgets('a drag outside the handles still scrolls', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(FitGridSection), const Offset(0, -200));
    await tester.pumpAndSettle();
    expect(fitGridSection().verticalOffset, greaterThan(0));
    expect(names(controller).first, 'Person 0');
  });

  testWidgets('the selection and the focus follow the moved row', (
    tester,
  ) async {
    await pump(tester);
    controller.selection.select(<int>[1]);
    controller.focus.moveTo(1, 'name');
    await tester.pump();
    await dragRow(tester, 1, 4);
    expect(controller.selection.selected, <int>{3});
    expect(controller.focus.rowIndex, 3);
    expect(controller.data.view[3].name, 'Person 1');
  });

  testWidgets('Alt+arrows move the focused row', (tester) async {
    await pump(tester);
    controller.focus.moveTo(2, 'name');
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    await tester.pumpAndSettle();
    expect(names(controller).first, 'Person 2');
    expect(controller.focus.rowIndex, 0);
  });

  testWidgets('with onRowReorder the host moves the rows', (tester) async {
    final moves = <(int, int)>[];
    await pump(tester, onRowReorder: (from, to) => moves.add((from, to)));
    await dragRow(tester, 1, 4);
    expect(moves, <(int, int)>[(1, 3)]);
    expect(names(controller)[1], 'Person 1');
  });

  testWidgets('no moving while sorted; the handles say so', (tester) async {
    await pump(tester);
    controller.toggleSort('name');
    await tester.pumpAndSettle();
    final before = names(controller);
    await dragRow(tester, 1, 4);
    expect(names(controller), before);
    expect(
      fitGridCellSpec(row: 0, column: 0).semanticLabel,
      contains('fixed while sorted'),
    );
  });

  testWidgets('under a filter the row lands next to its drop target', (
    tester,
  ) async {
    await pump(tester);
    controller.filter.query = 'Designer'; // Person 1, 3, 5, …
    await tester.pumpAndSettle();
    await dragRow(tester, 0, 3); // Person 1 before Person 7
    // Among the supplied rows it lands right after the row it passed, the
    // hidden rows around it keeping their places.
    final all = controller.data.rows.map((e) => e.name).toList();
    expect(all.indexOf('Person 1'), all.indexOf('Person 5') + 1);
    expect(names(controller).take(4), <String>[
      'Person 3',
      'Person 5',
      'Person 1',
      'Person 7',
    ]);
  });
}
