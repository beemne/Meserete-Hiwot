import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/providers.dart';
import '../../models/json.dart';
import '../../models/user.dart';
import '../../repositories/providers.dart';
import '../../widgets/dialogs.dart';
import '../admin/admin_widgets.dart';
import 'member_form.dart';

/// Admin: register a member (children too, without a phone) or edit one — the account, the
/// classification (group, can log in, status, spiritual level, student / worker) and the form.
class MemberEditorScreen extends ConsumerStatefulWidget {
  const MemberEditorScreen({super.key, this.user, this.profile});
  final AppUser? user;
  final Json? profile;

  @override
  ConsumerState<MemberEditorScreen> createState() => _MemberEditorScreenState();
}

class _MemberEditorScreenState extends ConsumerState<MemberEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _data = MemberFormData(user: widget.user, profile: widget.profile);
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _data.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l = context.l10n;
    if (!_form.currentState!.validate()) {
      showSnack(context, l.checkFields);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repo = ref.read(adminRepositoryProvider);
    try {
      String? temp;
      if (widget.user == null) {
        final r = await repo.createUser(_data.adminJson());
        temp = r.tempPassword;
      } else {
        final r = await repo.updateMember(widget.user!.id, _data.adminJson());
        temp = r.tempPassword;
      }
      if (!mounted) return;
      // A new sign-in (new member, or login just allowed): show the temporary password once.
      if (temp != null) await showTempPassword(context, temp);
      if (!mounted) return;
      showSnack(context, l.saved);
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
      _form.currentState!.validate();
      showErrorSnack(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final online = ref.watch(isOnlineProvider);
    return AdminScaffold(
      title: widget.user == null ? l.createUser : l.editMember,
      actions: [
        IconButton(
          tooltip: online ? l.save : l.needsConnection,
          onPressed: (_busy || !online) ? null : _save,
          icon: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded),
        ),
      ],
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 32), children: [
          MemberFormFields(data: _data, mode: MemberFormMode.admin, serverError: (f) => serverFieldError(l, _error, f)),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: (_busy || !online) ? null : _save,
            child: Text(online ? l.save : '${l.save} · ${l.needsConnection}'),
          ),
        ]),
      ),
    );
  }
}
