import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controller/fitgrid_filter.dart';
import '../model/column_filter.dart';
import '../model/fitgrid_column.dart';
import '../sizing/column_layout.dart';
import '../theme/fitgrid_strings.dart';
import '../theme/fitgrid_theme.dart';

/// A row of filter fields under the header, one per filterable column.
///
/// Widgets, like the header and the footer, and on the same band geometry, so
/// a pinned column's field stays over that column while the rest scroll.
///
/// A field writes to `controller.filter` as it is typed into, in the short
/// form [FitGridColumnFilter.parse] reads — `>5`, `10..20`, `=Paris` — and
/// shows back whatever filter the column has, so it agrees with the filter
/// dialog, saved state and code that sets filters directly. A filter the
/// short form cannot express, `starts with` say, shows as a hint until the
/// field is typed into. A checklist column gets a button that opens the
/// filter dialog instead of a field.
class FitGridFilterRow<T> extends StatelessWidget {
  const FitGridFilterRow({
    required this.columns,
    required this.layout,
    required this.theme,
    required this.horizontalOffset,
    required this.filter,
    required this.onOpenDialog,
    super.key,
  });

  final List<FitGridColumn<T>> columns;
  final FitGridColumnLayout layout;
  final FitGridThemeData theme;
  final double horizontalOffset;
  final FitGridFilterState<T> filter;

  /// Opens the full filter dialog for a column: what a checklist column's
  /// button does.
  final ValueChanged<String> onOpenDialog;

  /// The row's height: the header's, so the two read as one block.
  static double heightFor(FitGridThemeData theme) =>
      theme.effectiveHeaderHeight;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);

    return SizedBox(
      height: heightFor(theme),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final viewport = constraints.maxWidth;
          final leading = layout.leadingFrozenWidth;
          final trailing = layout.trailingFrozenWidth;

          return ClipRect(
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: theme.headerBackground),
                ),
                Positioned.directional(
                  textDirection: textDirection,
                  start: leading,
                  top: 0,
                  bottom: 0,
                  width: math.max(0.0, viewport - leading - trailing),
                  child: ClipRect(
                    child: _band(
                      textDirection,
                      layout.leadingFrozenCount,
                      layout.trailingFrozenStart,
                      leading + horizontalOffset,
                    ),
                  ),
                ),
                if (layout.leadingFrozenCount > 0)
                  Positioned.directional(
                    textDirection: textDirection,
                    start: 0,
                    top: 0,
                    bottom: 0,
                    width: leading,
                    child: _band(
                      textDirection,
                      0,
                      layout.leadingFrozenCount,
                      0,
                    ),
                  ),
                if (layout.trailingFrozenStart < layout.length)
                  Positioned.directional(
                    textDirection: textDirection,
                    start: viewport - trailing,
                    top: 0,
                    bottom: 0,
                    width: trailing,
                    child: _band(
                      textDirection,
                      layout.trailingFrozenStart,
                      layout.length,
                      layout.offsets[layout.trailingFrozenStart],
                    ),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: theme.dividerThickness,
                    color: theme.border,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _band(
    TextDirection textDirection,
    int firstColumn,
    int lastColumn,
    double origin,
  ) {
    if (lastColumn <= firstColumn) return const SizedBox.shrink();
    return Stack(
      clipBehavior: Clip.none,
      children: [
        for (var i = firstColumn; i < lastColumn; i++)
          Positioned.directional(
            // Keyed by column, so a field keeps its text and focus when its
            // column is pinned, moved or scrolled into another band.
            key: ValueKey<String>(columns[i].id),
            textDirection: textDirection,
            start: layout.offsets[i] - origin,
            top: 0,
            bottom: 0,
            width: layout.widths[i],
            child: _divided(i, _cell(columns[i])),
          ),
      ],
    );
  }

  Widget _divided(int i, Widget child) {
    if (i == layout.length - 1) return child;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          end: BorderSide(
            color: theme.columnDivider,
            width: theme.dividerThickness,
          ),
        ),
      ),
      child: child,
    );
  }

  Widget _cell(FitGridColumn<T> column) {
    final spec = column.filter;
    if (spec == null) return const SizedBox.shrink();
    if (spec.kind == FitGridFilterKind.checklist) {
      return _ChecklistButton(
        column: column,
        theme: theme,
        filter: filter,
        onPressed: () => onOpenDialog(column.id),
      );
    }
    return _FilterField<T>(
      column: column,
      kind: spec.kind,
      theme: theme,
      filter: filter,
    );
  }
}

class _FilterField<T> extends StatefulWidget {
  const _FilterField({
    required this.column,
    required this.kind,
    required this.theme,
    required this.filter,
  });

  final FitGridColumn<T> column;
  final FitGridFilterKind kind;
  final FitGridThemeData theme;
  final FitGridFilterState<T> filter;

  @override
  State<_FilterField<T>> createState() => _FilterFieldState<T>();
}

class _FilterFieldState<T> extends State<_FilterField<T>> {
  final TextEditingController _text = TextEditingController();

  String get _id => widget.column.id;
  FitGridColumnFilter? get _current => widget.filter.filters[_id];

  @override
  void initState() {
    super.initState();
    _sync();
    widget.filter.addListener(_onFilterChanged);
  }

