import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  const groups = <FitGridColumnGroup>[
    FitGridColumnGroup(
      id: 'job',
      label: 'Job',
      columnIds: <String>['role', 'salary'],
    ),
  ];

  testWidgets('a band spans its columns above their headers', (tester) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          columns: columns(),
          columnGroups: groups,
        ),
      ),
    );

    final band = tester.getRect(find.text('Job'));
    final role = tester.getRect(find.text('Role'));
    final salary = tester.getRect(find.text('Salary'));
    final name = tester.getRect(find.text('Name'));

    // Above both of its columns, and centred across them.
    expect(band.bottom, lessThanOrEqualTo(role.top));
    expect(band.bottom, lessThanOrEqualTo(salary.top));
    expect(band.center.dx, greaterThan(role.left));
    expect(band.center.dx, lessThan(salary.right));
    // The ungrouped column's header takes both rows, so its label sits
    // lower than the band's and higher than the grouped labels.
    expect(name.center.dy, greaterThan(band.center.dy));
    expect(name.center.dy, lessThan(role.center.dy));
  });

  testWidgets('the header grows by the band row, and only with groups', (
    tester,
  ) async {
    Future<double> headerHeight(List<FitGridColumnGroup> groups) async {
      await tester.pumpWidget(
        host(
          FitGrid<Employee>(
            rows: makeRows(5),
            columns: columns(),
            columnGroups: groups,
          ),
        ),
      );
      return tester.getSize(find.byType(FitGridHeader<Employee>)).height;
    }

    final plain = await headerHeight(const <FitGridColumnGroup>[]);
    final grouped = await headerHeight(groups);
    expect(grouped, greaterThan(plain));
  });

  testWidgets('a group split by a reorder gets a band per run', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, columnGroups: groups)),
    );
    expect(find.text('Job'), findsOneWidget);

    controller.moveColumnBefore('salary', 'name'); // salary, name, role
    await tester.pump();
    expect(find.text('Job'), findsNWidgets(2));
  });

  testWidgets('a pinned member splits from its band, which stays whole', (
    tester,
  ) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(5),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      host(FitGrid<Employee>(controller: controller, columnGroups: groups)),
    );
    controller.columns.setFreeze('salary', FitGridFreeze.end);
    await tester.pump();
    // Role in the scrolling band, salary in the trailing pinned band.
    expect(find.text('Job'), findsNWidgets(2));
  });

  testWidgets('bands are announced as headers', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          columns: columns(),
          columnGroups: groups,
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Job')),
      matchesSemantics(label: 'Job', isHeader: true),
    );
    handle.dispose();
  });

  testWidgets('a column claimed twice belongs to the first group', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        FitGrid<Employee>(
          rows: makeRows(5),
          columns: columns(),
          columnGroups: const <FitGridColumnGroup>[
            FitGridColumnGroup(
              id: 'a',
              label: 'First',
              columnIds: <String>['role'],
            ),
            FitGridColumnGroup(
              id: 'b',
              label: 'Second',
              columnIds: <String>['role', 'salary'],
            ),
          ],
        ),
      ),
    );
    final first = tester.getRect(find.text('First')).center.dx;
    final second = tester.getRect(find.text('Second')).center.dx;
    final layout = fitGridSection().columnLayout;
    final left = tester.getTopLeft(find.byType(FitGridHeader<Employee>)).dx;
    // role is column 1, salary column 2.
    double edge(int i) => left + layout.offsets[i];
    expect(first, inInclusiveRange(edge(1), edge(2)));
    // "Second" keeps only salary, the column nobody claimed first.
    expect(second, inInclusiveRange(edge(2), edge(3)));
  });

  testWidgets('nothing changes for a grid with no groups', (tester) async {
    await tester.pumpWidget(
      host(FitGrid<Employee>(rows: makeRows(5), columns: columns())),
    );
    final theme = FitGridThemeData.fromTheme(
      ThemeData.light(useMaterial3: true),
    );
    expect(
      tester.getSize(find.byType(FitGridHeader<Employee>)).height,
      theme.effectiveHeaderHeight,
    );
  });
}
