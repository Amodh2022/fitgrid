import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  testWidgets('a column is wide enough for its footer total', (tester) async {
    const total = 'Total of every salary: 123,456,789,012';
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          stretchColumnsToFill: false,
          columns: <FitGridColumn<Employee>>[
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
            ),
            FitGridColumn<Employee>(
              id: 'salary',
              label: 'Pay',
              value: (e) => '${e.salary}',
              footerLabel: 'Sum',
              aggregate: (_) => total,
            ),
          ],
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.textContaining(total, findRichText: true),
    );
    expect(paragraph.didExceedMaxLines, isFalse);
    expect(
      paragraph.size.width,
      paragraph.getMaxIntrinsicWidth(double.infinity),
    );
  });

  testWidgets('with the footer hidden, the total does not widen the column', (
    tester,
  ) async {
    Future<double> width({required bool footer}) async {
      await tester.pumpWidget(
        host(
          FitGrid<Employee>(
            rows: makeRows(5),
            stretchColumnsToFill: false,
            showFooter: footer,
            columns: <FitGridColumn<Employee>>[
              FitGridColumn<Employee>(
                id: 'salary',
                label: 'Pay',
                value: (e) => '${e.salary}',
                aggregate: (_) =>
                    'a very long total that is wider than any cell',
              ),
            ],
          ),
        ),
      );
      return tester
          .widget<FitGridHeader<Employee>>(find.byType(FitGridHeader<Employee>))
          .layout
          .widths
          .first;
    }

    expect(await width(footer: false), lessThan(await width(footer: true)));
  });
}
