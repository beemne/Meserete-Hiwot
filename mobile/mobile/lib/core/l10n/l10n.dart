import 'package:flutter/widgets.dart';

import '../../l10n/app_localizations.dart';

export '../../l10n/app_localizations.dart';

extension L10nX on BuildContext {
  /// All user-visible text comes from here (lib/l10n/app_am.arb is the source of truth).
  AppLocalizations get l10n => AppLocalizations.of(this);
  bool get isEn => Localizations.localeOf(this).languageCode == 'en';
}

extension AppLocalizationsX on AppLocalizations {
  bool get isEn => localeName == 'en';
}
