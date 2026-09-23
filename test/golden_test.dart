@Tags(<String>['golden'])
library;

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

/// Goldens exist because the output of this package is pixels.
///
/// Every other test asserts geometry or state, and all of them would still pass
/// if the paint pass drew the right boxes in the wrong colours, put the fade on
/// the wrong edge, or mirrored the pinned band the wrong way. These are the
/// ones that would not.
///
/// They run on the Flutter test font, which draws every glyph as a filled box —
/// so they check layout, colour and structure rather than typography, which is
/// exactly the part that can regress silently.
///
/// Regenerate with `flutter test --update-goldens test/golden_test.dart`.
Widget frame(
  Widget child, {
  Size size = const Size(700, 320),
  Brightness? mode,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(
    useMaterial3: true,
    brightness: mode ?? Brightness.light,
    colorSchemeSeed: const Color(0xFF3355CC),
  ),
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: RepaintBoundary(child: child),
      ),
    ),
  ),
);

List<FitGridColumn<Employee>> noteColumns() => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    sortable: true,
  ),
  FitGridColumn<Employee>(
    id: 'note',
    label: 'Note',
    value: (e) =>
        'A note long enough that it will not fit inside the column it is in',
    width: const FitGridColumnWidth.fixed(180),
  ),
  FitGridColumn<Employee>(
    id: 'salary',
    label: 'Salary',
    value: (e) => e.salary.toString(),
    alignment: FitGridAlignment.end,
  ),
];

void main() {
  testWidgets('light', (tester) async {
    await tester.pumpWidget(
      frame(FitGrid<Employee>(rows: makeRows(8), columns: columns())),
    );
    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/light.png'),
    );
  });

  testWidgets('dark', (tester) async {
    await tester.pumpWidget(
      frame(
        FitGrid<Employee>(rows: makeRows(8), columns: columns()),
        mode: Brightness.dark,
      ),
    );
    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/dark.png'),
    );
  });

  testWidgets('densities', (tester) async {
    await tester.pumpWidget(
      frame(
        Column(
          children: <Widget>[
            for (final density in FitGridDensity.values)
              Expanded(
                child: FitGridTheme(
                  data: FitGridThemeData.fromTheme(
                    ThemeData(useMaterial3: true),
                    density: density,
                  ),
                  child: FitGrid<Employee>(
                    rows: makeRows(3),
                    columns: columns(),
                  ),
                ),
              ),
          ],
        ),
        size: const Size(700, 560),
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/densities.png'),
    );
  });

  testWidgets('overflow policies', (tester) async {
    await tester.pumpWidget(
      frame(
        Column(
          children: <Widget>[
            for (final overflow in FitGridOverflow.values)
              Expanded(
                child: FitGrid<Employee>(
                  rows: makeRows(2),
                  columns: <FitGridColumn<Employee>>[
                    for (final column in noteColumns())
                      column.id == 'note'
                          ? column.copyWith(overflow: overflow)
                          : column,
                  ],
                ),
              ),
          ],
        ),
        size: const Size(700, 640),
      ),
    );
    await expectLater(
      find.byType(Column).first,
      matchesGoldenFile('goldens/overflow.png'),
    );
  });

  testWidgets('rtl mirrors everything', (tester) async {
    await tester.pumpWidget(
      frame(
        Directionality(
          textDirection: TextDirection.rtl,
          child: FitGrid<Employee>(rows: makeRows(8), columns: noteColumns()),
        ),
      ),
    );
    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/rtl.png'),
    );
  });

  testWidgets('frozen columns and their shadow', (tester) async {
    await tester.pumpWidget(
      frame(
        FitGrid<Employee>(
          rows: makeRows(8),
          stretchColumnsToFill: false,
          columns: <FitGridColumn<Employee>>[
            FitGridColumn<Employee>(
              id: 'name',
              label: 'Name',
              value: (e) => e.name,
              width: const FitGridColumnWidth.fixed(160),
              freeze: FitGridFreeze.start,
            ),
            for (var i = 0; i < 5; i++)
              FitGridColumn<Employee>(
                id: 'filler$i',
                label: 'Filler $i',
                value: (e) => e.role,
                width: const FitGridColumnWidth.fixed(160),
              ),
            FitGridColumn<Employee>(
              id: 'salary',
              label: 'Salary',
              value: (e) => e.salary.toString(),
              width: const FitGridColumnWidth.fixed(140),
              alignment: FitGridAlignment.end,
              freeze: FitGridFreeze.end,
            ),
          ],
        ),
      ),
    );
    await tester.drag(find.byType(FitGrid<Employee>), const Offset(-200, 0));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/frozen.png'),
    );
  });

  testWidgets('selection, grouping and a footer', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(9),
      columns: <FitGridColumn<Employee>>[
        ...columns().sublist(0, 2),
        columns().last.copyWith(
          aggregate: (rows) =>
              rows.fold<int>(0, (sum, e) => sum + e.salary).toString(),
          footerLabel: 'Total',
        ),
      ],
    );
    addTearDown(controller.dispose);
    controller.grouping.groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
    controller.selection
      ..mode = FitGridSelectionMode.multiple
      ..select(<int>[0, 2]);
    controller.focus.moveTo(2, 'name');

    await tester.pumpWidget(
      frame(
        FitGrid<Employee>(controller: controller, showSelectionColumn: true),
        size: const Size(700, 420),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/grouped.png'),
    );
  });

  testWidgets('search highlighting', (tester) async {
    final controller = FitGridController<Employee>(
      rows: makeRows(8),
      columns: columns(),
    );
    addTearDown(controller.dispose);
    controller.filter.query = 'son';

    await tester.pumpWidget(frame(FitGrid<Employee>(controller: controller)));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(FitGrid<Employee>),
      matchesGoldenFile('goldens/search.png'),
    );
  });
}