  @override
  void didUpdateWidget(covariant _FilterField<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.filter, widget.filter)) {
      oldWidget.filter.removeListener(_onFilterChanged);
      widget.filter.addListener(_onFilterChanged);
    }
    if (!identical(oldWidget.filter, widget.filter) ||
        oldWidget.kind != widget.kind) {
      _sync();
    }
  }

  @override
  void dispose() {
    widget.filter.removeListener(_onFilterChanged);
    _text.dispose();
    super.dispose();
  }

  void _onFilterChanged() {
    if (!mounted) return;
    setState(_sync);
  }

  /// Shows the column's filter in the field, unless the field already says
  /// it. Comparing the parsed text rather than the text itself leaves `>= 5`
  /// alone instead of rewriting it to `>=5` under the user's cursor, and
  /// leaves a half-typed `>` alone while no filter is set.
  void _sync() {
    final current = _current;
    if (FitGridColumnFilter.parse(_text.text, widget.kind) == current) return;
    final text = current?.toText(widget.kind) ?? '';
    _text.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  void _onChanged(String text) {
    widget.filter.setFilter(_id, FitGridColumnFilter.parse(text, widget.kind));
    // The error state depends on the text alone; the filter may not change.
    setState(() {});
  }

  void _clear() {
    _text.clear();
    widget.filter.setFilter(_id, null);
  }

  /// What the hint says for a filter the field cannot show as text:
  /// `Starts with ab`, `Is empty`.
  String? _foreignHint(FitGridStrings strings) {
    final current = _current;
    if (current == null || current.toText(widget.kind) != null) return null;
    final label = strings.filterOperator(current.operator);
    final value = current.value;
    if (value == null) return label;
    final shown = value is DateTime
        ? value.toIso8601String().split('T').first
        : '$value';
    return '$label $shown';
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final strings = FitGridLocalizations.of(context);
    final error = Theme.of(context).colorScheme.error;
    final text = _text.text;
    final invalid =
        text.trim().isNotEmpty &&
        FitGridColumnFilter.parse(text, widget.kind) == null;
    final foreign = _foreignHint(strings);
    final active = _current != null;
    final label = widget.column.label.isEmpty
        ? widget.column.id
        : widget.column.label;

    return Semantics(
      container: true,
      label: strings.filterRowLabel(label),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: theme.effectiveHeaderPadding.left / 2,
          vertical: 4,
        ),
        child: TextField(
          controller: _text,
          onChanged: _onChanged,
          style: theme.cellTextStyle,
          textAlignVertical: TextAlignVertical.center,
          // Plain text for numbers too: `>=`, `..` and `!=` are not on a
          // numeric keypad.
          keyboardType: widget.kind == FitGridFilterKind.date
              ? TextInputType.datetime
              : TextInputType.text,
          decoration: InputDecoration(
            isDense: true,
            filled: true,
            fillColor: theme.rowBackground,
            hintText: foreign ?? strings.filterRowHint,
            hintStyle: theme.cellTextStyle.copyWith(
              color: foreign == null
                  ? theme.placeholderForeground
                  : theme.headerForeground,
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: theme.effectiveHeaderPadding.left / 2,
              vertical: 6,
            ),
            prefixIcon: Icon(
              active ? theme.filterActiveIcon : theme.filterIcon,
              size: theme.sortIconSize,
              color: active ? theme.focusOutline : theme.placeholderForeground,
            ),
            prefixIconConstraints: BoxConstraints(
              minWidth: theme.sortIconSize + 8,
            ),
            suffixIcon: active || text.isNotEmpty
                ? IconButton(
                    tooltip: strings.clearFilter,
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(
                      minWidth: theme.sortIconSize + 8,
                      minHeight: theme.sortIconSize + 8,
                    ),
                    iconSize: theme.sortIconSize,
                    icon: const Icon(Icons.close),
                    onPressed: _clear,
                  )
                : null,
            suffixIconConstraints: BoxConstraints(
              minWidth: theme.sortIconSize + 8,
            ),
            border: _border(theme.border),
            enabledBorder: _border(invalid ? error : theme.border),
            focusedBorder: _border(invalid ? error : theme.focusOutline),
          ),
        ),
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: BorderSide(color: color, width: widget.theme.dividerThickness),
  );
}

/// A checklist column's filter-row cell: a button naming how many values are
/// ticked, which opens the dialog to change them.
class _ChecklistButton<T> extends StatelessWidget {
  const _ChecklistButton({
    required this.column,
    required this.theme,
    required this.filter,
    required this.onPressed,
  });

  final FitGridColumn<T> column;
  final FitGridThemeData theme;
  final FitGridFilterState<T> filter;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final strings = FitGridLocalizations.of(context);
    return ListenableBuilder(
      listenable: filter,
      builder: (context, _) {
        final current = filter.filters[column.id];
        final active = current != null;
        final label = column.label.isEmpty ? column.id : column.label;
        return Semantics(
          container: true,
          button: true,
          label: strings.filterRowLabel(label),
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: theme.effectiveHeaderPadding.left,
              ),
              child: Row(
                children: [
                  Icon(
                    active ? theme.filterActiveIcon : theme.filterIcon,
                    size: theme.sortIconSize,
                    color: active
                        ? theme.focusOutline
                        : theme.placeholderForeground,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      current == null
                          ? strings.filterRowAll
                          : current.operator == FitGridFilterOperator.inList
                          ? strings.filterRowSelected(current.values.length)
                          : strings.filterOperator(current.operator),
                      style: theme.cellTextStyle.copyWith(
                        color: active
                            ? theme.headerForeground
                            : theme.placeholderForeground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
