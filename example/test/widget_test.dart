import 'package:example/main.dart';
import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _open(WidgetTester tester, String title) async {
  await tester.binding.setSurfaceSize(const Size(1400, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const ExampleApp());
  await tester.scrollUntilVisible(find.text(title), 100);
  // Fully on screen, not just past the edge, or the tap lands off the card.
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the gallery lists every example', (tester) async {
    await tester.pumpWidget(const ExampleApp());
    for (final (_, examples) in exampleSections) {
      for (final example in examples) {
        await tester.scrollUntilVisible(find.text(example.title), 100);
        expect(find.text(example.title), findsOneWidget);
      }
    }
  });

  testWidgets('the playground renders a populated grid', (tester) async {
    await _open(tester, 'Playground');

    expect(fitGridRowCount(), 1000);
    // Painted, so there is no Text widget to find — read the cell spec instead.
    // The demo turns the selection column on, so the ID is the second column.
    final ids = fitGridColumnIds();
    expect(ids.first, FitGrid.selectionColumnId);
    expect(fitGridRowText(0)[ids.indexOf('id')], '1000');
    expect(fitGridLaidOutRowCount(), lessThan(60));
  });

  testWidgets('a wide window shows both designs at once', (tester) async {
    await _open(tester, 'Two designs, same data');
    expect(find.text('Admin console'), findsOneWidget);
    expect(find.text('Terminal'), findsOneWidget);
    // Both are paginated, so each has its own pager.
    expect(find.textContaining('ROWS 1-40'), findsOneWidget);
  });

  testWidgets('the lazy grid loads pages and leaves cleanly', (tester) async {
    await _open(tester, 'Lazy loading');
    // The fake server answers after its latency; the first page arrives, and
    // the pages the grid then asks for arrive after it.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
    expect(fitGridRowCount(), 250000);
    expect(fitGridRowText(0).first, '#100000');

    // Leave while a fetch could still be in flight.
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
  });

  testWidgets('widget cells are real widgets, and only a screenful', (
    tester,
  ) async {
    await _open(tester, 'Widget cells');
    expect(fitGridRowCount(), 100000);
    final switches = find.byType(Switch).evaluate().length;
    expect(switches, greaterThan(0));
    expect(switches, lessThan(40));

    // A switch owns its tap: it toggles, and the row is not selected.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(find.byType(Switch).first).value, isTrue);
  });

  for (final title in [
    'Pagination',
    'Conditional formatting',
    'Column widths & row heights',
    'Controller patterns',
    'Grouping & tree rows',
  ]) {
    testWidgets('"$title" opens without errors', (tester) async {
      await _open(tester, title);
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      expect(fitGridRowCount(), greaterThan(0));
    });
  }
}
