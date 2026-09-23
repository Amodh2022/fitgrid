import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:fitgrid_table/testing.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Row {
  const _Row(this.name, this.role);
  final String name;
  final String role;
}

List<_Row> _rows(int count) => <_Row>[
  for (var i = 0; i < count; i++) _Row('Person $i', 'Role $i'),
];

Widget _host(Widget child, {TextDirection textDirection = TextDirection.ltr}) =>
    MaterialApp(
      theme: ThemeData.light(useMaterial3: true),
      home: Directionality(
        textDirection: textDirection,
        child: Scaffold(
          body: Center(child: SizedBox(width: 800, height: 400, child: child)),
        ),
      ),
    );

/// The centre of the handle straddling the trailing divider of column [index].
///
/// Offsets run from the grid's leading edge, which is the right one under RTL.
Offset _handleCentre(
  WidgetTester tester,
  int index, {
  TextDirection textDirection = TextDirection.ltr,
}) {
  final layout = fitGridSection().columnLayout;
  final grid = find.byType(FitGrid<_Row>);
  final edge = textDirection == TextDirection.rtl
      ? tester.getTopRight(grid)
      : tester.getTopLeft(grid);
  final along = textDirection == TextDirection.rtl
      ? edge.dx - layout.offsets[index + 1]
      : edge.dx + layout.offsets[index + 1];
  // 20px down puts the pointer inside the header band.
  return Offset(along, edge.dy + 20);
}

/// Drags a resize handle by [dx] logical pixels.
///
/// The first move only wins the gesture arena — `DragStartBehavior.start`
/// rebases the drag origin once it is accepted, so that move's distance is
/// discarded. A separate nudge past the touch slop keeps [dx] meaning what it
/// says.
Future<void> _dragHandle(
  WidgetTester tester,
  int index,
  double dx, {
  TextDirection textDirection = TextDirection.ltr,
}) async {
  final gesture = await tester.startGesture(
    _handleCentre(tester, index, textDirection: textDirection),
  );
  await gesture.moveBy(
    Offset(dx.isNegative ? -kDragSlopDefault : kDragSlopDefault, 0),
  );
  await tester.pump();
  await gesture.moveBy(Offset(dx, 0));
  await tester.pump();
  await gesture.up();
  // The handle also listens for double-taps, and that recognizer arms a timer
  // on pointer-down. Letting it lapse keeps the test from tripping the
  // pending-timer invariant.
  await tester.pump(kDoubleTapTimeout);
}

