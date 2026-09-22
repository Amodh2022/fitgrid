/// Test helpers for grids.
///
/// A [FitGrid] paints its cells rather than building a `Text` widget for each
/// one. That is the whole point of the package, and it has one consequence that
/// will otherwise cost you an afternoon: `find.text('Amit')` will never match a
/// row, because there is no `Text` widget to find. There is a `TextPainter`,
/// and it is inside a `RenderBox`.
///
/// These helpers read the same cell specs the renderer paints from, so
/// assertions see exactly what the user sees.
///
/// ```dart
/// testWidgets('shows the employee', (tester) async {
///   await tester.pumpWidget(app);
///   expectFitGridCell(tester, row: 0, column: 1, 'Amit');
/// });
/// ```
library;

import 'package:flutter_test/flutter_test.dart';

import 'src/render/render_fitgrid_section.dart';
import 'src/widgets/fitgrid_section.dart';

/// The painted section behind a grid.
///
/// Pass [of] to disambiguate when a test pumps more than one grid.
RenderFitGridSection fitGridSection(WidgetTester tester, {Finder? of}) {
  final finder = of ?? find.byType(FitGridSection);
  return tester.renderObject<RenderFitGridSection>(finder);
}

/// The text painted into one cell.
String fitGridCellText(
  WidgetTester tester, {
  required int row,
  required int column,
  Finder? of,
}) => fitGridSection(tester, of: of).cellText(row, column);

/// The text painted across one row.
List<String> fitGridRowText(WidgetTester tester, int row, {Finder? of}) {
  final section = fitGridSection(tester, of: of);
  return <String>[
    for (var i = 0; i < section.columnLayout.length; i++)
      section.cellText(row, i),
  ];
}

/// Number of rows the grid holds, including those outside the viewport.
int fitGridRowCount(WidgetTester tester, {Finder? of}) =>
    fitGridSection(tester, of: of).rowCount;

/// Number of rows currently laid out.
///
/// Assert on this to prove virtualization is working: it should track the
/// viewport, not the dataset. A grid of 100,000 rows in a 600px viewport should
/// report tens, not tens of thousands.
int fitGridLaidOutRowCount(WidgetTester tester, {Finder? of}) {
  final section = fitGridSection(tester, of: of);
  return (section.firstVisibleRow + section.visibleRowCount).clamp(
        0,
        section.rowCount,
      ) -
      section.firstVisibleRow;
}

/// The resolved height of a row.
///
/// Uniform under [FitGridRowHeight.fixed]; under
/// [FitGridRowHeight.contentSized] this is what the row actually measured to,
/// which is the assertion worth making about a wrapping column.
double fitGridRowHeight(WidgetTester tester, int row, {Finder? of}) =>
    fitGridSection(tester, of: of).rowHeightAt(row);

/// The top edge of a row in content space, measured from the first row.
double fitGridRowOffset(WidgetTester tester, int row, {Finder? of}) =>
    fitGridSection(tester, of: of).rowOffsetAt(row);

/// The resolved width of a column, by column id.
double fitGridColumnWidth(WidgetTester tester, String columnId, {Finder? of}) =>
    fitGridSection(tester, of: of).columnLayout.widthOf(columnId);

/// Whether a cell's text is currently ellipsized.
///
/// Only meaningful for cells inside the viewport — cells outside it have not
/// been laid out, so nothing is known about them.
bool fitGridCellIsTruncated(
  WidgetTester tester, {
  required int row,
  required int column,
  Finder? of,
}) => fitGridSection(tester, of: of).isTruncated(row, column);

/// The height of a cell's laid-out text.
///
/// Null for a cell outside the viewport, which has not been laid out. Assert on
/// it against [fitGridRowHeight] to prove a wrapping cell stays inside its row
/// rather than painting over the one below.
double? fitGridPaintedTextHeight(
  WidgetTester tester, {
  required int row,
  required int column,
  Finder? of,
}) => fitGridSection(tester, of: of).paintedTextHeight(row, column);

/// Asserts that a cell paints [expected].
void expectFitGridCell(
  WidgetTester tester,
  String expected, {
  required int row,
  required int column,
  Finder? of,
}) {
  expect(
    fitGridCellText(tester, row: row, column: column, of: of),
    expected,
    reason: 'cell ($row, $column)',
  );
}

/// Asserts that a row paints [expected], left to right.
void expectFitGridRow(
  WidgetTester tester,
  int row,
  List<String> expected, {
  Finder? of,
}) {
  expect(fitGridRowText(tester, row, of: of), expected, reason: 'row $row');
}
