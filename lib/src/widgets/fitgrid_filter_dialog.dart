import 'package:flutter/material.dart';

import '../controller/fitgrid_controller.dart';
import '../model/column_filter.dart';
import '../model/fitgrid_column.dart';

/// Opens the filter editor for one column.
///
/// What the column menu's "Filter…" item shows, and callable directly — from a
/// toolbar, say — for any column that has a [FitGridColumn.filter] spec. The
/// result goes straight to `controller.filter`, so the grid, the header glyph
/// and any attached data source all follow without the caller doing anything.
Future<void> showFitGridFilterDialog<T>(
  BuildContext context,
  FitGridController<T> controller,
  String columnId,
) async {
  final column = controller.columns.byId(columnId);
  final spec = column?.filter;
  if (column == null || spec == null) return;
  await showDialog<void>(
    context: context,
    builder: (context) =>
        _FilterDialog<T>(controller: controller, column: column, spec: spec),
  );
}

class _FilterDialog<T> extends StatefulWidget {
  const _FilterDialog({
    required this.controller,
    required this.column,
    required this.spec,
  });

  final FitGridController<T> controller;
  final FitGridColumn<T> column;
  final FitGridFilterSpec<T> spec;

  @override
  State<_FilterDialog<T>> createState() => _FilterDialogState<T>();
}

class _FilterDialogState<T> extends State<_FilterDialog<T>> {
  late FitGridFilterOperator _operator;
  final TextEditingController _value = TextEditingController();
  final TextEditingController _value2 = TextEditingController();
  final TextEditingController _search = TextEditingController();

  /// Every distinct value, for a checklist, in the order it is listed.
  late final List<String> _options;
  late Set<String> _checked;
  String? _error;

  FitGridFilterSpec<T> get _spec => widget.spec;

  @override
  void initState() {
    super.initState();
    final existing = widget.controller.filter.filters[widget.column.id];
    // A filter set in code, or restored from saved state, may use an operator
    // this kind of column does not offer; the picker cannot show that.
    _operator = existing != null && _spec.operators.contains(existing.operator)
        ? existing.operator
        : _spec.operators.first;
    _value.text = _format(existing?.value);
    _value2.text = _format(existing?.value2);

    if (_spec.kind == FitGridFilterKind.checklist) {
      _options = _spec.options ?? _distinctValues();
      // No filter yet means everything is ticked: unticking is how a checklist
      // filter is built, and starting from nothing ticked would hide every row
      // the moment the dialog was applied untouched.
      _checked = existing == null
          ? _options.toSet()
          : existing.values.intersection(_options.toSet());
    } else {
      _options = const <String>[];
      _checked = <String>{};
    }
  }

  /// The column's distinct values across every row — not only the ones the
  /// other filters have left, or a value filtered out elsewhere could never be
  /// ticked back in.
  List<String> _distinctValues() {
    final seen = <String>{};
    for (final row in widget.controller.data.rows) {
      seen.add(widget.column.value(row));
    }
    final sorted = seen.toList()..sort();
    return sorted;
  }

  @override
  void dispose() {
    _value.dispose();
    _value2.dispose();
    _search.dispose();
    super.dispose();
  }

  String _format(Object? value) {
    if (value == null) return '';
    if (value is DateTime) {
      String two(int n) => n.toString().padLeft(2, '0');
      return '${value.year}-${two(value.month)}-${two(value.day)}';
    }
    return '$value';
  }

  /// Reads typed text as this column's kind of value, or null when it does
  /// not parse.
  Object? _parse(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return switch (_spec.kind) {
      FitGridFilterKind.number => num.tryParse(trimmed.replaceAll(',', '')),
      FitGridFilterKind.date => DateTime.tryParse(trimmed),
      _ => trimmed,
    };
  }

  void _apply() {
    final FitGridColumnFilter? filter;
    if (_spec.kind == FitGridFilterKind.checklist) {
      // Everything ticked is the same as no filter, and saying so keeps the
      // header from claiming a filter that removes nothing.
      filter = _checked.length == _options.length
          ? null
          : FitGridColumnFilter.oneOf(Set<String>.of(_checked));
    } else if (_operator.isUnary) {
      filter = FitGridColumnFilter(operator: _operator);
    } else {
      final value = _parse(_value.text);
      final value2 = _operator == FitGridFilterOperator.between
          ? _parse(_value2.text)
          : null;
      final typedSomething =
          _value.text.trim().isNotEmpty || _value2.text.trim().isNotEmpty;
      if (typedSomething &&
          (value == null ||
              (_operator == FitGridFilterOperator.between &&
                  _value2.text.trim().isNotEmpty &&
                  value2 == null))) {
        setState(() {
          _error = switch (_spec.kind) {
            FitGridFilterKind.number => 'Enter a number',
            FitGridFilterKind.date => 'Enter a date as YYYY-MM-DD',
            _ => 'Enter a value',
          };
        });
        return;
      }
      filter = value == null
          ? null
          : FitGridColumnFilter(
              operator: _operator,
              value: value,
              value2: value2,
            );
    }
    widget.controller.filter.setFilter(widget.column.id, filter);
    Navigator.of(context).pop();
  }

