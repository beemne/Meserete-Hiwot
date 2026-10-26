import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/l10n/l10n.dart';
import '../../core/storage/local_prefs.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';

/// Keeps an editor's unsaved state on the device: every change is written (debounced) until the
/// form is submitted. A draft identical to the saved version is removed.
class DraftKeeper {
  DraftKeeper(this._prefs, this._key);
  final LocalPrefs _prefs;
  String _key;
  Timer? _timer;
  String? _baseline;
  String? _last;

  /// The saved (server) state the draft is compared against.
  void setBaseline(Json snapshot) => _baseline = jsonEncode(snapshot);

  /// A stored draft that differs from the saved state, if any.
  Json? pending() {
    final d = _prefs.draft(_key);
    if (d == null || d == _baseline) return null;
    try {
      return asJson(jsonDecode(d));
    } catch (_) {
      return null;
    }
  }

  /// Record the current form state (call on every change / rebuild).
  void changed(Json snapshot) {
    final s = jsonEncode(snapshot);
    if (s == _last) return;
    _last = s;
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 600), _write);
  }

  void _write() {
    final s = _last;
    if (s == null) return;
    if (s == _baseline) {
      unawaited(_prefs.removeDraft(_key));
    } else {
      unawaited(_prefs.setDraft(_key, s));
    }
  }

  /// Write any pending change now (e.g. when leaving the page).
  void flush() {
    if (_timer?.isActive ?? false) {
      _timer!.cancel();
      _write();
    }
  }

  /// Submitted: the saved version is the new baseline and the draft is gone.
  Future<void> clear({Json? baseline}) async {
    _timer?.cancel();
    if (baseline != null) setBaseline(baseline);
    _last = null;
    await _prefs.removeDraft(_key);
  }

  /// A new item got its id: move the draft to that item's key.
  Future<void> rekey(String key) async {
    if (key == _key) return;
    await _prefs.removeDraft(_key);
    _key = key;
  }

  void dispose() {
    flush();
    _timer?.cancel();
  }
}

/// "Restored your unsaved changes · Discard" strip shown at the top of an editor.
class DraftRestoredBanner extends StatelessWidget {
  const DraftRestoredBanner({super.key, required this.onDiscard});
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
      decoration: BoxDecoration(color: AppColors.gold.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const Icon(Icons.restore_rounded, color: AppColors.goldDark),
        const SizedBox(width: 8),
        Expanded(child: Text(l.draftRestored, style: context.sans(13, weight: FontWeight.w600, color: AppColors.goldDark))),
        TextButton(onPressed: onDiscard, child: Text(l.discardDraft)),
      ]),
    );
  }
}

/// One-line hint under the Save button.
class DraftHint extends StatelessWidget {
  const DraftHint({super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(context.l10n.draftAutosave, textAlign: TextAlign.center, style: context.sans(11, color: context.palette.subtle)),
      );
}
