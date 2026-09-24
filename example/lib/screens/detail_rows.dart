import 'dart:math';

import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter/material.dart';

import '../data/employee.dart';
import '../shared/demo_page.dart';

/// One pay review in an employee's history — what the detail panel lists.
class PayReview {
  const PayReview(this.year, this.salary, this.reviewer);
  final int year;
  final int salary;
  final String reviewer;
}

/// Deterministic per employee, so a panel shows the same history every time
/// it opens.
List<PayReview> reviewsFor(Employee e) {
  final random = Random(e.id);
  final count = 2 + random.nextInt(5);
  var salary = e.salary;
  return <PayReview>[
    for (var i = 0; i < count; i++)
      PayReview(
        2025 - i,
        salary = i == 0
            ? salary
            : (salary * (0.9 + random.nextDouble() * 0.06)).round(),
        const ['M. Okafor', 'L. Chen', 'R. Patel', 'S. Moreau'][random.nextInt(
          4,
        )],
      ),
  ];
}

/// Rows that open a panel beneath them — here, a nested grid of pay reviews.
class DetailRowsScreen extends StatefulWidget {
  const DetailRowsScreen({super.key});

  @override
  State<DetailRowsScreen> createState() => _DetailRowsScreenState();
}

class _DetailRowsScreenState extends State<DetailRowsScreen> {
  late final FitGridController<Employee> _controller =
      FitGridController<Employee>(
        rows: generateEmployees(10000),
        columns: [
          FitGridColumn<Employee>(
            id: 'name',
            label: 'Name',
            value: (e) => e.name,
            sortable: true,
          ),
          FitGridColumn<Employee>(
            id: 'department',
            label: 'Department',
            value: (e) => e.department,
            sortable: true,
          ),
          FitGridColumn<Employee>(
            id: 'role',
            label: 'Role',
            value: (e) => e.role,
            width: const FitGridColumnWidth.auto(max: 220),
          ),
          FitGridColumn<Employee>(
            id: 'salary',
            label: 'Salary',
            value: (e) => e.salaryText,
            alignment: FitGridAlignment.end,
            sortable: true,
            comparator: (a, b) => a.salary.compareTo(b.salary),
          ),
        ],
      );

  static const double _reviewRow = 34;

  static final List<FitGridColumn<PayReview>> _reviewColumns = [
    FitGridColumn<PayReview>(
      id: 'year',
      label: 'Year',
      value: (r) => '${r.year}',
    ),
    FitGridColumn<PayReview>(
      id: 'salary',
      label: 'Salary',
      value: (r) => '\$${r.salary}',
      alignment: FitGridAlignment.end,
    ),
    FitGridColumn<PayReview>(
      id: 'reviewer',
      label: 'Reviewer',
      value: (r) => r.reviewer,
    ),
  ];

  /// Room for the nested grid's header and every review row — and never less
  /// than the profile beside it needs, or a two-review panel would clip it.
  static double _panelHeight(Employee e) =>
      max(150, 24 + 48 + _reviewRow * reviewsFor(e).length);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _panel(BuildContext context, Employee e) {
    final theme = Theme.of(context);
    final reviews = reviewsFor(e);
    return Padding(
      padding: const EdgeInsets.fromLTRB(56, 12, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 200,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Every line capped: the panel's height is set up front, so
                // its content must not be allowed to grow past it.
                Text(
                  e.name,
                  style: theme.textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(e.role, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  '${e.department} · since ${e.startedOnText}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (e.note.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    e.note,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // A grid inside a grid: the panel is an ordinary widget.
          Expanded(
            child: FitGrid<PayReview>(
              rows: reviews,
              columns: _reviewColumns,
              rowHeight: const FitGridRowHeight.fixed(_reviewRow),
              theme: FitGridTheme.of(context)
                  .copyWith(density: FitGridDensity.compact),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DemoPage(
      title: 'Detail rows',
      notes: const [
        DemoNote(
          'Tap a chevron to open a panel under the row. Each panel here holds a '
          'second FitGrid, sized to the number of reviews it lists. Sort the '
          'grid: open panels follow their rows.',
        ),
        DemoNote.recommended(
          'Give the grid a rowKey when rows are rebuilt from fresh objects, so '
          'an open panel can find its row again.',
          code:
              'FitGrid<Employee>(\n'
              '  rowKey: (e) => e.id,\n'
              '  detailBuilder: (context, e, index) => EmployeePanel(e),\n'
              '  detailHeight: (e, index) => 60.0 + 34 * reviewsFor(e).length,\n'
              ')',
        ),
        DemoNote(
          'A panel is built only while its row is on screen, like a widget '
          'cell, and takes no part in selection, copy or export.',
        ),
        DemoNote.avoid(
          'Very tall panels without a height policy. Say how tall each one is '
          'with detailHeight; the grid cannot measure a widget before building '
          'it, and the scrollbar needs every height up front.',
        ),
      ],
      controls: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.tonal(
            onPressed: () {
              for (final e in _controller.data.view.take(5)) {
                _controller.details.setExpanded(e.id, true);
              }
            },
            child: const Text('Open first five'),
          ),
          TextButton(
            onPressed: _controller.details.collapseAll,
            child: const Text('Close all'),
          ),
          ListenableBuilder(
            listenable: _controller.details,
            builder: (context, _) => StatChip(
              label: 'Open',
              value: '${_controller.details.expanded.length}',
            ),
          ),
        ],
      ),
      child: FitGrid<Employee>(
        controller: _controller,
        rowKey: (e) => e.id,
        selectionMode: FitGridSelectionMode.single,
        detailBuilder: (context, e, _) => _panel(context, e),
        detailHeight: (e, _) => _panelHeight(e),
      ),
    );
  }
}
