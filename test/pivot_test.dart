import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

class Sale {
  const Sale(this.region, this.quarter, this.amount);
  final String region;
  final int quarter;
  final num? amount;
}

const sales = <Sale>[
  Sale('North', 1, 10),
  Sale('North', 1, 20),
  Sale('North', 2, 5),
  Sale('South', 2, 40),
  Sale('South', 3, null),
  Sale('East', 1, 7),
];

final region = FitGridPivotDimension<Sale>(
  id: 'region',
  label: 'Region',
  keyOf: (s) => s.region,
);
final quarter = FitGridPivotDimension<Sale>(
  id: 'q',
  label: 'Quarter',
  keyOf: (s) => s.quarter,
  format: (k) => 'Q$k',
);
final revenue = FitGridPivotValue<Sale>(
  id: 'rev',
  label: 'Revenue',
  valueOf: (s) => s.amount,
);

void main() {
  test('aggregations skip nulls, except count', () {
    const values = <num?>[1, null, 5];
    expect(FitGridAggregation.sum.reduce(values), 6);
    expect(FitGridAggregation.average.reduce(values), 3);
    expect(FitGridAggregation.min.reduce(values), 1);
    expect(FitGridAggregation.max.reduce(values), 5);
    expect(FitGridAggregation.count.reduce(values), 3);
    expect(FitGridAggregation.sum.reduce(const <num?>[null]), isNull);
  });

  test('rows only: one row per heading, sorted', () {
    final pivot = fitGridPivot<Sale>(sales, rows: [region], values: [revenue]);
    expect(pivot.rows.map((r) => r.keys.single), ['East', 'North', 'South']);
    expect(pivot.rows.map((r) => r['rev']), [7, 35, 40]);
    expect(pivot.totals['rev'], 82);
    expect(pivot.columns.map((c) => c.id), ['region', 'rev']);
  });

  test('a column dimension spreads values under headings, with totals', () {
    final pivot = fitGridPivot<Sale>(
      sales,
      rows: [region],
      columns: quarter,
      values: [revenue],
    );
    expect(pivot.columns.map((c) => c.label), [
      'Region',
      'Q1',
      'Q2',
      'Q3',
      'Total',
    ]);
    final north = pivot.rows.firstWhere((r) => r.keys.single == 'North');
    expect(north['q=Q1/rev'], 30);
    expect(north['q=Q2/rev'], 5);
    expect(north['q=Q3/rev'], isNull);
    expect(north['total/rev'], 35);
    expect(pivot.totals['q=Q1/rev'], 37);
    expect(pivot.totals['total/rev'], 82);
  });

  test('grand averages come from the source, not from the cells', () {
    final avg = FitGridPivotValue<Sale>(
      id: 'avg',
      label: 'Average',
      valueOf: (s) => s.amount,
      aggregation: FitGridAggregation.average,
    );
    final pivot = fitGridPivot<Sale>(sales, rows: [region], values: [avg]);
    // Average of the five amounts is 16.4; the average of the three regional
    // averages would be 22.33 — the wrong answer this avoids.
    expect(pivot.totals['avg'], closeTo(16.4, 1e-9));
  });

  test('several values and a count get their own columns', () {
    final pivot = fitGridPivot<Sale>(
      sales,
      rows: [region],
      columns: quarter,
      values: [revenue, const FitGridPivotValue<Sale>.count()],
      columnTotals: false,
    );
    expect(pivot.columns.map((c) => c.label), contains('Q1 · Count'));
    expect(pivot.columns.map((c) => c.label), isNot(contains('Total')));
    final south = pivot.rows.firstWhere((r) => r.keys.single == 'South');
    expect(south['q=Q3/count'], 1, reason: 'a row with no amount still counts');
  });

  testWidgets('the result drops straight into a grid, footer and sort', (
    tester,
  ) async {
    final pivot = fitGridPivot<Sale>(
      sales,
      rows: [region],
      columns: quarter,
      values: [revenue],
    );
    final controller = FitGridController<FitGridPivotRow>(
      rows: pivot.rows,
      columns: pivot.columns,
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<FitGridPivotRow>(controller: controller)),
    );

    expect(fitGridCellText(row: 1, column: 0), 'North');
    expect(fitGridCellText(row: 1, column: 1), '30');
    expect(find.text('Total'), findsWidgets);
    expect(
      find.text('82'),
      findsOneWidget,
      reason: 'grand total in the footer',
    );

    controller.toggleSort('total/rev');
    controller.toggleSort('total/rev');
    await tester.pump();
    expect(fitGridCellText(row: 0, column: 0), 'South');
    expect(controller.export().rows.first.cells.last, '40');
  });
}
