import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// The centre of a painted cell, in global coordinates.
Offset _cellCentre(int row, String columnId) {
  final section = fitGridSection();
  final left = fitGridColumnLeft(columnId);
  final x = left + fitGridColumnWidth(columnId) / 2;
  final y = fitGridRowOffset(row) + fitGridRowHeight(row) / 2;
  return section.localToGlobal(Offset(x, y));
}

Future<void> _doubleTapAt(WidgetTester tester, Offset position) async {
  await tester.tapAt(position);
  await tester.pump(kDoubleTapMinTime);
  await tester.tapAt(position);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a double-tap reports the row and the cell', (tester) async {
    final rows = makeRows(10);
    (Employee, int)? rowHit;
    (int, String)? cellHit;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: rows,
          columns: columns(),
          onRowDoubleTap: (row, index) => rowHit = (row, index),
          onCellDoubleTap: (row, index, columnId) =>
              cellHit = (index, columnId),
        ),
      ),
    );

    await _doubleTapAt(tester, _cellCentre(3, 'role'));

    expect(rowHit, (rows[3], 3));
    expect(cellHit, (3, 'role'));
  });

  testWidgets('a single tap is not a double-tap', (tester) async {
    var doubleTaps = 0;
    var taps = 0;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(10),
          columns: columns(),
          onRowTap: (_, _) => taps++,
          onRowDoubleTap: (_, _) => doubleTaps++,
        ),
      ),
    );

    await tester.tapAt(_cellCentre(2, 'name'));
    // The tap waits out the double-tap window before it counts as one.
    await tester.pump(kDoubleTapTimeout);
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(doubleTaps, 0);
  });

  testWidgets('a double-tap still opens the editor', (tester) async {
    var doubleTaps = 0;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(10),
          columns: <FitGridColumn<Employee>>[
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
              editor: FitGridEditor<Employee>(onCommit: (_, _, _) {}),
            ),
          ],
          onRowDoubleTap: (_, _) => doubleTaps++,
        ),
      ),
    );

    await _doubleTapAt(tester, _cellCentre(1, 'name'));

    expect(doubleTaps, 1);
    expect(find.byType(EditableText), findsOneWidget);
  });

  testWidgets('a long-press reports the row and takes it from the menu', (
    tester,
  ) async {
    final rows = makeRows(10);
    (Employee, int)? rowHit;
    (int, String)? cellHit;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: rows,
          columns: columns(),
          contextMenuBuilder: (context, target) => <PopupMenuEntry<void>>[
            const PopupMenuItem<void>(child: Text('Menu item')),
          ],
          onRowLongPress: (row, index) => rowHit = (row, index),
          onCellLongPress: (row, index, columnId) =>
              cellHit = (index, columnId),
        ),
      ),
    );

    await tester.longPressAt(_cellCentre(4, 'salary'));
    await tester.pumpAndSettle();

    expect(rowHit, (rows[4], 4));
    expect(cellHit, (4, 'salary'));
    expect(find.text('Menu item'), findsNothing);
  });

  testWidgets('without a long-press callback, a long-press opens the menu', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(10),
          columns: columns(),
          contextMenuBuilder: (context, target) => <PopupMenuEntry<void>>[
            const PopupMenuItem<void>(child: Text('Menu item')),
          ],
        ),
      ),
    );

    await tester.longPressAt(_cellCentre(4, 'salary'));
    await tester.pumpAndSettle();

    expect(find.text('Menu item'), findsOneWidget);
  });

  testWidgets('the checkbox column reports no double-tap', (tester) async {
    var doubleTaps = 0;
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(10),
          columns: columns(),
          showSelectionColumn: true,
          onRowDoubleTap: (_, _) => doubleTaps++,
        ),
      ),
    );

    await _doubleTapAt(tester, _cellCentre(2, FitGrid.selectionColumnId));

    expect(doubleTaps, 0);
  });
}
