import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n/l10n.dart';
import '../core/providers.dart';
import '../core/utils/formatters.dart';
import '../repositories/providers.dart';
import 'local_notifications.dart';

/// Text of a program reminder offset ("starts in 1 hour", "starts in 1 hour 30 minutes").
String startsInText(AppLocalizations l, int offset) {
  final isEn = l.localeName.startsWith('en');
  final dur = Formatters.formatReminderDuration(offset, isEn: isEn);
  return isEn ? 'Starts in $dur' : 'በ $dur ውስጥ ይጀምራል';
}

/// Label of a reminder choice ("1 hour before", "1 hour 30 minutes before").
String remindBeforeText(AppLocalizations l, int offset) {
  final isEn = l.localeName.startsWith('en');
  final dur = Formatters.formatReminderDuration(offset, isEn: isEn);
  return isEn ? '$dur before' : 'ከ $dur በፊት';
}

/// Re-arms the phone's program alarms from the upcoming programs (sign-in, resume, back online,
/// and right after the member changes a program's reminders).
class ProgramAlarmSync {
  ProgramAlarmSync(this._ref);
  final Ref _ref;

  static const String offlineNoticeAm =
      'ኢንተርኔት ባለመኖሩ አዳዲስ መርሐ ግብሮች አልተመሳሰሉም፤ ቀደም ሲል የተያዙት ማንቂያዎች በስልኩ ላይ እንደነበሩ ይሠራሉ';
  static const String offlineNoticeEn =
      'You are offline. Previously scheduled alarms remain active on this device, but new programs require internet to sync.';

  String get offlineLimitationNotice {
    final locale = _ref.read(appSettingsProvider).locale;
    return locale.languageCode == 'en' ? offlineNoticeEn : offlineNoticeAm;
  }

  bool lastSyncWasOffline = false;

  Future<bool> run() async {
    try {
      final l = lookupAppLocalizations(_ref.read(appSettingsProvider).locale);
      // Upcoming programs, recurring series included (each carries its next occurrences).
      final page = await _ref.read(programRepositoryProvider).list(scope: 'upcoming', limit: 100);
      await _ref.read(localNotificationsProvider).syncProgramAlarms(
            page.items,
            title: l.programReminderAlarm,
            channelName: l.programs,
            describe: (o) => startsInText(l, o),
            snooze: l.alarmSnooze,
            dismiss: l.alarmDismiss,
          );
      lastSyncWasOffline = false;
      return true;
    } catch (_) {
      // Offline — retain last scheduled alarms with limitation notice.
      lastSyncWasOffline = true;
      return false;
    }
  }
}

final programAlarmSyncProvider = Provider<ProgramAlarmSync>((ref) => ProgramAlarmSync(ref));