  void _clear() {
    widget.controller.filter.setFilter(widget.column.id, null);
    Navigator.of(context).pop();
  }

  Future<void> _pickDate(TextEditingController field) async {
    final initial = DateTime.tryParse(field.text) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
    if (picked != null) setState(() => field.text = _format(picked));
  }

  Widget _field(TextEditingController field, String label) {
    final date = _spec.kind == FitGridFilterKind.date;
    return TextField(
      controller: field,
      autofocus: identical(field, _value),
      keyboardType: _spec.kind == FitGridFilterKind.number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : date
          ? TextInputType.datetime
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        hintText: date ? 'YYYY-MM-DD' : null,
        isDense: true,
        suffixIcon: date
            ? IconButton(
                tooltip: 'Pick a date',
                icon: const Icon(Icons.calendar_today_outlined, size: 18),
                onPressed: () => _pickDate(field),
              )
            : null,
      ),
      onSubmitted: (_) => _apply(),
      onChanged: (_) {
        if (_error != null) setState(() => _error = null);
      },
    );
  }

  Widget _conditionEditor() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        DropdownButtonFormField<FitGridFilterOperator>(
          initialValue: _operator,
          isDense: true,
          decoration: const InputDecoration(labelText: 'Condition'),
          items: <DropdownMenuItem<FitGridFilterOperator>>[
            for (final op in _spec.operators)
              DropdownMenuItem(value: op, child: Text(op.label)),
          ],
          onChanged: (op) => setState(() => _operator = op ?? _operator),
        ),
        if (!_operator.isUnary) ...<Widget>[
          const SizedBox(height: 12),
          _field(
            _value,
            _operator == FitGridFilterOperator.between ? 'From' : 'Value',
          ),
        ],
        if (_operator == FitGridFilterOperator.between) ...<Widget>[
          const SizedBox(height: 12),
          _field(_value2, 'To'),
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _checklist() {
    final query = _search.text.toLowerCase();
    final shown = <String>[
      for (final option in _options)
        if (query.isEmpty || option.toLowerCase().contains(query)) option,
    ];
    final allShownChecked = shown.every(_checked.contains);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, size: 18),
            hintText: 'Search values',
            isDense: true,
          ),
          onChanged: (_) => setState(() {}),
        ),
        CheckboxListTile(
          dense: true,
          controlAffinity: ListTileControlAffinity.leading,
          value: shown.isEmpty
              ? false
              : allShownChecked
              ? true
              : shown.any(_checked.contains)
              ? null
              : false,
          tristate: true,
          title: Text(query.isEmpty ? '(Select all)' : '(Select all shown)'),
          onChanged: (_) => setState(() {
            if (allShownChecked) {
              _checked.removeAll(shown);
            } else {
              _checked.addAll(shown);
            }
          }),
        ),
        const Divider(height: 1),
        SizedBox(
          height: 240,
          // Built lazily: a column of ten thousand distinct values should cost
          // a screenful of tiles, which is the whole spirit of this package.
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (context, index) {
              final option = shown[index];
              return CheckboxListTile(
                dense: true,
                controlAffinity: ListTileControlAffinity.leading,
                value: _checked.contains(option),
                title: Text(option.isEmpty ? '(Blank)' : option),
                onChanged: (on) => setState(() {
                  if (on ?? false) {
                    _checked.add(option);
                  } else {
                    _checked.remove(option);
                  }
                }),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.controller.filter.filters.containsKey(
      widget.column.id,
    );
    return AlertDialog(
      title: Text(
        'Filter ${widget.column.label.isEmpty ? widget.column.id : widget.column.label}',
      ),
      content: SizedBox(
        width: 320,
        child: _spec.kind == FitGridFilterKind.checklist
            ? _checklist()
            : _conditionEditor(),
      ),
      actions: <Widget>[
        if (active) TextButton(onPressed: _clear, child: const Text('Clear')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
