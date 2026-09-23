import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class Stock {
  const Stock(this.name, this.change, this.done, this.history);
  final String name;
  final double change;
  final double done;
  final List<num> history;
}

const stocks = <Stock>[
  Stock('Up', 5, 0.25, <num>[1, 3, 2, 5]),
  Stock('Down', -10, 1.4, <num>[4, 4, 4, 4]),
  Stock('Flat', 0, 0, <num>[9]),
];

List<FitGridColumn<Stock>> stockColumns() => <FitGridColumn<Stock>>[
  FitGridColumn<Stock>(id: 'name', label: 'Name', value: (s) => s.name),
  FitGridColumn<Stock>(
    id: 'change',
    label: 'Change',
    value: (s) => s.change.toString(),
    width: const FitGridColumnWidth.fixed(120),
    visual: FitGridCellVisual<Stock>.bar((s) => s.change),
  ),
  FitGridColumn<Stock>(
    id: 'done',
    label: 'Done',
    value: (s) => '${(s.done * 100).round()}%',
    width: const FitGridColumnWidth.fixed(120),
    visual: FitGridCellVisual<Stock>.progress((s) => s.done),
  ),
  FitGridColumn<Stock>(
    id: 'trend',
    label: 'Trend',
    value: (s) => s.history.join(', '),
    width: const FitGridColumnWidth.fixed(120),
    visual: FitGridCellVisual<Stock>.sparkline((s) => s.history, filled: true),
  ),
];

void main() {
  test('bars start from zero and cover the data range', () {
    final bar = FitGridCellVisual<Stock>.bar((s) => s.change);
    // Range -10..5: zero sits two thirds of the way across.
    final up = bar.resolve(stocks[0], (-10, 5))!;
    expect(up.from, closeTo(2 / 3, 1e-9));
    expect(up.to, 1);
    expect(up.negative, isFalse);
    final down = bar.resolve(stocks[1], (-10, 5))!;
    expect(down.from, 0);
    expect(down.to, closeTo(2 / 3, 1e-9));
    expect(down.negative, isTrue);
    // An explicit range wins and needs no data pass.
    final fixed = FitGridCellVisual<Stock>.bar(
      (s) => s.change,
      min: 0,
      max: 10,
    );
    expect(fixed.needsRange, isFalse);
    expect(fixed.resolve(stocks[0], null)!.to, 0.5);
  });

  test('progress clamps, sparklines normalise and survive a flat series', () {
    final progress = FitGridCellVisual<Stock>.progress((s) => s.done);
    expect(progress.resolve(stocks[1], null)!.to, 1);
    final line = FitGridCellVisual<Stock>.sparkline((s) => s.history);
    expect(line.resolve(stocks[0], null)!.points, <double>[0, 0.5, 0.25, 1]);
    expect(line.resolve(stocks[1], null)!.points, <double>[0.5, 0.5, 0.5, 0.5]);
    expect(
      line.resolve(stocks[2], null),
      isNull,
      reason: 'one point is no line',
    );
  });

  testWidgets('specs carry the charts; sparkline text is hidden but spoken', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(FitGrid<Stock>(rows: stocks, columns: stockColumns())),
    );
    final bar = fitGridCellSpec(row: 1, column: 1);
    expect(bar.visual!.kind, FitGridVisualKind.bar);
    expect(bar.visual!.negative, isTrue);
    expect(bar.text, '-10.0');

    final spark = fitGridCellSpec(row: 0, column: 3);
    expect(spark.visual!.kind, FitGridVisualKind.sparkline);
    expect(spark.text, isEmpty);
    expect(spark.semanticLabel, '1, 3, 2, 5');
  });

  testWidgets('charts are painted, not built', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Stock>(rows: stocks, columns: stockColumns())),
    );
    expect(
      find.byType(FitGridSection),
      paints
        ..rrect() // a data bar
        ..path(), // a sparkline
    );
    // No widget per chart.
    expect(
      find.descendant(
        of: find.byType(FitGridSection),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('the range follows the data', (tester) async {
    final controller = FitGridController<Stock>(
      rows: stocks,
      columns: stockColumns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(host(FitGrid<Stock>(controller: controller)));
    expect(fitGridCellSpec(row: 0, column: 1).visual!.to, 1);

    controller.data.rows = <Stock>[
      ...stocks,
      const Stock('Rocket', 20, 0, <num>[1, 2]),
    ];
    await tester.pump();
    // Up (+5) is now a quarter of the positive range, not all of it.
    final up = fitGridCellSpec(row: 0, column: 1).visual!;
    expect(up.to - up.from, closeTo(5 / 30, 1e-9));
  });
}
