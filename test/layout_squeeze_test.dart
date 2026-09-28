import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

List<FitGridColumn<Employee>> _columns() => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    filter: const FitGridFilterSpec.text(),
  ),
  FitGridColumn<Employee>(
    id: 'salary',
    label: 'Salary',
    value: (e) => e.salary.toString(),
    aggregate: (rows) => '${rows.length}',
  ),
];

void main() {
  testWidgets('a grid shorter than its chrome clips rather than overflows', (
    tester,
  ) async {
    // Header, filter row, footer and pager do not fit in 90 pixels: what an
    // Expanded grid is left with when a phone keyboard comes up.
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(40),
          columns: _columns(),
          paginated: true,
          showFilterRow: true,
        ),
        size: const Size(340, 90),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(FitGrid<Employee>)).height, 90);
  });

  testWidgets('the pager fits a phone', (tester) async {
    for (final width in <double>[320, 400, 480, 800]) {
      await tester.pumpWidget(
        host(
          FitGrid<Employee>(
            rows: makeRows(1000),
            columns: _columns(),
            paginated: true,
          ),
          size: Size(width, 400),
        ),
      );
      expect(tester.takeException(), isNull, reason: 'at $width');
      // Previous and next survive at every width.
      expect(find.byTooltip('Next page'), findsOneWidget, reason: '$width');
      expect(find.byTooltip('Previous page'), findsOneWidget);
    }
    // Wide enough for everything.
    expect(find.byTooltip('Last page'), findsOneWidget);
    expect(find.text('Rows'), findsOneWidget);
  });

  testWidgets('a filter field keeps focus as the grid is squeezed', (
    tester,
  ) async {
    Widget grid(double height) => host(
      FitGrid<Employee>(
        rows: makeRows(40),
        columns: _columns(),
        paginated: true,
        showFilterRow: true,
      ),
      size: Size(340, height),
    );
    await tester.pumpWidget(grid(400));
    final field = find.byType(EditableText);
    await tester.showKeyboard(field);
    await tester.pump();
    final state = tester.state<EditableTextState>(field);
    expect(state.widget.focusNode.hasFocus, isTrue);

    // Past the point where the frame no longer fits, and back.
    for (final height in <double>[90, 400]) {
      await tester.pumpWidget(grid(height));
      expect(tester.takeException(), isNull);
      expect(state.mounted, isTrue, reason: 'field rebuilt at $height');
      expect(state.widget.focusNode.hasFocus, isTrue);
    }
  });
}
