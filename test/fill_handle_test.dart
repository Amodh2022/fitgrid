import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class Item {
  const Item(this.name, this.qty, this.code);
  final String name;
  final int qty;
  final String code;
}

class _Sheet {
  _Sheet(int count)
    : rows = <Item>[
        for (var i = 0; i < count; i++) Item('Item ${i + 1}', i + 1, 'x'),
      ];

  List<Item> rows;
  late final FitGridController<Item> controller = FitGridController<Item>(
    rows: rows,
    columns: <FitGridColumn<Item>>[
      FitGridColumn<Item>(
        id: 'name',
        label: 'Name',
        value: (e) => e.name,
        editor: FitGridEditor<Item>(
          onCommit: (row, i, v) => _set(i, Item(v, row.qty, row.code)),
        ),
      ),
      FitGridColumn<Item>(
        id: 'qty',
        label: 'Qty',
        value: (e) => '${e.qty}',
        editor: FitGridEditor<Item>(
          validator: (_, v) => int.tryParse(v) == null ? 'Number' : null,
          onCommit: (row, i, v) =>
              _set(i, Item(row.name, int.parse(v), row.code)),
        ),
      ),
      FitGridColumn<Item>(
        id: 'code',
        label: 'Code',
        value: (e) => e.code,
        editor: FitGridEditor<Item>(
          onCommit: (row, i, v) => _set(i, Item(row.name, row.qty, v)),
        ),
      ),
    ],
  );

  void _set(int i, Item item) {
    rows = List<Item>.of(rows)..[i] = item;
    controller.data.rows = rows;
  }
}

Offset cellCentre(WidgetTester tester, int row, int column) {
  final section = fitGridSection();
  final origin = tester.getTopLeft(find.byType(FitGridSection));
  return origin +
      Offset(
        section.debugColumnLeft(column) +
            section.columnLayout.widths[column] / 2,
        section.rowOffsetAt(row) +
            section.rowHeightAt(row) / 2 -
            section.verticalOffset,
      );
}

void main() {
  group('fitGridFillSeries', () {
    test('numbers with a constant step continue it', () {
      expect(fitGridFillSeries(['1', '2', '3'], 2), ['4', '5']);
      expect(fitGridFillSeries(['10', '20'], 2), ['30', '40']);
      expect(fitGridFillSeries(['1.5', '2'], 2), ['2.5', '3.0']);
      expect(fitGridFillSeries(['1', '2'], 2, backwards: true), ['0', '-1']);
    });

    test('a single number, or an uneven series, repeats', () {
      expect(fitGridFillSeries(['5'], 3), ['5', '5', '5']);
      expect(fitGridFillSeries(['1', '2', '4'], 4), ['1', '2', '4', '1']);
    });

    test('text ending in a number counts on, padding kept', () {
      expect(fitGridFillSeries(['Item 1'], 2), ['Item 2', 'Item 3']);
      expect(fitGridFillSeries(['Q1', 'Q3'], 1), ['Q5']);
      expect(fitGridFillSeries(['Row 007'], 1), ['Row 008']);
      expect(fitGridFillSeries(['Item 3'], 1, backwards: true), ['Item 2']);
    });

    test('other text repeats, in either direction', () {
      expect(fitGridFillSeries(['a', 'b'], 3), ['a', 'b', 'a']);
      expect(fitGridFillSeries(['a', 'b'], 3, backwards: true), [
        'b',
        'a',
        'b',
      ]);
      expect(fitGridFillSeries(['A1', 'B1'], 1), ['A1']);
    });
  });

  late _Sheet sheet;
  setUp(() => sheet = _Sheet(12));
  tearDown(() => sheet.controller.dispose());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 700,
            height: 500,
            child: FitGrid<Item>(
              controller: sheet.controller,
              cellSelection: true,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Drags the fill handle to the middle of a cell.
  Future<void> dragHandleTo(WidgetTester tester, int row, int column) async {
    final section = fitGridSection();
    final origin = tester.getTopLeft(find.byType(FitGridSection));
    final start = origin + section.fillHandleRect!.center;
    final end = cellCentre(tester, row, column);
    final gesture = await tester.startGesture(
      start,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(Offset.lerp(start, end, i / 6)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('a handle sits on the corner of the range', (tester) async {
    await pump(tester);
    expect(fitGridSection().fillHandleCell, (-1, -1));
    sheet.controller.range.range = const FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 1,
      extentColumnId: 'qty',
    );
    await tester.pump();
    expect(fitGridSection().fillHandleCell, (1, 1));
    expect(fitGridSection().fillHandleRect, isNotNull);
  });

  testWidgets('dragging down continues series and repeats text', (
    tester,
  ) async {
    await pump(tester);
    sheet.controller.range.range = const FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 1,
      extentColumnId: 'code',
    );
    // Make the codes a repeating pair.
    sheet.controller.data.rows = sheet.rows = <Item>[
      const Item('Item 1', 1, 'a'),
      const Item('Item 2', 2, 'b'),
      ...sheet.rows.skip(2),
    ];
    await tester.pumpAndSettle();
    await dragHandleTo(tester, 4, 1);

    expect(sheet.rows.take(5).map((e) => '${e.name}|${e.qty}|${e.code}'), [
      'Item 1|1|a',
      'Item 2|2|b',
      'Item 3|3|a',
      'Item 4|4|b',
      'Item 5|5|a',
    ]);
    // The filled block is selected, and it is one undo step.
    final range = sheet.controller.range.range!;
    expect((range.firstRow, range.lastRow), (0, 4));
    expect(sheet.controller.history.undoDepth, 1);
    sheet.controller.undo();
    await tester.pumpAndSettle();
    expect(sheet.rows[2].code, 'x');
  });

  testWidgets('dragging right fills across, through the validators', (
    tester,
  ) async {
    await pump(tester);
    sheet.controller.range.range = const FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 0,
      extentColumnId: 'name',
    );
    await tester.pumpAndSettle();
    await dragHandleTo(tester, 0, 2);
    // "Item 1" continues as "Item 2" into qty — which refuses it — and
    // "Item 3" into code, which takes it.
    expect(sheet.rows[0].qty, 1);
    expect(sheet.rows[0].code, 'Item 3');
  });

  testWidgets('a drag that ends inside the range writes nothing', (
    tester,
  ) async {
    await pump(tester);
    sheet.controller.range.range = const FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 3,
      extentColumnId: 'qty',
    );
    await tester.pumpAndSettle();
    await dragHandleTo(tester, 1, 0);
    expect(sheet.controller.history.canUndo, isFalse);
  });

  testWidgets('pressing the handle does not start a new range', (tester) async {
    await pump(tester);
    const range = FitGridCellRange(
      anchorRow: 0,
      anchorColumnId: 'name',
      extentRow: 1,
      extentColumnId: 'qty',
    );
    sheet.controller.range.range = range;
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byType(FitGridSection));
    final gesture = await tester.startGesture(
      origin + fitGridSection().fillHandleRect!.center,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(sheet.controller.range.range, range);
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
