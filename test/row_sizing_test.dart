import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/src/widgets/fitgrid_section.dart';
import 'package:fitgrid/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Note {
  const _Note(this.title, this.body);
  final String title;
  final String body;
}

const String _short = 'one line';
const String _long =
    'a body long enough that it cannot possibly fit on a single line inside a '
    'column two hundred pixels wide, and so has to wrap onto several';

List<_Note> _rows(int count) => <_Note>[
  for (var i = 0; i < count; i++)
    _Note('Note $i', i.isEven ? _short : '$_long ($i)'),
];

/// A grid whose second column is allowed to wrap. Its width is fixed, because
/// an `auto` column sizes itself to its longest line and then never wraps.
Widget _grid({
  required FitGridRowHeight? rowHeight,
  int rowCount = 6,
  int? maxLines = 4,
  Size size = const Size(600, 400),
  void Function(_Note row, int rowIndex)? onRowTap,
}) => MaterialApp(
  theme: ThemeData.light(useMaterial3: true),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: FitGrid<_Note>(
          rows: _rows(rowCount),
          rowHeight: rowHeight,
          stretchColumnsToFill: false,
          onRowTap: onRowTap,
          columns: <FitGridColumn<_Note>>[
            FitGridColumn<_Note>(
              id: 'title',
              label: 'Title',
              value: (n) => n.title,
              width: const FitGridColumnWidth.fixed(120),
            ),
            FitGridColumn<_Note>(
              id: 'body',
              label: 'Body',
              value: (n) => n.body,
              width: const FitGridColumnWidth.fixed(200),
              maxLines: maxLines,
            ),
          ],
        ),
      ),
    ),
  ),
);

void main() {
  group('FitGridRowMetrics', () {
    test('uniform metrics are arithmetic', () {
      const metrics = FitGridRowMetrics.uniform(rowCount: 10, rowHeight: 20);

      expect(metrics.isUniform, isTrue);
      expect(metrics.totalHeight, 200);
      expect(metrics.offsetOf(3), 60);
      expect(metrics.heightOf(3), 20);
      expect(metrics.rowAtOffset(65), 3);
      expect(metrics.rowsSpanning(0, 100), 6);
    });

    test('measured metrics binary search a prefix sum', () {
      final metrics = FitGridRowMetrics.measured(<double>[10, 30, 20, 40]);

      expect(metrics.isUniform, isFalse);
      expect(metrics.totalHeight, 100);
      expect(metrics.offsetOf(0), 0);
      expect(metrics.offsetOf(2), 40);
      // Defined one past the end, so the bottom edge of the last row needs no
      // special case.
      expect(metrics.offsetOf(4), 100);
      expect(metrics.heightOf(1), 30);

      expect(metrics.rowAtOffset(0), 0);
      expect(metrics.rowAtOffset(9.9), 0);
      expect(metrics.rowAtOffset(10), 1);
      expect(metrics.rowAtOffset(39.9), 1);
      expect(metrics.rowAtOffset(40), 2);
      expect(metrics.rowAtOffset(99.9), 3);
    });

    test('offsets outside the content are rejected, not clamped', () {
      final metrics = FitGridRowMetrics.measured(<double>[10, 30]);

      expect(metrics.rowAtOffset(-1), -1);
      expect(metrics.rowAtOffset(40), -1);
      // Windowing wants the opposite: a position past either end still names a
      // row, so a scroll overshoot has something to draw.
      expect(metrics.clampedRowAt(-1), 0);
      expect(metrics.clampedRowAt(40), 1);
    });

    test('rowsSpanning covers the partial rows at both ends', () {
      final metrics = FitGridRowMetrics.measured(<double>[10, 30, 20, 40]);

      // From row 1 (top 10), 45px reaches y=55, which is inside row 2.
      expect(metrics.rowsSpanning(1, 45), 2);
      // One pixel further and row 3 is partly on screen too.
      expect(metrics.rowsSpanning(1, 51), 3);
      expect(metrics.rowsSpanning(0, 0), 1);
    });
  });

  group('content-sized rows', () {
    testWidgets('a wrapping cell makes its row taller', (tester) async {
      await tester.pumpWidget(
        _grid(rowHeight: const FitGridRowHeight.contentSized()),
      );

      final oneLine = fitGridRowHeight(0);
      final wrapped = fitGridRowHeight(1);

      expect(wrapped, greaterThan(oneLine));
      // Rows alternate short and long, so heights alternate too.
      expect(fitGridRowHeight(2), oneLine);
      expect(fitGridRowHeight(3), wrapped);
    });

    testWidgets('offsets accumulate the real heights', (tester) async {
      await tester.pumpWidget(
        _grid(rowHeight: const FitGridRowHeight.contentSized()),
      );

      expect(fitGridRowOffset(0), 0);
      expect(
        fitGridRowOffset(2),
        closeTo(fitGridRowHeight(0) + fitGridRowHeight(1), 0.01),
      );
    });

    testWidgets('min and max clamp the measurement', (tester) async {
      await tester.pumpWidget(
        _grid(rowHeight: const FitGridRowHeight.contentSized(min: 40, max: 60)),
      );

      // The short row wants less than 40 and the wrapped one more than 60;
      // both land on their clamp.
      expect(fitGridRowHeight(0), 40);
      expect(fitGridRowHeight(1), 60);
    });

    testWidgets('costs nothing when no column can wrap', (tester) async {
      await tester.pumpWidget(
        _grid(rowHeight: const FitGridRowHeight.contentSized(), maxLines: 1),
      );

      final section = fitGridSection();
      expect(
        section.rowMetrics.isUniform,
        isTrue,
        reason: 'single-line columns should not need a height table',
      );
    });

    testWidgets('a tap lands on the row the user actually hit', (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        _grid(
          rowHeight: const FitGridRowHeight.contentSized(),
          onRowTap: (row, index) => taps.add(index),
        ),
      );

      final section = fitGridSection();
      final topLeft = tester.getTopLeft(find.byType(FitGridSection));
      // Row 3 sits behind two rows of unequal height, so dividing by a single
      // row height would land on the wrong one.
      await tester.tapAt(
        topLeft +
            Offset(20, section.rowOffsetAt(3) + section.rowHeightAt(3) / 2),
      );
      await tester.pump();

      expect(taps, <int>[3]);
    });

    testWidgets('windowing still tracks the viewport, not the dataset', (
      tester,
    ) async {
      await tester.pumpWidget(
        _grid(rowHeight: const FitGridRowHeight.contentSized(), rowCount: 2000),
      );

      // Rows differ in height, so the window is found by binary search rather
      // than division — but it is still a window.
      expect(fitGridLaidOutRowCount(), lessThan(40));
      expect(fitGridRowCount(), 2000);
    });
  });
}
