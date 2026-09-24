import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Rows that can be written to, and columns that write to them, so paste and
/// clear have somewhere to land.
class _Sheet {
  _Sheet(int count) : rows = makeRows(count);

  List<Employee> rows;
  late final FitGridController<Employee> controller = FitGridController(
    rows: rows,
    columns: <FitGridColumn<Employee>>[
      FitGridColumn<Employee>(
        id: 'name',
        label: 'Name',
        value: (e) => e.name,
        editor: FitGridEditor<Employee>(
          onCommit: (row, index, value) =>
              _write(index, Employee(value, row.role, row.salary)),
        ),
      ),
      FitGridColumn<Employee>(id: 'role', label: 'Role', value: (e) => e.role),
      FitGridColumn<Employee>(
        id: 'salary',
        label: 'Salary',
        value: (e) => e.salary.toString(),
        editor: FitGridEditor<Employee>(
          validator: (_, value) =>
              value.isEmpty || int.tryParse(value) != null ? null : 'Number',
          onCommit: (row, index, value) => _write(
            index,
            Employee(row.name, row.role, int.tryParse(value) ?? 0),
          ),
        ),
      ),
    ],
  );

  void _write(int index, Employee employee) {
    rows = List<Employee>.of(rows)..[index] = employee;
    controller.data.rows = rows;
  }
}

Future<void> press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  List<LogicalKeyboardKey> with_ = const <LogicalKeyboardKey>[],
}) async {
  for (final modifier in with_) {
    await tester.sendKeyDownEvent(modifier);
  }
  await tester.sendKeyEvent(key);
  for (final modifier in with_.reversed) {
    await tester.sendKeyUpEvent(modifier);
  }
  await tester.pumpAndSettle();
}

/// A tap that has waited out the double-tap window, as it must on a grid with
/// editable columns before the single tap is recognised.
Future<void> tapCell(WidgetTester tester, int row, int column) async {
  await tester.tapAt(cellCentre(tester, row, column));
  await tester.pump(const Duration(milliseconds: 400));
}

Offset cellCentre(WidgetTester tester, int row, int column) {
  final section = fitGridSection();
  final origin = tester.getTopLeft(find.byType(FitGridSection));
  final layout = section.columnLayout;
  return origin +
      Offset(
        section.debugColumnLeft(column) + layout.widths[column] / 2,
        section.rowOffsetAt(row) -
            section.verticalOffset +
            section.rowHeightAt(row) / 2,
      );
}

/// Captures what the grid puts on the clipboard, and serves [paste] back.
String? useClipboard(WidgetTester tester, {String? paste}) {
  String? copied;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, Object?>{'text': paste};
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
  return copied;
}

