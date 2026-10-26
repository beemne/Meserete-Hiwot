import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../models/json.dart';
import '../../repositories/providers.dart';
import '../../widgets/brand.dart';
import '../../widgets/dialogs.dart';
import '../../widgets/states.dart';
import '../members/department_participation.dart' show periodLabel;
import '../settings/attendance_calendar.dart';

/// My result in the current holiday Mezmur service selection (open / in review / finalized).
final myEligibilityProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(choirRepositoryProvider).me());

String _n(num? v) => v == null ? '—' : (v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1));

const selectionComponents = ['course_attendance', 'exam', 'mezmur_attendance', 'contribution', 'participation'];

String componentName(AppLocalizations l, String key) => switch (key) {
      'course_attendance' => '📚 ${l.selCourseAttendance}',
      'exam' => '📝 ${l.selExam}',
      'mezmur_attendance' => '🎤 ${l.selMezmurAttendance}',
      'contribution' => '💰 ${l.selContribution}',
      'participation' => '👥 ${l.eligParticipation}',
      'bonus' => '⭐ ${l.selBonus}',
      _ => l.eligTotal,
    };

/// Why a component was not counted / what is missing.
String reasonText(AppLocalizations l, String? r) => switch (r) {
      'not_enrolled' => l.reasonNotEnrolled,
      'no_sessions' => l.reasonNoSessions,
      'no_exam' => l.reasonNoExam,
      'exam_not_required' => l.reasonExamNotRequired,
      'not_configured' => l.reasonNotConfigured,
      'exempt' => l.paymentExempt,
      'nothing_due' => l.reasonNothingDue,
      'not_in_department' => l.reasonNotInDepartment,
      'no_scores' => l.reasonNoScores,
      'missing_months' => l.reasonMissingMonths,
      'not_member_yet' => l.reasonNotMemberYet,
      _ => l.choirNoData,
    };

String resultText(AppLocalizations l, String? r) => r == 'qualified' ? l.selQualified : l.selNotQualified;
Color resultColor(String? r) => r == 'qualified' ? AppColors.success : AppColors.danger;

/// "Mezmur attendance 12/30 — requires 15/30 (3 short)".
String failureText(AppLocalizations l, Json f, Json components, {num? totalMax}) {
  final key = '${f['component'] ?? f['category']}';
  final max = key == 'total' ? (totalMax ?? 100) : asIntOr(asJson(components[key])['weight']);
  return l.eligFailure(componentName(l, key), '${_n(asDouble(f['current']))}/${_n(max)}', '${_n(asDouble(f['required']))}/${_n(max)}', _n(asDouble(f['shortfall'])));
}

/// Compact card (User data page): the current selection, my result and what is missing.
class EligibilitySummaryCard extends ConsumerWidget {
  const EligibilitySummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    return ref.watch(myEligibilityProvider).when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (d) {
            final sel = asJson(d['selection']);
            if (sel.isEmpty) return const SizedBox.shrink();
            final result = asStr(d['result']);
            final failed = asJsonList(d['failed']);
            return AppCard(
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const EligibilityScreen())),
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.verified_user_outlined, color: AppColors.maroon),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${sel['name']}', style: context.sans(15, weight: FontWeight.w700))),
                  Pill(resultText(l, result), color: resultColor(result)),
                ]),
                const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_n(asDouble(d['total'])), style: context.serif(30)),
                  Padding(padding: const EdgeInsets.only(bottom: 6, left: 4), child: Text(l.selPoints, style: context.sans(13, color: p.muted))),
                  const Spacer(),
                  Icon(Icons.chevron_right_rounded, color: p.faint),
                ]),
                if (failed.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  for (final f in failed.take(3)) Text('✗ ${failureText(l, f, asJson(d['components']))}', style: context.sans(12, color: AppColors.danger)),
                ],
              ]),
            );
          },
        );
  }
}

/// The member's dashboard for the current holiday selection.
class EligibilityScreen extends ConsumerWidget {
  const EligibilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return PatternScaffold(
      appBar: AppBar(title: Text(l.eligTitle)),
      body: RefreshIndicator(
        color: AppColors.gold,
        onRefresh: () async => ref.invalidate(myEligibilityProvider),
        child: AsyncView(
          value: ref.watch(myEligibilityProvider),
          onRetry: () => ref.invalidate(myEligibilityProvider),
          data: (d) => asJson(d['selection']).isEmpty
              ? ListView(children: [EmptyView(message: l.selNoneOpen, icon: Icons.event_busy_outlined)])
              : EligibilityView(data: d),
        ),
      ),
    );
  }
}

