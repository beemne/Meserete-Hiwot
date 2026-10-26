import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/qr.dart';
import '../../widgets/states.dart';
import '../auth/session.dart';
import '../../core/providers.dart';
import '../admin/org_admin.dart' show departmentName;
import '../choir/eligibility_screen.dart';
import '../hub/hub_screen.dart' show myCardProvider, myPaymentsProvider, paymentYearSummary, scanAndShowMember;
import '../members/department_participation.dart';
import '../members/member_form.dart';
import '../members/profile_changes.dart' show ProfileChangeRequestScreen;
import '../guidance/contextual_help_sheet.dart';
import '../guidance/tour_engine.dart';

/// My membership form (read-only) and my departments (member / leader).
final myProfileProvider = FutureProvider.autoDispose<Json>((ref) => ref.read(apiClientProvider).get<Json>('/me/profile', parse: asJson));

/// User data (opened from the card at the top of Settings): the member ID (hidden until tapped),
/// photo, member card with QR, choir eligibility, attendance, payments and borrowed items.
class MyDataScreen extends ConsumerStatefulWidget {
  const MyDataScreen({super.key});

  @override
  ConsumerState<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends ConsumerState<MyDataScreen> {

  Future<void> _changePhoto() async {
    final l = context.l10n;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(leading: const Icon(Icons.photo_library_outlined), title: Text(l.pickFromGallery), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: Text(l.takePhoto), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ]),
      ),
    );
    if (source == null) return;
    final picked = await ImagePicker().pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
    if (picked == null || !mounted) return;
    final user = await runWithProgress(context, () => ref.read(accountRepositoryProvider).uploadAvatar(picked.path));
    if (user == null || !mounted) return;
    ref.read(sessionProvider.notifier).updateUser(user);
    ref.invalidate(myCardProvider);
    showSnack(context, l.photoUpdated);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final p = context.palette;
    final user = ref.watch(currentUserProvider);
    final pay = ref.watch(myPaymentsProvider).value;
    if (user == null) return const SizedBox.shrink();

    return PatternScaffold(
      appBar: AppBar(
        title: Text(l.userData),
        actions: const [ContextualHelpButton(screenRoute: '/settings/me')],
      ),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async {
          ref.invalidate(myCardProvider);
          ref.invalidate(myPaymentsProvider);
          ref.invalidate(myEligibilityProvider);
          ref.invalidate(myProfileProvider);
          ref.invalidate(ledDepartmentsProvider);
          await ref.read(sessionProvider.notifier).refreshUser();
        },
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
          AppCard(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Stack(children: [
                UserAvatar(user: user, radius: 36),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: IconButton.filled(
                    tooltip: l.changePhoto,
                    iconSize: 16,
                    visualDensity: VisualDensity.compact,
                    style: IconButton.styleFrom(backgroundColor: AppColors.maroon, foregroundColor: Colors.white),
                    onPressed: _changePhoto,
                    icon: const Icon(Icons.photo_camera_rounded),
                  ),
                ),
              ]),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.fullName, style: context.serif(17, color: p.text)),
                  if (user.memberId != null) MemberIdBadge(user.memberId!),
                  Text(user.phone, style: context.sans(12, color: p.muted)),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 14),
          AsyncView(
            value: ref.watch(myCardProvider),
            onRetry: () => ref.invalidate(myCardProvider),
            data: (card) => MemberCard(key: TourKeys.memberCard, card: card),
          ),
          const SizedBox(height: 14),
          const EligibilitySummaryCard(),
          const SizedBox(height: 14),
          SettingsGroup(children: [
            // Department leaders record their department's monthly participation.
            for (final d in ref.watch(ledDepartmentsProvider).value ?? const <Json>[])
              SettingsTile(
                icon: Icons.workspace_premium_rounded,
                label: l.departmentParticipation,
                value: departmentName(context, d),
                onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DepartmentParticipationScreen(department: d))),
              ),
            SettingsTile(
              icon: Icons.assignment_ind_outlined,
              label: l.myMembershipForm,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => PatternScaffold(
                  appBar: AppBar(title: Text(l.myMembershipForm)),
                  body: Consumer(
                    builder: (context, ref, _) => AsyncView(
                      value: ref.watch(myProfileProvider),
                      onRetry: () => ref.invalidate(myProfileProvider),
                      data: (p) => ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
                        MemberProfileView(user: user, profile: asJson(p['profile']), departments: asJsonList(p['departments'])),
                        const SizedBox(height: 12),
                        // Members ask for changes; an administrator approves or declines with a reason.
                        FilledButton.tonalIcon(
                          key: const ValueKey('profile-request-change'),
                          icon: const Icon(Icons.edit_note_rounded),
                          label: Text(context.l10n.requestProfileChange),
                          onPressed: () async {
                            final sent = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(builder: (_) => ProfileChangeRequestScreen(user: user, profile: asJson(p['profile']))),
                            );
                            if (sent == true) ref.invalidate(myProfileProvider);
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
              )),
            ),
            SettingsTile(
              icon: Icons.payments_outlined,
              label: l.monthlyPayments,
              // "All paid" only for a fully paid current year; otherwise how many of its 12 months are paid.
              value: pay == null ? null : (pay['year'] is Map ? paymentYearSummary(l, asJson(pay['year'])) : l.paymentsUnpaid(asIntOr(pay['unpaid_count']))),
              onTap: () => context.push('/settings/payments'),
            ),
            SettingsTile(icon: Icons.inventory_2_outlined, label: l.myBorrowings, onTap: () => context.push('/settings/borrowings')),
            if (user.isAdmin) SettingsTile(icon: Icons.qr_code_scanner_rounded, label: l.scanMember, onTap: () => scanAndShowMember(context, ref)),
          ]),
        ]),
      ),
    );
  }
}
