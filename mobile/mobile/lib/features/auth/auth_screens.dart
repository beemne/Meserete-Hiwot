import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/l10n/error_text.dart';
import '../../core/l10n/l10n.dart';
import '../../core/network/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/validators.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import 'session.dart';
import '../members/member_form.dart';
import '../members/profile_changes.dart' show profileFieldLabel;

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return PatternScaffold(
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const AppLogo(size: 112),
          const SizedBox(height: 22),
          Text(context.l10n.appName, style: context.serif(26)),
          const SizedBox(height: 6),
          Text(context.l10n.schoolName, style: context.sans(13, color: context.palette.muted)),
          const SizedBox(height: 28),
          const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 2.5)),
        ]),
      ),
    );
  }
}

/// Branded layout shared by all authentication screens.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, this.subtitle, required this.children, this.showBack = false, this.logoLongPress});
  final String title;
  final String? subtitle;
  final List<Widget> children;
  final bool showBack;
  final VoidCallback? logoLongPress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return PatternScaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                if (showBack)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: CircleAction(icon: Icons.chevron_left_rounded, onTap: () => context.canPop() ? context.pop() : context.go('/login')),
                  ),
                const SizedBox(height: 8),
                Center(child: GestureDetector(onLongPress: logoLongPress, child: const AppLogo(size: 96))),
                const SizedBox(height: 16),
                Text(context.l10n.appName, textAlign: TextAlign.center, style: context.serif(24)),
                Text(context.l10n.schoolName, textAlign: TextAlign.center, style: context.sans(12, color: p.muted)),
                const SizedBox(height: 26),
                AppCard(
                  padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Text(title, style: context.serif(19)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: context.sans(13, color: p.muted)),
                    ],
                    const SizedBox(height: 18),
                    ...children,
                  ]),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({super.key, required this.controller, required this.label, this.validator, this.helper, this.errorText, this.textInputAction, this.onSubmitted, this.pin = false});
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final String? helper;
  final String? errorText;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  /// A PIN of 4 to 6 digits: number keyboard, digits only.
  final bool pin;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;
  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: const [AutofillHints.password],
      keyboardType: widget.pin ? TextInputType.number : null,
      maxLength: widget.pin ? 6 : null,
      inputFormatters: widget.pin ? [FilteringTextInputFormatter.digitsOnly] : null,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helper,
        errorText: widget.errorText,
        counterText: widget.pin ? '' : null,
        prefixIcon: Icon(widget.pin ? Icons.pin_outlined : Icons.lock_outline_rounded),
        suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _obscure = !_obscure)),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({super.key, required this.label, required this.onPressed, this.busy = false, this.icon});
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: busy ? null : onPressed,
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      child: busy
          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
          : Row(mainAxisSize: MainAxisSize.min, children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Flexible(child: Text(label, textAlign: TextAlign.center)),
            ]),
    );
  }
}

