import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/testing.dart';

class _Row {
  const _Row(this.a, this.b);
  final String a;
  final String b;
}

Widget _grid(int rowCount, {double height = 400}) => MaterialApp(
  theme: ThemeData.light(useMaterial3: true),
  home: Scaffold(
    body: SizedBox(
      width: 600,
      height: height,
      child: FitGrid<_Row>(
        rows: List<_Row>.generate(rowCount, (i) => _Row('name $i', 'role $i')),
        columns: [
          FitGridColumn<_Row>(id: 'a', label: 'Name', value: (r) => r.a),
          FitGridColumn<_Row>(id: 'b', label: 'Role', value: (r) => r.b),
        ],
      ),
    ),
  ),
);

void main() {
  testWidgets('actually runs the text pass over visible cells', (tester) async {
    await tester.pumpWidget(_grid(3));
    await tester.pump();

    // Every other test asserts geometry, and all of them would still pass if
    // the text pass never ran. This is the one that would not: a cell painter
    // is created and laid out only when paint() actually reaches that cell.
    expect(fitGridSection().paintedCellCount, 6, reason: '3 rows x 2 columns');
    expect(fitGridCellIsTruncated(row: 0, column: 0), isFalse);
  });

  testWidgets('paints cells for the window, not the dataset', (tester) async {
    await tester.pumpWidget(_grid(500, height: 200));
    await tester.pump();

    // 500 rows x 2 columns is 1000 cells. Only the windowed ones may ever be
    // laid out, so the painter count has to track the viewport instead.
    final window = fitGridLaidOutRowCount();
    expect(window, lessThan(30));
    expect(fitGridSection().paintedCellCount, window * 2);
  });

  testWidgets('identical values share one painter', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 400,
            child: FitGrid<_Row>(
              rows: List<_Row>.generate(40, (i) => const _Row('Active', 'ok')),
              columns: [
                FitGridColumn<_Row>(id: 'a', label: 'A', value: (r) => r.a),
                FitGridColumn<_Row>(id: 'b', label: 'B', value: (r) => r.b),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // Forty rows of the same two words is two laid-out cells, not eighty. This
    // is the whole reason the cache is keyed on content: a status column is the
    // most repetitive thing in any real table.
    expect(fitGridSection().paintedCellCount, 2);
  });

  testWidgets('prunes painters for rows that scrolled away', (tester) async {
    await tester.pumpWidget(_grid(5000, height: 200));
    await tester.pump();
    final before = fitGridSection().paintedCellCount;

    await tester.drag(find.byType(FitGrid<_Row>), const Offset(0, -20000));
    await tester.pump();

    // Without pruning the cache would simply grow for the length of the
    // scroll, which is the quiet way a painted grid becomes a memory leak.
    // Painters are keyed by content rather than by position, so a scroll keeps
    // a little slack for the rows it is passing — but the bound is the window,
    // never the dataset.
    expect(fitGridSection().firstVisibleRow, greaterThan(100));
    expect(fitGridSection().paintedCellCount, lessThanOrEqualTo(before * 3));
  });
}
