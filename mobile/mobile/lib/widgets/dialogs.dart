import 'package:flutter/material.dart';

import '../core/l10n/error_text.dart';
import '../core/l10n/l10n.dart';
import '../core/theme/app_colors.dart';

Future<bool> showConfirm(BuildContext context, String message, {String? title, String? confirmLabel, bool destructive = false}) async {
  final l = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title == null ? null : Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: AppColors.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel ?? l.confirm),
        ),
      ],
    ),
  );
  return ok ?? false;
}

Future<void> showInfo(BuildContext context, String message, {String? title, bool selectable = false}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: title == null ? null : Text(title),
      content: selectable ? SelectableText(message) : Text(message),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.ok))],
    ),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showErrorSnack(BuildContext context, Object error) => showSnack(context, errorText(context.l10n, error));

/// Run an async action with a blocking progress indicator; shows a translated error on failure.
Future<T?> runWithProgress<T>(BuildContext context, Future<T> Function() action, {String? success}) async {
  final nav = Navigator.of(context, rootNavigator: true);
  // Captured up front: the widget that started the action (e.g. a list row) may be rebuilt
  // while it runs, and the result — above all an error — must still be shown.
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = context.l10n;
  void notify(String m) => messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  );
  try {
    final r = await action();
    nav.pop();
    if (success != null) notify(success);
    return r;
  } catch (e) {
    nav.pop();
    notify(errorText(l, e));
    return null;
  }
}

/// Simple single-line text prompt (reason fields etc.).
Future<String?> promptText(BuildContext context, {required String title, String? label, String? hint, String? initial, int maxLines = 1, bool required = false}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      scrollable: true,
      title: Text(title),
      content: TextField(controller: ctrl, maxLines: maxLines, autofocus: true, decoration: InputDecoration(labelText: label, helperText: hint, helperMaxLines: 4)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.cancel)),
        FilledButton(
          onPressed: () {
            if (required && ctrl.text.trim().isEmpty) return;
            Navigator.pop(ctx, ctrl.text.trim());
          },
          child: Text(ctx.l10n.ok),
        ),
      ],
    ),
  );
}
