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
///   expect(fitGridCellText(row: 0, column: 1), 'Amit');
/// });
/// ```
///
/// Nothing here imports `flutter_test`. That is deliberate: `testing.dart` is
/// shipped API, and a library that imported the test framework would drag it
/// into the dependency graph of every application that uses the package. The
/// helpers find the grid themselves rather than being handed a `WidgetTester`,
/// and you use your own `expect` on what they return.
library;

import 'package:flutter/widgets.dart';

import 'src/render/cell_spec.dart';
import 'src/render/render_fitgrid_section.dart';

export 'src/render/cell_spec.dart' show FitGridCellSpec;
export 'src/render/render_fitgrid_section.dart' show RenderFitGridSection;

/// Every painted grid section currently mounted, in tree order.
List<RenderFitGridSection> fitGridSections() {
  final found = <RenderFitGridSection>[];
  void visit(Element element) {
    if (element is RenderObjectElement) {
      final renderObject = element.renderObject;
      if (renderObject is RenderFitGridSection) found.add(renderObject);
    }
    element.visitChildren(visit);
  }

  final root = WidgetsBinding.instance.rootElement;
  if (root != null) visit(root);
  return found;
}

/// The painted section behind a grid.
///
/// Pass [index] to disambiguate when a test pumps more than one grid.
RenderFitGridSection fitGridSection({int index = 0}) {
  final sections = fitGridSections();
  if (index < 0 || index >= sections.length) {
    throw StateError(
      'No FitGrid section at index $index; ${sections.length} are mounted. '
      'A grid with no rows paints no section, so check the grid is not '
      'showing its empty state.',
    );
  }
  return sections[index];
}

/// The text painted into one cell.
String fitGridCellText({
  required int row,
  required int column,
  int index = 0,
}) => fitGridSection(index: index).cellText(row, column);

/// The full paint spec behind a cell — its style, icon, highlights and
/// accessibility label as well as its text.
FitGridCellSpec fitGridCellSpec({
  required int row,
  required int column,
  int index = 0,
}) => fitGridSection(index: index).cellSpecAt(row, column);

/// The text painted across one row.
List<String> fitGridRowText(int row, {int index = 0}) {
  final section = fitGridSection(index: index);
  return <String>[
    for (var i = 0; i < section.columnLayout.length; i++)
      section.cellText(row, i),
  ];
}

/// Number of rows the grid holds, including those outside the viewport.
int fitGridRowCount({int index = 0}) => fitGridSection(index: index).rowCount;

/// Number of rows currently laid out.
///
/// Assert on this to prove virtualization is working: it should track the
/// viewport, not the dataset. A grid of 100,000 rows in a 600px viewport should
/// report tens, not tens of thousands.
int fitGridLaidOutRowCount({int index = 0}) {
  final section = fitGridSection(index: index);
  return (section.firstVisibleRow + section.visibleRowCount).clamp(
        0,
        section.rowCount,
      ) -
      section.firstVisibleRow;
}

/// How many cell painters the grid is holding.
///
/// The cost of the text pass, made observable. It should track the viewport and
/// never the dataset.
int fitGridPaintedCellCount({int index = 0}) =>
    fitGridSection(index: index).paintedCellCount;

/// How many accessibility nodes the grid is holding.
///
/// Assert on this for the same reason as [fitGridPaintedCellCount]: emitting a
/// node per row of the dataset would undo virtualization from the one direction
/// nobody watches.
int fitGridSemanticsNodeCount({int index = 0}) =>
    fitGridSection(index: index).semanticsNodeCount;

/// The resolved height of a row.
///
/// Uniform under `FitGridRowHeight.fixed`; under
/// `FitGridRowHeight.contentSized` this is what the row actually measured to,
/// which is the assertion worth making about a wrapping column.
double fitGridRowHeight(int row, {int index = 0}) =>
    fitGridSection(index: index).rowHeightAt(row);

/// The top edge of a row in content space, measured from the first row.
double fitGridRowOffset(int row, {int index = 0}) =>
    fitGridSection(index: index).rowOffsetAt(row);

/// The resolved width of a column, by column id.
double fitGridColumnWidth(String columnId, {int index = 0}) =>
    fitGridSection(index: index).columnLayout.widthOf(columnId);

/// The ids of the visible columns, in the order they are laid out — pinned
/// columns first, whatever order they were declared in.
List<String> fitGridColumnIds({int index = 0}) =>
    fitGridSection(index: index).columnLayout.ids;

/// The on-screen x of a column's leading edge, in the section's coordinates.
///
/// The assertion to make about a pinned column: it should not move when the
/// grid is scrolled sideways.
double fitGridColumnLeft(String columnId, {int index = 0}) {
  final section = fitGridSection(index: index);
  final at = section.columnLayout.indexOf(columnId);
  if (at < 0) throw StateError('No visible column "$columnId"');
  return section.debugColumnLeft(at);
}

/// Whether a cell's text is currently ellipsized.
///
/// Only meaningful for cells inside the viewport — cells outside it have not
/// been laid out, so nothing is known about them.
bool fitGridCellIsTruncated({
  required int row,
  required int column,
  int index = 0,
}) => fitGridSection(index: index).isTruncated(row, column);

/// The height of a cell's laid-out text.
///
/// Null for a cell outside the viewport, which has not been laid out. Assert on
/// it against [fitGridRowHeight] to prove a wrapping cell stays inside its row
/// rather than painting over the one below.
double? fitGridPaintedTextHeight({
  required int row,
  required int column,
  int index = 0,
}) => fitGridSection(index: index).paintedTextHeight(row, column);
