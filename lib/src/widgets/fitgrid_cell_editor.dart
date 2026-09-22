import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../model/fitgrid_editor.dart';
import '../theme/fitgrid_theme.dart';

/// The one real editor widget a grid ever builds.
///
/// It is an overlay child of the painted section, laid out into the cell's own
/// box by the render object — the same mechanism a `cellBuilder` column uses.
/// The painted text underneath is skipped while this is open, so the two never
/// show through each other.
///
/// Keys follow the spreadsheet contract people already know: Enter commits,
/// Escape abandons, Tab commits and moves on. That is handled here rather than
/// left to the host, because getting it wrong is the difference between an
/// editable grid and an infuriating one.
class FitGridCellEditor<T> extends StatefulWidget {
  const FitGridCellEditor({
    required this.editor,
    required this.session,
    required this.theme,
    required this.alignment,
    this.onNext,
    super.key,
  });

  final FitGridEditor<T> editor;
  final FitGridEditorSession<T> session;
  final FitGridThemeData theme;
  final TextAlign alignment;

  /// Tab. Null when there is no next editable cell to move to.
  final VoidCallback? onNext;

  @override
  State<FitGridCellEditor<T>> createState() => _FitGridCellEditorState<T>();
}

class _FitGridCellEditorState<T> extends State<FitGridCellEditor<T>> {
  late final TextEditingController _text;
  late final FocusNode _focus;

  /// Set once the edit is on its way out, so the focus-loss handler does not
  /// fire a second commit as the editor tears itself down. It lifts again only
  /// when a commit was rejected and the field is staying put.
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.session.initialText);
    if (widget.editor.selectAllOnOpen) {
      _text.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _text.text.length,
      );
    }
    _focus = FocusNode(debugLabel: 'FitGridCellEditor');
    _focus.addListener(_onFocusChanged);
    // Autofocus rather than `autofocus: true`: the editor is created during a
    // layout driven by a gesture, and requesting focus in the same frame races
    // with the field's own attachment.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _text.dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (_focus.hasFocus || _closing) return;
    if (widget.editor.commitOnFocusLoss) {
      _commit();
    } else {
      widget.session.cancel();
    }
  }

  void _commit() {
    if (_closing) return;
    _closing = true;
    final accepted = widget.session.commit(_text.text);
    // A rejected commit leaves the editor open, so the guard has to lift again
    // or the field would go inert. An accepted one keeps it set: the widget is
    // about to be removed, and the focus loss that follows must not commit a
    // second time.
    if (!accepted && mounted) _closing = false;
  }

  void _commitAndAdvance() {
    if (_closing) return;
    _closing = true;
    if (widget.session.commit(_text.text)) {
      widget.onNext?.call();
    } else if (mounted) {
      _closing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final custom = widget.editor.builder;
    if (custom != null) return custom(context, widget.session);

    final theme = widget.theme;
    final padding = theme.effectiveCellPadding;

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.escape): _CancelIntent(),
        SingleActivator(LogicalKeyboardKey.enter): _CommitIntent(),
        SingleActivator(LogicalKeyboardKey.numpadEnter): _CommitIntent(),
        SingleActivator(LogicalKeyboardKey.tab): _CommitAndAdvanceIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _CancelIntent: CallbackAction<_CancelIntent>(
            onInvoke: (_) {
              _closing = true;
              widget.session.cancel();
              return null;
            },
          ),
          _CommitIntent: CallbackAction<_CommitIntent>(
            onInvoke: (_) {
              _commit();
              return null;
            },
          ),
          _CommitAndAdvanceIntent: CallbackAction<_CommitAndAdvanceIntent>(
            onInvoke: (_) {
              _commitAndAdvance();
              return null;
            },
          ),
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.rowBackground,
            border: Border.all(color: theme.focusOutline, width: 2),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: padding.left - 2),
            child: Center(
              child: TextField(
                controller: _text,
                focusNode: _focus,
                style: theme.cellTextStyle,
                textAlign: widget.editor.textAlign ?? widget.alignment,
                keyboardType: widget.editor.keyboardType,
                inputFormatters: widget.editor.inputFormatters,
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _commit(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CancelIntent extends Intent {
  const _CancelIntent();
}

class _CommitIntent extends Intent {
  const _CommitIntent();
}

class _CommitAndAdvanceIntent extends Intent {
  const _CommitAndAdvanceIntent();
}