void main() {
  testWidgets('dragging a divider resizes the column', (tester) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FitGrid<_Row>(controller: controller, stretchColumnsToFill: false)),
    );

    final before = fitGridColumnWidth('name');
    await _dragHandle(tester, 0, 60);

    expect(fitGridColumnWidth('name'), closeTo(before + 60, 1));
    expect(controller.columns.isResized('name'), isTrue);
  });

  testWidgets('a drag is clamped by the column policy', (tester) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(
          id: 'name',
          label: 'Name',
          value: (r) => r.name,
          width: const FitGridColumnWidth.auto(min: 90, max: 140),
        ),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FitGrid<_Row>(controller: controller, stretchColumnsToFill: false)),
    );

    await _dragHandle(tester, 0, 400);

    expect(fitGridColumnWidth('name'), 140);
  });

  testWidgets('double-clicking a divider re-fits the column', (tester) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FitGrid<_Row>(controller: controller, stretchColumnsToFill: false)),
    );

    final measured = fitGridColumnWidth('name');

    controller.columns.setWidth('name', measured + 120);
    await tester.pump();
    expect(fitGridColumnWidth('name'), measured + 120);

    final centre = _handleCentre(tester, 0);
    await tester.tapAt(centre);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(centre);
    await tester.pump(kDoubleTapTimeout);

    expect(fitGridColumnWidth('name'), measured);
    expect(controller.columns.isResized('name'), isFalse);
  });

  testWidgets('a right-to-left drag grows the column it points at', (
    tester,
  ) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        FitGrid<_Row>(controller: controller, stretchColumnsToFill: false),
        textDirection: TextDirection.rtl,
      ),
    );

    final before = fitGridColumnWidth('name');
    // Leftwards, which is outwards — and so wider — under RTL.
    await _dragHandle(tester, 0, -50, textDirection: TextDirection.rtl);

    expect(fitGridColumnWidth('name'), closeTo(before + 50, 1));
  });

  testWidgets('a pinned column gets no handle', (tester) async {
    await tester.pumpWidget(
      _host(
        FitGrid<_Row>(
          rows: _rows(20),
          stretchColumnsToFill: false,
          columns: <FitGridColumn<_Row>>[
            FitGridColumn<_Row>(
              id: 'name',
              label: 'Name',
              value: (r) => r.name,
              width: const FitGridColumnWidth.fixed(120),
            ),
            FitGridColumn<_Row>(
              id: 'role',
              label: 'Role',
              value: (r) => r.role,
              resizable: false,
            ),
          ],
        ),
      ),
    );

    await _dragHandle(tester, 0, 60);

    expect(fitGridColumnWidth('name'), 120);
  });

  testWidgets('resizableColumns: false removes the handles entirely', (
    tester,
  ) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(
        FitGrid<_Row>(
          controller: controller,
          stretchColumnsToFill: false,
          resizableColumns: false,
        ),
      ),
    );

    final before = fitGridColumnWidth('name');
    await _dragHandle(tester, 0, 60);

    expect(fitGridColumnWidth('name'), before);
    expect(controller.columns.isResized('name'), isFalse);
  });

  testWidgets('the hit target is far wider than the grip', (tester) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FitGrid<_Row>(controller: controller, stretchColumnsToFill: false)),
    );

    final before = fitGridColumnWidth('name');
    final centre = _handleCentre(tester, 0);

    // 12px off the divider: well outside the 8px grip, comfortably inside a
    // finger-sized target.
    final gesture = await tester.startGesture(centre.translate(12, 0));
    await gesture.moveBy(const Offset(kDragSlopDefault, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);

    expect(fitGridColumnWidth('name'), closeTo(before + 40, 1));
  });

  testWidgets('a narrow column keeps half its own width', (tester) async {
    final controller = FitGridController<_Row>(
      rows: _rows(20),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(
          id: 'name',
          label: 'N',
          value: (r) => r.name,
          width: const FitGridColumnWidth.auto(max: 30),
        ),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FitGrid<_Row>(controller: controller, stretchColumnsToFill: false)),
    );

    // The target shrinks to the narrow column rather than covering it whole,
    // so a point well inside that column is still the column, not the handle.
    final grid = tester.getTopLeft(find.byType(FitGrid<_Row>));
    final gesture = await tester.startGesture(
      Offset(grid.dx + 4, grid.dy + 20),
    );
    await gesture.moveBy(const Offset(kDragSlopDefault, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump(kDoubleTapTimeout);

    expect(controller.columns.isResized('name'), isFalse);
  });

  testWidgets('a grip is shown on every resizable divider', (tester) async {
    await tester.pumpWidget(
      _host(
        FitGrid<_Row>(
          rows: _rows(5),
          stretchColumnsToFill: false,
          columns: <FitGridColumn<_Row>>[
            FitGridColumn<_Row>(id: 'a', label: 'A', value: (r) => r.name),
            FitGridColumn<_Row>(id: 'b', label: 'B', value: (r) => r.role),
            // Pinned to one width, so a drag would have nothing to do.
            FitGridColumn<_Row>(
              id: 'c',
              label: 'C',
              value: (r) => r.role,
              width: const FitGridColumnWidth.fixed(80),
            ),
            FitGridColumn<_Row>(
              id: 'd',
              label: 'D',
              value: (r) => r.role,
              resizable: false,
            ),
          ],
        ),
      ),
    );

    // Two of the four columns can move; the grip is visible without hovering,
    // which is the only affordance a touch user gets.
    expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
  });

  testWidgets('no grip when the grid is not resizable', (tester) async {
    await tester.pumpWidget(
      _host(
        FitGrid<_Row>(
          rows: _rows(5),
          resizableColumns: false,
          stretchColumnsToFill: false,
          columns: <FitGridColumn<_Row>>[
            FitGridColumn<_Row>(id: 'a', label: 'A', value: (r) => r.name),
            FitGridColumn<_Row>(id: 'b', label: 'B', value: (r) => r.role),
          ],
        ),
      ),
    );

    expect(find.byIcon(Icons.drag_indicator), findsNothing);
  });

  testWidgets('squeezing a sortable column does not overflow the header', (
    tester,
  ) async {
    final controller = FitGridController<_Row>(
      rows: _rows(10),
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(
          id: 'name',
          label: 'A Rather Long Header',
          value: (r) => r.name,
          sortable: true,
        ),
        FitGridColumn<_Row>(id: 'role', label: 'Role', value: (r) => r.role),
      ],
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      _host(FitGrid<_Row>(controller: controller, stretchColumnsToFill: false)),
    );

    // Walk it down past the point where the label, the gap and the sort icon
    // stop fitting. The icon should drop out rather than overflow the row.
    for (final width in <double>[120, 80, 48, 32, 24, 12, 4, 1]) {
      controller.columns.setWidth('name', width);
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'header overflowed at ${width}px',
      );
    }

    // Wide again, and the affordance comes back.
    controller.columns.autoSize('name');
    await tester.pump();
    expect(find.byIcon(Icons.unfold_more_rounded), findsOneWidget);
  });

  test('autoSize drops the override rather than pinning a measurement', () {
    final state = FitGridColumnState<_Row>(
      columns: <FitGridColumn<_Row>>[
        FitGridColumn<_Row>(id: 'name', label: 'Name', value: (r) => r.name),
      ],
    );
    addTearDown(state.dispose);

    state.setWidth('name', 300);
    expect(state.isResized('name'), isTrue);

    state.autoSize('name');
    expect(state.isResized('name'), isFalse);
    expect(state.widthOverrides, isEmpty);
  });
}
