import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/src/sizing/column_sizer.dart';

class _Row {
  const _Row(this.name, this.note);
  final String name;
  final String note;
}

const _rows = <_Row>[
  _Row('Amit', 'short'),
  _Row('Bernadette', 'a considerably longer note than the others'),
  _Row('Cai', 'mid length note'),
];

FitGridThemeData _theme() =>
    FitGridThemeData.fromTheme(ThemeData.light(useMaterial3: true));

void main() {
  late FitGridColumnSizer sizer;

  setUp(() => sizer = FitGridColumnSizer());
  tearDown(() => sizer.dispose());

  FitGridColumnLayoutProbe resolve(
    List<FitGridColumn<_Row>> columns, {
    double availableWidth = 1000,
    bool stretch = true,
    Map<String, double> overrides = const {},
    List<_Row> rows = _rows,
  }) {
    final layout = sizer.resolve(
      columns: columns,
      rows: rows,
      theme: _theme(),
      availableWidth: availableWidth,
      textDirection: TextDirection.ltr,
      overrides: overrides,
      stretchToFill: stretch,
    );
    return FitGridColumnLayoutProbe(
      layout.ids,
      layout.widths,
      layout.totalWidth,
    );
  }

  group('auto width', () {
    test('sizes a column from its longest cell, not its header', () {
      final result = resolve([
        FitGridColumn<_Row>(id: 'name', label: 'N', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'note', label: 'N', value: (r) => r.note),
      ], stretch: false);

      // Same one-character header; the difference can only come from content.
      expect(result.widthOf('note'), greaterThan(result.widthOf('name')));
    });

    test('never sizes below its own header', () {
      final result = resolve([
        FitGridColumn<_Row>(
          id: 'name',
          label: 'A very long header indeed',
          value: (r) => r.name,
        ),
      ], stretch: false);

      // The header is far longer than any cell, so it sets the floor.
      expect(result.widthOf('name'), greaterThan(150));
    });

    test('honours min and max clamps', () {
      final result = resolve([
        FitGridColumn<_Row>(
          id: 'note',
          label: 'Note',
          value: (r) => r.note,
          width: const FitGridColumnWidth.auto(max: 120),
        ),
        FitGridColumn<_Row>(
          id: 'name',
          label: 'N',
          value: (r) => r.name,
          width: const FitGridColumnWidth.auto(min: 300),
        ),
      ], stretch: false);

      expect(result.widthOf('note'), 120);
      expect(result.widthOf('name'), 300);
    });

    test('ignores cell content for widget columns', () {
      final withBuilder = resolve([
        FitGridColumn<_Row>(
          id: 'note',
          label: 'Note',
          value: (r) => r.note,
          cellBuilder: (_, _, _) => const SizedBox(),
        ),
      ], stretch: false).widthOf('note');

      final withoutBuilder = resolve([
        FitGridColumn<_Row>(id: 'note', label: 'Note', value: (r) => r.note),
      ], stretch: false).widthOf('note');

      // Measuring a string nobody paints would size the column to a lie.
      expect(withBuilder, lessThan(withoutBuilder));
    });

    test('sampling finds the widest cell even when it is last', () {
      final rows = <_Row>[
        for (var i = 0; i < 500; i++) const _Row('x', 'tiny'),
        const _Row('x', 'THE SINGLE WIDEST NOTE IN THE ENTIRE DATASET'),
      ];
      final sampled = resolve(
        [FitGridColumn<_Row>(id: 'note', label: 'N', value: (r) => r.note)],
        rows: rows,
        stretch: false,
      ).widthOf('note');

      final exhaustive = resolve(
        [
          FitGridColumn<_Row>(
            id: 'note',
            label: 'N',
            value: (r) => r.note,
            width: const FitGridColumnWidth.auto(measureAllRows: true),
          ),
        ],
        rows: rows,
        stretch: false,
      ).widthOf('note');

      expect(sampled, exhaustive);
    });
  });

  group('fixed and flex', () {
    test('fixed width is never measured or stretched', () {
      final result = resolve([
        FitGridColumn<_Row>(
          id: 'note',
          label: 'Note',
          value: (r) => r.note,
          width: const FitGridColumnWidth.fixed(90),
        ),
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
      ]);

      expect(result.widthOf('note'), 90);
    });

    test('flex columns split the leftover by their factors', () {
      final result = resolve([
        FitGridColumn<_Row>(
          id: 'a',
          label: 'A',
          value: (r) => r.name,
          width: const FitGridColumnWidth.fixed(200),
        ),
        FitGridColumn<_Row>(
          id: 'b',
          label: 'B',
          value: (r) => r.name,
          width: const FitGridColumnWidth.flex(1),
        ),
        FitGridColumn<_Row>(
          id: 'c',
          label: 'C',
          value: (r) => r.name,
          width: const FitGridColumnWidth.flex(3),
        ),
      ], availableWidth: 1000);

      expect(result.totalWidth, closeTo(1000, 0.5));
      // b and c start from equal header widths, so the leftover split is what
      // separates them: c should end up roughly three times b's share of it.
      final bShare = result.widthOf('b');
      final cShare = result.widthOf('c');
      expect(cShare, greaterThan(bShare * 2));
    });

    test('a saturated column recirculates its surplus', () {
      final result = resolve([
        FitGridColumn<_Row>(
          id: 'capped',
          label: 'A',
          value: (r) => r.name,
          width: const FitGridColumnWidth.flex(1, max: 120),
        ),
        FitGridColumn<_Row>(
          id: 'open',
          label: 'B',
          value: (r) => r.name,
          width: const FitGridColumnWidth.flex(1),
        ),
      ], availableWidth: 1000);

      expect(result.widthOf('capped'), 120);
      // The width the capped column could not take must not simply vanish.
      expect(result.totalWidth, closeTo(1000, 0.5));
    });
  });

  group('stretching', () {
    test('fills the width when asked to', () {
      final result = resolve([
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'note', label: 'Note', value: (r) => r.note),
      ], availableWidth: 900);

      expect(result.totalWidth, closeTo(900, 0.5));
    });

    test('leaves slack when told not to stretch', () {
      final result = resolve(
        [
          FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
          FitGridColumn<_Row>(id: 'note', label: 'Note', value: (r) => r.note),
        ],
        availableWidth: 900,
        stretch: false,
      );

      expect(result.totalWidth, lessThan(900));
    });

    test('never shrinks content to fit a narrow viewport', () {
      final result = resolve([
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'note', label: 'Note', value: (r) => r.note),
      ], availableWidth: 50);

      // Too narrow to hold the content, so the grid scrolls rather than
      // crushing columns into illegibility.
      expect(result.totalWidth, greaterThan(50));
    });
  });

  group('overrides', () {
    test('a dragged width wins over the policy', () {
      final result = resolve(
        [FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name)],
        overrides: {'name': 275},
        stretch: false,
      );

      expect(result.widthOf('name'), 275);
    });

    test('a dragged width is still clamped by the policy', () {
      final result = resolve(
        [
          FitGridColumn<_Row>(
            id: 'name',
            label: 'Name',
            value: (r) => r.name,
            width: const FitGridColumnWidth.auto(max: 200),
          ),
        ],
        overrides: {'name': 900},
        stretch: false,
      );

      expect(result.widthOf('name'), 200);
    });
  });

  group('layout geometry', () {
    test('offsets are prefix sums and locate columns by x', () {
      final layout = FitGridColumnLayout(
        ids: const ['a', 'b', 'c'],
        widths: const [100, 50, 200],
      );

      expect(layout.offsets, [0, 100, 150, 350]);
      expect(layout.totalWidth, 350);
      expect(layout.columnAtOffset(0), 0);
      expect(layout.columnAtOffset(99), 0);
      expect(layout.columnAtOffset(100), 1);
      expect(layout.columnAtOffset(149), 1);
      expect(layout.columnAtOffset(150), 2);
      expect(layout.columnAtOffset(349), 2);
      expect(layout.columnAtOffset(350), 3);
    });

    test('hidden columns are absent from the layout', () {
      final result = resolve([
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(
          id: 'note',
          label: 'Note',
          value: (r) => r.note,
          visible: false,
        ),
      ]);

      expect(result.ids, ['name']);
    });
  });
}

/// Small read-only view of a resolved layout, so the tests can assert by
/// column id rather than by index.
class FitGridColumnLayoutProbe {
  const FitGridColumnLayoutProbe(this.ids, this.widths, this.totalWidth);
  final List<String> ids;
  final List<double> widths;
  final double totalWidth;
  double widthOf(String id) => widths[ids.indexOf(id)];
}
