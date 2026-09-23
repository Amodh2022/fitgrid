import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/sizing/column_sizer.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

List<String> longTailRows(int count) => <String>[
  for (var i = 0; i < count; i++)
    i == count - 1 ? 'the widest value of them all' : 'x',
];

List<FitGridColumn<String>> exhaustiveColumn() => <FitGridColumn<String>>[
  FitGridColumn<String>(
    id: 'v',
    label: 'V',
    value: (r) => r,
    width: const FitGridColumnWidth.auto(measureAllRows: true),
  ),
];

void main() {
  test('exhaustive measurement is rationed across passes', () {
    final sizer = FitGridColumnSizer(measurementBudget: 100);
    addTearDown(sizer.dispose);

    final rows = longTailRows(1000);
    final columns = exhaustiveColumn();
    final theme = FitGridThemeData.fromTheme(ThemeData.light());

    FitGridColumnLayout pass() => sizer.resolve(
      columns: columns,
      rows: rows,
      theme: theme,
      availableWidth: 100,
      textDirection: TextDirection.ltr,
      stretchToFill: false,
    );

    var layout = pass();
    // The widest value is the last row, so one pass of 100 cannot have seen it.
    expect(sizer.isComplete, isFalse);
    final first = layout.widths.first;

    for (var i = 0; i < 20 && !sizer.isComplete; i++) {
      layout = pass();
    }

    expect(sizer.isComplete, isTrue);
    // Widths only ever grow towards the truth, so nothing jumps backwards on
    // the way there.
    expect(layout.widths.first, greaterThan(first));
  });

  test('a sampled column is never rationed — it is already bounded', () {
    final sizer = FitGridColumnSizer(measurementBudget: 10);
    addTearDown(sizer.dispose);

    sizer.resolve(
      columns: <FitGridColumn<String>>[
        FitGridColumn<String>(id: 'v', label: 'V', value: (r) => r),
      ],
      rows: longTailRows(5000),
      theme: FitGridThemeData.fromTheme(ThemeData.light()),
      availableWidth: 400,
      textDirection: TextDirection.ltr,
    );

    expect(sizer.isComplete, isTrue);
  });

  test('a new dataset restarts the measurement', () {
    final sizer = FitGridColumnSizer(measurementBudget: 50);
    addTearDown(sizer.dispose);
    final columns = exhaustiveColumn();
    final theme = FitGridThemeData.fromTheme(ThemeData.light());

    sizer.resolve(
      columns: columns,
      rows: longTailRows(500),
      theme: theme,
      availableWidth: 100,
      textDirection: TextDirection.ltr,
    );
    expect(sizer.isComplete, isFalse);

    // A different list is a different maximum, and carrying the old one across
    // would leave a column sized for data nobody is looking at any more.
    sizer.resolve(
      columns: columns,
      rows: <String>['tiny'],
      theme: theme,
      availableWidth: 100,
      textDirection: TextDirection.ltr,
    );
    expect(sizer.isComplete, isTrue);
  });

  testWidgets('a grid finishes measuring without being asked twice', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 600,
            height: 300,
            child: FitGrid<String>(
              rows: longTailRows(6000),
              columns: exhaustiveColumn(),
              stretchColumnsToFill: false,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The grid keeps scheduling passes until the sizer is done, so the final
    // width is the honest one even though no single frame measured 6000 rows.
    expect(fitGridColumnWidth('v'), greaterThan(150));
  });
}
