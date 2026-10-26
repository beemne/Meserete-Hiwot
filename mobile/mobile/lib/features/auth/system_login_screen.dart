import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/utils/validators.dart';
import '../../widgets/dialogs.dart';
import 'auth_screens.dart';
import 'session.dart';

/// Internal system-authority sign-in (password + authenticator code). Not linked from any menu.
class SystemLoginScreen extends ConsumerStatefulWidget {
  const SystemLoginScreen({super.key});
  @override
  ConsumerState<SystemLoginScreen> createState() => _SystemLoginScreenState();
}

class _SystemLoginScreenState extends ConsumerState<SystemLoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  final _totp = TextEditingController();
  bool _busy = false;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionProvider.notifier).systemLogin(_id.text, _pw.text, _totp.text);
    } catch (_) {
      // The server answers 404 for every failure here — show a generic credentials message.
      if (mounted) showSnack(context, context.l10n.errInvalidCredentials);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return AuthLayout(
      title: l.systemLogin,
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(controller: _id, validator: v.identifier, decoration: InputDecoration(labelText: l.phoneOrEmail)),
            const SizedBox(height: 14),
            PasswordField(controller: _pw, label: l.password, validator: v.required),
            const SizedBox(height: 14),
            TextFormField(
              controller: _totp,
              keyboardType: TextInputType.number,
              maxLength: 6,
              validator: v.code6,
              decoration: InputDecoration(labelText: l.totpCode, counterText: ''),
            ),
            const SizedBox(height: 18),
            PrimaryButton(label: l.login, busy: _busy, onPressed: _submit),
          ]),
        ),
      ],
    );
  }
}
