import 'package:flutter/foundation.dart';

/// How a column filter compares a cell to what the user typed.
enum FitGridFilterOperator {
  contains,
  notContains,
  equals,
  notEquals,
  startsWith,
  endsWith,
  greaterThan,
  greaterOrEqual,
  lessThan,
  lessOrEqual,

  /// Inclusive at both ends, the way people mean "between 10 and 20".
  between,

  /// The cell is one of a set of values — the checklist filter.
  inList,
  isEmpty,
  isNotEmpty;

  /// Whether the operator takes no value at all.
  bool get isUnary => this == isEmpty || this == isNotEmpty;

  /// A short label for the operator picker.
  String get label => switch (this) {
    contains => 'Contains',
    notContains => 'Does not contain',
    equals => 'Equals',
    notEquals => 'Does not equal',
    startsWith => 'Starts with',
    endsWith => 'Ends with',
    greaterThan => 'Greater than',
    greaterOrEqual => 'At least',
    lessThan => 'Less than',
    lessOrEqual => 'At most',
    between => 'Between',
    inList => 'Is one of',
    isEmpty => 'Is empty',
    isNotEmpty => 'Is not empty',
  };
}

/// What kind of value a column filters on, which decides the operators the
/// filter panel offers and how the typed text is read.
enum FitGridFilterKind { text, number, date, checklist }

/// One column's filter, as data.
///
/// Deliberately a value rather than a closure: it can be shown back to the
/// user in the filter panel, saved with the rest of the grid's state, and sent
/// to a server as JSON — none of which a `bool Function(T)` can do.
@immutable
class FitGridColumnFilter {
  const FitGridColumnFilter({
    required this.operator,
    this.value,
    this.value2,
    this.values = const <String>{},
  });

  /// A checklist filter: the cell's text must be one of [values].
  const FitGridColumnFilter.oneOf(this.values)
    : operator = FitGridFilterOperator.inList,
      value = null,
      value2 = null;

  final FitGridFilterOperator operator;

  /// The operand: a `String`, a `num` or a `DateTime`, by the column's kind.
  final Object? value;

  /// The upper bound of [FitGridFilterOperator.between].
  final Object? value2;

  /// The accepted values of [FitGridFilterOperator.inList].
  final Set<String> values;

  /// Tests a cell. [text] is the column's text for the row; [typed] is the
  /// value its filter spec extracts, for number and date columns.
  bool matches(String text, Object? typed) {
    switch (operator) {
      case FitGridFilterOperator.isEmpty:
        return typed == null && text.trim().isEmpty;
      case FitGridFilterOperator.isNotEmpty:
        return typed != null || text.trim().isNotEmpty;
      case FitGridFilterOperator.inList:
        return values.contains(text);
      default:
    }

    final operand = value;
    if (operand == null) return true;
    if (operand is String) {
      final haystack = text.toLowerCase();
      final needle = operand.toLowerCase();
      return switch (operator) {
        FitGridFilterOperator.contains => haystack.contains(needle),
        FitGridFilterOperator.notContains => !haystack.contains(needle),
        FitGridFilterOperator.equals => haystack == needle,
        FitGridFilterOperator.notEquals => haystack != needle,
        FitGridFilterOperator.startsWith => haystack.startsWith(needle),
        FitGridFilterOperator.endsWith => haystack.endsWith(needle),
        _ => _compare(haystack, needle, value2?.toString().toLowerCase()),
      };
    }
    if (typed == null) return operator == FitGridFilterOperator.notEquals;
    return _compare(typed, operand, value2);
  }

  bool _compare(Object cell, Object operand, Object? upper) {
    final c = _order(cell, operand);
    if (c == null) return false;
    return switch (operator) {
      FitGridFilterOperator.equals => c == 0,
      FitGridFilterOperator.notEquals => c != 0,
      FitGridFilterOperator.greaterThan => c > 0,
      FitGridFilterOperator.greaterOrEqual => c >= 0,
      FitGridFilterOperator.lessThan => c < 0,
      FitGridFilterOperator.lessOrEqual => c <= 0,
      FitGridFilterOperator.between =>
        c >= 0 && (upper == null || (_order(cell, upper) ?? 1) <= 0),
      _ => true,
    };
  }

