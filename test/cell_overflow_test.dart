import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  const _Row(this.body);
  final String body;
}

const _long =
    'a body long enough that it cannot possibly fit on a single line inside a '
    'narrow column, and so wraps onto a great many lines indeed — far more '
    'than any clamped row height could hold without spilling somewhere';

Widget _grid({
  required FitGridRowHeight rowHeight,
  int? maxLines,
  FitGridOverflow overflow = FitGridOverflow.ellipsis,
}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: 600,
        height: 400,
        child: FitGrid<_Row>(
          rows: const [_Row('short'), _Row(_long), _Row('short')],
          rowHeight: rowHeight,
          stretchColumnsToFill: false,
          columns: <FitGridColumn<_Row>>[
            FitGridColumn<_Row>(
              id: 'body',
              label: 'Body',
              value: (r) => r.body,
              width: const FitGridColumnWidth.fixed(200),
              maxLines: maxLines,
              overflow: overflow,
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('a clamped row caps its text instead of spilling', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        rowHeight: const FitGridRowHeight.contentSized(max: 60),
        maxLines: null,
      ),
    );

    final rowHeight = fitGridRowHeight(1);
    final textHeight = fitGridPaintedTextHeight(row: 1, column: 0)!;

    expect(rowHeight, 60, reason: 'the max clamp should bind');
    expect(
      textHeight,
      lessThanOrEqualTo(rowHeight),
      reason: 'text taller than its row would paint over the rows either side',
    );
    expect(fitGridCellIsTruncated(row: 1, column: 0), isTrue);
  });

  testWidgets('a fixed row height caps a wrapping column too', (tester) async {
    await tester.pumpWidget(
      _grid(rowHeight: const FitGridRowHeight.fixed(44), maxLines: 6),
    );

    final textHeight = fitGridPaintedTextHeight(row: 1, column: 0)!;

    expect(textHeight, lessThanOrEqualTo(44));
    expect(fitGridCellIsTruncated(row: 1, column: 0), isTrue);
  });

  testWidgets('a cell that fits is left alone', (tester) async {
    await tester.pumpWidget(
      _grid(rowHeight: const FitGridRowHeight.contentSized(), maxLines: 4),
    );

    expect(fitGridCellIsTruncated(row: 0, column: 0), isFalse);
    expect(
      fitGridPaintedTextHeight(row: 0, column: 0),
      lessThanOrEqualTo(fitGridRowHeight(0)),
    );
  });

  testWidgets('wrapping still uses every line the row can afford', (
    tester,
  ) async {
    await tester.pumpWidget(
      _grid(
        rowHeight: const FitGridRowHeight.contentSized(max: 100),
        maxLines: null,
      ),
    );

    final oneLine = fitGridPaintedTextHeight(row: 0, column: 0)!;
    final capped = fitGridPaintedTextHeight(row: 1, column: 0)!;

    // Capped, but not back down to a single line — the point of wrapping is
    // that the row spends the height it was given.
    expect(capped, greaterThan(oneLine * 2));
    expect(capped, lessThanOrEqualTo(fitGridRowHeight(1)));
  });

  testWidgets('a clip-overflow cell is clipped, not spilled', (tester) async {
    await tester.pumpWidget(
      _grid(
        rowHeight: const FitGridRowHeight.contentSized(max: 50),
        maxLines: null,
        overflow: FitGridOverflow.clip,
      ),
    );

    expect(
      fitGridPaintedTextHeight(row: 1, column: 0),
      lessThanOrEqualTo(fitGridRowHeight(1)),
    );
    expect(tester.takeException(), isNull);
  });
}
