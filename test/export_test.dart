import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support.dart';

void main() {
  test('exports the visible columns with their copy values', () {
    final data = buildFitGridExport<Employee>(
      columns: <FitGridColumn<Employee>>[
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
        FitGridColumn<Employee>(
          id: 'salary',
          label: 'Salary',
          // Painted for the eye, exported for the spreadsheet.
          value: (e) => '£${e.salary}',
          copyValue: (e) => e.salary.toString(),
        ),
      ],
      rows: makeRows(2),
    );

    expect(data.headers, <String>['Name', 'Salary']);
    expect(fitGridToCsv(data), 'Name,Salary\nPerson 0,50000\nPerson 1,50001');
  });

  test('fields carrying the delimiter are quoted, not split', () {
    final data = buildFitGridExport<String>(
      columns: <FitGridColumn<String>>[
        FitGridColumn<String>(id: 'v', label: 'Value', value: (r) => r),
      ],
      rows: <String>['a,b', 'say "hi"', 'two\nlines'],
    );

    expect(fitGridToCsv(data), 'Value\n"a,b"\n"say ""hi"""\n"two\nlines"');
  });

  test('a tab export leaves commas alone', () {
    final data = buildFitGridExport<String>(
      columns: <FitGridColumn<String>>[
        FitGridColumn<String>(id: 'a', label: 'A', value: (r) => r),
        FitGridColumn<String>(id: 'b', label: 'B', value: (r) => 'x,y'),
      ],
      rows: <String>['a,b'],
    );

    // A comma is only special to the comma format, so nothing is quoted here.
    expect(fitGridToTsv(data), 'A\tB\na,b\tx,y');
  });

  test('the selection column never reaches the file', () {
    final data = buildFitGridExport<Employee>(
      columns: <FitGridColumn<Employee>>[
        FitGridColumn<Employee>(
          id: FitGrid.selectionColumnId,
          label: '',
          value: (_) => '',
        ),
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
      ],
      rows: makeRows(1),
    );

    expect(data.headers, <String>['Name']);
    expect(data.rows.single.cells, <String>['Person 0']);
  });

  test('only exports the rows asked for', () {
    final data = buildFitGridExport<Employee>(
      columns: <FitGridColumn<Employee>>[
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
      ],
      rows: makeRows(10),
      only: <int>{2, 5},
    );

    expect(data.rows.map((r) => r.cells.single), <String>[
      'Person 2',
      'Person 5',
    ]);
  });

  test('grouping survives into the export as indented headers', () {
    final rows = makeRows(4);
    final display = flattenGroupsForTest(rows);

    final data = buildFitGridExport<Employee>(
      columns: <FitGridColumn<Employee>>[
        FitGridColumn<Employee>(
          id: 'name',
          label: 'Name',
          value: (e) => e.name,
        ),
      ],
      rows: rows,
      display: display,
    );

    expect(data.rows.first.isHeader, isTrue);
    expect(fitGridToCsv(data).split('\n')[1], 'Engineer (2)');
    expect(fitGridToCsv(data).split('\n')[2], '  Person 0');
  });

  test(
    'the controller exports what is on screen, filter and sort included',
    () {
      final controller = FitGridController<Employee>(
        rows: makeRows(10),
        columns: columns(),
      );
      addTearDown(controller.dispose);

      controller.filter.query = 'Designer';
      controller.toggleSort('salary');

      final csv = fitGridToCsv(controller.export());
      final lines = csv.split('\n');

      expect(lines.first, 'Name,Role,Salary');
      expect(lines.length, 6); // header plus five designers
      expect(lines[1], 'Person 1,Designer,50001');
    },
  );
}

/// Groups the sample rows by role, everything expanded.
List<FitGridDisplayRow<Employee>> flattenGroupsForTest(List<Employee> rows) {
  final grouping = FitGridGroupingState<Employee>()
    ..groups = <FitGridGroup<Employee>>[
      FitGridGroup<Employee>(keyOf: (e) => e.role),
    ];
  addTearDown(grouping.dispose);
  return flattenGroups<Employee>(
    rows: rows,
    groups: grouping.groups,
    isExpanded: grouping.isExpanded,
  );
}
