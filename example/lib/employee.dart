import 'dart:math';

/// A row type with enough variety to exercise the sizer: names that differ
/// wildly in length, a short enumerated column, numbers that want right
/// alignment, and a notes field long enough to force truncation.
class Employee {
  const Employee({
    required this.id,
    required this.name,
    required this.department,
    required this.role,
    required this.salary,
    required this.startedOn,
    required this.note,
  });

  final int id;
  final String name;
  final String department;
  final String role;
  final int salary;
  final DateTime startedOn;
  final String note;

  String get salaryText =>
      '\$${salary.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},')}';

  String get startedOnText =>
      '${startedOn.year}-${startedOn.month.toString().padLeft(2, '0')}-'
      '${startedOn.day.toString().padLeft(2, '0')}';
}

const _first = [
  'Amodh',
  'Priya',
  'Bartholomew',
  'Wei',
  'Ingrid',
  'Olusegun',
  'Mei',
  'Aleksandr',
  'Fatima',
  'Jo',
  'Constantina',
  'Raj',
  'Ana',
  'Thibault',
];
const _last = [
  'Nadiger',
  'Fotheringay-Smythe',
  'Li',
  'Okonkwo',
  'Andersson',
  'Nakamura',
  'Ng',
  'Volkov',
  'Al-Rashid',
  'Park',
  'Papadopoulos',
  'Silva',
  'Dubois',
];
const _departments = [
  'Engineering',
  'Design',
  'Platform',
  'Data',
  'Support',
  'Finance',
];
const _roles = [
  'Staff Engineer',
  'Designer',
  'SRE',
  'Analyst',
  'Manager',
  'Intern',
  'Principal Engineering Manager',
];
const _notes = [
  'On rotation',
  '',
  'Relocating next quarter; visa paperwork is with the immigration team and '
      'expected to clear before the end of the month',
  'Part time',
  'Mentoring two interns',
  '',
];

/// Deterministic, so a screenshot or a benchmark run is reproducible.
List<Employee> generateEmployees(int count) {
  final random = Random(20260922);
  return <Employee>[
    for (var i = 0; i < count; i++)
      Employee(
        id: 1000 + i,
        name:
            '${_first[random.nextInt(_first.length)]} '
            '${_last[random.nextInt(_last.length)]}',
        department: _departments[random.nextInt(_departments.length)],
        role: _roles[random.nextInt(_roles.length)],
        salary: 45000 + random.nextInt(180000),
        startedOn: DateTime(
          2015 + random.nextInt(11),
          1 + random.nextInt(12),
          1 + random.nextInt(28),
        ),
        note: _notes[random.nextInt(_notes.length)],
      ),
  ];
}
