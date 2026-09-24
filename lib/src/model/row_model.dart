import 'package:flutter/foundation.dart';

/// Groups rows by a key derived from each one.
///
/// The key is whatever you say it is — a string, an enum, a truncated date —
/// and only has to support `==` and `hashCode`, because that is all the
/// grouping does with it.
@immutable
class FitGridGroup<T> {
  const FitGridGroup({
    required this.keyOf,
    this.label,
    this.comparator,
    this.initiallyExpanded = true,
  });

  /// The group a row belongs to.
  final Object Function(T row) keyOf;

  /// What the group's header says. Defaults to the key's `toString()` with the
  /// row count after it.
  final String Function(Object key, List<T> rows)? label;

  /// Orders the groups. Null keeps them in the order their first row appeared,
  /// which is the sort the user already applied — re-sorting the groups by key
  /// would quietly override it.
  final int Function(Object a, Object b)? comparator;

  final bool initiallyExpanded;

  String labelFor(Object key, List<T> rows) =>
      label?.call(key, rows) ?? '$key (${rows.length})';
}

/// Turns flat rows into a tree.
@immutable
class FitGridTree<T> {
  const FitGridTree({required this.childrenOf, this.initiallyExpanded = false});

  /// A row's children, or an empty list for a leaf.
  ///
  /// Called only for rows that are actually on screen or being expanded, so a
  /// lazily-built hierarchy does not have to be materialized up front.
  final List<T> Function(T row) childrenOf;

  final bool initiallyExpanded;

  bool hasChildren(T row) => childrenOf(row).isNotEmpty;
}

/// One line in the body: a data row, or a header standing over a group of them.
///
/// Grouping and tree rows produce the same shape, which is the point — the
/// render layer, the hit tests and the semantics only ever see a flat list of
/// these, and neither feature needs its own path through any of them.
@immutable
class FitGridDisplayRow<T> {
  const FitGridDisplayRow.data(
    this.row, {
    required this.sourceIndex,
    this.depth = 0,
    this.expandable = false,
    this.expanded = false,
    this.groupKey,
  }) : label = null,
       childCount = 0,
       detailOf = null,
       ownerIndex = null,
       isDetail = false;

  const FitGridDisplayRow.header({
    required this.groupKey,
    required this.label,
    required this.childCount,
    required this.depth,
    required this.expanded,
  }) : row = null,
       sourceIndex = -1,
       expandable = true,
       detailOf = null,
       ownerIndex = null,
       isDetail = false;

  /// The expanded detail panel under a row — a full-width line holding
  /// whatever `FitGrid.detailBuilder` builds for [owner].
  ///
  /// Like a header it is not a row: it takes no part in selection, editing,
  /// copy or the keyboard, so [row] is null and [sourceIndex] is -1. The row
  /// it belongs to is [detailOf], at [ownerIndex].
  const FitGridDisplayRow.detail(
    T owner, {
    required int this.ownerIndex,
    this.depth = 0,
    this.groupKey,
  }) : row = null,
       detailOf = owner,
       sourceIndex = -1,
       expandable = false,
       expanded = false,
       label = null,
       childCount = 0,
       isDetail = true;

  /// The row itself, or null when this line is a header.
  final T? row;

  /// Index into the filtered, sorted row list, or -1 for a header.
  ///
  /// This is what selection, editing and `onRowTap` speak in, so that
  /// collapsing a group does not renumber everything below it.
  final int sourceIndex;

  /// How deep this line sits, for indentation.
  final int depth;

  /// Whether the line can be opened and closed.
  final bool expandable;
  final bool expanded;

  /// The key identifying the group or subtree, for the expansion set.
  final Object? groupKey;

  /// Header text, or null for a data row.
  final String? label;

  /// How many rows the header stands over.
  final int childCount;

  /// Whether this line is a detail panel rather than a row or a header.
  final bool isDetail;

  /// The row a detail panel belongs to, or null for any other line.
  final T? detailOf;

  /// Index of [detailOf] into the filtered, sorted row list, for a detail
  /// panel; null otherwise.
  final int? ownerIndex;

  bool get isHeader => row == null && !isDetail;

  /// Whether this line is a data row — neither a header nor a detail panel.
  bool get isData => row != null;
}