  /// Orders two values of the same kind, or null when they cannot be
  /// compared. Dates compare by day, because a filter typed as a date means
  /// the whole of that day rather than its first millisecond.
  static int? _order(Object a, Object b) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is DateTime && b is DateTime) {
      return DateTime(
        a.year,
        a.month,
        a.day,
      ).compareTo(DateTime(b.year, b.month, b.day));
    }
    if (a is String && b is String) return a.compareTo(b);
    return null;
  }

  /// A JSON-friendly map. Numbers stay numbers; a date becomes
  /// `{"date": "<ISO-8601>"}`, so it cannot be mistaken for a string
  /// operand on the way back in.
  Map<String, Object?> toJson() => <String, Object?>{
    'op': operator.name,
    if (value != null) 'value': _encode(value),
    if (value2 != null) 'value2': _encode(value2),
    if (values.isNotEmpty) 'values': (values.toList()..sort()),
  };

  factory FitGridColumnFilter.fromJson(Map<String, Object?> json) {
    final name = json['op'];
    final operator = FitGridFilterOperator.values.firstWhere(
      (op) => op.name == name,
      orElse: () => FitGridFilterOperator.contains,
    );
    return FitGridColumnFilter(
      operator: operator,
      value: _decode(json['value']),
      value2: _decode(json['value2']),
      values: <String>{
        for (final v in (json['values'] as List<Object?>?) ?? const []) '$v',
      },
    );
  }

  static Object? _encode(Object? value) =>
      value is DateTime ? {'date': value.toIso8601String()} : value;

  static Object? _decode(Object? value) {
    if (value is Map && value['date'] is String) {
      return DateTime.tryParse(value['date'] as String);
    }
    return value;
  }

  @override
  bool operator ==(Object other) =>
      other is FitGridColumnFilter &&
      other.operator == operator &&
      other.value == value &&
      other.value2 == value2 &&
      setEquals(other.values, values);

  @override
  int get hashCode =>
      Object.hash(operator, value, value2, Object.hashAllUnordered(values));

  @override
  String toString() => 'FitGridColumnFilter(${toJson()})';
}

/// How a column takes part in filtering: what kind of value it holds, and
/// where that value comes from.
///
/// Giving a column one of these is what puts a "Filter…" item in its column
/// menu. The filter itself is plain data — a [FitGridColumnFilter] — so this
/// is the only place that knows how to read a row.
@immutable
class FitGridFilterSpec<T> {
  /// Filters on the column's text: contains, starts with, equals and so on.
  const FitGridFilterSpec.text()
    : kind = FitGridFilterKind.text,
      numberOf = null,
      dateOf = null,
      options = null;

  /// Filters on a number read from the row, so "greater than 9" does not put
  /// "10" before "9" the way comparing text would.
  const FitGridFilterSpec.number(num? Function(T row) this.numberOf)
    : kind = FitGridFilterKind.number,
      dateOf = null,
      options = null;

  /// Filters on a date read from the row, by calendar day.
  const FitGridFilterSpec.date(DateTime? Function(T row) this.dateOf)
    : kind = FitGridFilterKind.date,
      numberOf = null,
      options = null;

  /// A checklist of the column's distinct values — right for a status or a
  /// category, where typing is slower than ticking.
  ///
  /// The checklist is built from the rows the grid holds. Pass [options] when
  /// that is not all of them — a grid backed by a data source holds only the
  /// rows on screen — or to fix the order the values are listed in.
  const FitGridFilterSpec.values({this.options})
    : kind = FitGridFilterKind.checklist,
      numberOf = null,
      dateOf = null;

  final FitGridFilterKind kind;
  final num? Function(T row)? numberOf;
  final DateTime? Function(T row)? dateOf;

  /// The values a checklist offers, or null to collect them from the rows.
  final List<String>? options;

  /// The typed value for a row, or null for a text or checklist column.
  Object? typedValueOf(T row) => switch (kind) {
    FitGridFilterKind.number => numberOf!(row),
    FitGridFilterKind.date => dateOf!(row),
    _ => null,
  };

  /// The operators the filter panel offers for this kind of column.
  List<FitGridFilterOperator> get operators => switch (kind) {
    FitGridFilterKind.text => const <FitGridFilterOperator>[
      FitGridFilterOperator.contains,
      FitGridFilterOperator.notContains,
      FitGridFilterOperator.equals,
      FitGridFilterOperator.notEquals,
      FitGridFilterOperator.startsWith,
      FitGridFilterOperator.endsWith,
      FitGridFilterOperator.isEmpty,
      FitGridFilterOperator.isNotEmpty,
    ],
    FitGridFilterKind.number ||
    FitGridFilterKind.date => const <FitGridFilterOperator>[
      FitGridFilterOperator.equals,
      FitGridFilterOperator.notEquals,
      FitGridFilterOperator.greaterThan,
      FitGridFilterOperator.greaterOrEqual,
      FitGridFilterOperator.lessThan,
      FitGridFilterOperator.lessOrEqual,
      FitGridFilterOperator.between,
      FitGridFilterOperator.isEmpty,
      FitGridFilterOperator.isNotEmpty,
    ],
    FitGridFilterKind.checklist => const <FitGridFilterOperator>[
      FitGridFilterOperator.inList,
    ],
  };
}
