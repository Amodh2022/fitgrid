import 'package:example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A phone in portrait, and the keyboard it shows.
const _phone = Size(390, 844);
const _keyboard = 336.0;

Future<void> _openOnPhone(WidgetTester tester, String title) async {
  tester.view.physicalSize = _phone * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const ExampleApp());
  await tester.scrollUntilVisible(
    find.text(title),
    // Large steps: on a phone the gallery is a long single column, and the
    // default 50 steps of 100px no longer reach the last examples.
    300,
    // The page scroller, not the search field's own.
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(find.text(title));
  await tester.pumpAndSettle();
  await tester.tap(find.text(title));
  await tester.pumpAndSettle();
}

Future<void> _keyboardUp(WidgetTester tester, bool up) async {
  tester.view.viewInsets = up
      ? const FakeViewPadding(bottom: _keyboard * 3)
      : FakeViewPadding.zero;
  await tester.pumpAndSettle();
}

void main() {
  for (final example in <String>[
    'Columns, filters & layouts',
    'Playground',
    'Spreadsheet editing',
  ]) {
    testWidgets('$example: a field keeps focus when the keyboard opens', (
      tester,
    ) async {
      await _openOnPhone(tester, example);
      final fields = find.byType(EditableText);
      if (fields.evaluate().isEmpty) return;
      // The first field on the page and, if there is one, a filter-row field.
      for (final field in <Finder>[fields.first, fields.last]) {
        await tester.ensureVisible(field);
        await tester.pumpAndSettle();
        await tester.showKeyboard(field);
        await tester.pumpAndSettle();
        final state = tester.state<EditableTextState>(field);
        final focusNode = state.widget.focusNode;
        expect(focusNode.hasFocus, isTrue);

        await _keyboardUp(tester, true);
        expect(tester.takeException(), isNull);
        // Rebuilding the field's subtree would drop its focus, which on a
        // device closes the keyboard the moment it opens.
        expect(focusNode.hasFocus, isTrue, reason: 'focus lost');
        expect(state.mounted, isTrue, reason: 'field was rebuilt');

        await _keyboardUp(tester, false);
        expect(focusNode.hasFocus, isTrue, reason: 'focus lost on close');
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
      }
    });
  }
}
