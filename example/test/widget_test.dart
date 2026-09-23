import 'package:fitgrid/testing.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:example/main.dart';

void main() {
  testWidgets('the demo renders a populated grid', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    await tester.pumpAndSettle();

    expect(fitGridRowCount(), 1000);
    // Painted, so there is no Text widget to find — read the cell spec instead.
    expect(fitGridRowText(0).first, '1000');
    expect(fitGridLaidOutRowCount(), lessThan(60));
  });
}
