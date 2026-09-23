/// The values a fill-handle drag writes, continuing [source] for [count]
/// cells.
///
/// The rules a spreadsheet user expects, and only those:
///
/// * Numbers with a constant step continue the step: `1, 2, 3` fills `4, 5`;
///   `10, 20` fills `30, 40`; `1.5, 2` fills `2.5, 3`.
/// * Text ending in a number continues the number, from a single cell too:
///   `Item 1` fills `Item 2, Item 3`; `Q1, Q3` fills `Q5`.
/// * Anything else repeats: `a, b` fills `a, b, a`. A single number repeats
///   as well — a lone `5` dragged down is a column of fives, not a count.
///
/// With [backwards] the fill runs the other way — upwards or leftwards — and
/// the result is listed from the cell next to the source outwards.
List<String> fitGridFillSeries(
  List<String> source,
  int count, {
  bool backwards = false,
}) {
  if (source.isEmpty || count <= 0) return const <String>[];

  final numbers = <num>[
    for (final value in source) ?num.tryParse(value.trim()),
  ];
  if (numbers.length == source.length && numbers.length >= 2) {
    final step = numbers[1] - numbers[0];
    final constant = <bool>[
      for (var i = 2; i < numbers.length; i++)
        (numbers[i] - numbers[i - 1] - step).abs() < 1e-9,
    ].every((same) => same);
    if (constant) {
      final decimals = source
          .map((v) => v.contains('.') ? v.trim().split('.').last.length : 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      final origin = backwards ? numbers.first : numbers.last;
      return <String>[
        for (var k = 1; k <= count; k++)
          _format(origin + (backwards ? -step : step) * k, decimals),
      ];
    }
  }

  final numbered = <(String, int, int)>[
    for (final value in source)
      if (_trailingNumber.firstMatch(value) case final m?)
        (m.group(1)!, int.parse(m.group(2)!), m.group(2)!.length),
  ];
  if (numbered.length == source.length &&
      numbers.length != source.length &&
      numbered.every((p) => p.$1 == numbered.first.$1)) {
    final prefix = numbered.first.$1;
    final step = numbered.length >= 2 ? numbered[1].$2 - numbered[0].$2 : 1;
    final constant = <bool>[
      for (var i = 2; i < numbered.length; i++)
        numbered[i].$2 - numbered[i - 1].$2 == step,
    ].every((same) => same);
    if (constant) {
      // Zero padding survives: "Row 007" fills "Row 008".
      final width = numbered.first.$3;
      final origin = backwards ? numbered.first.$2 : numbered.last.$2;
      return <String>[
        for (var k = 1; k <= count; k++)
          '$prefix${(origin + (backwards ? -step : step) * k).toString().padLeft(width, '0')}',
      ];
    }
  }

  final n = source.length;
  return <String>[
    for (var k = 0; k < count; k++)
      backwards ? source[n - 1 - (k % n)] : source[k % n],
  ];
}

final RegExp _trailingNumber = RegExp(r'^(.*?)(\d+)$');

String _format(num value, int decimals) {
  if (decimals == 0 && value == value.roundToDouble()) {
    return value.round().toString();
  }
  return value.toStringAsFixed(decimals);
}
