import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/widgets/fitgrid_section.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  late FitGridController<Employee> controller;

  setUp(() {
    controller = FitGridController<Employee>(
      rows: makeRows(200),
      columns: columns(),
    );
  });
  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester, {bool sticky = true}) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(controller: controller, stickyGroupHeaders: sticky),
        size: const Size(800, 400),
      ),
    );
  }

  /// Jumps the body to an exact vertical offset. A drag would lose the touch
  /// slop and then fling, and these tests need the pixel.
  Future<void> scrollTo(WidgetTester tester, double offset) async {
    final vertical = tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.axisDirection == AxisDirection.down);
    vertical.position.jumpTo(offset);
    await tester.pumpAndSettle();
  }

  testWidgets('the group header stays pinned while its rows scroll', (
    tester,
  ) async {
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    await pump(tester);
    expect(fitGridSection().stickyRowAtOffset(1), -1);

    await scrollTo(tester, 1000);
    final section = fitGridSection();
    expect(section.verticalOffset, greaterThan(0));
    // The first line is Engineer's header; it is pinned at the top.
    expect(section.stickyRowAtOffset(1), 0);
    expect(fitGridCellText(row: 0, column: 0), startsWith('Engineer'));
  });

  testWidgets('nested headers stack, outermost on top', (tester) async {
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
      FitGridGroup<Employee>(keyOf: (e) => e.salary ~/ 50 % 2),
    ];
    await pump(tester);
    await scrollTo(tester, 600);
    final section = fitGridSection();
    final outer = section.stickyRowAtOffset(1);
    final inner = section.stickyRowAtOffset(section.rowHeightAt(0) + 1);
    expect(outer, 0);
    expect(inner, greaterThan(0));
    expect(fitGridSection().cellText(inner, 0), isNot(startsWith('Engineer')));
  });

  testWidgets('the next header pushes the pinned one away', (tester) async {
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    await pump(tester);
    final section = fitGridSection();
    final height = section.rowHeightAt(0);
    // Designer's header is line 101: scroll so it sits half a row below the
    // top, overlapping where the pinned Engineer header would be.
    final designerTop = section.rowOffsetAt(101);
    await scrollTo(tester, designerTop - height / 2);
    final after = fitGridSection();
    final designer = after.rowOffsetAt(101) - after.verticalOffset;
    expect(designer, inExclusiveRange(0, height));
    // Engineer's header is pinned but pushed up so that it ends exactly
    // where Designer's header begins.
    expect(after.stickyRowAtOffset(designer - 1), 0);
    expect(after.stickyRowAtOffset(designer + 1), -1);
  });

  testWidgets('tapping a pinned header collapses its group', (tester) async {
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    await pump(tester);
    await scrollTo(tester, 1000);
    final origin = tester.getTopLeft(find.byType(FitGridSection));
    await tester.tapAt(origin + const Offset(200, 5));
    await tester.pumpAndSettle();
    expect(controller.grouping.isExpanded('Engineer'), isFalse);
  });

  testWidgets('off when asked, and nothing to pin without groups', (
    tester,
  ) async {
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    await pump(tester, sticky: false);
    await scrollTo(tester, 1000);
    expect(fitGridSection().stickyRowAtOffset(1), -1);

    controller.grouping.groups = const <FitGridGroup<Employee>>[];
    await pump(tester);
    await scrollTo(tester, 1000);
    expect(fitGridSection().stickyRowAtOffset(1), -1);
  });
}
