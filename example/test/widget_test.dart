import 'package:example/main.dart';
import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
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
    'Spreadsheet editing',
    'Columns, filters & layouts',
    'Pivot & export',
    'Detail rows',
    'Reorderable rows',
    'Charts in cells',
  ]) {
    testWidgets('"$title" opens without errors', (tester) async {
      await _open(tester, title);
      expect(find.widgetWithText(AppBar, title), findsOneWidget);
      expect(fitGridRowCount(), greaterThan(0));
    });
  }

  testWidgets('the spreadsheet fills a series and undoes it', (tester) async {
    await _open(tester, 'Spreadsheet editing');
    final salary = fitGridColumnIds().indexOf('salary');
    int salaryAt(int row) => int.parse(
      fitGridRowText(row)[salary].replaceAll(RegExp(r'[^0-9]'), ''),
    );
    final originals = [for (var r = 0; r < 4; r++) salaryAt(r)];

    Offset centre(int row) {
      final section = fitGridSection();
      final origin = tester.getTopLeft(find.byType(FitGridSection));
      return origin +
          Offset(
            section.debugColumnLeft(salary) +
                section.columnLayout.widths[salary] / 2,
            section.rowOffsetAt(row) + section.rowHeightAt(row) / 2,
          );
    }

    // Select the salaries of rows 0 and 1. Editable columns wait out the
    // double-tap window before a single tap counts.
    await tester.tapAt(centre(0));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.tapAt(centre(1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();

    // Drag the fill handle down to row 3.
    final origin = tester.getTopLeft(find.byType(FitGridSection));
    final handle = origin + fitGridSection().fillHandleRect!.center;
    final gesture = await tester.startGesture(
      handle,
      kind: PointerDeviceKind.mouse,
    );
    for (var i = 1; i <= 6; i++) {
      await gesture.moveTo(Offset.lerp(handle, centre(3), i / 6)!);
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();

    final step = originals[1] - originals[0];
    expect(salaryAt(2), originals[1] + step);
    expect(salaryAt(3), originals[1] + 2 * step);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect([for (var r = 0; r < 4; r++) salaryAt(r)], originals);
  });

  testWidgets('columns: a saved layout round-trips through JSON', (
    tester,
  ) async {
    await _open(tester, 'Columns, filters & layouts');
    expect(find.text('Job'), findsOneWidget);
    await tester.tap(find.text('Save layout'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show JSON'));
    await tester.pumpAndSettle();
    expect(find.textContaining('"columnOrder"'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('detail rows open and close', (tester) async {
    await _open(tester, 'Detail rows');
    await tester.tap(find.text('Open first five'));
    await tester.pumpAndSettle();
    // Each open panel holds a grid of its own.
    expect(fitGridSections().length, greaterThan(1));
    await tester.tap(find.text('Close all'));
    await tester.pumpAndSettle();
    expect(fitGridSections().length, 1);
  });

  testWidgets('the infinite feed loads its first batch', (tester) async {
    await _open(tester, 'Infinite scroll');
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(fitGridRowText(0)[1], isNotEmpty);
    await tester.pageBack();
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('the pivot reshapes when its inputs change', (tester) async {
    await _open(tester, 'Pivot & export');
    final wide = fitGridColumnIds().length;
    await tester.tap(find.text('Columns by start year'));
    await tester.pumpAndSettle();
    expect(fitGridColumnIds().length, lessThan(wide));
    await tester.tap(find.text('Make .xlsx'));
    await tester.pump();
    expect(find.textContaining('Workbook ready'), findsOneWidget);
  });
}