// ---------------------------------------------------------------------------
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _pw = TextEditingController();
  bool _busy = false;
  Object? _error;
  int _logoPresses = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final s = ref.read(sessionProvider);
      if (s is SignedOut && s.reasonCode != null && mounted) {
        showInfo(context, context.l10n.errorSessionExpired, title: context.l10n.sessionExpiredTitle);
      }
    });
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).login(_id.text, _pw.text);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'DEVICE_ALREADY_REGISTERED' || e.code == 'DEVICE_IN_USE') {
        await showInfo(context, errorText(context.l10n, e), title: context.l10n.deviceLockedTitle);
      } else {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _loginError(AppLocalizations l, Object error) {
    if (error is ApiException) {
      if (error.code == 'LOGIN_NOT_ALLOWED') return l.errAccountDisabled;
      if (error.code == 'ACCOUNT_PENDING') return l.errAccountPending;
      if (error.code == 'ACCOUNT_DISABLED') return l.errAccountDisabled;
      if (error.code == 'ACCOUNT_LOCKED') return l.errAccountLocked;
      // Do not show "You don't have permission to do this" on login:
      if (error.status == 403) return l.errInvalidCredentials;
    }
    final text = errorText(l, error);
    if (text == l.errorForbidden) {
      return l.errInvalidCredentials;
    }
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return AuthLayout(
      title: l.loginTitle,
      subtitle: l.loginSubtitle,
      // Internal system sign-in is intentionally not advertised anywhere in the UI.
      logoLongPress: () {
        if (++_logoPresses >= 3) context.push('/system-login');
      },
      children: [
        Form(
          key: _form,
          child: AutofillGroup(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              TextFormField(
                controller: _id,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.telephoneNumber, AutofillHints.email],
                validator: v.identifier,
                decoration: InputDecoration(labelText: l.phoneOrEmail, prefixIcon: const Icon(Icons.person_outline_rounded)),
              ),
              const SizedBox(height: 14),
              // Members sign in with their 4 / 6 digit PIN (older accounts may still have a password).
              PasswordField(controller: _pw, label: l.pinOrPassword, validator: v.required, textInputAction: TextInputAction.done, onSubmitted: (_) => _submit()),
              if (_error != null) _ErrorLine(_loginError(l, _error!)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => context.push('/forgot'), child: Text(l.forgotPassword)),
              ),
              const SizedBox(height: 4),
              PrimaryButton(label: l.login, busy: _busy, onPressed: _submit),
              const SizedBox(height: 14),
              Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
                Text(l.noAccount, style: context.sans(13, color: context.palette.muted)),
                TextButton(onPressed: () => context.push('/register'), child: Text(l.register)),
              ]),
            ]),
          ),
        ),
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 18),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: context.sans(13, color: AppColors.danger))),
        ]),
      );
}

// ---------------------------------------------------------------------------
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