/// A member's result in a holiday selection (member dashboard; admins see the same for one member).
class EligibilityView extends ConsumerWidget {
  const EligibilityView({super.key, required this.data, this.forMember = true, this.footer = const []});
  final Json data;
  final bool forMember;

  /// Extra widgets after the components (e.g. the admin's exception actions) — the view is itself
  /// the scrollable list, so it must not be nested in another one.
  final List<Widget> footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final p = context.palette;
    final f = Formatters(l, Localizations.localeOf(context).languageCode);
    final sel = asJson(data['selection']);
    final cfg = asJson(sel['config']);
    final components = asJson(data['components']);
    final failed = asJsonList(data['failed']);
    final missing = asJsonList(data['missing']);
    final result = asStr(data['result']);
    final bonus = asJson(data['bonus_detail']);
    final bonusMax = asDouble(asJson(cfg['bonus'])['max']);
    final totalMin = asDouble(cfg['total_minimum']);
    final period = asJson(data['period']);

    Widget line(String label, String value, {Color? color}) => Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(children: [
            Expanded(child: Text(label, style: context.sans(13))),
            Text(value, style: context.sans(13, weight: FontWeight.w600, color: color)),
          ]),
        );

    List<Widget> details(String key, Json c) {
      final d = asJson(c['detail']);
      switch (key) {
        case 'course_attendance':
          return [
            for (final k in asJsonList(d['classes'])) line('${k['class_name']}', '${asIntOr(k['attended'])}/${asIntOr(k['total'])} · ${_n(k['percent'] as num?)}%'),
            if (d['explanation'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${d['explanation']}', style: context.sans(12, color: p.muted).copyWith(fontStyle: FontStyle.italic))),
            if (forMember)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(l.eligAttendanceCalendar),
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => PatternScaffold(
                      appBar: AppBar(title: Text(componentName(l, key))),
                      body: AttendanceCalendarView(fetch: (from, to, _) => ref.read(choirRepositoryProvider).educationCalendar(from: from, to: to), showCategories: false),
                    ),
                  )),
                ),
              ),
          ];
        case 'exam':
          return [
            for (final k in asJsonList(d['courses']))
              line('${k['course_name']}', '${_n(asDouble(k['obtained']))}/${_n(asDouble(k['max']))} · ${_n(k['percent'] as num?)}%'),
          ];
        case 'mezmur_attendance':
          return [
            if (d['total'] != null) line(l.eligAttendance, '${asIntOr(d['attended']) + asIntOr(d['late'])}/${asIntOr(d['total'])}'),
            if (asJsonList(d['excluded_programs']).isNotEmpty) line(l.selExcludedSessions, '${asIntOr(d['excluded_sessions'])}', color: p.muted),
            if (asJsonList(d['additional_counted']).isNotEmpty) line(l.selAdditionalCounted, asJsonList(d['additional_counted']).map((x) => '${x['title']}').join(', ')),
            if (d['explanation'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text('${d['explanation']}', style: context.sans(12, color: p.muted).copyWith(fontStyle: FontStyle.italic))),
          ];
        case 'contribution':
          final totalM = asIntOr(d['total_months']);
          final paidM = asIntOr(d['paid_months']);
          final unpaidM = asIntOr(d['unpaid_months']);
          return [
            if (totalM > 0)
              line(
                l.status,
                l.selContribPaidMonthsCount(paidM, totalM, unpaidM),
              ),
            if (asJsonList(d['months']).isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Expanded(flex: 3, child: Text(l.month, style: context.sans(11, color: p.muted))),
                  Expanded(flex: 2, child: Text(l.required, style: context.sans(11, color: p.muted))),
                  Expanded(flex: 2, child: Text(l.status, style: context.sans(11, color: p.muted))),
                ]),
              ),
              for (final m in asJsonList(d['months']).reversed)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Expanded(flex: 3, child: Text(periodLabel(context, '${m['period']}'), style: context.sans(13))),
                    Expanded(flex: 2, child: Text(_n(m['required'] as num?), style: context.sans(13))),
                    Expanded(flex: 2, child: Text(paymentStatusText(l, '${m['status']}'), style: context.sans(12, weight: FontWeight.w600, color: paymentStatusColor('${m['status']}')))),
                  ]),
                ),
            ],
          ];
        case 'participation':
          final max = asDouble(d['max_score'], 10);
          final en = Localizations.localeOf(context).languageCode == 'en';
          return [
            if (d['average'] != null) line(l.selAverage, '${_n(asDouble(d['average']))} / ${_n(max)}'),
            for (final m in asJsonList(d['months']))
              line('${periodLabel(context, '${m['period']}')} · ${(en ? m['department_en'] : null) ?? m['department'] ?? ''}', '${_n(asDouble(m['score']))} / ${_n(max)}'),
            for (final m in asJsonList(d['missing']))
              line('${periodLabel(context, '${m['period']}')} · ${(en ? m['department_en'] : null) ?? m['department'] ?? ''}', l.selNotScored, color: AppColors.goldDark),
          ];
      }
      return const [];
    }

    Widget componentCard(String key) {
      final c = asJson(components[key]);
      if (c.isEmpty) return const SizedBox.shrink();
      final weight = asDouble(c['weight']);
      if (weight == 0) return const SizedBox.shrink();
      final counted = c['counted'] == true;
      final passed = c['passed'] != false;
      final points = asDouble(c['points']);
      final minimum = c['minimum'] == null ? null : asDouble(c['minimum']);
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(componentName(l, key), style: context.serif(16, color: p.text))),
              Text(counted ? '${_n(points)} / ${_n(weight)}' : '— / ${_n(weight)}', style: context.serif(18)),
            ]),
            const SizedBox(height: 6),
            if (counted)
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Stack(children: [
                  LinearProgressIndicator(value: weight == 0 ? 0 : (points / weight).clamp(0, 1), minHeight: 8, color: passed ? AppColors.success : AppColors.danger, backgroundColor: p.pill),
                  if (minimum != null)
                    Positioned.fill(
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (minimum / weight).clamp(0, 1),
                        child: const Align(alignment: Alignment.centerRight, child: SizedBox(width: 2, height: 8, child: ColoredBox(color: Colors.black54))),
                      ),
                    ),
                ]),
              ),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: Text(minimum == null ? l.selNoMinimum : l.eligMinimum('${_n(minimum)} / ${_n(weight)}'), style: context.sans(12, color: p.muted))),
              const SizedBox(width: 8),
              if (counted)
                Text(passed ? '${l.eligPass} ✓' : '${l.eligFail} ✗', style: context.sans(13, weight: FontWeight.w700, color: passed ? AppColors.success : AppColors.danger))
              else
                Text(l.selNotCounted, style: context.sans(12, color: AppColors.goldDark)),
            ]),
            if (c['percent'] != null) line(l.selPercent, '${_n(c['percent'] as num?)}%'),
            if (!counted && c['reason'] != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(reasonText(l, asStr(c['reason'])), style: context.sans(12, color: p.muted))),
            ...details(key, c),
          ]),
        ),
      );
    }

    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
      MaroonCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${sel['name'] ?? ''}', style: context.sans(12, color: AppColors.goldLight))),
            if (data['config_version'] != null)
              Pill('${data['config_version']}', color: AppColors.goldLight),
          ]),
          const SizedBox(height: 4),
          Text('${resultText(l, result).toUpperCase()} ${result == 'qualified' ? '✓' : '✗'}', style: context.serif(24, color: Colors.white)),
          if (data['service_category'] != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.goldLight),
              ),
              child: Text(
                '${data['service_category']}${data['service_rank'] != null ? ' · ደረጃ: ${data['service_rank']}' : ''}',
                style: context.sans(13, weight: FontWeight.w700, color: Colors.white),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(l.selTotalLine(_n(asDouble(data['base_score'])), _n(asDouble(data['bonus'])), _n(asDouble(data['total'])), _n(totalMin)), style: context.sans(14, color: Colors.white)),
          if (data['override'] != null) ...[
            const SizedBox(height: 6),
            Text('${l.selException}: ${data['override_reason'] ?? ''}', style: context.sans(12, color: AppColors.goldLight)),
          ],
          const SizedBox(height: 6),
          Text(
            [
              if (sel['from'] != null) l.eligWindow(f.date(Formatters.parseDateOnly(asStr(period['from'] ?? sel['from']))), f.date(Formatters.parseDateOnly(asStr(period['to'] ?? sel['to'])))),
              selectionStatusText(l, asStr(sel['status'])),
              if (data['live'] == true) l.selLive,
            ].join(' · '),
            style: context.sans(11, color: Colors.white70),
          ),
        ]),
      ),
      if (failed.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.eligFailedRequirements, style: context.sans(14, weight: FontWeight.w700, color: AppColors.danger)),
              for (final x in failed) Padding(padding: const EdgeInsets.only(top: 6), child: Text('• ${failureText(l, x, components, totalMax: 100 + bonusMax)}', style: context.sans(13))),
            ]),
          ),
        ),
      if (missing.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.selMissingTitle, style: context.sans(14, weight: FontWeight.w700, color: AppColors.goldDark)),
              for (final m in missing)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('• ${m['component'] == 'all' ? l.eligTotal : componentName(l, '${m['component']}')}: ${reasonText(l, asStr(m['reason']))}', style: context.sans(13)),
                ),
            ]),
          ),
        ),
      for (final k in selectionComponents) componentCard(k),
      if (bonusMax > 0)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: AppCard(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(componentName(l, 'bonus'), style: context.serif(16, color: p.text))),
                Text('+${_n(asDouble(data['bonus']))} / ${_n(bonusMax)}', style: context.serif(18)),
              ]),
              if (bonus['percent'] != null) line(l.eligAttendance, '${_n(bonus['percent'] as num?)}%'),
              Padding(padding: const EdgeInsets.only(top: 4), child: Text(l.selBonusHint, style: context.sans(12, color: p.muted))),
            ]),
          ),
        ),
      if (asStr(sel['formula']) != null)
        Padding(padding: const EdgeInsets.only(top: 12), child: Text(l.selFormula, style: context.sans(11, color: p.muted))),
      if (forMember && sel['status'] == 'finalized' && sel['is_published'] == true)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: OutlinedButton.icon(
            icon: const Icon(Icons.rate_review_outlined),
            label: Text(Localizations.localeOf(context).languageCode == 'am' ? 'ስለ ምርጫው አስተያየት ይስጡ' : 'Submit Feedback'),
            onPressed: () => _openFeedbackDialog(context, ref, asIntOr(sel['id'])),
          ),
        ),
      ...footer,
    ]);
  }
}

