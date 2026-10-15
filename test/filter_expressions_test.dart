import 'package:fitgrid_table/fitgrid_table.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FitGridColumnFilter inList & OR expressions', () {
    test('parses in: format', () {
      final filter = FitGridColumnFilter.parse('in: Alpha, Beta', FitGridFilterKind.text);
      expect(filter, isNotNull);
      expect(filter!.operator, FitGridFilterOperator.inList);
      expect(filter.values, containsAll(<String>['Alpha', 'Beta']));
      expect(filter.matches('Alpha', null), isTrue);
      expect(filter.matches('beta', null), isTrue);
      expect(filter.matches('Gamma', null), isFalse);
    });

    test('parses in(...) format', () {
      final filter = FitGridColumnFilter.parse('in(Alpha, Beta)', FitGridFilterKind.text);
      expect(filter, isNotNull);
      expect(filter!.operator, FitGridFilterOperator.inList);
      expect(filter.matches('Alpha', null), isTrue);
      expect(filter.matches('Gamma', null), isFalse);
    });

    test('parses OR expressions', () {
      final filter = FitGridColumnFilter.parse('Alpha or Beta', FitGridFilterKind.text);
      expect(filter, isNotNull);
      expect(filter!.operator, FitGridFilterOperator.inList);
      expect(filter.matches('Alpha', null), isTrue);
      expect(filter.matches('Beta', null), isTrue);
      expect(filter.matches('Gamma', null), isFalse);
    });

    test('toText formats inList correctly', () {
      const filter = FitGridColumnFilter(
        operator: FitGridFilterOperator.inList,
        values: <String>{'Alpha', 'Beta'},
      );
      expect(filter.toText(FitGridFilterKind.text), 'in: Alpha, Beta');
    });
  });
}