/// Self-registration: the account, member group, student / worker and the membership form
/// (form.dot). The account waits for an administrator's approval.
class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _data = MemberFormData();
  final _pw2 = TextEditingController();
  bool _busy = false;
  Object? _error;

  @override
  void dispose() {
    _data.dispose();
    _pw2.dispose();
    super.dispose();
  }

  static String _fieldLabel(AppLocalizations l, String f) => switch (f) {
        'pin' || 'password' => l.pin,
        'device_id' || 'device_name' => l.deviceLockedTitle,
        _ => profileFieldLabel(l, f.startsWith('profile.') ? f.substring(8) : f),
      };

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).register(
            fullName: _data.name.text,
            phone: _data.phone.text,
            email: _data.email.text,
            password: _data.password.text,
            extra: {'member_group': _data.group, 'member_type': _data.memberType, 'profile': _data.profileJson()},
          );
      if (!mounted) return;
      await showInfo(context, context.l10n.registerPendingBody, title: context.l10n.registerPendingTitle);
      if (mounted) context.go('/login');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.code == 'DEVICE_IN_USE') {
        await showInfo(context, errorText(context.l10n, e), title: context.l10n.deviceLockedTitle);
      } else {
        setState(() => _error = e);
        _form.currentState!.validate();
        // The exact fields and reasons, not a general "check the information" message.
        final l = context.l10n;
        showSnack(context, fieldErrorsSummary(l, e, (f) => _fieldLabel(l, f)) ?? errorText(l, e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return AuthLayout(
      title: l.registerTitle,
      subtitle: l.registerSubtitle,
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            MemberFormFields(
              data: _data,
              mode: MemberFormMode.register,
              serverError: (f) => serverFieldError(l, _error, f),
              passwordField: Column(children: [
                PasswordField(controller: _data.password, label: l.pin, helper: l.pinHelp, validator: v.pin, pin: true, textInputAction: TextInputAction.next),
                const SizedBox(height: 10),
                PasswordField(controller: _pw2, label: l.confirmPin, validator: v.confirmPin(() => _data.password.text), pin: true),
              ]),
            ),
            if (_error != null) _ErrorLine(fieldErrorsSummary(l, _error, (f) => _fieldLabel(l, f)) ?? errorText(l, _error!)),
            const SizedBox(height: 18),
            PrimaryButton(label: l.register, busy: _busy, onPressed: _submit),
            const SizedBox(height: 10),
            Wrap(alignment: WrapAlignment.center, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Text(l.haveAccount, style: context.sans(13, color: context.palette.muted)),
              TextButton(onPressed: () => context.go('/login'), child: Text(l.login)),
            ]),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _code = TextEditingController();
  final _pw = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;
  Object? _error;

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).forgotPassword(_id.text);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _error = null;
      });
      showSnack(context, context.l10n.codeSent);
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).resetPassword(_id.text, _code.text, _pw.text);
      if (!mounted) return;
      await showInfo(context, context.l10n.passwordResetDone);
      if (mounted) context.go('/login');
    } catch (e) {
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    return AuthLayout(
      title: l.forgotTitle,
      subtitle: l.forgotHint,
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            TextFormField(
              controller: _id,
              enabled: !_codeSent,
              validator: v.identifier,
              decoration: InputDecoration(labelText: l.phoneOrEmail, prefixIcon: const Icon(Icons.person_outline_rounded)),
            ),
            if (_codeSent) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _code,
                keyboardType: TextInputType.number,
                maxLength: 6,
                validator: v.code6,
                decoration: InputDecoration(labelText: l.resetCode, prefixIcon: const Icon(Icons.pin_outlined), counterText: ''),
              ),
              const SizedBox(height: 14),
              PasswordField(controller: _pw, label: l.newPin, helper: l.pinHelp, validator: v.pin, pin: true),
            ],
            if (_error != null) _ErrorLine(errorText(l, _error!)),
            const SizedBox(height: 18),
            PrimaryButton(label: _codeSent ? l.resetPassword : l.sendCode, busy: _busy, onPressed: _codeSent ? _reset : _send),
          ]),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});
  final bool forced;
  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _cur = TextEditingController();
  final _pw = TextEditingController();
  final _pw2 = TextEditingController();
  bool _busy = false;
  Object? _error;

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(sessionProvider.notifier).changePassword(_cur.text, _pw.text);
      if (!mounted) return;
      showSnack(context, ref.read(currentUserProvider)?.isAccountAdmin == true ? context.l10n.passwordChanged : context.l10n.pinChanged);
      if (!widget.forced) context.pop();
    } catch (e) {
      if (mounted) setState(() => _error = e);
      _form.currentState?.validate();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = Validators(l);
    // Every account uses a PIN of 4 to 6 digits. The current one may still be an old password
    // (free text) — after this change it is a PIN.
    final body = Form(
      key: _form,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PasswordField(controller: _cur, label: l.currentPinOrPassword, validator: v.required, errorText: serverFieldError(l, _error, 'current_password')),
        const SizedBox(height: 14),
        PasswordField(
          controller: _pw,
          label: l.newPin,
          helper: l.pinHelp,
          validator: v.pin,
          pin: true,
          errorText: serverFieldError(l, _error, 'new_password'),
        ),
        const SizedBox(height: 14),
        PasswordField(controller: _pw2, label: l.confirmPin, validator: v.confirmPin(() => _pw.text), pin: true),
        if (_error != null && (_error is! ApiException || (_error as ApiException).fieldErrors.isEmpty)) _ErrorLine(errorText(l, _error!)),
        const SizedBox(height: 18),
        PrimaryButton(label: l.resetPassword, busy: _busy, onPressed: _submit),
        if (widget.forced) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: () => ref.read(sessionProvider.notifier).logout(), child: Text(l.logout)),
        ],
      ]),
    );
    if (widget.forced) {
      return AuthLayout(title: l.changePinTitle, subtitle: l.mustChangePasswordHint, children: [body]);
    }
    return PatternScaffold(
      appBar: AppBar(title: Text(l.changePinTitle)),
      body: SingleChildScrollView(padding: const EdgeInsets.all(18), child: AppCard(padding: const EdgeInsets.all(18), child: body)),
    );
  }
}
