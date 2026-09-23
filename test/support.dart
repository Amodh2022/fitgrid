import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

/// A row type with one of each shape of value, so a test can exercise text,
/// numbers and a category without inventing a model each time.
class Employee {
  const Employee(this.name, this.role, this.salary);

  final String name;
  final String role;
  final int salary;
}

List<Employee> makeRows(int count) => <Employee>[
  for (var i = 0; i < count; i++)
    Employee('Person $i', i.isEven ? 'Engineer' : 'Designer', 50000 + i),
];

List<FitGridColumn<Employee>> columns() => <FitGridColumn<Employee>>[
  FitGridColumn<Employee>(
    id: 'name',
    label: 'Name',
    value: (e) => e.name,
    sortable: true,
  ),
  FitGridColumn<Employee>(id: 'role', label: 'Role', value: (e) => e.role),
  FitGridColumn<Employee>(
    id: 'salary',
    label: 'Salary',
    value: (e) => e.salary.toString(),
    alignment: FitGridAlignment.end,
    sortable: true,
    comparator: (a, b) => a.salary.compareTo(b.salary),
  ),
];

Widget host(
  Widget child, {
  Size size = const Size(800, 600),
  TextDirection textDirection = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? ThemeData.light(useMaterial3: true),
    home: Directionality(
      textDirection: textDirection,
      child: Scaffold(
        body: Center(
          child: SizedBox(width: size.width, height: size.height, child: child),
        ),
      ),
    ),
  );
}