Future<void> _openFeedbackDialog(BuildContext context, WidgetRef ref, int selectionId) async {
  final l = context.l10n;
  final isAm = Localizations.localeOf(context).languageCode == 'am';
  final ctrl = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(isAm ? 'ስለ ምርጫው አስተያየት' : 'Selection Feedback'),
      content: TextField(
        controller: ctrl,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: isAm ? 'አስተያየትዎን እዚህ ይጻፉ...' : 'Enter your feedback here...',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.save)),
      ],
    ),
  );
  if (ok == true && ctrl.text.trim().isNotEmpty && context.mounted) {
    try {
      await ref.read(stageRepositoryProvider).submitSelectionFeedback(selectionId, ctrl.text.trim());
      if (context.mounted) {
        showSnack(context, isAm ? 'አስተያየትዎ በተሳካ ሁኔታ ደርሷል' : 'Feedback submitted successfully');
      }
    } catch (e) {
      if (context.mounted) showErrorSnack(context, e);
    }
  }
}

String selectionStatusText(AppLocalizations l, String? s) => switch (s) {
      'draft' => l.selStatusDraft,
      'open' => l.selStatusOpen,
      'review' => l.selStatusReview,
      'finalized' => l.selStatusFinalized,
      'cancelled' => l.selStatusCancelled,
      _ => s ?? '',
    };

String paymentStatusText(AppLocalizations l, String s) => switch (s) {
      'paid' => '✓ ${l.paid}',
      'late' => '✓ ${l.paidLate}',
      'exempt' => l.paymentExempt,
      'due' => l.paymentDue,
      _ => '✗ ${l.notPaid}',
    };

Color paymentStatusColor(String s) => switch (s) {
      'paid' => AppColors.success,
      'late' => AppColors.goldDark,
      'exempt' => AppColors.goldDark,
      'due' => AppColors.goldDark,
      _ => AppColors.danger,
    };
