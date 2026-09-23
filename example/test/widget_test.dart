import 'package:fitgrid/fitgrid.dart';
import 'package:fitgrid/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('the demo renders a populated grid', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pump();

    expect(fitGridRowCount(), 1000);
    // Painted, so there is no Text widget to find — read the cell spec instead.
    // The demo turns the selection column on, so the ID is the second column.
    final ids = fitGridColumnIds();
    expect(ids.first, FitGrid.selectionColumnId);
    expect(fitGridRowText(0)[ids.indexOf('id')], '1000');
    expect(fitGridLaidOutRowCount(), lessThan(60));
  });
}
