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

void main() {
  late FitGridController<Employee> controller;

  Widget grid({
    double Function(Employee, int)? detailHeight,
    FitGridSelectionMode mode = FitGridSelectionMode.multiple,
    bool paginated = false,
  }) {
    return host(
      FitGrid<Employee>(
        controller: controller,
        selectionMode: mode,
        autofocus: true,
        paginated: paginated,
        pageSize: 10,
        detailRowHeight: 120,
        detailHeight: detailHeight,
        detailBuilder: (context, row, index) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Detail of ${row.name} @ $index'),
              TextButton(onPressed: () {}, child: Text('Act on ${row.name}')),
            ],
          ),
        ),
      ),
    );
  }

  setUp(() {
    controller = FitGridController<Employee>(
      rows: makeRows(30),
      columns: columns(),
    );
  });
  tearDown(() => controller.dispose());

  testWidgets('a chevron column is added, pinned, and paints a glyph', (
    tester,
  ) async {
    await tester.pumpWidget(grid());
    final section = fitGridSection();
    expect(section.columnLayout.leadingFrozenCount, 1);
    expect(
      fitGridCellSpec(row: 0, column: 0).icon,
      Icons.keyboard_arrow_right_rounded,
    );
    // The host's columns are not disturbed.
    expect(controller.columns.columns.length, 3);
    expect(fitGridCellText(row: 0, column: 1), 'Person 0');
  });

  testWidgets('tapping the chevron opens a panel under the row', (
    tester,
  ) async {
    await tester.pumpWidget(grid());
    await tester.tapAt(cellCentre(tester, 1, 0));
    await tester.pumpAndSettle();

    expect(controller.details.isExpanded(controller.data.view[1]), isTrue);
    expect(find.text('Detail of Person 1 @ 1'), findsOneWidget);
    // The panel is its own line, full width and as tall as asked.
    final section = fitGridSection();
    expect(section.rowCount, 31);
    expect(section.rowHeightAt(2), 120);
    final panel = tester.getRect(find.byType(ColoredBox).last);
    expect(panel.width, section.size.width);
    // Rows after it still paint their own text.
    expect(fitGridCellText(row: 3, column: 1), 'Person 2');
    // A chevron tap is a control, not a selection.
    expect(controller.selection.isEmpty, isTrue);

    await tester.tapAt(cellCentre(tester, 1, 0));
    await tester.pumpAndSettle();
    expect(find.text('Detail of Person 1 @ 1'), findsNothing);
    expect(fitGridSection().rowCount, 30);
  });

  testWidgets('a panel follows its row through a sort', (tester) async {
    await tester.pumpWidget(grid());
    controller.details.toggle(controller.data.view[3]);
    await tester.pumpAndSettle();
    expect(find.text('Detail of Person 3 @ 3'), findsOneWidget);

    controller.toggleSort('salary');
    controller.toggleSort('salary'); // descending: Person 3 is now row 26
    await tester.pumpAndSettle();
    controller.scrollTo(26);
    await tester.pumpAndSettle();
    expect(find.text('Detail of Person 3 @ 26'), findsOneWidget);
  });

  testWidgets('panel content is interactive and does not select the row', (
    tester,
  ) async {
    await tester.pumpWidget(grid());
    controller.details.toggle(controller.data.view[0]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Act on Person 0'));
    await tester.pumpAndSettle();
    expect(controller.selection.isEmpty, isTrue);
  });

  testWidgets('Enter on the chevron toggles the panel', (tester) async {
    await tester.pumpWidget(grid());
    await tester.pumpAndSettle();
    controller.focus.moveTo(0, FitGrid.detailColumnId);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('Detail of Person 0 @ 0'), findsOneWidget);
  });

  testWidgets('per-row heights, and panels are skipped by copy and export', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(grid(detailHeight: (row, i) => 100.0 + i));
    controller.details.toggle(controller.data.view[2]);
    await tester.pumpAndSettle();
    expect(fitGridSection().rowHeightAt(3), 102);

    controller.selection.select(<int>[2, 3]);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    // No blank chevron column, and no line for the panel.
    expect(copied, 'Person 2\tEngineer\t50002\nPerson 3\tDesigner\t50003');
    expect(controller.export().headers, <String>['Name', 'Role', 'Salary']);
  });

  testWidgets('panels compose with pagination and grouping', (tester) async {
    await tester.pumpWidget(grid(paginated: true));
    controller.details.toggle(controller.data.view[0]);
    await tester.pumpAndSettle();
    // Ten lines a page, the panel being one of them.
    expect(fitGridSection().rowCount, 10);
    expect(find.text('Detail of Person 0 @ 0'), findsOneWidget);

    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    await tester.pumpAndSettle();
    // Header, Person 0, its panel.
    expect(fitGridSection().rowHeightAt(2), 120);
    expect(find.text('Detail of Person 0 @ 0'), findsOneWidget);
  });

  testWidgets('a panel line is not announced as a row of blank cells', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(grid());
    controller.details.toggle(controller.data.view[0]);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Name, blank'), findsNothing);
    expect(find.text('Detail of Person 0 @ 0'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('rowKey keeps panels open across new row objects', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          rowKey: (e) => e.name,
          detailBuilder: (context, row, index) => Text('Panel ${row.name}'),
        ),
      ),
    );
    controller.details.toggle('Person 1');
    await tester.pumpAndSettle();
    expect(find.text('Panel Person 1'), findsOneWidget);

    controller.data.rows = makeRows(30); // fresh objects, same names
    await tester.pumpAndSettle();
    expect(find.text('Panel Person 1'), findsOneWidget);
  });
}