/// Flattens rows into display lines, expanding only what is open.
///
/// Collapsed groups cost their header and nothing else, so a hundred thousand
/// rows in twelve collapsed groups is twelve lines of work — which is the whole
/// reason to group in the first place.
List<FitGridDisplayRow<T>> flattenGroups<T>({
  required List<T> rows,
  required List<FitGridGroup<T>> groups,
  required bool Function(Object key) isExpanded,
  int depth = 0,
  Object? parentKey,
}) {
  if (groups.isEmpty) {
    return <FitGridDisplayRow<T>>[
      for (var i = 0; i < rows.length; i++)
        FitGridDisplayRow<T>.data(rows[i], sourceIndex: i, depth: depth),
    ];
  }
  return _flatten(
    rows: rows,
    indices: List<int>.generate(rows.length, (i) => i),
    groups: groups,
    isExpanded: isExpanded,
    depth: depth,
    parentKey: parentKey,
  );
}

List<FitGridDisplayRow<T>> _flatten<T>({
  required List<T> rows,
  required List<int> indices,
  required List<FitGridGroup<T>> groups,
  required bool Function(Object key) isExpanded,
  required int depth,
  required Object? parentKey,
}) {
  final out = <FitGridDisplayRow<T>>[];
  if (groups.isEmpty) {
    for (final index in indices) {
      out.add(
        FitGridDisplayRow<T>.data(
          rows[index],
          sourceIndex: index,
          depth: depth,
          groupKey: parentKey,
        ),
      );
    }
    return out;
  }

  final group = groups.first;
  // A LinkedHashMap, so groups come out in the order their first row appeared —
  // which is the order the active sort put them in.
  final buckets = <Object, List<int>>{};
  for (final index in indices) {
    buckets.putIfAbsent(group.keyOf(rows[index]), () => <int>[]).add(index);
  }

  var keys = buckets.keys.toList();
  if (group.comparator != null) keys.sort(group.comparator);

  for (final key in keys) {
    final members = buckets[key]!;
    // The key is scoped by its parent, or two groups called "Open" under
    // different parents would expand and collapse together.
    final scoped = parentKey == null ? key : _NestedKey(parentKey, key);
    final expanded = isExpanded(scoped);
    out.add(
      FitGridDisplayRow<T>.header(
        groupKey: scoped,
        label: group.labelFor(key, <T>[for (final i in members) rows[i]]),
        childCount: members.length,
        depth: depth,
        expanded: expanded,
      ),
    );
    if (!expanded) continue;
    out.addAll(
      _flatten<T>(
        rows: rows,
        indices: members,
        groups: groups.sublist(1),
        isExpanded: isExpanded,
        depth: depth + 1,
        parentKey: scoped,
      ),
    );
  }
  return out;
}

/// Flattens a hierarchy into display lines, descending only into open nodes.
///
/// Every line is a data row — a tree has no headers, only parents — so editing,
/// selection and copy work on a tree exactly as they do on a flat list.
List<FitGridDisplayRow<T>> flattenTree<T>({
  required List<T> rows,
  required FitGridTree<T> tree,
  required bool Function(Object key) isExpanded,
  required Object Function(T row) keyOf,
}) {
  final out = <FitGridDisplayRow<T>>[];
  var next = 0;

  void walk(List<T> level, int depth) {
    for (final row in level) {
      final children = tree.childrenOf(row);
      final key = keyOf(row);
      final expanded = children.isNotEmpty && isExpanded(key);
      out.add(
        FitGridDisplayRow<T>.data(
          row,
          sourceIndex: next++,
          depth: depth,
          expandable: children.isNotEmpty,
          expanded: expanded,
          groupKey: key,
        ),
      );
      if (expanded) walk(children, depth + 1);
    }
  }

  walk(rows, 0);
  return out;
}

/// A group key scoped by the one above it.
@immutable
class _NestedKey {
  const _NestedKey(this.parent, this.key);

  final Object parent;
  final Object key;

  @override
  bool operator ==(Object other) =>
      other is _NestedKey && other.parent == parent && other.key == key;

  @override
  int get hashCode => Object.hash(parent, key);

  @override
  String toString() => '$parent/$key';
}

/// Inserts a detail line after every data line whose row [isExpanded] says is
/// open.
///
/// Only called when at least one detail is open, so a grid whose details are
/// all closed pays nothing for the feature.
List<FitGridDisplayRow<T>> insertDetails<T>(
  List<FitGridDisplayRow<T>> lines,
  bool Function(T row) isExpanded,
) {
  final out = <FitGridDisplayRow<T>>[];
  for (final line in lines) {
    out.add(line);
    final row = line.row;
    if (row != null && isExpanded(row)) {
      out.add(
        FitGridDisplayRow<T>.detail(
          row,
          ownerIndex: line.sourceIndex,
          depth: line.depth,
          groupKey: line.groupKey,
        ),
      );
    }
  }
  return out;
}