void main() {
  test('a range knows its rows and columns in either direction', () {
    const range = FitGridCellRange(
      anchorRow: 5,
      anchorColumnId: 'c',
      extentRow: 2,
      extentColumnId: 'a',
    );
    expect(range.firstRow, 2);
    expect(range.lastRow, 5);
    expect(range.columnIdsIn(<String>['a', 'b', 'c', 'd']), <String>[
      'a',
      'b',
      'c',
    ]);
    expect(range.columnIdsIn(<String>['a', 'b']), isEmpty);
  });

  test('delimited text parses back, quotes and all', () {
    expect(
      fitGridParseDelimited('a\tb\n"x\ty"\t"say ""hi"""\r\n', delimiter: '\t'),
      <List<String>>[
        <String>['a', 'b'],
        <String>['x\ty', 'say "hi"'],
      ],
    );
    expect(fitGridParseDelimited('one'), <List<String>>[
      <String>['one'],
    ]);
    expect(fitGridParseDelimited('"multi\nline",2'), <List<String>>[
      <String>['multi\nline', '2'],
    ]);
  });

  testWidgets('shift+click selects a block and copies it as a block', (
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

    final controller = FitGridController<Employee>(
      rows: makeRows(20),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, cellSelection: true)),
    );

    await tester.tapAt(cellCentre(tester, 1, 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(cellCentre(tester, 3, 2));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    final range = controller.range.range!;
    expect((range.firstRow, range.lastRow), (1, 3));
    expect(fitGridSection().selectedRange, (1, 3, 1, 2));
    // Shift+click extended the cells, not the rows.
    expect(controller.selection.isEmpty, isTrue);

    await press(
      tester,
      LogicalKeyboardKey.keyC,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );
    expect(copied, 'Designer\t50001\nEngineer\t50002\nDesigner\t50003');
  });

  testWidgets('a mouse drag selects a block; a touch drag scrolls', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(200),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, cellSelection: true)),
    );

    final mouse = await tester.startGesture(
      cellCentre(tester, 0, 0),
      kind: PointerDeviceKind.mouse,
    );
    await mouse.moveTo(cellCentre(tester, 4, 2));
    await mouse.up();
    await tester.pumpAndSettle();
    final range = controller.range.range!;
    expect((range.anchorRow, range.anchorColumnId), (0, 'name'));
    expect((range.extentRow, range.extentColumnId), (4, 'salary'));
    expect(fitGridSection().verticalOffset, 0);

    await tester.drag(find.byType(FitGridSection), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(fitGridSection().verticalOffset, greaterThan(0));
    expect(controller.range.range, range);
  });

  testWidgets('dragging past the bottom edge scrolls and keeps extending', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(200),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(controller: controller, cellSelection: true),
        size: const Size(800, 300),
      ),
    );

    final bottom = tester.getBottomLeft(find.byType(FitGridSection));
    final gesture = await tester.startGesture(
      cellCentre(tester, 0, 0),
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 0; i < 10; i++) {
      await gesture.moveTo(bottom + Offset(40, -4.0 - i % 2));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(fitGridSection().verticalOffset, greaterThan(0));
    expect(controller.range.range!.lastRow, greaterThan(5));
  });

  testWidgets('shift+arrows extend the range, a plain arrow collapses it', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(20),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: controller,
          cellSelection: true,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(cellCentre(tester, 2, 0));
    await tester.pumpAndSettle();
    await press(
      tester,
      LogicalKeyboardKey.arrowDown,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft],
    );
    await press(
      tester,
      LogicalKeyboardKey.arrowRight,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft],
    );
    var range = controller.range.range!;
    expect((range.anchorRow, range.anchorColumnId), (2, 'name'));
    expect((range.extentRow, range.extentColumnId), (3, 'role'));

    await press(tester, LogicalKeyboardKey.escape);
    expect(controller.range.isMultiCell, isFalse);

    await press(
      tester,
      LogicalKeyboardKey.arrowDown,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.shiftLeft],
    );
    await press(tester, LogicalKeyboardKey.arrowDown);
    range = controller.range.range!;
    expect(range.isSingleCell, isTrue);
    expect(range.anchorRow, controller.focus.rowIndex);
  });

  testWidgets('paste writes a block through the editors, from the anchor', (
    tester,
  ) async {
    useClipboard(tester, paste: 'Ann\t9\nBob\tnope\nCat\t7\n');
    final sheet = _Sheet(10);
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: sheet.controller,
          cellSelection: true,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tapCell(tester, 1, 0);
    await tester.pumpAndSettle();
    await press(
      tester,
      LogicalKeyboardKey.keyV,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );

    // Two pasted columns land on name and role; role has no editor, so the
    // second column of the clipboard is skipped rather than shifted onward.
    expect(sheet.rows[1].name, 'Ann');
    expect(sheet.rows[2].name, 'Bob');
    expect(sheet.rows[3].name, 'Cat');
    expect(sheet.rows[1].role, 'Designer');
    expect(sheet.rows[4].name, 'Person 4');
    // The pasted block is left selected.
    final range = sheet.controller.range.range!;
    expect((range.firstRow, range.lastRow), (1, 3));
  });

  testWidgets('a single value pasted over a range fills it, validated', (
    tester,
  ) async {
    useClipboard(tester, paste: '42');
    final sheet = _Sheet(10);
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: sheet.controller,
          cellSelection: true,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    sheet.controller.range.range = const FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 2,
      extentColumnId: 'salary',
    );
    await tapCell(tester, 0, 0);
    sheet.controller.range.range = const FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 2,
      extentColumnId: 'salary',
    );
    await tester.pumpAndSettle();
    await press(
      tester,
      LogicalKeyboardKey.keyV,
      with_: <LogicalKeyboardKey>[LogicalKeyboardKey.controlLeft],
    );

    for (var i = 0; i <= 2; i++) {
      expect(sheet.rows[i].name, '42');
      expect(sheet.rows[i].salary, 42);
    }
    expect(sheet.rows[3].salary, 50003);
  });

  testWidgets('Delete clears the editable cells of the range', (tester) async {
    final sheet = _Sheet(10);
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: sheet.controller,
          cellSelection: true,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tapCell(tester, 0, 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tapCell(tester, 1, 2);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    await press(tester, LogicalKeyboardKey.delete);
    expect(sheet.rows[0].name, '');
    expect(sheet.rows[1].salary, 0);
    expect(sheet.rows[0].role, 'Engineer');
    expect(sheet.rows[2].name, 'Person 2');
  });

  testWidgets('no range, and no Delete, unless cellSelection is on', (
    tester,
  ) async {
    final sheet = _Sheet(10);
    addTearDown(sheet.controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: sheet.controller, autofocus: true)),
    );
    await tester.pumpAndSettle();
    await tapCell(tester, 0, 0);
    await tester.pumpAndSettle();
    expect(sheet.controller.range.isActive, isFalse);
    await press(tester, LogicalKeyboardKey.delete);
    expect(sheet.rows[0].name, 'Person 0');
  });

  testWidgets('keys typed into an open editor stay in the editor', (
    tester,
  ) async {
    final sheet = _Sheet(5);
    addTearDown(sheet.controller.dispose);
    sheet.controller.selection.mode = FitGridSelectionMode.multiple;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          controller: sheet.controller,
          cellSelection: true,
          autofocus: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    sheet.controller.focus.moveTo(0, 'name');
    sheet.controller.editing.begin(0, 'name');
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();

    expect(sheet.controller.selection.isEmpty, isTrue);
    expect(sheet.controller.focus.rowIndex, 0);
    expect(sheet.controller.editing.isEditing, isTrue);
    expect(sheet.rows[0].name, 'Person 0');
    expect(find.byType(TextField), findsOneWidget);
  });
}
