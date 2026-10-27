// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Meserete Hiwot';

  @override
  String get schoolName => 'Meserete Hiwot Sunday School';

  @override
  String get churchName => 'Debre Enqu St. Lideta Lemariam Church';

  @override
  String get navHome => 'Home';

  @override
  String get navPrograms => 'Programs';

  @override
  String get navLibrary => 'My library';

  @override
  String get navNotifications => 'Alerts';

  @override
  String get navSettings => 'Settings';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get retry => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get confirm => 'Confirm';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get search => 'Search';

  @override
  String get open => 'Open';

  @override
  String get seeAll => 'See all';

  @override
  String get loading => 'Loading…';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get create => 'Create';

  @override
  String get add => 'Add';

  @override
  String get send => 'Send';

  @override
  String get select => 'Select';

  @override
  String get selectAll => 'Select all visible';

  @override
  String get clearSelection => 'Clear selection';

  @override
  String get apply => 'Apply';

  @override
  String get filter => 'Filter';

  @override
  String get remove => 'Remove';

  @override
  String get share => 'Share';

  @override
  String get none => 'None';

  @override
  String get all => 'All';

  @override
  String get optional => 'Optional';

  @override
  String get saved => 'Saved';

  @override
  String get deleted => 'Deleted';

  @override
  String get done => 'Done';

  @override
  String get deleteConfirm => 'Delete this? This cannot be undone.';

  @override
  String get continueAction => 'Continue';

  @override
  String get details => 'Details';

  @override
  String get notes => 'Notes';

  @override
  String get status => 'Status';

  @override
  String get date => 'Date';

  @override
  String get time => 'Time';

  @override
  String get from => 'From';

  @override
  String get to => 'To';

  @override
  String get change => 'Change';

  @override
  String get pickDate => 'Pick a date';

  @override
  String get pickTime => 'Pick a time';

  @override
  String get copied => 'Copied';

  @override
  String get errorNetwork =>
      'No internet connection. Please check your connection.';

  @override
  String get errorTimeout => 'The request timed out. Please try again.';

  @override
  String get errorUnauthorized => 'Please sign in again.';

  @override
  String get errorForbidden => 'You don\'t have permission to do this.';

  @override
  String get errorNotFound => 'The requested item was not found.';

  @override
  String get errorValidation => 'Please check the information you entered.';

  @override
  String get errorServer => 'Something went wrong. Please try again later.';

  @override
  String get errorSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorOffline => 'You are offline';

  @override
  String get errorTooMany => 'Too many attempts. Please wait and try again.';

  @override
  String get errorGeneric => 'An unexpected error occurred.';

  @override
  String get errorFileTooLarge => 'The file is too large.';

  @override
  String get errorInvalidFileType => 'This file type is not allowed.';

  @override
  String get errInvalidCredentials => 'Incorrect phone/email or PIN.';

  @override
  String get errAccountLocked =>
      'Too many failed attempts. Your account is locked for 15 minutes.';

  @override
  String get errAccountDisabled =>
      'Your account is disabled. Please contact an administrator.';

  @override
  String get errDeviceAlreadyRegistered =>
      'This account is registered on another device. Ask an administrator to reset your device to sign in here.';

  @override
  String get errDeviceInUse =>
      'This device is registered to another account. Please contact an administrator.';

  @override
  String get errAccountExists =>
      'An account with this phone number or email already exists.';

  @override
  String get errPhoneTaken => 'This phone number is already registered';

  @override
  String get errEmailTaken => 'This email is already registered';

  @override
  String get errInvalidResetCode => 'The code is incorrect or has expired.';

  @override
  String get errPasswordChangeRequired => 'You must set a new PIN to continue.';

  @override
  String get errProgramFull => 'The program is full.';

  @override
  String get errProgramEnded => 'The program has ended.';

  @override
  String get errDuplicateReminder => 'A reminder already exists at this time.';

  @override
  String get errInsufficientQuantity => 'Not enough items in stock.';

  @override
  String get errItemUnavailable => 'The item is not available for borrowing.';

  @override
  String get errAlreadyReturned => 'This borrowing has already been returned.';

  @override
  String get errSignatureExists => 'This borrowing is already signed.';

  @override
  String get errCategoryNotEmpty =>
      'The category has subcategories or Mezmurs. Deactivate it instead.';

  @override
  String get errCategoryCycle =>
      'A category cannot be placed under itself or its subcategory.';

  @override
  String get errItemCodeTaken => 'This item code already exists.';

  @override
  String get errItemHasActiveBorrowings =>
      'The item has unreturned borrowings.';

  @override
  String get errPermissionNotGrantable =>
      'You cannot grant permissions you don\'t have.';

  @override
  String get errRoleNotAssignable =>
      'You cannot assign a role at or above your own level.';

  @override
  String get errAdminNotManageable => 'You cannot manage this administrator.';

  @override
  String get errCannotModifySelf =>
      'You cannot change your own role, permissions or status.';

  @override
  String get errNoRecipients => 'No recipients selected.';

  @override
  String get errSyncConflict => 'This was changed elsewhere.';

  @override
  String get errRoleInUse => 'The role is assigned to administrators.';

  @override
  String get errRoleIsSystem => 'Built-in roles cannot be deleted.';

  @override
  String get vRequired => 'This field is required';

  @override
  String get vInvalidPhone =>
      'Enter a valid Ethiopian phone number (e.g. 0911223344)';

  @override
  String get vInvalidEmail => 'Enter a valid email';

  @override
  String get vPasswordShort => 'The PIN must be 4 to 6 digits';

  @override
  String get vPasswordWeak => 'The PIN must contain digits only';

  @override
  String get vPasswordMismatch => 'The PINs do not match';

  @override
  String get vTooLong => 'Too long';

  @override
  String get vTooShort => 'Too short';

  @override
  String get vInvalidDate => 'Enter a valid date';

  @override
  String get vEndBeforeStart => 'End cannot be before start';

  @override
  String get vDeadlineBeforeBorrow =>
      'Due date cannot be before the borrow date';

  @override
  String get vReturnBeforeBorrow =>
      'Return date cannot be before the borrow date';

  @override
  String get vNegativeAmount => 'Amount cannot be negative';

  @override
  String get vInvalidNumber => 'Enter a valid number';

  @override
  String get vWrongPassword => 'Current PIN is incorrect';

  @override
  String get vPasswordReused => 'The new PIN must differ from the old one';

  @override
  String get vHtmlNotAllowed => 'Special characters (< >) are not allowed';

  @override
  String get vInvalidCode => 'Enter the 6-digit code';

  @override
  String get vInvalidCondition => 'Select the return condition';

  @override
  String get vInvalidReturnQuantity => 'Invalid returned quantity';

  @override
  String get vQuantityBelowBorrowed =>
      'Quantity cannot be below the borrowed amount';

  @override
  String get vInvalidValue => 'Invalid value';

  @override
  String get vReminderInPast => 'You cannot pick a time in the past';

  @override
  String get loginTitle => 'Welcome';

  @override
  String get loginSubtitle => 'Sign in to continue';

  @override
  String get phoneOrEmail => 'Phone number or email';

  @override
  String get password => 'PIN';

  @override
  String get login => 'Sign in';

  @override
  String get noAccount => 'No account?';

  @override
  String get register => 'Register';

  @override
  String get registerTitle => 'Create an account';

  @override
  String get registerSubtitle =>
      'Register to access Mezmurs, programs and notifications';

  @override
  String get fullName => 'Full name';

  @override
  String get phone => 'Phone number';

  @override
  String get email => 'Email';

  @override
  String get emailOptional => 'Email (optional)';

  @override
  String get confirmPassword => 'Confirm PIN';

  @override
  String get passwordHelp => 'At least 8 characters with letters and digits';

  @override
  String get haveAccount => 'Already have an account?';

  @override
  String get forgotPassword => 'Forgot PIN?';

  @override
  String get forgotTitle => 'Reset PIN';

  @override
  String get forgotHint =>
      'Enter your phone number or email. A 6-digit code will be sent via Telegram (if linked) or email.';

  @override
  String get sendCode => 'Send code';

  @override
  String get codeSent => 'If the account exists, a code has been sent.';

  @override
  String get resetCode => 'Verification code';

  @override
  String get newPassword => 'New PIN';

  @override
  String get resetPassword => 'Change PIN';

  @override
  String get passwordResetDone => 'Your PIN was changed. You can sign in now.';

  @override
  String get changePasswordTitle => 'Change PIN';

  @override
  String get currentPassword => 'Current PIN';

  @override
  String get mustChangePasswordHint =>
      'For your security, set your own PIN (4 to 6 digits) now.';

  @override
  String get passwordChanged => 'PIN changed';

  @override
  String get logout => 'Sign out';

  @override
  String get logoutConfirm => 'Sign out of your account?';

  @override
  String syncPendingLogoutTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unsynced changes',
      one: '1 unsynced change',
    );
    return '$_temp0';
  }

  @override
  String syncPendingLogoutBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes recorded offline are not synced yet. If you sign out and discard them, they will be lost permanently.',
      one:
          '1 change recorded offline is not synced yet. If you sign out and discard it, it will be lost permanently.',
    );
    return '$_temp0';
  }

  @override
  String get syncStaySignedIn => 'Stay signed in';

  @override
  String get syncDiscardAndLogout => 'Sign out and discard';

  @override
  String syncDiscardConfirmBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Are you sure you want to permanently discard $count offline records? This action cannot be undone.',
      one:
          'Are you sure you want to permanently discard 1 offline record? This action cannot be undone.',
    );
    return '$_temp0';
  }

  @override
  String get syncDiscardConfirmBtn => 'Discard and sign out';

  @override
  String get selContribUseCustomRange => 'Use custom Ethiopian month range';

  @override
  String get selContribUseCustomRangeHint =>
      'Count payments for specific Ethiopian months instead of the selection dates';

  @override
  String get selContribEthYear => 'Ethiopian Year';

  @override
  String get selContribStartMonth => 'From month';

  @override
  String get selContribEndMonth => 'To month';

  @override
  String selContribCountsRange(
    String startMonth,
    String endMonth,
    int year,
    int months,
  ) {
    return 'Counts $startMonth – $endMonth $year ($months months)';
  }

  @override
  String selContribPaidMonthsCount(int paid, int total, int unpaid) {
    return 'Paid months: $paid / $total ($unpaid unpaid)';
  }

  @override
  String get deviceLockedTitle => 'Account is on another device';

  @override
  String get sessionExpiredTitle => 'Session expired';

  @override
  String get searchHint => 'Search Mezmurs or categories';

  @override
  String get categories => 'Categories';

  @override
  String categoriesCount(String count) {
    return '$count categories';
  }

  @override
  String get featured => 'Featured';

  @override
  String get recentlyAdded => 'Recently added';

  @override
  String get popular => 'Popular';

  @override
  String get upcomingPrograms => 'Upcoming programs';

  @override
  String mezmurCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mezmurs',
      one: '1 Mezmur',
      zero: 'No Mezmurs',
    );
    return '$_temp0';
  }

  @override
  String minutesShort(int count) {
    return '$count min';
  }

  @override
  String get offlineBanner =>
      'You\'re offline — downloaded Mezmurs are available';

  @override
  String offlineBannerWithSync(String time, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
    );
    return 'Offline · last synced $time · $_temp0';
  }

  @override
  String offlineBannerNoPending(String time) {
    return 'Offline · last synced $time';
  }

  @override
  String offlineBannerNoSync(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
    );
    return 'Offline · $_temp0';
  }

  @override
  String get syncStatusTitle => 'Sync status';

  @override
  String get lastSync => 'Last synced';

  @override
  String syncStatusPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending changes',
      one: '1 pending change',
    );
    return '$_temp0';
  }

  @override
  String get syncStatusNoPending => 'No pending changes';

  @override
  String syncStatusCaptured(String time) {
    return 'Captured: $time';
  }

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncStatusLastError => 'Last sync error';

  @override
  String get needsConnection => 'Needs a connection';

  @override
  String get offlineNotCached => 'Not saved for offline use yet';

  @override
  String get notAvailableForAccount => 'Not available for your account';

  @override
  String get syncWhatLesson => 'Lesson completion';

  @override
  String get syncWhatLibrary => 'Library circulation';

  @override
  String get emptyCategories => 'No categories yet';

  @override
  String get playAll => 'Play all';

  @override
  String get shuffle => 'Shuffle';

  @override
  String get subcategories => 'Subcategories';

  @override
  String get lyricsOnly => 'Lyrics only';

  @override
  String get noMezmursInCategory => 'No Mezmurs in this category';

  @override
  String get mezmurLabel => 'Mezmur';

  @override
  String get lyrics => 'Lyrics';

  @override
  String get addFavorite => 'Add to favorites';

  @override
  String get removeFavorite => 'Remove from favorites';

  @override
  String get addedToFavorites => 'Added to favorites';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get download => 'Download';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get downloading => 'Downloading';

  @override
  String get removeDownload => 'Remove download';

  @override
  String get related => 'Related Mezmurs';

  @override
  String get fontSize => 'Font size';

  @override
  String get noAudio => 'No audio for this Mezmur';

  @override
  String get openPlayer => 'Open player';

  @override
  String get downloadWithAudio => 'Download with audio';

  @override
  String get downloadLyricsOnly => 'Download lyrics only';

  @override
  String get offlineCopy => 'Offline copy';

  @override
  String get nowPlaying => 'Now playing';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get nextTrack => 'Next';

  @override
  String get previousTrack => 'Previous';

  @override
  String get repeat => 'Repeat';

  @override
  String get viewLyrics => 'View lyrics';

  @override
  String get audioError => 'Could not play the audio';

  @override
  String get searchTitle => 'Search';

  @override
  String get recentSearches => 'Recent searches';

  @override
  String get results => 'Results';

  @override
  String get noResults => 'No results found';

  @override
  String categoryResult(String count) {
    return 'Category · $count';
  }

  @override
  String mezmurResult(String category) {
    return 'Mezmur · $category';
  }

  @override
  String get clearRecent => 'Clear';

  @override
  String get searchOfflineNote => 'Offline — searched downloaded Mezmurs only';

  @override
  String get searchPrompt => 'Type a Mezmur title or a word from the lyrics';

  @override
  String get favorites => 'Favorites';

  @override
  String get downloads => 'Downloads';

  @override
  String get noFavorites => 'You haven\'t added favorites yet';

  @override
  String get noDownloads => 'No downloaded Mezmurs';

  @override
  String storageUsed(String size) {
    return 'Storage used: $size';
  }

  @override
  String get downloadAllFavorites => 'Download all favorites';

  @override
  String get retryDownload => 'Retry download';

  @override
  String get downloadFailed => 'Download failed';

  @override
  String get downloadQueued => 'Queued';

  @override
  String get removeAllDownloads => 'Remove all downloads';

  @override
  String get confirmRemoveDownload => 'Remove this download?';

  @override
  String get confirmRemoveAllDownloads => 'Remove all downloads?';

  @override
  String get staleDownload => 'Update available — download again';

  @override
  String get wifiOnlyBlocked =>
      'Wi-Fi only downloads are on. Connect to Wi-Fi.';

  @override
  String get unavailableDownload => 'This Mezmur is no longer available';

  @override
  String get programs => 'Programs';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get past => 'Past';

  @override
  String get mine => 'Mine';

  @override
  String get noPrograms => 'No programs';

  @override
  String get location => 'Location';

  @override
  String capacity(int count) {
    return 'Capacity: $count';
  }

  @override
  String get registerProgram => 'Register';

  @override
  String get cancelRegistration => 'Cancel registration';

  @override
  String get registeredForProgram => 'You are registered';

  @override
  String get registered => 'Registered';

  @override
  String get invited => 'Invited';

  @override
  String get attPresent => 'Attended';

  @override
  String get attLate => 'Attended (late)';

  @override
  String get attAbsent => 'Absent';

  @override
  String get attExcused => 'Excused';

  @override
  String get setReminder => 'Set reminder';

  @override
  String get programCancelled => 'Cancelled';

  @override
  String get programCompleted => 'Completed';

  @override
  String get moreInfo => 'More information';

  @override
  String participantsCount(int count) {
    return '$count participants';
  }

  @override
  String get registrationRequired => 'Registration required';

  @override
  String get myAttendanceStatus => 'Your attendance';

  @override
  String get reminders => 'Reminders';

  @override
  String get newReminder => 'New reminder';

  @override
  String get editReminder => 'Edit reminder';

  @override
  String get reminderTitle => 'Title';

  @override
  String get reminderNote => 'Note (optional)';

  @override
  String get repeatLabel => 'Repeat';

  @override
  String get repeatNone => 'Once';

  @override
  String get repeatDaily => 'Daily';

  @override
  String get repeatWeekly => 'Weekly';

  @override
  String get enabled => 'Enabled';

  @override
  String get noReminders => 'No reminders';

  @override
  String get reminderSaved => 'Reminder saved';

  @override
  String reminderDefaultTitle(String title) {
    return 'Program: $title';
  }

  @override
  String get notifications => 'Notifications';

  @override
  String get markAllRead => 'Mark all as read';

  @override
  String get noNotifications => 'No notifications';

  @override
  String get justNow => 'Just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String daysAgo(int count) {
    return '$count d ago';
  }

  @override
  String get unreadOnly => 'Unread';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get appSection => 'App';

  @override
  String get language => 'Language';

  @override
  String get amharic => 'አማርኛ';

  @override
  String get english => 'English';

  @override
  String get darkMode => 'Dark theme';

  @override
  String get autoplay => 'Autoplay';

  @override
  String get notificationsSection => 'Notifications';

  @override
  String get pushEnabled => 'Allow notifications';

  @override
  String get eventReminders => 'Program reminders';

  @override
  String get borrowingReminders => 'Borrowing reminders';

  @override
  String get reminderTime => 'Reminder time';

  @override
  String get downloadsSection => 'Downloads';

  @override
  String get wifiOnly => 'Download on Wi-Fi only';

  @override
  String get downloadAudio => 'Also download audio';

  @override
  String get manageDownloads => 'Manage downloads';

  @override
  String get about => 'About';

  @override
  String get aboutApp => 'About the app';

  @override
  String get aboutBody =>
      'Mezmur Zelideta is the Mezmur, program and library app of Meserete Hiwot Sunday School. Read and listen to Mezmurs, download them for offline use, and follow the Sunday School\'s programs.';

  @override
  String get version => 'Version';

  @override
  String get profile => 'Profile';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get myAttendance => 'My attendance';

  @override
  String get myBorrowings => 'My borrowed items';

  @override
  String get adminPanel => 'Admin panel';

  @override
  String get profileSaved => 'Profile saved';

  @override
  String get changePhoto => 'Change photo';

  @override
  String get removePhoto => 'Remove photo';

  @override
  String get preferredCategories => 'Preferred categories';

  @override
  String get preferredCategoriesHint =>
      'Choose the categories you like for notifications and suggestions';

  @override
  String get myActivity => 'My activity';

  @override
  String get calendarEthiopian => 'E.C.';

  @override
  String get calendarGregorian => 'G.C.';

  @override
  String get borrowings => 'Borrowings';

  @override
  String get borrowedOn => 'Borrowed on';

  @override
  String get dueOn => 'Due on';

  @override
  String daysRemaining(int count) {
    return '$count days left';
  }

  @override
  String get dueToday => 'Due today';

  @override
  String overdueDays(int count) {
    return '$count days overdue';
  }

  @override
  String get bStatusActive => 'On loan';

  @override
  String get bStatusReturned => 'Returned';

  @override
  String get bStatusPartial => 'Partially returned';

  @override
  String get bStatusLost => 'Lost';

  @override
  String get fine => 'Fine';

  @override
  String fineAmountValue(String amount, String currency) {
    return '$amount $currency';
  }

  @override
  String get fineNone => 'No fine';

  @override
  String get finePending => 'Unpaid';

  @override
  String get finePaid => 'Paid';

  @override
  String get fineWaived => 'Waived';

  @override
  String get quantity => 'Quantity';

  @override
  String get returnCondition => 'Return condition';

  @override
  String get signature => 'Signature';

  @override
  String get signedAt => 'Signed at';

  @override
  String get notSigned => 'Not signed';

  @override
  String get noBorrowings => 'No borrowings';

  @override
  String get noAttendance => 'No attendance recorded yet';

  @override
  String get item => 'Item';

  @override
  String get eventDate => 'Event date';

  @override
  String get ethMonth1 => 'Meskerem';

  @override
  String get ethMonth2 => 'Tikimt';

  @override
  String get ethMonth3 => 'Hidar';

  @override
  String get ethMonth4 => 'Tahsas';

  @override
  String get ethMonth5 => 'Tir';

  @override
  String get ethMonth6 => 'Yekatit';

  @override
  String get ethMonth7 => 'Megabit';

  @override
  String get ethMonth8 => 'Miyazya';

  @override
  String get ethMonth9 => 'Ginbot';

  @override
  String get ethMonth10 => 'Sene';

  @override
  String get ethMonth11 => 'Hamle';

  @override
  String get ethMonth12 => 'Nehase';

  @override
  String get ethMonth13 => 'Pagume';

  @override
  String get weekday1 => 'Monday';

  @override
  String get weekday2 => 'Tuesday';

  @override
  String get weekday3 => 'Wednesday';

  @override
  String get weekday4 => 'Thursday';

  @override
  String get weekday5 => 'Friday';

  @override
  String get weekday6 => 'Saturday';

  @override
  String get weekday7 => 'Sunday';

  @override
  String get timeMorning => 'AM';

  @override
  String get timeAfternoon => 'PM';

  @override
  String get admin => 'Administration';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get users => 'Users';

  @override
  String get mezmurs => 'Mezmurs';

  @override
  String get advertisements => 'Banners';

  @override
  String get pages => 'Internal pages';

  @override
  String get attendance => 'Attendance';

  @override
  String get sendNotification => 'Send notification';

  @override
  String get borrowing => 'Borrowing';

  @override
  String get items => 'Items';

  @override
  String get fines => 'Fines';

  @override
  String get reports => 'Reports';

  @override
  String get auditLogs => 'Audit log';

  @override
  String get activityLogs => 'User Reports (activity)';

  @override
  String get admins => 'Administrators';

  @override
  String get roles => 'Roles';

  @override
  String get permissions => 'Permissions';

  @override
  String get systemSettings => 'System settings';

  @override
  String get totalUsers => 'Total users';

  @override
  String get activeUsers => 'Active users (30 days)';

  @override
  String get newUsers => 'New users (30 days)';

  @override
  String get totalMezmurs => 'Mezmurs';

  @override
  String get totalCategories => 'Categories';

  @override
  String get upcomingProgramsStat => 'Upcoming programs';

  @override
  String get attendance30 => 'Attendance (30 days)';

  @override
  String get activeBorrowings => 'Open borrowings';

  @override
  String get overdueBorrowings => 'Overdue borrowings';

  @override
  String get pendingFines => 'Unpaid fines';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get recentNotifications => 'Recent notifications';

  @override
  String get signups30 => 'Sign-ups (30 days)';

  @override
  String get statusActive => 'Active';

  @override
  String get statusDisabled => 'Disabled';

  @override
  String get device => 'Device';

  @override
  String get noDevice => 'No device registered';

  @override
  String get lastLogin => 'Last login';

  @override
  String get registeredAt => 'Registered';

  @override
  String get resetDevice => 'Reset device';

  @override
  String get resetDeviceConfirm =>
      'This user\'s device will be reset and the current session closed immediately. Continue?';

  @override
  String get resetReason => 'Reason (optional)';

  @override
  String get deviceResetDone => 'Device reset';

  @override
  String get forceLogout => 'Sign out everywhere';

  @override
  String get forceLogoutConfirm =>
      'The user will be signed out of all sessions. Continue?';

  @override
  String get disable => 'Disable';

  @override
  String get enable => 'Enable';

  @override
  String get disableConfirm => 'Disable this account?';

  @override
  String get resetUserPassword => 'Issue temporary PIN';

  @override
  String get tempPasswordTitle => 'Temporary PIN';

  @override
  String tempPasswordBody(String password) {
    return '$password\n\nThis PIN is shown only once. The user must set their own PIN after signing in.';
  }

  @override
  String get deviceHistory => 'Device history';

  @override
  String selectedCount(int count) {
    return '$count selected';
  }

  @override
  String get selectAllMatching => 'Select all matching the filter';

  @override
  String allMatchingSelected(int count) {
    return 'All matching selected ($count)';
  }

  @override
  String get bulkNotify => 'Send notification';

  @override
  String get bulkInvite => 'Invite to program';

  @override
  String get bulkBorrow => 'Lend item';

  @override
  String bulkConfirm(int count) {
    return '$count users selected. Continue?';
  }

  @override
  String get createUser => 'Create user';

  @override
  String get devBound => 'Registered';

  @override
  String get devLogin => 'Signed in';

  @override
  String get devLoginRejected => 'Rejected';

  @override
  String get devReset => 'Reset';

  @override
  String get devForceLogout => 'Signed out';

  @override
  String get hasActiveBorrowing => 'Has unreturned items';

  @override
  String get stats => 'Statistics';

  @override
  String get newMezmur => 'New Mezmur';

  @override
  String get editMezmur => 'Edit Mezmur';

  @override
  String get title => 'Title';

  @override
  String get description => 'Description';

  @override
  String get category => 'Category';

  @override
  String get noCategory => 'No category';

  @override
  String get tagsHint => 'Tags (comma separated)';

  @override
  String get statusDraft => 'Draft';

  @override
  String get statusPublished => 'Published';

  @override
  String get statusArchived => 'Archived';

  @override
  String get featuredFlag => 'Featured (shown on home)';

  @override
  String get audio => 'Audio';

  @override
  String get uploadAudio => 'Upload audio';

  @override
  String get removeAudio => 'Remove audio';

  @override
  String get coverImage => 'Cover image';

  @override
  String get uploadImage => 'Upload image';

  @override
  String get removeImage => 'Remove image';

  @override
  String get audioDuration => 'Audio length (seconds)';

  @override
  String get uploadDone => 'Uploaded';

  @override
  String get uploading => 'Uploading…';

  @override
  String get saveFirstToUpload => 'Save first to upload files';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String get newCategory => 'New category';

  @override
  String get editCategory => 'Edit category';

  @override
  String get parentCategory => 'Parent category';

  @override
  String get topLevel => 'Top level';

  @override
  String get icon => 'Icon';

  @override
  String get displayOrder => 'Display order';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get addSubcategory => 'Add subcategory';

  @override
  String get categoryImage => 'Category image';

  @override
  String get moveUp => 'Move up';

  @override
  String get moveDown => 'Move down';

  @override
  String get newAd => 'New banner';

  @override
  String get editAd => 'Edit banner';

  @override
  String get adKind => 'Type';

  @override
  String get kindAdvertisement => 'Advertisement';

  @override
  String get kindEvent => 'Event';

  @override
  String get kindAnnouncement => 'Announcement';

  @override
  String get kindCampaign => 'Campaign';

  @override
  String get kindInfo => 'Information';

  @override
  String get shortDescription => 'Short description';

  @override
  String get startsAt => 'Starts';

  @override
  String get endsAt => 'Ends';

  @override
  String get linkedPage => 'Internal page to open';

  @override
  String get linkedProgram => 'Program to open';

  @override
  String get noExternalLinks => 'Banners only open internal pages or programs.';

  @override
  String get newPage => 'New page';

  @override
  String get editPage => 'Edit page';

  @override
  String get summary => 'Summary';

  @override
  String get content => 'Content';

  @override
  String get ctaLabel => 'Button text';

  @override
  String get ctaAction => 'Button action';

  @override
  String get ctaNone => 'No button';

  @override
  String get ctaOpenProgram => 'Open program';

  @override
  String get ctaRegisterProgram => 'Register for program';

  @override
  String get ctaOpenMezmur => 'Open Mezmur';

  @override
  String get ctaOpenCategory => 'Open category';

  @override
  String get ctaTarget => 'Button target';

  @override
  String get gallery => 'Images';

  @override
  String get addImage => 'Add image';

  @override
  String get newProgram => 'New program';

  @override
  String get editProgram => 'Edit program';

  @override
  String get requiresRegistration => 'Registration required';

  @override
  String get requiresAttendance => 'Track attendance';

  @override
  String get capacityLabel => 'Capacity (optional)';

  @override
  String get audience => 'Reminder recipients';

  @override
  String get audienceAll => 'All users';

  @override
  String get audienceParticipants => 'Participants only';

  @override
  String get reminderEnabled => 'Automatic reminder';

  @override
  String get reminderDaysBefore => 'Days before the program';

  @override
  String get reminderTitleLabel => 'Reminder title (optional)';

  @override
  String get reminderBodyLabel => 'Reminder message (optional)';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusCompleted => 'Completed';

  @override
  String get participants => 'Participants';

  @override
  String get inviteUsers => 'Invite users';

  @override
  String get notifyInvited => 'Notify invited users';

  @override
  String invitedResult(int count) {
    return '$count users invited';
  }

  @override
  String get attendanceRoster => 'Attendance roster';

  @override
  String get unmarked => 'Not marked';

  @override
  String get showAllUsers => 'Show all users';

  @override
  String get markSelectedAs => 'Mark selected as:';

  @override
  String get attendanceSaved => 'Attendance saved';

  @override
  String get removeParticipant => 'Remove participant';

  @override
  String get notificationKind => 'Message type';

  @override
  String get kindReminder => 'Reminder';

  @override
  String get kindProgramInfo => 'Program information';

  @override
  String get kindAdminMessage => 'Administrative message';

  @override
  String get message => 'Message';

  @override
  String get recipients => 'Recipients';

  @override
  String get targetSelected => 'Selected users';

  @override
  String get targetFilter => 'By filter';

  @override
  String get targetAll => 'All users';

  @override
  String get pickUsers => 'Pick users';

  @override
  String sendConfirm(int count) {
    return 'Send to $count users?';
  }

  @override
  String sentTo(int count) {
    return 'Sent to $count users';
  }

  @override
  String get history => 'History';

  @override
  String readOf(int read, int total) {
    return '$read/$total read';
  }

  @override
  String get linkTo => 'Opens (optional)';

  @override
  String get filterStatus => 'By status';

  @override
  String get filterProgram => 'By program participation';

  @override
  String get newItem => 'New item';

  @override
  String get editItem => 'Edit item';

  @override
  String get itemName => 'Item name';

  @override
  String get itemCode => 'Item code';

  @override
  String get itemCategory => 'Item type';

  @override
  String get condition => 'Condition';

  @override
  String availableOf(int available, int total) {
    return '$available/$total available';
  }

  @override
  String get storageLocation => 'Storage location';

  @override
  String get itemStatusRetired => 'Retired';

  @override
  String get issueBorrowing => 'Lend item';

  @override
  String get bulkBorrowing => 'Bulk lend';

  @override
  String get selectUser => 'Select user';

  @override
  String get selectUsers => 'Select users';

  @override
  String get selectItem => 'Select item';

  @override
  String get addItem => 'Add item';

  @override
  String get loanDays => 'Loan days';

  @override
  String get signHere => 'Borrower signs here';

  @override
  String get clearSignature => 'Clear signature';

  @override
  String signFor(String name) {
    return '$name — please sign';
  }

  @override
  String get skipSignature => 'Continue without signature';

  @override
  String get signatureRequiredHint =>
      'The signature confirms the borrower received the item.';

  @override
  String get borrowingCreated => 'Borrowing recorded';

  @override
  String bulkCreated(int count) {
    return '$count borrowing records created';
  }

  @override
  String get processReturn => 'Record return';

  @override
  String get returnedQuantity => 'Returned quantity';

  @override
  String get returnedOn => 'Returned on';

  @override
  String get returnNotes => 'Condition notes';

  @override
  String get fineOverride => 'Override fine';

  @override
  String get overrideReason => 'Reason';

  @override
  String get clearOverride => 'Back to automatic fine';

  @override
  String get markPaid => 'Mark as paid';

  @override
  String get waiveFine => 'Waive fine';

  @override
  String get issuedBy => 'Issued by';

  @override
  String get returnedTo => 'Received by';

  @override
  String get openBorrowings => 'Open';

  @override
  String get overdueFilter => 'Overdue';

  @override
  String get returnConditions => 'Return conditions';

  @override
  String get marksLost => 'Counts as lost';

  @override
  String get restock => 'Goes back to stock';

  @override
  String get finePolicy => 'Fine policy';

  @override
  String get fineEnabled => 'Fines enabled';

  @override
  String get fineAmount => 'Fine amount (ETB)';

  @override
  String get finePeriod => 'Charged';

  @override
  String get perDay => 'Per day';

  @override
  String get perWeek => 'Per week';

  @override
  String get graceDays => 'Grace days';

  @override
  String get maxFine => 'Maximum fine (optional)';

  @override
  String get fineOverridden => 'Overridden';

  @override
  String get borrower => 'Borrower';

  @override
  String get borrowingsDue => 'Due';

  @override
  String get signNow => 'Sign now';

  @override
  String get reportUsers => 'Users report';

  @override
  String get reportMezmurs => 'Mezmur usage';

  @override
  String get reportAttendance => 'Attendance report';

  @override
  String get reportBorrowings => 'Borrowing report';

  @override
  String get reportNotifications => 'Notifications report';

  @override
  String get reportAdminActivity => 'Admin activity';

  @override
  String get topViewed => 'Most viewed';

  @override
  String get topPlayed => 'Most played';

  @override
  String get topFavorited => 'Most favorited';

  @override
  String get topDownloaded => 'Most downloaded';

  @override
  String get topSearches => 'Top searches';

  @override
  String get registrationsPerDay => 'Registrations per day';

  @override
  String get distinctLogins => 'Users who signed in';

  @override
  String get byStatus => 'By status';

  @override
  String get byItem => 'By item';

  @override
  String attendedOf(int attended, int participants) {
    return '$attended/$participants attended';
  }

  @override
  String get sender => 'Sender';

  @override
  String get countLabel => 'Count';

  @override
  String get last30Days => 'Last 30 days';

  @override
  String get last7Days => 'Last 7 days';

  @override
  String get last90Days => 'Last 90 days';

  @override
  String get action => 'Action';

  @override
  String get actor => 'Actor';

  @override
  String get target => 'Target';

  @override
  String get user => 'User';

  @override
  String get newAdmin => 'Assign administrator';

  @override
  String get role => 'Role';

  @override
  String get level => 'Level';

  @override
  String get rolePermissions => 'Role permissions';

  @override
  String get extraPermissions => 'Extra permissions';

  @override
  String get newRole => 'New role';

  @override
  String get roleSlug => 'Identifier (a-z, _)';

  @override
  String get roleName => 'Role name';

  @override
  String get notManageable => 'You cannot manage this administrator';

  @override
  String get adminCreated => 'Administrator assigned';

  @override
  String get perm_users_view => 'View users';

  @override
  String get perm_users_create => 'Create users';

  @override
  String get perm_users_update => 'Edit users';

  @override
  String get perm_users_disable => 'Disable / enable users';

  @override
  String get perm_users_reset_device => 'Reset devices';

  @override
  String get perm_mezmurs_view => 'View Mezmurs (incl. drafts)';

  @override
  String get perm_mezmurs_create => 'Create Mezmurs';

  @override
  String get perm_mezmurs_update => 'Edit Mezmurs';

  @override
  String get perm_mezmurs_delete => 'Delete Mezmurs';

  @override
  String get perm_categories_manage => 'Manage categories';

  @override
  String get perm_ads_manage => 'Manage banners';

  @override
  String get perm_pages_manage => 'Manage internal pages';

  @override
  String get perm_programs_manage => 'Manage programs';

  @override
  String get perm_attendance_manage => 'Record attendance';

  @override
  String get perm_notifications_send => 'Send notifications';

  @override
  String get perm_notifications_send_all => 'Send to all users';

  @override
  String get perm_borrowing_manage => 'Lend & return items';

  @override
  String get perm_items_manage => 'Manage items';

  @override
  String get perm_fines_manage => 'Manage fines';

  @override
  String get perm_reports_view => 'View reports';

  @override
  String get perm_audit_logs_view => 'View audit log';

  @override
  String get perm_activity_logs_view => 'View user activity';

  @override
  String get perm_admins_view => 'View administrators';

  @override
  String get perm_admins_manage => 'Manage administrators';

  @override
  String get perm_settings_manage => 'System settings';

  @override
  String get reminderSettings => 'Reminder settings';

  @override
  String get borrowingDaysBefore => 'Notify days before due date';

  @override
  String get overdueRepeatDays => 'Repeat overdue notice every (days)';

  @override
  String get defaultLoanDays => 'Default loan days';

  @override
  String get programReminderDefault => 'Program reminder (default)';

  @override
  String get notificationRetention => 'Keep read notifications (days)';

  @override
  String get systemLogin => 'System sign-in';

  @override
  String get totpCode => 'Authenticator code (6 digits)';

  @override
  String get systemConsole => 'System console';

  @override
  String get hiddenEntries => 'Hidden entries';

  @override
  String get visibleEntries => 'Visible entries';

  @override
  String get deniedAttempts => 'Denied attempts (7 days)';

  @override
  String get adminsByRole => 'Administrators by role';

  @override
  String get allAdmins => 'All administrators';

  @override
  String get act_register => 'Registered';

  @override
  String get act_login => 'Signed in';

  @override
  String get act_login_failed => 'Failed sign-in';

  @override
  String get act_logout => 'Signed out';

  @override
  String get act_password_change => 'Changed PIN';

  @override
  String get act_password_reset => 'Reset PIN';

  @override
  String get act_profile_update => 'Updated profile';

  @override
  String get act_device_change => 'Device changed';

  @override
  String get act_mezmur_view => 'Viewed Mezmur';

  @override
  String get act_mezmur_search => 'Searched';

  @override
  String get act_audio_play => 'Played audio';

  @override
  String get act_audio_complete => 'Finished audio';

  @override
  String get act_favorite_add => 'Added favorite';

  @override
  String get act_favorite_remove => 'Removed favorite';

  @override
  String get act_download => 'Downloaded';

  @override
  String get act_download_remove => 'Removed download';

  @override
  String get act_offline_access => 'Used offline';

  @override
  String get act_program_view => 'Viewed program';

  @override
  String get act_program_register => 'Registered for program';

  @override
  String get act_program_unregister => 'Cancelled registration';

  @override
  String get act_reminder_create => 'Created reminder';

  @override
  String get act_reminder_update => 'Updated reminder';

  @override
  String get act_reminder_delete => 'Deleted reminder';

  @override
  String get act_notification_open => 'Opened notification';

  @override
  String get act_attendance => 'Attended';

  @override
  String get act_borrow => 'Borrowed item';

  @override
  String get act_return => 'Returned item';

  @override
  String get act_page_view => 'Viewed page';

  @override
  String get telegram => 'Telegram';

  @override
  String get telegramConnect => 'Connect Telegram';

  @override
  String get telegramLinked => 'Connected';

  @override
  String get telegramHint =>
      'Link Telegram to receive PIN-reset codes and temporary PINs there.';

  @override
  String get telegramOpenBot =>
      'Telegram will open. Tap “Start”, then come back to the app.';

  @override
  String get telegramDisconnect => 'Disconnect';

  @override
  String get telegramDisconnectConfirm => 'Disconnect Telegram?';

  @override
  String get errTelegramNotConfigured =>
      'The Telegram bot is not configured yet. Contact an administrator.';

  @override
  String get forgotHintTelegram =>
      'If you linked Telegram, the code is sent there.';

  @override
  String get copy => 'Copy';

  @override
  String get tempPasswordSentTelegram =>
      'This PIN was also sent to the user on Telegram.';

  @override
  String profileChangePending(String change) {
    return 'Your name/phone change is waiting for admin approval: $change';
  }

  @override
  String get profileChangeSubmitted =>
      'Change sent for approval. It applies once an admin approves it.';

  @override
  String get profileApprovalNote =>
      'Name and phone changes must be approved by an administrator.';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get changeRequests => 'Profile change requests';

  @override
  String get approve => 'Approve';

  @override
  String get reject => 'Reject';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get pendingStatus => 'Pending';

  @override
  String get noChangeRequests => 'No pending requests';

  @override
  String get currentValue => 'Current';

  @override
  String get requestedValue => 'Requested';

  @override
  String get youtubeLink => 'YouTube link (optional)';

  @override
  String get watchOnYoutube => 'Watch on YouTube';

  @override
  String get vInvalidYoutube =>
      'Enter a valid YouTube link (youtube.com or youtu.be)';

  @override
  String reminderReturnItem(String item) {
    return 'Return “$item”';
  }

  @override
  String get attendanceToday => 'Today & upcoming';

  @override
  String get attendanceRecent => 'Past programs';

  @override
  String get attendanceOnlyAdmins =>
      'Only the taker HR assigned to a program records its attendance; members sign when recorded.';

  @override
  String get releases => 'App versions';

  @override
  String get newRelease => 'Upload new version';

  @override
  String get versionName => 'Version name (e.g. 1.1.0)';

  @override
  String get versionCode => 'Version code (build number)';

  @override
  String get releaseNotes => 'Release notes';

  @override
  String get mandatoryUpdate => 'Mandatory (older versions must update)';

  @override
  String get minSupportedCode => 'Minimum supported version code (optional)';

  @override
  String get publish => 'Publish';

  @override
  String get chooseApk => 'Choose APK file';

  @override
  String downloadsCount(int count) {
    return 'Downloaded $count times';
  }

  @override
  String get openDownloadPage => 'Open download page';

  @override
  String get errVersionExists => 'This version code already exists.';

  @override
  String get vInvalidVersion => 'Enter a valid version (e.g. 1.1.0)';

  @override
  String get unpublish => 'Unpublish';

  @override
  String get updateRequiredTitle => 'Update required';

  @override
  String updateRequiredBody(String version) {
    return 'Please download and install the new version ($version) to continue.';
  }

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String updateAvailableBody(String version) {
    return 'A new version ($version) is available.';
  }

  @override
  String get updateNow => 'Update now';

  @override
  String get later => 'Later';

  @override
  String get checkAgain => 'Check again';

  @override
  String get perm_releases_manage => 'Manage app versions';

  @override
  String get permissionTitle => 'Absence permission';

  @override
  String get requestPermission => 'Request permission';

  @override
  String get permissionReason => 'Reason (optional)';

  @override
  String get permissionRequested => 'Permission requested';

  @override
  String get permissionPending => 'Requested — waiting for approval';

  @override
  String get permissionApproved => 'Permission approved — you are excused';

  @override
  String get permissionRejected => 'Permission not approved';

  @override
  String get cancelPermission => 'Cancel request';

  @override
  String permissionDeadline(String date) {
    return 'Request before $date';
  }

  @override
  String permissionQuotaMonth(int used, int limit) {
    return 'This month: $used of $limit';
  }

  @override
  String permissionQuotaQuarter(int used, int limit) {
    return 'This quarter: $used of $limit';
  }

  @override
  String get errPermissionDeadline =>
      'The deadline for requesting permission has passed';

  @override
  String get errPermissionMonthly =>
      'You have used all your permissions for this month';

  @override
  String get errPermissionQuarterly =>
      'You have used all your permissions for this quarter';

  @override
  String get errPermissionExists =>
      'You already requested permission for this program';

  @override
  String get errPermissionRejected =>
      'Your permission request for this program was not approved';

  @override
  String get errPermissionNotApplicable =>
      'Permission requests are not available for this program';

  @override
  String get errPermissionDisabled => 'Permission requests are turned off';

  @override
  String get permissionRequests => 'Permission requests';

  @override
  String get noPermissionRequests => 'No permission requests';

  @override
  String get permissionPolicy => 'Permission rules';

  @override
  String get permissionsEnabled => 'Allow permission requests';

  @override
  String get permissionDeadlineHours =>
      'Deadline (hours before the program starts)';

  @override
  String get permissionMonthlyLimit => 'Max per month (empty = unlimited)';

  @override
  String get permissionQuarterlyLimit => 'Max per quarter (empty = unlimited)';

  @override
  String get permissionWeight =>
      'Attendance weight of an excused absence (0 – 1)';

  @override
  String get permissionWeightHint =>
      '0 counts like absent, 1 like present, 0.5 as half';

  @override
  String permissionUsage(int month, int quarter) {
    return 'This month $month · this quarter $quarter';
  }

  @override
  String attendanceRate(String rate) {
    return 'Attendance rate: $rate%';
  }

  @override
  String get tapForLyrics => 'Tap the image to see the lyrics';

  @override
  String get noLyricsYet => 'No lyrics for this Mezmur';

  @override
  String get statusPending => 'Waiting for approval';

  @override
  String get errAccountPending =>
      'Your account is waiting for an administrator\'s approval.';

  @override
  String get registerPendingTitle => 'Registration received';

  @override
  String get registerPendingBody =>
      'An administrator will review your account. You can sign in once it is approved.';

  @override
  String get profileLockedNote =>
      'Only administrators can change profile details. Please contact an administrator.';

  @override
  String get errProfileLocked => 'Profile changes are made by administrators.';

  @override
  String get myProfile => 'My profile';

  @override
  String get todayStudy => 'Today\'s practice';

  @override
  String get markToday => 'Show in “ዛሬ የሚጠኑ” today';

  @override
  String get programKind => 'Program type';

  @override
  String get programGeneral => 'General — everyone attends';

  @override
  String get programSpecial => 'Special event — invited people only';

  @override
  String get eventType => 'Event type';

  @override
  String get eventWedding => 'Wedding';

  @override
  String get eventHoliday => 'Holiday';

  @override
  String get eventMemorial => 'Memorial';

  @override
  String get eventCelebration => 'Celebration';

  @override
  String get eventOther => 'Other';

  @override
  String get specialInviteHint =>
      'After saving, invite people from Participants — only they will see this event.';

  @override
  String get checkFields => 'Please check the highlighted fields';

  @override
  String get audioOnPhone => 'Audio on this phone';

  @override
  String get browseFiles => 'Browse files';

  @override
  String get audioPermissionNeeded =>
      'Allow access to audio files to choose a recording.';

  @override
  String get allowAccess => 'Allow access';

  @override
  String get openSettings => 'Open settings';

  @override
  String get noAudioFiles => 'No audio files found on this phone';

  @override
  String get searchAudio => 'Search recordings';

  @override
  String get currentRecording => 'Current recording';

  @override
  String get noRecordingYet => 'No recording attached yet';

  @override
  String get savedForUpload =>
      'Saved the Mezmur so the recording can be attached';

  @override
  String get lyricsSavedOffline =>
      'Lyrics are saved automatically for offline use';

  @override
  String get programAlarm30 =>
      'You will get an alarm 30 minutes before it starts';

  @override
  String get programSoonTitle => 'Starting in 30 minutes';

  @override
  String get entityMezmur => 'Mezmur';

  @override
  String get entityProgram => 'Program';

  @override
  String get entityCategory => 'Category';

  @override
  String searchedFor(String q, int n) {
    return 'Searched “$q” · $n results';
  }

  @override
  String get activityDetails => 'Details';

  @override
  String get closePlayer => 'Close player';

  @override
  String get relatedMezmurs => 'Related Mezmurs';

  @override
  String get adminAlerts => 'Needs your attention';

  @override
  String permissionAsked(String name, String title) {
    return '$name asked to miss “$title”';
  }

  @override
  String pendingCount(int n) {
    return '$n waiting';
  }

  @override
  String get noAdminAlerts => 'Nothing is waiting for you';

  @override
  String get editMode => 'Edit mode';

  @override
  String get editModeOn => 'Edit mode: tap ✎ to edit, + to add';

  @override
  String get addNew => 'Add new';

  @override
  String get bulkImport => 'Bulk import';

  @override
  String get importMezmurs => 'Mezmurs (lyrics)';

  @override
  String get importFormat => 'File format';

  @override
  String get importMezmursHelp =>
      'A .txt file (UTF-8). One Mezmur per block; separate blocks with a line of ===.\nEach block starts with header lines, then an empty line, then the lyrics:\n  Title: … (required)\n  Category: Parent > Child (optional, must exist)\n  Tags: a, b (optional)\n  Status: published or draft (default draft)\n  YouTube: https://youtu.be/… (optional)';

  @override
  String get importCategoriesHelp =>
      'A .csv file (UTF-8) with the header: name,parent,description,order,active\nparent is the name (or \"Parent > Child\" path) of an existing category or of a row above; leave it empty for a top-level category.';

  @override
  String get importUsersHelp =>
      'A .csv file (UTF-8) with the header: full_name,phone,email,pin\nemail and pin may be empty; pin is 4 to 6 digits. Without one a temporary PIN is created and shown after the import; the user must set their own at first sign-in.';

  @override
  String get shareTemplate => 'Share template';

  @override
  String get chooseFile => 'Choose file';

  @override
  String get checkFile => 'Check file';

  @override
  String importNow(int n) {
    return 'Import $n';
  }

  @override
  String importResult(int ok, int skipped, int failed) {
    return '$ok ready · $skipped already exist · $failed with errors';
  }

  @override
  String importDone(int n) {
    return 'Imported $n';
  }

  @override
  String lineN(int n) {
    return 'Line $n';
  }

  @override
  String get tempPasswordsNote =>
      'Give each user their temporary PIN — they must set their own at first sign-in.';

  @override
  String get attachments => 'Files & links';

  @override
  String get addFile => 'Add file (PDF / image)';

  @override
  String get addLink => 'Add link';

  @override
  String get linkUrl => 'Link (https://…)';

  @override
  String get vInvalidUrl => 'Enter a link starting with https://';

  @override
  String get draftRestored => 'Restored your unsaved changes';

  @override
  String get discardDraft => 'Discard';

  @override
  String get savedAsDraft => 'Saved as draft';

  @override
  String get draftAutosave =>
      'Changes are kept as a draft until you press Save';

  @override
  String get shareLinkNote => 'Opens this page in the app';

  @override
  String get todayDate => 'Today';

  @override
  String get hubEducation => 'Education';

  @override
  String get hubMezmur => 'Mezmur';

  @override
  String get hubAboutMe => 'About me';

  @override
  String get hubEducationSub =>
      'Classes, schedule, attendance, assignments and results';

  @override
  String get hubMezmurSub => 'Hymns, programs, library and notifications';

  @override
  String get hubAboutMeSub => 'My ID card, departments and monthly payments';

  @override
  String get hubHome => 'Home';

  @override
  String hubGreeting(String name) {
    return 'Hello, $name';
  }

  @override
  String get myClasses => 'My classes';

  @override
  String get myDepartments => 'My departments';

  @override
  String get noDepartments => 'Not assigned to a department yet';

  @override
  String get departmentLead => 'Department lead';

  @override
  String get memberQrHint =>
      'Show this code for attendance, ID checks and borrowing';

  @override
  String get programRegular => 'Regular';

  @override
  String get programDistance => 'Distance';

  @override
  String get scanQr => 'Scan QR code';

  @override
  String get scanQrHint => 'Point the camera at the member\'s QR code';

  @override
  String get flashlight => 'Flashlight';

  @override
  String get cameraUnavailable =>
      'The camera is not available. Allow camera access for the app in the phone settings.';

  @override
  String get scanMember => 'Scan a member';

  @override
  String get monthlyPayments => 'Monthly Contributions';

  @override
  String get paymentsAllPaid => 'All months paid';

  @override
  String paymentsUnpaid(int n) {
    return '$n unpaid month(s)';
  }

  @override
  String paidMonths(int n) {
    return '$n paid';
  }

  @override
  String monthlyAmount(String amount) {
    return 'Monthly amount: $amount';
  }

  @override
  String get totalPaid => 'Total paid';

  @override
  String get noPayments => 'No payments yet';

  @override
  String get paid => 'Paid';

  @override
  String get notPaid => 'Not paid';

  @override
  String get methodCash => 'Cash';

  @override
  String get methodBank => 'Bank';

  @override
  String get methodTelebirr => 'telebirr';

  @override
  String get methodOther => 'Other';

  @override
  String get amount => 'Amount';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get paymentReference => 'Reference / transaction no.';

  @override
  String get recordPayment => 'Record';

  @override
  String get attachReceipt => 'Attach receipt photo';

  @override
  String get attachReceiptQ => 'Attach a receipt photo?';

  @override
  String get viewReceipt => 'View receipt';

  @override
  String get deletePayment => 'Delete payment';

  @override
  String get paymentPolicy => 'Payment settings';

  @override
  String get monthlyAmountLabel => 'Monthly amount';

  @override
  String get currency => 'Currency';

  @override
  String get paymentsStartFrom => 'Members owe from';

  @override
  String get fromSignUp => 'Their sign-up month';

  @override
  String get useSelectedMonth => 'Use shown month';

  @override
  String paymentsSummary(int n, String total) {
    return '$n paid · $total';
  }

  @override
  String get departments => 'Departments';

  @override
  String get newDepartment => 'New department';

  @override
  String get departmentKind => 'Area';

  @override
  String get departmentLeadHint => 'Lead (an administrator)';

  @override
  String get deptHr => 'Human resources';

  @override
  String get deptPayments => 'Payments';

  @override
  String memberCount(int n) {
    return '$n members';
  }

  @override
  String get assignMember => 'Assign member';

  @override
  String get roleLabel => 'Role label';

  @override
  String get noRoleLabel => 'No role label';

  @override
  String get noMembers => 'No members yet';

  @override
  String get removeMemberConfirm => 'Remove this member from the department?';

  @override
  String get eduManage => 'Manage classes';

  @override
  String get eduRegister => 'Class registration';

  @override
  String eduOpenCount(int n) {
    return '$n class(es) open for registration';
  }

  @override
  String get eduNoOpen => 'No class is open for registration now';

  @override
  String get eduUpcoming => 'Upcoming sessions';

  @override
  String get eduNotEnrolled => 'You are not enrolled in a class yet';

  @override
  String get eduTeaching => 'I teach';

  @override
  String eduStudentCount(int n) {
    return '$n students';
  }

  @override
  String get eduTakeAttendance => 'Take attendance';

  @override
  String get eduBorrowings => 'Education library';

  @override
  String get eduBorrowingsSub => 'Books and materials borrowed for classes';

  @override
  String get eduChooseProgram => 'Choose your program';

  @override
  String get eduEnrolled => 'Registered';

  @override
  String get eduEnroll => 'Register';

  @override
  String eduSeats(int taken, int total) {
    return '$taken / $total seats';
  }

  @override
  String eduOpensOn(String date) {
    return 'Registration opens $date';
  }

  @override
  String eduClosesOn(String date) {
    return 'Registration closes $date';
  }

  @override
  String get eduOpenNow => 'Registration is open';

  @override
  String eduYouAreEnrolled(String program) {
    return 'Registered · $program';
  }

  @override
  String get eduWithdraw => 'Withdraw from class';

  @override
  String get eduWithdrawConfirm => 'Withdraw from this class?';

  @override
  String get eduDetails => 'Details';

  @override
  String get eduAssignments => 'Assignments';

  @override
  String get eduResults => 'Results';

  @override
  String get eduSchedule => 'Weekly schedule';

  @override
  String get eduNoSchedule => 'No schedule yet';

  @override
  String get eduCourses => 'Courses';

  @override
  String get eduNoTeacher => 'No teacher assigned';

  @override
  String get eduNoAttendanceYet => 'No attendance recorded yet';

  @override
  String get eduNoAssignments => 'No assignments yet';

  @override
  String get eduGroupWork => 'Group work';

  @override
  String eduDue(String date) {
    return 'Due $date';
  }

  @override
  String get eduOpenAttachment => 'Open attachment';

  @override
  String eduScore(String score, String max) {
    return '$score / $max';
  }

  @override
  String get eduSubmitted => 'Submitted';

  @override
  String get eduResubmit => 'Resubmit';

  @override
  String get eduSubmit => 'Submit';

  @override
  String get eduAnswer => 'Your answer';

  @override
  String get eduAttachFile => 'Attach a file (PDF, photo, Word…)';

  @override
  String get eduNoResults => 'No results yet';

  @override
  String get notMarked => 'Not marked';

  @override
  String eduMarkedPresent(String name) {
    return '$name — present ✓';
  }

  @override
  String get eduNoStudents => 'No students yet';

  @override
  String eduMarkedCount(int marked, int total) {
    return '$marked of $total marked';
  }

  @override
  String get eduStudents => 'Students';

  @override
  String get eduAssessments => 'Results entry';

  @override
  String get eduGroupMembers => 'Group members';

  @override
  String get eduGroups => 'Groups';

  @override
  String get eduNewGroup => 'New group';

  @override
  String get eduNoGroups => 'No groups yet';

  @override
  String get eduNewAssignment => 'New assignment';

  @override
  String eduSubmissionCount(int n) {
    return '$n submitted';
  }

  @override
  String get eduInstructions => 'Instructions';

  @override
  String get eduDueDate => 'Due date';

  @override
  String get eduMaxScore => 'Out of';

  @override
  String get eduScoreLabel => 'Score';

  @override
  String get eduFeedback => 'Feedback';

  @override
  String get eduSubmissions => 'Submissions';

  @override
  String get eduNoSubmissions => 'Nothing submitted yet';

  @override
  String get eduGrade => 'Grade';

  @override
  String get eduNewAssessment => 'New assessment';

  @override
  String get eduAssessmentHint => 'e.g. Mid exam, Quiz 1';

  @override
  String get eduWeight => 'Weight %';

  @override
  String get eduNoAssessments => 'No assessments yet';

  @override
  String get eduNewClass => 'New class';

  @override
  String get eduNoClasses => 'No classes yet';

  @override
  String get eduRegOpen => 'Registration open';

  @override
  String get eduRegClosed => 'Registration closed';

  @override
  String get eduNewCourse => 'New course';

  @override
  String get eduTeacher => 'Teacher';

  @override
  String get eduAddSession => 'Add session';

  @override
  String get eduWeekday => 'Day';

  @override
  String get eduTerm => 'Term';

  @override
  String get eduRegOpens => 'Registration opens';

  @override
  String get eduRegCloses => 'Registration closes';

  @override
  String get eduSaveFirst =>
      'Save the class to add courses, schedule and attendance takers';

  @override
  String get eduNoCourses => 'No courses yet';

  @override
  String get eduAttendanceTakers => 'Attendance takers';

  @override
  String get eduNoTakers => 'Nobody assigned yet';

  @override
  String get eduViewStudents => 'View students';

  @override
  String get eduRemoveStudent => 'Remove from class';

  @override
  String get eduRemoveStudentConfirm => 'Remove this student from the class?';

  @override
  String get perm_departments_manage => 'Manage departments and their leads';

  @override
  String get perm_hr_manage => 'Assign members to departments (HR)';

  @override
  String get perm_payments_manage => 'Record monthly payments';

  @override
  String get perm_education_manage =>
      'Manage classes, courses and teachers (moderator)';

  @override
  String get navMyLibrary => 'My Library';

  @override
  String get themeToggle => 'Switch theme (light / dark)';

  @override
  String get userData => 'User data';

  @override
  String get adminSection => 'Administration';

  @override
  String get downloadSettings => 'Download settings';

  @override
  String get downloadAudioHint =>
      'Mezmur audio downloads automatically (on by default). With “Wi-Fi only” on, nothing downloads over mobile data. Failed downloads are retried later.';

  @override
  String get calendarUpcoming => 'Upcoming';

  @override
  String get calendarNoProgram => 'No program';

  @override
  String get allCategories => 'All';

  @override
  String get previousMonth => 'Previous month';

  @override
  String get nextMonth => 'Next month';

  @override
  String get attendanceStats => 'Attendance statistics';

  @override
  String get totalPrograms => 'Total';

  @override
  String memberIdLabel(String id) {
    return 'መ/ሕ/ተማሪ $id';
  }

  @override
  String get tapToShowId => 'Tap to show your ID';

  @override
  String get pickFromGallery => 'Choose from gallery';

  @override
  String get takePhoto => 'Take a photo';

  @override
  String get photoUpdated => 'Your photo was updated';

  @override
  String get choirTitle => 'Choir';

  @override
  String get choirWerebMezmur => 'Wereb and Mezmur';

  @override
  String get choirMezmurOnly => 'Mezmur only';

  @override
  String get choirEligible => 'Eligible';

  @override
  String get choirNotEligible => 'Not eligible yet';

  @override
  String choirPassing(String score) {
    return 'Passing score: $score';
  }

  @override
  String get choirEducation => 'Education (attendance)';

  @override
  String get choirMezmurAttendance => 'Mezmur (attendance)';

  @override
  String get choirParticipation => 'Other participation';

  @override
  String get choirPayment => 'Monthly payment';

  @override
  String choirSelectedOn(String date) {
    return 'Selected on $date';
  }

  @override
  String get notifGateTitle => 'Allow notifications';

  @override
  String get notifGateBody =>
      'Program alarms, attendance, permission answers and announcements reach you as notifications. Notifications must be allowed to use the app.';

  @override
  String get notifGateAllow => 'Allow notifications';

  @override
  String get notifGateOpenSettings => 'Open phone settings';

  @override
  String get programCategory => 'Program category';

  @override
  String get programCategoryDefault => 'Default: General';

  @override
  String get programCategories => 'Program categories';

  @override
  String get newProgramCategory => 'New category';

  @override
  String get editProgramCategory => 'Edit category';

  @override
  String get categoryNameAm => 'Name (Amharic)';

  @override
  String get categoryNameEn => 'Name (English)';

  @override
  String get categoryColor => 'Colour';

  @override
  String get deleteCategoryConfirm =>
      'Delete this category? If programs use it, it is deactivated instead.';

  @override
  String get recurrence => 'Repeats';

  @override
  String get recurrenceOnce => 'One day';

  @override
  String get recurrenceWeekly => 'Weekly';

  @override
  String get recurrenceMonthly => 'Monthly';

  @override
  String get monthlyRule => 'Monthly rule';

  @override
  String get monthlyRuleDay =>
      'Same date every month (last day if the month is shorter)';

  @override
  String get monthlyRuleWeekday =>
      'Same weekday of the month (e.g. 2nd Sunday)';

  @override
  String get recurrenceUntil => 'Until (empty = no end)';

  @override
  String everyWeekday(String weekday) {
    return 'Every $weekday';
  }

  @override
  String everyNthWeekday(String n, String weekday) {
    return 'Every month, $weekday no. $n';
  }

  @override
  String everyMonthDay(String day) {
    return 'Every month on day $day';
  }

  @override
  String untilDate(String date) {
    return 'until $date';
  }

  @override
  String get nextOccurrenceLabel => 'Next date';

  @override
  String get occurrenceDate => 'Program date';

  @override
  String get today => 'Today';

  @override
  String get attendanceCleared => 'Mark cleared';

  @override
  String get attendanceNotOpen =>
      'Attendance can be marked only on the program day.';

  @override
  String get attendanceNeedsConnection =>
      'Marking attendance needs an internet connection.';

  @override
  String get expectedMembers => 'Expected';

  @override
  String get choirSelected => 'Selected';

  @override
  String get choirRefresh => 'Recalculate scores';

  @override
  String choirRefreshed(String count, String newly) {
    return '$count members scored; $newly newly eligible';
  }

  @override
  String get choirPolicy => 'Choir rules';

  @override
  String get choirWeights => 'Weights (total 100)';

  @override
  String choirWeightsTotal(String total) {
    return 'Total: $total / 100';
  }

  @override
  String get choirWeightsMust100 => 'The weights must add up to 100';

  @override
  String get choirPassingScore => 'Passing score (0–100)';

  @override
  String get choirWindow => 'Evaluation window (months)';

  @override
  String get choirEducationCats => 'Categories counted as education';

  @override
  String get choirMezmurCats => 'Categories counted as mezmur';

  @override
  String get choirNoData => 'Nothing to measure in this period';

  @override
  String choirSelectAs(String type) {
    return 'Select as “$type”';
  }

  @override
  String get choirRemove => 'Remove from choir';

  @override
  String get choirRemoveConfirm => 'Remove this member from the choir?';

  @override
  String get choirNotEligibleHint =>
      'Members below the passing score cannot be selected.';

  @override
  String get choirSeason => 'Season';

  @override
  String get choirSeasonHint => 'e.g. Timket 2019 (optional)';

  @override
  String get choirNotComputed => 'Not computed yet';

  @override
  String get participationAdd => 'Record participation';

  @override
  String get participationActivity => 'Activity';

  @override
  String get participationPoints => 'Points (0–100)';

  @override
  String pointsCount(String points) {
    return '$points points';
  }

  @override
  String get paymentMonths => 'Months covered';

  @override
  String monthsCount(String n) {
    return '$n month(s)';
  }

  @override
  String get memberTypeLabel => 'Member type';

  @override
  String get memberStudent => 'Student';

  @override
  String get memberWorker => 'Worker';

  @override
  String amountAuto(String amount) {
    return 'Leave empty for $amount (rate × months)';
  }

  @override
  String coverage(String from, String to) {
    return '$from – $to';
  }

  @override
  String get verifyPayment => 'Verify payment';

  @override
  String get paymentVerified => 'Verified';

  @override
  String get paymentRates => 'Payment rates';

  @override
  String get addRate => 'New rate';

  @override
  String get effectiveFrom => 'Effective from';

  @override
  String effectiveFromDate(String date) {
    return 'from $date';
  }

  @override
  String get noRates => 'No rates yet';

  @override
  String paidUntil(String month) {
    return 'Paid until $month';
  }

  @override
  String get savedOffline =>
      'Saved offline — it will sync when you are back online';

  @override
  String get attendanceOfflineNote =>
      'You are offline: Start, records and signatures are kept on the phone (encrypted) and sent automatically when the connection is back.';

  @override
  String get pendingSync => 'Waiting to sync';

  @override
  String get borrowingSavedOffline =>
      'Borrowing saved offline — it will sync when you are back online';

  @override
  String offlineChangeRejected(String what, String error) {
    return '$what was not saved: $error';
  }

  @override
  String get syncWhatAttendance => 'An attendance mark made offline';

  @override
  String get syncWhatClassAttendance => 'A class attendance mark made offline';

  @override
  String get syncWhatBorrowing => 'A borrowing recorded offline';

  @override
  String get syncWhatReturn => 'A return recorded offline';

  @override
  String get syncWhatReminder => 'A reminder change';

  @override
  String get deptParticipation =>
      'Participation (its lead records choir participation points)';

  @override
  String get formTitle => 'Membership form';

  @override
  String get memberAccount => 'Account and classification';

  @override
  String get mfFullName => 'Full name (with grandfather\'s name)';

  @override
  String get phoneMobile => 'Phone (mobile)';

  @override
  String get phoneHome => 'Phone (home)';

  @override
  String get memberGroup => 'Member group';

  @override
  String get groupChildren => 'Children';

  @override
  String get groupYouth => 'Youth & Adult';

  @override
  String get groupMarried => 'Married';

  @override
  String get canLogin => 'Can log in to the app';

  @override
  String get canLoginHint =>
      'Children are allowed by an admin when they grow up';

  @override
  String get cannotLogin => 'Cannot log in';

  @override
  String get membershipStatus => 'Membership status';

  @override
  String get stActive => 'Active';

  @override
  String get stDeceased => 'Deceased';

  @override
  String get stInactive => 'Not active currently';

  @override
  String get stUniversity => 'At university';

  @override
  String get stAbroad => 'Abroad';

  @override
  String get dateOfDeath => 'Date of death';

  @override
  String get universityName => 'Which university';

  @override
  String get countryName => 'Which country';

  @override
  String get spiritualLevel => 'Spiritual education level';

  @override
  String get notSet => 'Not set';

  @override
  String levelN(String n) {
    return 'Level $n';
  }

  @override
  String get gender => 'Gender';

  @override
  String get male => 'Male';

  @override
  String get female => 'Female';

  @override
  String get motherName => 'Mother\'s name';

  @override
  String get birthSection => 'Birth';

  @override
  String get birthDate => 'Date of birth';

  @override
  String get birthDiocese => 'Diocese';

  @override
  String get city => 'City';

  @override
  String get woreda => 'Woreda';

  @override
  String get kebele => 'Kebele';

  @override
  String get birthPlaceName => 'Specific place name';

  @override
  String get christianName => 'Christian name';

  @override
  String get baptismChurch => 'Church of baptism';

  @override
  String get baptismDate => 'Date of baptism';

  @override
  String get addressSection => 'Residential address';

  @override
  String get houseNumber => 'House number';

  @override
  String get emergencySection => 'Emergency contact';

  @override
  String get abinetSection => 'Church (abinet) education';

  @override
  String get abinetQes => 'Priesthood';

  @override
  String get abinetDeacon => 'Diaconate';

  @override
  String get abinetNone => 'None';

  @override
  String get other => 'Other';

  @override
  String get spiritualSection => 'Spiritual education';

  @override
  String get theology => 'Theology';

  @override
  String get eduMasters => 'Master\'s';

  @override
  String get eduDegree => 'Degree';

  @override
  String get eduDiploma => 'Diploma';

  @override
  String get eduCertificate => 'Certificate';

  @override
  String get eduDoctorate => 'Doctorate';

  @override
  String get secularSection => 'Secular education';

  @override
  String get institutionName => 'Higher education institution';

  @override
  String get fieldOfStudy => 'Field of study';

  @override
  String get livelihoodSection => 'Livelihood';

  @override
  String get employer => 'Employer';

  @override
  String get employerPrivate => 'Private';

  @override
  String get employerGovernment => 'Government';

  @override
  String get profession => 'Current profession';

  @override
  String get experienceProfession => 'Skill gained by experience';

  @override
  String get churchService => 'Church service (if any)';

  @override
  String get studyPlaceName => 'School / institution you attend';

  @override
  String get chooseStudentWorker => 'Choose student or worker first';

  @override
  String get confessionSection => 'Confession father';

  @override
  String get maritalSection => 'Marital life';

  @override
  String get married => 'Married';

  @override
  String get single => 'Single';

  @override
  String get marriageSection => 'Type of marriage';

  @override
  String get teklil => 'Teklil';

  @override
  String get kurban => 'Kurban';

  @override
  String get photo => 'Photo';

  @override
  String get deptLeader => 'Leader';

  @override
  String get deptMember => 'Member';

  @override
  String get editMember => 'Edit member';

  @override
  String get addMembers => 'Add members';

  @override
  String get chooseLeader => 'Choose the leader';

  @override
  String get leaderHint =>
      'Each department has one leader, who records the department\'s monthly participation (no admin access).';

  @override
  String get makeLeader => 'Make leader';

  @override
  String get makeMember => 'Make member';

  @override
  String get eligTitle => 'Service eligibility';

  @override
  String get eligEducation => 'Education';

  @override
  String get eligMezmur => 'Mezmur';

  @override
  String get eligPayment => 'Monthly payment';

  @override
  String get eligParticipation => 'Department participation';

  @override
  String get eligTotal => 'Total';

  @override
  String get eligEligible => 'Eligible';

  @override
  String get eligIneligible => 'Ineligible';

  @override
  String get eligPass => 'Pass';

  @override
  String get eligFail => 'Fail';

  @override
  String get eligStatus => 'Eligibility status';

  @override
  String eligMinimum(String value) {
    return 'Minimum: $value';
  }

  @override
  String eligTotalScore(String score, String minimum) {
    return 'Total score $score (minimum $minimum)';
  }

  @override
  String eligWindow(String from, String to) {
    return 'Assessed period: $from – $to';
  }

  @override
  String get eligFailedRequirements => 'Failed requirements';

  @override
  String eligFailure(
    String category,
    String current,
    String required,
    String shortfall,
  ) {
    return '$category: $current — requires $required ($shortfall short)';
  }

  @override
  String get eligAttendance => 'Attendance';

  @override
  String get eligAssessment => 'Course assessment';

  @override
  String get eligAttendanceCalendar => 'Attendance calendar';

  @override
  String get eligActivities => 'Other Mezmur participation';

  @override
  String get paymentExempt => 'Not required';

  @override
  String get required => 'Required';

  @override
  String get paidLate => 'Paid after due month';

  @override
  String get participationHint =>
      'Give each member 0 – 10 for this month. A member left unscored is not counted as 0; it is shown for review.';

  @override
  String participationMissing(String count) {
    return '$count members have no score (not counted as 0). Continue?';
  }

  @override
  String get departmentParticipation => 'Department participation (monthly)';

  @override
  String get myMembershipForm => 'My membership form';

  @override
  String get month => 'Month';

  @override
  String get programForGroups => 'Who the program is for';

  @override
  String get allGroups => 'Everyone';

  @override
  String get setMemberTypeFirst =>
      'The amount depends on student / worker. Set it on the member first.';

  @override
  String get rateNotSet => 'No monthly rate is set for this member type';

  @override
  String get paymentSettings => 'Payment settings';

  @override
  String get graceDaysHint =>
      'Days after a month ends during which a payment still counts as on time';

  @override
  String get editRate => 'Edit rate';

  @override
  String get memberTypeMissing => 'Student / worker not set';

  @override
  String get polWeightsMinimums => 'Weights and minimums (weights total 100)';

  @override
  String get polWeight => 'Weight';

  @override
  String get polMinimum => 'Minimum';

  @override
  String get polMinAboveWeight => 'A minimum cannot be above its weight';

  @override
  String get polTotalMinimum => 'Minimum total score';

  @override
  String get polAllMinimumsHint =>
      'Eligible only when every minimum and the total are met';

  @override
  String get polClasses => 'Classes';

  @override
  String get polClassesHint => 'None selected = each member\'s own classes';

  @override
  String get polCourses => 'Courses (for assessment)';

  @override
  String get polCoursesHint => 'None selected = every course of those classes';

  @override
  String get polAttendanceRange =>
      'Attendance range (empty = the evaluation window)';

  @override
  String get polEduShare => 'Attendance share of Education (rest: assessment)';

  @override
  String get polActivitiesHint => 'Programs such as ሠርክ, Sunday service, study';

  @override
  String get polMezShare => 'Attendance share of Mezmur (rest: activities)';

  @override
  String get polLateCredit => 'Credit for a month paid late';

  @override
  String get polLateCreditHint => 'A month paid on time earns 100%';

  @override
  String get polParticipationHint =>
      'Taken automatically from department leaders\' monthly records';

  @override
  String get errLoginNotAllowed =>
      'This account is not allowed to sign in. Please contact an administrator.';

  @override
  String get errPaymentOverlap => 'One of these months is already paid';

  @override
  String get errChildrenExempt => 'Children do not pay monthly payments';

  @override
  String get errChildrenNoDepartment =>
      'Children are not assigned to departments';

  @override
  String get errNotDepartmentLeader =>
      'Only the department\'s leader can do this';

  @override
  String get errFuturePeriod =>
      'A month that has not started cannot be recorded';

  @override
  String get errNotAMember => 'This member is not in this department';

  @override
  String get errChoirNotEligible => 'This member is not eligible for service';

  @override
  String get paymentDue => 'Due (not yet late)';

  @override
  String get additionalSession => 'Additional session';

  @override
  String get additionalSessionHint =>
      'An extra session outside the regular schedule';

  @override
  String get countsForSelection => 'Counts for holiday selections';

  @override
  String get countsForSelectionHint =>
      'Each selection can still include or exclude it';

  @override
  String get attAfterLate => 'After the late period';

  @override
  String get attAfterLateLate => 'Record as late';

  @override
  String get attAfterLateReject => 'Refuse (the taker files a comment instead)';

  @override
  String get attAttended => 'Attended';

  @override
  String get attCloseConfirm =>
      'Close this session? Unmarked members then count as absent and changes need a correction request.';

  @override
  String get attCloseSession => 'Close session';

  @override
  String get attClosed => 'Closed';

  @override
  String get attClosedNotice =>
      'This session is closed. File a correction request for any change.';

  @override
  String get attCorrectionHint =>
      'A comment does not change attendance by itself; a reviewer decides.';

  @override
  String get attCorrectionRequest => 'Comment / correction request';

  @override
  String get attCorrectionSent => 'Request sent';

  @override
  String get attCorrections => 'Attendance corrections';

  @override
  String get attLateMinutes => 'Late period (minutes)';

  @override
  String get attOnTimeMinutes => 'On time until (minutes after start)';

  @override
  String get attOverride => 'Override (after closure)';

  @override
  String get attPermissionReason => 'Reason for the permission';

  @override
  String get attRules => 'Attendance time rules';

  @override
  String get attRulesHint =>
      'From the program start: on time → late → the rule below. When the program ends, unmarked members count as absent.';

  @override
  String attRulesLine(String onTime, String late) {
    return 'On time for $onTime min, then late for $late min';
  }

  @override
  String get attScan => 'Scan QR';

  @override
  String get attUnmarked => 'Unmarked';

  @override
  String availableCount(String n) {
    return 'Available: $n';
  }

  @override
  String get bStatusPending => 'Awaiting approval';

  @override
  String get borrowApprovalHint =>
      'When the issuer cannot approve, the loan waits for approval';

  @override
  String get borrowApprovalRequired => 'Approval required';

  @override
  String get borrowDirectPolicy => 'Direct borrowing rules';

  @override
  String get borrowDirectPolicyHint =>
      'Lending to members directly, without a department request. Which items can be lent is set on each item.';

  @override
  String get borrowMaxDays => 'Maximum days';

  @override
  String get borrowMaxQuantity => 'Maximum quantity';

  @override
  String get borrowPerItemHint =>
      'Empty = no limit (an item\'s own limit comes first)';

  @override
  String get borrowRenew => 'Renew';

  @override
  String get comment => 'Comment';

  @override
  String get department => 'Department';

  @override
  String get deptAddAdmin => 'Add administrator';

  @override
  String get deptAdminRolesHint =>
      'They get only the permissions of these roles';

  @override
  String get deptAdmins => 'Department administrators';

  @override
  String get deptAdminsHint =>
      'Department administrators are members who can do only what their roles allow. Nobody can change their own roles.';

  @override
  String get deptExtraPermissions => 'Individual permissions';

  @override
  String get deptExtraPermissionsHint =>
      'Permissions for this member only, on top of their roles';

  @override
  String get deptNoAdmins => 'No administrators yet';

  @override
  String get ethiopianDaysHint =>
      'Days of every Ethiopian month (e.g. ሰርክ: 1, 10, 19)';

  @override
  String everyEthiopianDays(String days) {
    return 'Every Ethiopian month on day $days';
  }

  @override
  String get itemDepartment => 'Owning / responsible department';

  @override
  String get itemDirectBorrowable => 'Can be lent to members directly';

  @override
  String get itemDirectBorrowableHint =>
      'Otherwise only through a department request';

  @override
  String get itemRenewable => 'Can be renewed';

  @override
  String get manageOccurrences => 'Dates (cancel / reschedule)';

  @override
  String get noDepartment => 'No department';

  @override
  String get occCancel => 'Cancel this date';

  @override
  String get occCancelled => 'Cancelled';

  @override
  String get occHint =>
      'A cancelled date takes no attendance and creates no absences.';

  @override
  String get occReschedule => 'Reschedule';

  @override
  String get occRestore => 'Restore';

  @override
  String get pending => 'Pending';

  @override
  String get perm_attendance_close => 'End attendance sessions (HR)';

  @override
  String get perm_attendance_configure =>
      'Configure attendance (signature rules) ? HR';

  @override
  String get perm_attendance_correction_approve =>
      'Review attendance corrections';

  @override
  String get perm_attendance_correction_request =>
      'Submit attendance corrections';

  @override
  String get perm_attendance_override => 'Change attendance after closure';

  @override
  String get perm_attendance_reports => 'Attendance reports';

  @override
  String get perm_attendance_view => 'View attendance';

  @override
  String get perm_borrowing_approve => 'Approve borrowings';

  @override
  String get perm_borrowing_configure => 'Configure direct borrowing';

  @override
  String get perm_choir_manage => 'Wedding choir services';

  @override
  String get perm_payments_configure => 'Payment rates and settings';

  @override
  String get perm_payments_view => 'View monthly contributions (read-only)';

  @override
  String get perm_program_categories_manage => 'Program categories';

  @override
  String get perm_property_request => 'Request property';

  @override
  String get perm_property_review => 'Review and issue property requests';

  @override
  String get perm_selection_configure => 'Configure holiday selections';

  @override
  String get perm_selection_exams => 'Decide whether exams are required';

  @override
  String get perm_selection_finalize => 'Finalize selections';

  @override
  String get perm_selection_review => 'Review selections';

  @override
  String get perm_selection_view => 'View selections';

  @override
  String get pgChoir => 'Choir and selections';

  @override
  String get pgContent => 'Content';

  @override
  String get pgHr => 'Human resources';

  @override
  String get pgNotifications => 'Notifications';

  @override
  String get pgPrograms => 'Programs and attendance';

  @override
  String get pgSystem => 'System';

  @override
  String get propDraft => 'Draft';

  @override
  String get propIssue => 'Issue';

  @override
  String get propIssued => 'Issued';

  @override
  String get propItemName => 'Item or service name';

  @override
  String get propNeededOn => 'Needed on';

  @override
  String get propNew => 'New property request';

  @override
  String get propNone => 'No property requests';

  @override
  String get propPartiallyIssued => 'Partially issued';

  @override
  String get propPickItem => 'Pick from the inventory';

  @override
  String get propPickItemHint => 'Or type a name below';

  @override
  String get propPurpose => 'Purpose';

  @override
  String get propQuantityOptional => 'Quantity (optional)';

  @override
  String get propRequests => 'Property requests';

  @override
  String get propReturn => 'Take back';

  @override
  String get propReturnOn => 'Return by';

  @override
  String get propReturned => 'Returned';

  @override
  String get propSaveDraft => 'Save draft';

  @override
  String get propSubmitted => 'Submitted';

  @override
  String get propUnderReview => 'Under review';

  @override
  String get reason => 'Reason';

  @override
  String get reasonExamNotRequired =>
      'Exams are not required in this selection';

  @override
  String get reasonMissingMonths => 'Some months have no score (for review)';

  @override
  String get reasonNoExam => 'No exam in this period';

  @override
  String get reasonNoScores => 'No monthly score from the department leader';

  @override
  String get reasonNoSessions => 'No sessions in this period';

  @override
  String get reasonNotConfigured => 'No categories chosen for this';

  @override
  String get reasonNotEnrolled => 'Not enrolled in a class';

  @override
  String get reasonNotInDepartment => 'Not in a department';

  @override
  String get reasonNotMemberYet => 'Not a member yet in this period';

  @override
  String get reasonNothingDue => 'Nothing due in this period';

  @override
  String get recurrenceEthiopianDays => 'Ethiopian month days';

  @override
  String get requestedBy => 'Requested by';

  @override
  String get roleActive => 'Role is active';

  @override
  String get roleActiveHint => 'A deactivated role grants nothing';

  @override
  String get roleDepartment => 'Default role of department';

  @override
  String roleInUse(String n) {
    return '$n holders';
  }

  @override
  String get selAdditionalCounted => 'Additional sessions counted';

  @override
  String get selAdditionalHint =>
      'Whether each additional session counts in this selection';

  @override
  String get selAdditionalSessions => 'Additional sessions';

  @override
  String get selAverage => 'Average';

  @override
  String get selBackToOpen => 'Back to open';

  @override
  String get selBonus => 'Service bonus';

  @override
  String get selBonusHint =>
      'Added for attending service programs such as ሰርክ (at most 30)';

  @override
  String get selBonusMax => 'Maximum bonus (≤ 30)';

  @override
  String get selBonusSources => 'Categories / programs counted for the bonus';

  @override
  String get selCancel => 'Cancel selection';

  @override
  String get selClearException => 'Remove the exception';

  @override
  String get selConfiguration => 'Configuration and formula';

  @override
  String get selConfigure => 'Configure';

  @override
  String selConfirmStatus(String status) {
    return 'Move the selection to “$status”?';
  }

  @override
  String get selContribution => 'Monthly contribution';

  @override
  String selCounts(String q, String t) {
    return '$q of $t qualified';
  }

  @override
  String get selCourseAttendance => 'Course attendance';

  @override
  String get selDefaultIn => 'Default (counts)';

  @override
  String get selDefaultOut => 'Default (not counted)';

  @override
  String get selDraftNoResults =>
      'Results are calculated when the selection opens';

  @override
  String get selExam => 'Exam / assessment';

  @override
  String get selExamsNotRequired => 'Exams not required';

  @override
  String get selExamsOnlyHint =>
      'You can only change whether exams are required';

  @override
  String get selExamsRequired => 'Exams required';

  @override
  String get selExamsRequiredHint =>
      'If off, the exam is left out and the rest is scaled to 100';

  @override
  String get selExamsRequiredSwitch => 'Exam results required';

  @override
  String get selException => 'Exception';

  @override
  String get selExceptionHint => 'An exception needs a reason and is recorded';

  @override
  String get selExclude => 'Exclude';

  @override
  String get selExcludedSessions => 'Sessions not counted';

  @override
  String get selFinalize => 'Finalize';

  @override
  String get selFormula =>
      'Formula: base = (sum of percent × weight) ÷ (sum of the counted weights) × 100; total = base + bonus (≤ 30). Qualified when every counted component reaches its minimum and the total reaches the total minimum. No ranking: equal scores are treated equally.';

  @override
  String get selInclude => 'Include';

  @override
  String get selLateCreditHint => '100% = a month paid late counts as paid';

  @override
  String get selLive => 'live';

  @override
  String get selMarkNotQualified => 'Mark not qualified';

  @override
  String get selMarkQualified => 'Mark qualified';

  @override
  String get selMezmurAttendance => 'Mezmur attendance';

  @override
  String get selMissingTitle => 'Missing data';

  @override
  String get selName => 'Holiday / service name';

  @override
  String get selNameHint => 'e.g. ጥምቀት 2019';

  @override
  String get selNew => 'New selection';

  @override
  String get selNoMinimum => 'No minimum';

  @override
  String get selNone => 'No selections yet';

  @override
  String get selNoneOpen => 'No holiday selection is open right now';

  @override
  String get selNotCounted => 'Not counted';

  @override
  String get selNotQualified => 'Not qualified';

  @override
  String get selNotScored => 'Not scored';

  @override
  String get selOpen => 'Open';

  @override
  String get selPercent => 'Percent';

  @override
  String get selPoints => 'points';

  @override
  String get selQualified => 'Qualified';

  @override
  String get selStatusCancelled => 'Cancelled';

  @override
  String get selStatusDraft => 'Draft';

  @override
  String get selStatusFinalized => 'Finalized';

  @override
  String get selStatusOpen => 'Open';

  @override
  String get selStatusReview => 'In review';

  @override
  String get selTitle => 'Holiday service selection';

  @override
  String get selToReview => 'Move to review';

  @override
  String selTotalLine(String base, String bonus, String total, String min) {
    return 'Base $base + bonus $bonus = $total (minimum $min)';
  }

  @override
  String selectCount(String n) {
    return 'Select $n';
  }

  @override
  String get wedAbsent => 'Absent';

  @override
  String get wedCompleted => 'Completed';

  @override
  String wedMembers(String n) {
    return 'Selected ($n)';
  }

  @override
  String get wedNew => 'New wedding service';

  @override
  String get wedNone => 'No wedding services';

  @override
  String get wedParticipated => 'Served';

  @override
  String get wedPlanned => 'Planned';

  @override
  String get wedSelectMembers => 'Select choir members';

  @override
  String get wedSelected => 'Selected';

  @override
  String get wedServiceAt => 'Service date and time';

  @override
  String get wedTitle => 'Other Mezmur services';

  @override
  String get wedWithdrawn => 'Withdrawn';

  @override
  String get minutesUnit => 'min';

  @override
  String get chatTitle => 'Department chat';

  @override
  String get chatNone => 'You are not assigned to a department yet.';

  @override
  String get chatPrivate => 'Private messages';

  @override
  String get chatNoMessages => 'No messages yet — write the first one.';

  @override
  String get chatTypeHint => 'Write a message…';

  @override
  String get chatSend => 'Send';

  @override
  String get chatAttach => 'Attach';

  @override
  String get chatPhoto => 'Photo';

  @override
  String get chatCamera => 'Camera';

  @override
  String get chatFile => 'Audio, video or document';

  @override
  String get chatMeeting => 'Voice meeting link';

  @override
  String get chatMeetingUrl =>
      'Meeting link (Jitsi, Google Meet, Zoom, Telegram)';

  @override
  String get chatMeetingNote => 'Note (optional)';

  @override
  String get chatMeetingWhen => 'Time (optional)';

  @override
  String get chatMeetingJoin => 'Join';

  @override
  String get chatMeetingTitle => 'Voice meeting';

  @override
  String get chatVoiceInfo =>
      'The current server (cPanel) cannot carry live voice calls or group voice chats. Leaders share a Jitsi, Google Meet or Telegram voice-meeting link instead.';

  @override
  String get chatDeleted => 'This message was deleted';

  @override
  String get chatDeleteConfirm => 'Delete this message?';

  @override
  String get chatLeader => 'Leader';

  @override
  String get chatNewPrivate => 'New private message';

  @override
  String get chatNoThreads => 'No private messages.';

  @override
  String get chatOpenFile => 'Open';

  @override
  String get chatLoadOlder => 'Older messages';

  @override
  String get midTitle => 'Member IDs';

  @override
  String get midHint =>
      'Numbers are permanent; only each group\'s prefix and the style change. A change re-displays the IDs of every member in that group at once.';

  @override
  String get midSeparator => 'Separator';

  @override
  String get midDigits => 'Minimum digits (0 = as is)';

  @override
  String get midPreview => 'Preview';

  @override
  String get midSpace => 'Space';

  @override
  String get midNone => '(none)';

  @override
  String get errMemberNotExpected =>
      'This member is not in this program\'s target group.';

  @override
  String get errSelfAttendance =>
      'You cannot record your own attendance; another attendance taker must record it.';

  @override
  String get errAttendanceNotActive =>
      'Attendance opens on the day of the program.';

  @override
  String get errChatForbidden => 'You are not a member of this department.';

  @override
  String get errChatPrivate =>
      'Private messages are only possible with your department\'s leaders.';

  @override
  String get errChatMedia =>
      'Only department leaders send pictures, media and meeting links.';

  @override
  String get errChatDelete => 'You can only delete your own messages.';

  @override
  String get vMessageEmpty => 'The message is empty.';

  @override
  String get vInvalidMeetingUrl =>
      'Enter a link from a known meeting service (Jitsi, Google Meet, Zoom, Telegram).';

  @override
  String get vNoSpaces => 'Spaces are not allowed.';

  @override
  String get pin => 'PIN';

  @override
  String get pinHelp => '4 to 6 digits';

  @override
  String get confirmPin => 'Confirm PIN';

  @override
  String get newPin => 'New PIN';

  @override
  String get currentPinOrPassword => 'Current PIN';

  @override
  String get pinOrPassword => 'PIN';

  @override
  String get pinOrPasswordHelp => '4 to 6 digits';

  @override
  String get vInvalidPin => 'The PIN must be 4 to 6 digits';

  @override
  String get vPinMismatch => 'The PINs do not match';

  @override
  String get vPinOrPassword => 'Enter a PIN of 4 to 6 digits';

  @override
  String get changePinTitle => 'Change PIN';

  @override
  String get pinChanged => 'Your PIN was changed';

  @override
  String get errorInvalidPin => 'The PIN must be 4 to 6 digits';

  @override
  String get errorPinOrPassword => 'Enter a PIN of 4 to 6 digits';

  @override
  String get remindBefore2880 => '2 days before';

  @override
  String get remindBefore1440 => '1 day before';

  @override
  String get remindBefore360 => '6 hours before';

  @override
  String get remindBefore60 => '1 hour before';

  @override
  String get startsIn2880 => 'starts in 2 days';

  @override
  String get startsIn1440 => 'starts tomorrow';

  @override
  String get startsIn360 => 'starts in 6 hours';

  @override
  String get startsIn60 => 'starts in 1 hour';

  @override
  String get programReminderAlarm => 'Program reminder';

  @override
  String get myProgramReminders => 'Reminders (alarm) for this program';

  @override
  String get myProgramRemindersHint =>
      'Your phone reminds you at the times you choose — it works without internet too.';

  @override
  String get useProgramReminders => 'Use the program\'s reminders';

  @override
  String get programReminderTimes => 'Reminder times';

  @override
  String get programReminderTimesHint =>
      'Members get a notification and an alarm at these times (each member can change it for themselves).';

  @override
  String get noEndTime => 'No end time';

  @override
  String get hasEndTime => 'Has an end time';

  @override
  String get noEndTimeHint =>
      'A program without an end time lasts until the end of its day.';

  @override
  String get attendanceWindow => 'Attendance window (minutes)';

  @override
  String get attendanceWindowHint =>
      'e.g. a program at 5:30 with 30 on-time minutes counts arrivals up to 6:00 as on time. Empty = the general rule.';

  @override
  String get onTimeMinutes => 'On time (minutes)';

  @override
  String get lateMinutes => 'Late (more minutes)';

  @override
  String onTimeUntil(String time) {
    return 'On time until $time';
  }

  @override
  String lateUntil(String time) {
    return 'Late until $time';
  }

  @override
  String fromTime(String time) {
    return 'From $time';
  }

  @override
  String get rolePermissionsRevokeHint =>
      'Unticking takes the permission away from this person only (the role stays the same); ticking it again gives it back.';

  @override
  String get permissionRevoked => 'Revoked';

  @override
  String seeAllCategories(String count) {
    return 'See all categories ($count)';
  }

  @override
  String get hubQuickLinks => 'Quick access';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get projectManagement => 'Project Management';

  @override
  String get pmOverview => 'Overview';

  @override
  String get pmMyTasks => 'My Tasks';

  @override
  String get pmIssues => 'Issues';

  @override
  String get pmSuggestions => 'Suggestions';

  @override
  String get pmBudget => 'Budget';

  @override
  String get pmExpenses => 'Expenses';

  @override
  String get pmReports => 'Reports';

  @override
  String get pmTasks => 'Tasks';

  @override
  String get pmTeam => 'Team';

  @override
  String get pmFiles => 'Files';

  @override
  String get pmActivity => 'Activity';

  @override
  String get pmApprovals => 'Approvals';

  @override
  String get pmNoDepartments =>
      'You are not in any department whose projects you can see.';

  @override
  String get pmNoProjects => 'No projects';

  @override
  String get pmNoTasks => 'No tasks';

  @override
  String get pmNoIssues => 'No issues';

  @override
  String get pmNoSuggestions => 'No suggestions';

  @override
  String get pmNoExpenses => 'No expenses';

  @override
  String get pmNoFiles => 'No files';

  @override
  String get pmNoActivity => 'No activity';

  @override
  String pmActiveCount(String count) {
    return '$count active';
  }

  @override
  String pmOverdueCount(String count) {
    return '$count overdue';
  }

  @override
  String pmOpenCount(String count) {
    return '$count open';
  }

  @override
  String pmProjectsCount(String count) {
    return '$count projects';
  }

  @override
  String get pmNewProject => 'New project';

  @override
  String get pmEditProject => 'Edit project';

  @override
  String get pmNewTask => 'New task';

  @override
  String get pmEditTask => 'Edit task';

  @override
  String get pmTitle => 'Title';

  @override
  String get pmLeader => 'Project leader';

  @override
  String get pmResponsible => 'Responsible';

  @override
  String get pmStartDate => 'Start date';

  @override
  String get pmDeadline => 'Deadline';

  @override
  String get pmProjectDeadline => 'Project deadline';

  @override
  String get pmTaskDeadline => 'Task deadline';

  @override
  String get pmNoDeadline => 'No deadline';

  @override
  String get pmPriority => 'Priority';

  @override
  String get pmProgress => 'Progress';

  @override
  String get pmProgressMode => 'Progress is calculated';

  @override
  String get pmProgressTasks => 'From completed tasks';

  @override
  String get pmProgressWeighted => 'By task weight';

  @override
  String get pmProgressManual => 'Manually';

  @override
  String get pmWeight => 'Weight';

  @override
  String get pmNotes => 'Notes';

  @override
  String get pmAllowLateTasks =>
      'Allow tasks that end after the project deadline';

  @override
  String get pmAfterProjectDeadline =>
      'Allow ending after the project deadline (needs authorization)';

  @override
  String pmTimeLeft(String time) {
    return '$time left';
  }

  @override
  String pmOverdueBy(String time) {
    return 'Overdue by $time';
  }

  @override
  String pmDays(String n) {
    return '$n d';
  }

  @override
  String pmHours(String n) {
    return '$n h';
  }

  @override
  String pmMinutes(String n) {
    return '$n min';
  }

  @override
  String get pmOverdue => 'Overdue';

  @override
  String get pmPrLow => 'Low';

  @override
  String get pmPrMedium => 'Medium';

  @override
  String get pmPrHigh => 'High';

  @override
  String get pmPrUrgent => 'Urgent';

  @override
  String get pmStPlanning => 'Planning';

  @override
  String get pmStNotStarted => 'Not started';

  @override
  String get pmStInProgress => 'In progress';

  @override
  String get pmStOnHold => 'On hold';

  @override
  String get pmStCompleted => 'Completed';

  @override
  String get pmStCancelled => 'Cancelled';

  @override
  String get pmStPending => 'Pending';

  @override
  String get pmStBlocked => 'Blocked';

  @override
  String get pmReasonApproval => 'Waiting for approval';

  @override
  String get pmReasonMaterials => 'Waiting for materials';

  @override
  String get pmReasonFinance => 'Waiting for Finance';

  @override
  String get pmReasonAnotherTask => 'Waiting for another task';

  @override
  String get pmReasonAnotherDepartment => 'Waiting for another department';

  @override
  String get pmReasonPaused => 'Temporarily paused';

  @override
  String get pmReasonOther => 'Other';

  @override
  String get pmChangeStatus => 'Change status';

  @override
  String get pmPendingWhy => 'What is it waiting for?';

  @override
  String get pmBlockedWhy => 'What is blocking it?';

  @override
  String get pmCompletionNote => 'Completion note (optional)';

  @override
  String get pmReason => 'Reason';

  @override
  String get pmMarkCompleted => 'Completed';

  @override
  String get pmAskStatus => 'Ask for status in the chat';

  @override
  String get pmAskedStatus =>
      'A status request was posted in the department chat';

  @override
  String get pmAssign => 'Assign people';

  @override
  String get pmReassignReason => 'Reason for the change (optional)';

  @override
  String pmCompletedBy(String name, String time) {
    return 'Completed by $name · $time';
  }

  @override
  String get pmProgram => 'Related program';

  @override
  String get pmNoProgram => 'No program';

  @override
  String get pmRelatedIssue => 'Related issue';

  @override
  String get pmComments => 'Comments';

  @override
  String get pmAddComment => 'Write a comment';

  @override
  String get pmReportIssue => 'Report a problem';

  @override
  String get pmIssueTitle => 'What is the problem?';

  @override
  String get pmAssignee => 'Assigned to';

  @override
  String get pmResolution => 'Resolution';

  @override
  String get pmReporter => 'Reported by';

  @override
  String get pmIsOpen => 'Open';

  @override
  String get pmIsUnderReview => 'Under review';

  @override
  String get pmIsAssigned => 'Assigned';

  @override
  String get pmIsResolved => 'Resolved';

  @override
  String get pmIsClosed => 'Closed';

  @override
  String get pmSuggest => 'Suggest an improvement';

  @override
  String get pmSuggestionTitle => 'Your suggestion';

  @override
  String get pmSgSubmitted => 'Submitted';

  @override
  String get pmSgAccepted => 'Accepted';

  @override
  String get pmSgRejected => 'Rejected';

  @override
  String get pmSgConverted => 'Made into a task';

  @override
  String get pmAccept => 'Accept';

  @override
  String get pmReject => 'Reject';

  @override
  String get pmReview => 'Review';

  @override
  String get pmConvertToTask => 'Make it a task';

  @override
  String get pmChooseProject => 'Choose a project';

  @override
  String get pmBudgetProposed => 'Proposed budget';

  @override
  String get pmBudgetApproved => 'Approved budget';

  @override
  String get pmBudgetSpent => 'Spent';

  @override
  String get pmBudgetRemaining => 'Remaining';

  @override
  String pmBudgetUsed(String percent) {
    return '$percent% used';
  }

  @override
  String get pmBudgetPending => 'Pending expenses';

  @override
  String get pmBudgetNotApproved => 'The budget is not approved yet';

  @override
  String get pmBudgetOver => 'Over budget';

  @override
  String get pmBudgetLines => 'Budget categories';

  @override
  String get pmEditBudget => 'Set the budget';

  @override
  String get pmApproveBudget => 'Approve the budget';

  @override
  String get pmAmount => 'Amount';

  @override
  String get pmCategory => 'Category';

  @override
  String get pmDescription => 'Description';

  @override
  String get pmExpenseDate => 'Expense date';

  @override
  String get pmPaidBy => 'Paid by';

  @override
  String get pmReceipt => 'Receipt';

  @override
  String get pmAttachReceipt => 'Attach a receipt';

  @override
  String get pmNewExpense => 'New expense';

  @override
  String get pmExApproved => 'Approved';

  @override
  String get pmExRecorded => 'Recorded';

  @override
  String get pmApprove => 'Approve';

  @override
  String get pmRecord => 'Record';

  @override
  String get pmOverride => 'Approve over the budget (a reason is required)';

  @override
  String get pmRequestAdjustment => 'Request more budget';

  @override
  String get pmAdjustments => 'Budget adjustments';

  @override
  String get pmAdditional => 'Additional amount';

  @override
  String get pmUploadFile => 'Upload a file';

  @override
  String get pmMembers => 'Members';

  @override
  String get pmEditTeam => 'Edit the team';

  @override
  String get pmRoleLeader => 'Leader';

  @override
  String get pmRoleAdmin => 'Admin';

  @override
  String get pmRoleMember => 'Member';

  @override
  String get pmDeleteProjectConfirm => 'Delete this project?';

  @override
  String get pmDeleteTaskConfirm => 'Delete this task?';

  @override
  String get pmOfflineQueued =>
      'Saved offline — it will be sent when you are back online';

  @override
  String get pmWaitingSync => 'Waiting to sync';

  @override
  String get pmSyncConflict =>
      'Someone else changed this task, so your offline change was not applied. Please check it again.';

  @override
  String get syncWhatTask => 'a task change';

  @override
  String get pmFilters => 'Filters';

  @override
  String get pmFilterUser => 'User';

  @override
  String get pmFilterProject => 'Project';

  @override
  String get pmFilterTask => 'Task';

  @override
  String get pmFilterDate => 'Date';

  @override
  String get pmFilterBudget => 'Budget';

  @override
  String get pmFilterCompletion => 'Completion';

  @override
  String get pmApply => 'Apply';

  @override
  String get pmClearFilters => 'Clear filters';

  @override
  String get pmAll => 'All';

  @override
  String get pmActive => 'Active';

  @override
  String get pmToday => 'Today';

  @override
  String get pmThisWeek => 'This week';

  @override
  String get pmThisMonth => 'This month';

  @override
  String get pmCustomRange => 'Custom range';

  @override
  String get pmDateField => 'Date of';

  @override
  String get pmByDeadline => 'Deadline';

  @override
  String get pmByCreated => 'Created';

  @override
  String get pmByStart => 'Start';

  @override
  String get pmByCompleted => 'Completed';

  @override
  String get pmWithinBudget => 'Within budget';

  @override
  String get pmNoBudget => 'No budget';

  @override
  String pmMinProgress(String n) {
    return 'At least $n%';
  }

  @override
  String get pmSummary => 'Summary';

  @override
  String get pmByUser => 'By person';

  @override
  String get pmProjectsInvolved => 'Projects';

  @override
  String get pmAssigned => 'Assigned';

  @override
  String get pmTotal => 'Total';

  @override
  String get pmCreatedBy => 'Created by';

  @override
  String get pmLiveUpdated => 'Updated';

  @override
  String get pmTaskBot => '🤖 Task Bot';

  @override
  String get pmBotNotAllowed =>
      '🔒 You are not authorized to update this task.';

  @override
  String get pmBotUpdated => '✅ Task updated';

  @override
  String get pmOpenTask => 'Open the task';

  @override
  String get pmPeople => 'People';

  @override
  String get pmSelectPeople => 'Select people';

  @override
  String get pmDepartment => 'Department';

  @override
  String get errTaskUpdateForbidden =>
      '🔒 You are not authorized to update this task.';

  @override
  String get errProjectForbidden => 'You are not allowed to do this.';

  @override
  String get errTaskAfterProjectDeadline =>
      'A task cannot end after the project deadline.';

  @override
  String get errPendingReasonRequired => 'Say what it is waiting for.';

  @override
  String get errBlockerRequired => 'Say what is blocking it.';

  @override
  String get errUserNotInDepartment => 'This person is not in the department.';

  @override
  String get errOverBudget =>
      'This expense goes over the approved budget. Approve a budget increase, or override with a reason.';

  @override
  String get errTaskChanged =>
      'Someone else changed the task. Please try again.';

  @override
  String get errResolutionRequired => 'Write the resolution.';

  @override
  String get errProjectClosed => 'This project is closed.';

  @override
  String get errExpenseApproveForbidden => 'Only Finance approves expenses.';

  @override
  String get perm_projects_view => 'View department projects';

  @override
  String get perm_projects_manage => 'Manage projects, tasks and teams';

  @override
  String get perm_projects_expenses_approve =>
      'Approve project budgets and expenses (Finance)';

  @override
  String get perm_projects_reports => 'View project reports';

  @override
  String get perm_projects_all_departments => 'Projects of every department';

  @override
  String get libTitle => 'Library';

  @override
  String get libDigital => 'Digital books';

  @override
  String get libPhysical => 'Books to borrow';

  @override
  String get libMine => 'Mine';

  @override
  String get libNoBooks => 'No books';

  @override
  String get libDownload => 'Download';

  @override
  String get libOpen => 'Open';

  @override
  String get libDownloaded => 'Downloaded';

  @override
  String get libDeleteDownload => 'Remove the download';

  @override
  String get libRequest => 'Request';

  @override
  String get libRequestTitle => 'Request this book';

  @override
  String get libRequestNote => 'Note (optional)';

  @override
  String get libNeededOn => 'Needed on (optional)';

  @override
  String get libRequested => 'Requested';

  @override
  String get libReqApproved => 'Ready — come and sign for it';

  @override
  String get libReqRejected => 'Not accepted';

  @override
  String get libReqIssued => 'Handed over';

  @override
  String get libReqCancelled => 'Cancelled';

  @override
  String libAvailable(String count) {
    return '$count available';
  }

  @override
  String get libNoneAvailable => 'None available now';

  @override
  String get libMyRequests => 'My requests';

  @override
  String get libNoRequests => 'No requests';

  @override
  String get libCancelRequest => 'Cancel the request';

  @override
  String get libRequestSent => 'Your request was sent';

  @override
  String get libAuthor => 'Author';

  @override
  String libDownloads(String count) {
    return '$count downloads';
  }

  @override
  String get libRequests => 'Book requests';

  @override
  String get libApprove => 'Approve';

  @override
  String get libReject => 'Reject';

  @override
  String get libHandOver => 'Hand over with signature';

  @override
  String get libLoanDays => 'Loan days';

  @override
  String get libBookKind => 'Book type';

  @override
  String get libKindPhysical => 'Printed';

  @override
  String get libKindDigital => 'Digital (PDF)';

  @override
  String get libUploadPdf => 'Upload PDF';

  @override
  String get libReplacePdf => 'Replace PDF';

  @override
  String get libPdfUploaded => 'PDF uploaded';

  @override
  String get libSaveFirst => 'Save first';

  @override
  String get libBooks => 'Books';

  @override
  String get errBookIsDigital => 'Digital books are downloaded, not borrowed.';

  @override
  String get errRequestExists => 'You already asked for this book.';

  @override
  String get errRequestClosed => 'This request is already closed.';

  @override
  String get regTitle => 'Student registration';

  @override
  String get regSubtitle => 'Register members with their courses';

  @override
  String get regChooseClass => 'Choose a class (courses)';

  @override
  String get regCourses => 'Courses';

  @override
  String get regExisting => 'Register existing members';

  @override
  String get regNewMember => 'Register a new member';

  @override
  String get regStudents => 'Registered students';

  @override
  String regDone(String count) {
    return '$count registered';
  }

  @override
  String regAlready(String count) {
    return '$count were already registered';
  }

  @override
  String get regTempPin => 'Temporary PIN';

  @override
  String get regTempPinHint =>
      'Give it to the member. They change it at their first sign-in.';

  @override
  String get regRemoveConfirm => 'Remove this student from the class?';

  @override
  String get regNoClasses => 'No active classes';

  @override
  String get courseManagement => 'Course management';

  @override
  String get eduSection => 'Education';

  @override
  String get adminGroupPeople => 'People & permissions';

  @override
  String get adminGroupContent => 'Mezmur & content';

  @override
  String get adminGroupPrograms => 'Programs & attendance';

  @override
  String get adminGroupEducation => 'Education';

  @override
  String get adminGroupLibrary => 'Library & property';

  @override
  String get adminGroupDepartments => 'Departments, projects & payments';

  @override
  String get adminGroupChoir => 'Choir services';

  @override
  String get adminGroupOversight => 'Oversight';

  @override
  String get adminGroupSystem => 'System';

  @override
  String get perm_education_register => 'Register students with their courses';

  @override
  String get libHomeSub =>
      'Download digital books, request printed ones, see what you borrowed';

  @override
  String get libRead => 'Read';

  @override
  String get libDownloadAgain =>
      'This book is no longer on this device. Please download it again.';

  @override
  String paymentsYearFull(String year) {
    return '$year Ethiopian Year\nPaid: 12 months\nUnpaid: 0 months\n✓ All months paid';
  }

  @override
  String paymentsYearPartial(String year, String paid, String unpaid) {
    return '$year Ethiopian Year\nPaid: $paid months\nUnpaid: $unpaid months';
  }

  @override
  String paymentsYearPaidList(String months) {
    return 'Months paid: $months';
  }

  @override
  String paymentsYearNone(String year) {
    return '$year Ethiopian Year\nPaid: 0 months\nUnpaid: 12 months';
  }

  @override
  String get promoteToAdmin => 'Promote to administrator';

  @override
  String get promoteChooseRole => 'Choose a role';

  @override
  String promoteHint(String name) {
    return '$name becomes an administrator and keeps every member feature. They sign in again and set their PIN.';
  }

  @override
  String get promoted => 'Promoted to administrator';

  @override
  String get demoteToMember => 'Return to member';

  @override
  String demoteConfirm(String name) {
    return 'Remove $name\'s administrator role and return them to a member?';
  }

  @override
  String get demoted => 'Returned to member';

  @override
  String get errAlreadyAdmin => 'This person is already an administrator.';

  @override
  String get adminBadge => 'Administrator';

  @override
  String get requestProfileChange => 'Request a change';

  @override
  String get requestProfileChangeHint =>
      'Edit what you want to change. Only the changed details are sent to an administrator for approval; your previous details are kept.';

  @override
  String get changeNote => 'Message to the administrator (optional)';

  @override
  String get sendForApproval => 'Send for approval';

  @override
  String get changeRequestSent => 'Your request was sent';

  @override
  String get myChangeRequests => 'My change requests';

  @override
  String get changeHistory => 'Change history';

  @override
  String get noChangeHistory => 'No changes recorded';

  @override
  String get historyByRequest => 'Member\'s request (approved)';

  @override
  String get historyByAdmin => 'By an administrator';

  @override
  String get historyBySelf => 'By themselves';

  @override
  String get declineReason => 'Reason for declining (the member sees it)';

  @override
  String get approveNote => 'Note (optional)';

  @override
  String get errNoChanges => 'Nothing was changed.';

  @override
  String get playerOptions => 'Options';

  @override
  String get playbackSpeed => 'Playback speed';

  @override
  String get sleepTimer => 'Sleep timer';

  @override
  String get off => 'Off';

  @override
  String get sleepEndOfMezmur => 'End of this Mezmur';

  @override
  String get upNext => 'Up next';

  @override
  String get syncedLyrics => 'Synced lyrics (.lrc)';

  @override
  String get syncedLyricsHint =>
      'The lyrics light up with the recording. Upload or paste a .lrc file, or make one here in the app (no other app needed).';

  @override
  String get lrcUpload => 'Upload .lrc file';

  @override
  String get lrcMake => 'Make in the app';

  @override
  String get lrcNeedsAudio =>
      'Upload the recording first to make synced lyrics in the app.';

  @override
  String get lrcInvalid =>
      'Not a valid .lrc (time tags like [00:12.50] are needed)';

  @override
  String lrcLoaded(String count) {
    return '$count lines loaded — tap Save to keep them';
  }

  @override
  String lrcLines(String count) {
    return '$count timed lines';
  }

  @override
  String get lrcMaker => 'Synced lyrics maker';

  @override
  String get lrcMakerHint =>
      'While the recording plays, tap \"Next line\" the moment each line starts. Tap Undo to fix a mistake.';

  @override
  String get lrcNoLyrics => 'Write the lyrics first.';

  @override
  String get lrcNextLine => 'Next line';

  @override
  String get lrcAllTimed => 'All lines timed';

  @override
  String get lrcUndo => 'Undo';

  @override
  String get lrcRestart => 'Start over';

  @override
  String get lrcRestartConfirm => 'Clear the times made so far and start over?';

  @override
  String get lrcBack5 => 'Back 5 seconds';

  @override
  String lrcProgress(String done, String total) {
    return '$done / $total lines';
  }

  @override
  String get adminGroupUsers => 'User management';

  @override
  String get adminGroupMemberServices => 'Member & Activity Management';

  @override
  String get adminGroupDepartmentsMgmt => 'Department management';

  @override
  String get adminGroupProperties => 'Properties';

  @override
  String get adminGroupEducationMgmt => 'Education management';

  @override
  String get adminGroupMezmurMgmt => 'Mezmur management';

  @override
  String get adminGroupPromotion => 'Promotion management';

  @override
  String get adminGroupAdministration => 'Administration management';

  @override
  String get eduManageCourses => 'Manage courses';

  @override
  String get eduManageClasses => 'Manage classes';

  @override
  String get eduManageLibrary => 'Manage library';

  @override
  String get serviceManagement => 'Service management';

  @override
  String get eduAllCourses => 'All courses';

  @override
  String get importMezmursHelp2 =>
      'One Mezmur per row: title, category, lyrics (many lines in one cell — Alt+Enter), tags, status. The Excel template has examples and the list of existing categories.';

  @override
  String get importUsersHelp2 =>
      'One member per row: full name, phone, email, PIN (4 to 6 digits; empty = temporary), member group, student/worker, gender. The allowed values are listed in the template.';

  @override
  String get importStepTemplate => 'Get the template';

  @override
  String get importStepRows => 'Add your rows';

  @override
  String get importStepCheck => 'Check — nothing is saved yet';

  @override
  String get importStepDone => 'Imported';

  @override
  String get importExcelTemplate => 'Excel template (.xlsx)';

  @override
  String get importTextTemplate => 'Text template';

  @override
  String get importUploadFile => 'Upload a file (.xlsx, .csv, .txt)';

  @override
  String get importPaste => 'Paste from Excel / Google Sheets';

  @override
  String get importPasteHint =>
      'Copy the rows (with the heading row) and paste them here';

  @override
  String get importPasted => 'Pasted rows';

  @override
  String get importTypeRows => 'Type them in the app';

  @override
  String importTyped(String count) {
    return '$count Mezmurs typed in the app';
  }

  @override
  String get importCheckRows => 'Check';

  @override
  String get importAddRow => 'Add another Mezmur';

  @override
  String get filters => 'Filters';

  @override
  String get fClearAll => 'Clear all';

  @override
  String get fPersonal => 'Personal details';

  @override
  String get fMembership => 'Membership';

  @override
  String get fAccount => 'Account';

  @override
  String get fActivity => 'Activity & groups';

  @override
  String get fAge => 'Age';

  @override
  String get fAccountType => 'Account type';

  @override
  String get fMembersOnly => 'Members only';

  @override
  String get fHasDevice => 'Has a device';

  @override
  String get fNoDevice => 'No device';

  @override
  String get fNoTelegram => 'Telegram not linked';

  @override
  String get fDepartment => 'Department';

  @override
  String get fLastActive => 'Last active';

  @override
  String fActiveWithin(String days) {
    return 'Within $days days';
  }

  @override
  String get fShowAll => 'Show all';

  @override
  String fApply(String count) {
    return 'Apply ($count)';
  }

  @override
  String get selAttendancePoints => 'Attendance points';

  @override
  String get selAttendancePointsHint =>
      'How many points each program attendance earns (% of a full attendance). Used for the Mezmur attendance and the bonus.';

  @override
  String get selExcusedPolicyHint => 'Empty = the permission policy\'s weight';

  @override
  String get selProgramWeights => 'Program weights';

  @override
  String get selProgramWeightsHint =>
      'Count a program more (×2) or less (×0.5) than the others; ×0 = not counted';

  @override
  String get errLateAbovePresent =>
      'Late points cannot be above present points.';

  @override
  String get mgTitle => 'Member types';

  @override
  String get mgHint =>
      'Programs, attendance, member IDs and filters use these types. Built-in types cannot be deleted or switched off; a new type can be deleted while nobody uses it, otherwise switch it off.';

  @override
  String get mgAdd => 'New member type';

  @override
  String get mgEdit => 'Member type';

  @override
  String get mgName => 'Name (Amharic)';

  @override
  String get mgNameEn => 'Name (English)';

  @override
  String get mgActive => 'Active (offered for new choices)';

  @override
  String get mgBuiltIn => 'Built-in';

  @override
  String get mgInactive => 'Switched off';

  @override
  String mgMembers(String count) {
    return '$count members';
  }

  @override
  String get mgDeleteConfirm => 'Delete this member type?';

  @override
  String get errMemberGroupInUse =>
      'Members or programs use this type; switch it off instead of deleting it.';

  @override
  String get errMemberGroupBuiltIn =>
      'A built-in member type cannot be deleted or switched off.';

  @override
  String get errInvalidMemberGroup => 'Unknown member type.';

  @override
  String get attVerifyTitle => 'Verify the member';

  @override
  String get attVerifyHint =>
      'Compare the photo with the person; record only if it is them.';

  @override
  String get attRecord => 'Record attendance';

  @override
  String get attScanNext => 'Scan next';

  @override
  String get attEligible => 'Can be recorded for this program';

  @override
  String attWillBe(String status) {
    return 'Will be recorded as: $status';
  }

  @override
  String get attAlreadyRecorded =>
      'Attendance already recorded for this program.';

  @override
  String attRecordedBy(String name, String time) {
    return 'Recorded by $name · $time';
  }

  @override
  String get attMethodQr => 'By QR';

  @override
  String get attMethodManual => 'Manually';

  @override
  String get attFindMember => 'Find a member (no phone)';

  @override
  String get attTakers => 'Attendance takers';

  @override
  String get attTakersHint =>
      'Empty = every attendance taker may record this program.';

  @override
  String get attTakersAll => 'Every attendance taker';

  @override
  String get errNotProgramTaker =>
      'You are not an attendance taker of this program.';

  @override
  String get errNotAttendanceTaker =>
      'The person chosen has no attendance-taking permission.';

  @override
  String get errAttendanceNotRequired =>
      'This program does not take attendance.';

  @override
  String get errProgramCancelled => 'The program is cancelled.';

  @override
  String get errMemberNotInGroup =>
      'This member is not of the program\'s member types (and is never counted absent here).';

  @override
  String get ctaOpenClass => 'Open a class';

  @override
  String get ctaOpenCourse => 'Open a course';

  @override
  String get ctaOpenAssignment => 'Open an assignment';

  @override
  String get ctaOpenPage => 'Open another page';

  @override
  String get ctaOpenLibrary => 'Open the education library';

  @override
  String get ctaOpenUrl => 'Open a web link';

  @override
  String get ctaUrl => 'Web address (https://…)';

  @override
  String get ctaNothingChosen => 'Nothing chosen yet';

  @override
  String get errInvalidUrl => 'The address must start with https://.';

  @override
  String get lrcRepeat => 'Repeat';

  @override
  String get lrcRepeatHint =>
      'When the singers repeat a line, tap that line above (or \"Repeat\"): the display goes back to it instead of listing it again. Up to 3 times per line.';

  @override
  String get lrcRepeatPick => 'Choose the line being repeated';

  @override
  String get lrcRepeatLimit => 'A line can be sung at most 3 times.';

  @override
  String get bioLock => 'Lock with fingerprint';

  @override
  String get bioLockHint =>
      'When the app opens, the phone\'s fingerprint (or its screen lock) is asked. The fingerprint stays on the phone; it is never sent to the server.';

  @override
  String get bioUnlock => 'Unlock';

  @override
  String get bioReason => 'Use your fingerprint to unlock the app';

  @override
  String get bioUnavailable =>
      'This phone has no fingerprint or screen lock set up.';

  @override
  String get bioLocked => 'The app is locked';

  @override
  String get errAttendanceTooLate =>
      'The late period is over; submit a correction request instead.';

  @override
  String get adminFromMemberHint =>
      'An administrator is an existing member: no new account is created. The member keeps their account, ID and history and sets their PIN at their next sign-in.';

  @override
  String get adminPickMember => 'Choose a member';

  @override
  String get errAdminFromMemberOnly =>
      'Choose an existing member to make an administrator.';

  @override
  String get errUserNotActive =>
      'Only an active member can become an administrator.';

  @override
  String get errMemberNotFound =>
      'Member not found. If you are offline, connect once so this phone can update its member list.';

  @override
  String get attOfflineChecked =>
      'Checked offline; the server confirms when the phone syncs (on time / late is decided there).';

  @override
  String get attNoMembersFound => 'No member found';

  @override
  String get alarmSnooze => 'Snooze 10 min';

  @override
  String get alarmDismiss => 'Dismiss';

  @override
  String get sessTitle => 'Sign-in sessions';

  @override
  String get sessHint =>
      'Where your account is signed in. Removing one signs that session out; the account itself is never deleted.';

  @override
  String get sessCurrent => 'This phone';

  @override
  String get sessRevoke => 'Sign out';

  @override
  String get sessRevokeOthers => 'Sign out all other sessions';

  @override
  String get sessRevokeAll => 'Sign out everywhere (this phone too)';

  @override
  String get sessRevokeAllConfirm =>
      'Sign out of every session? You will need to sign in again.';

  @override
  String sessSignedIn(String when) {
    return 'Signed in: $when';
  }

  @override
  String sessLastActive(String when) {
    return 'Last active: $when';
  }

  @override
  String sessRevokedCount(String n) {
    return '$n sessions signed out';
  }

  @override
  String get errMezmurTitleTaken =>
      'Another Mezmur already has this title; choose a different one.';

  @override
  String get errSessionNotFound => 'Session not found.';

  @override
  String get adminGroupProjects => 'Project & Task Management';

  @override
  String get adminGroupReports => 'Reports & Audit';

  @override
  String eduCourseProgress(String p) {
    return 'Course progress: $p %';
  }

  @override
  String get eduCourseCompletedHint =>
      'At 100 % the course is complete: no more attendance is expected after that.';

  @override
  String get eduFrequency => 'Frequency';

  @override
  String get eduWeekly => 'Every week';

  @override
  String get eduMonthly => 'Once a month';

  @override
  String get eduWeekOfMonth => 'Week of the month';

  @override
  String get eduWeek1 => '1st';

  @override
  String get eduWeek2 => '2nd';

  @override
  String get eduWeek3 => '3rd';

  @override
  String get eduWeek4 => '4th';

  @override
  String get eduWeekLast => 'Last';

  @override
  String eduMonthlyDay(String week, String day) {
    return '$week $day of the month';
  }

  @override
  String get eduSessionFor => 'For';

  @override
  String get eduMode => 'Mode';

  @override
  String get eduInPerson => 'In person';

  @override
  String get eduOnline => 'Online';

  @override
  String get export => 'Export';

  @override
  String get exportPdf => 'PDF (print)';

  @override
  String get exportExcel => 'Excel (XLSX)';

  @override
  String get exportCsv => 'CSV (data)';

  @override
  String get exportReady => 'File ready';

  @override
  String get itemHistory => 'Item history';

  @override
  String get issueCondition => 'Condition when issued';

  @override
  String get openWith => 'Open with / Share';

  @override
  String get previewUnavailable => 'This file cannot be previewed in the app.';

  @override
  String get fileTypeUnknown => 'Unknown type';

  @override
  String get recentActivityAndNotifications =>
      'Recent activity & notifications';

  @override
  String get resendNotification => 'Resend';

  @override
  String get alsoByEmail => 'Also send by email';

  @override
  String get alsoByEmailHint =>
      'To members with a registered email who allow it';

  @override
  String get resendNote =>
      'Resending creates a new notification; the original and its history stay unchanged.';

  @override
  String get notificationDetails => 'Notification details';

  @override
  String get channelPush => 'Push';

  @override
  String get channelEmail => 'Email';

  @override
  String resentFrom(String id) {
    return 'Resent from #$id';
  }

  @override
  String get sentAt => 'Sent';

  @override
  String get readCount => 'Read';

  @override
  String get resends => 'Resends';

  @override
  String readAt(String time) {
    return 'Read $time';
  }

  @override
  String get deliverySent => 'Delivered';

  @override
  String get deliveryFailed => 'Failed';

  @override
  String get deliverySkipped => 'Not sent';

  @override
  String get deliveryPending => 'Pending';

  @override
  String get deliveryNone => '—';

  @override
  String get notificationHealth => 'Notification delivery';

  @override
  String get providers => 'Services';

  @override
  String get fcmReady => 'Push (Firebase)';

  @override
  String get emailConfigured => 'Email (SMTP)';

  @override
  String get backgroundJobs => 'Background jobs';

  @override
  String get registeredDevices => 'Registered devices';

  @override
  String get oldestPending => 'Oldest pending';

  @override
  String get scheduledReminders => 'Scheduled reminders';

  @override
  String get notificationSettings => 'Notifications';

  @override
  String get notificationSettingsHint =>
      'Choose which notifications reach you, by topic. Every notification stays in the app\'s notification list; administrative messages always arrive.';

  @override
  String get notificationsAll => 'Allow notifications';

  @override
  String get noEmailForNotifications =>
      'No email address registered — add one to your profile to receive emails.';

  @override
  String get alwaysOn => 'Always on';

  @override
  String get topicProgram => 'Programs';

  @override
  String get topicAttendance => 'Attendance';

  @override
  String get topicProject => 'Projects';

  @override
  String get topicDepartment => 'Department (chat)';

  @override
  String get topicEducation => 'Education';

  @override
  String get topicProperty => 'Property';

  @override
  String get topicMezmur => 'Mezmur';

  @override
  String get topicSystem => 'System / Admin';

  @override
  String get pmActivityDetail => 'Activity details';

  @override
  String get pmViaBot => 'Via the Task Bot';

  @override
  String get pmActor => 'Done by';

  @override
  String get pmActName => 'Name';

  @override
  String get pmActLeaderRole => 'leader';

  @override
  String get pmActMemberRole => 'member';

  @override
  String get pmActDeptAdmin => 'Department admin';

  @override
  String get pmActProgram => 'Program';

  @override
  String get pmProject => 'Project';

  @override
  String get pmTask => 'Task';

  @override
  String get pmAssignees => 'Responsible';

  @override
  String get pmProblem => 'Problem';

  @override
  String get pmSolution => 'Solution';

  @override
  String get pmChanges => 'Changes';

  @override
  String get pmAdded => 'Added';

  @override
  String get pmRemoved => 'Removed';

  @override
  String get pmRelatedPeople => 'Related people';

  @override
  String get pmNotificationsSent => 'Notifications sent';

  @override
  String get pmBotMessages => 'Bot messages';

  @override
  String get pickGallery => 'Photo (gallery)';

  @override
  String get pickCamera => 'Camera';

  @override
  String get pickVideo => 'Video';

  @override
  String get pickRecordVideo => 'Record video';

  @override
  String get pickAudio => 'Audio';

  @override
  String get pickDocument => 'Document (PDF, Word, Excel…)';

  @override
  String get pickAnyFile => 'Other file';

  @override
  String get itemCodeAuto =>
      'Leave empty to generate it from the department and category';

  @override
  String get permissionCancelExcuse => 'Cancel excuse';

  @override
  String get permissionCancelExcuseHint =>
      'Cancels a permission approved by mistake. The \'excused\' attendance it created is removed and the member is notified.';

  @override
  String get permissionCancelled => 'Cancelled';

  @override
  String permissionCancelledBy(String name, String reason) {
    return 'Cancelled by $name: $reason';
  }

  @override
  String get wedManualSelectionHint =>
      'Participants are chosen by hand; there is no attendance or exam requirement.';

  @override
  String wedReviewTitle(String n) {
    return 'Confirm selecting $n members';
  }

  @override
  String get wedHideChosen => 'Not yet chosen';

  @override
  String get remindEvery15Days => 'Remind every 15 days';

  @override
  String get remindEvery15DaysHint =>
      'Participants get a reminder every 15 days until the program ends; it stops when the program is cancelled or completed.';

  @override
  String get remindEvery15DaysFrom =>
      'Starting on (empty = program start or today)';

  @override
  String get programTypeReminders =>
      'Default reminders for programs of this type';

  @override
  String get itemCategoriesConfig => 'Item categories';

  @override
  String get itemCategoryNew => 'New category';

  @override
  String get itemCategoryEdit => 'Edit category';

  @override
  String get itemCategoryNameAm => 'Name (Amharic)';

  @override
  String get itemCategoryNameEn => 'Name (English)';

  @override
  String get itemCategoryCode => 'Code prefix (e.g. EQ)';

  @override
  String get itemCategoryKey => 'Key';

  @override
  String get itemCategoryKeyHint =>
      'Latin letters, e.g. equipment — cannot be changed later';

  @override
  String get itemCategoryDeleteConfirm => 'Delete category?';

  @override
  String get itemRetired => 'Retired';

  @override
  String get eaAcademicYear => 'Academic year';

  @override
  String get eaAddInfoHint => 'Add information…';

  @override
  String get eaAdminComment => 'Administrator comment';

  @override
  String get eaAmend => 'Amend mark';

  @override
  String get eaAmendReason => 'Reason for the correction (required)';

  @override
  String get eaApproveAndPublish => 'Approve and publish';

  @override
  String get eaApproveConfirm => 'Approve the submitted marks?';

  @override
  String get eaApprovePublishConfirm =>
      'Approve the submitted marks and publish them to the students?';

  @override
  String get eaApproveRequestHint =>
      'Approving applies the change to the enrollment at once.';

  @override
  String get eaArchived => 'Archived';

  @override
  String get eaAssignedBy => 'Assigned by';

  @override
  String get eaAssignTeacher => 'Assign teacher';

  @override
  String get eaAssignToMe => 'Assign to me';

  @override
  String get eaAttachEvidence => 'Attach evidence (optional)';

  @override
  String get eaBy => 'by';

  @override
  String get eaCancelRequestConfirm => 'Cancel this request?';

  @override
  String get eaCatCourseAdmin => 'Course administration';

  @override
  String get eaCategory => 'Category';

  @override
  String get eaCatEnrollment => 'Enrollment';

  @override
  String get eaCatMarks => 'Marks';

  @override
  String get eaCatOther => 'Other';

  @override
  String get eaCatPlacement => 'Class or stream placement';

  @override
  String get eaCatStudyMode => 'Study mode';

  @override
  String get eaCatTeacher => 'Teacher';

  @override
  String get eaChangeTeacherStatus => 'Change teacher status';

  @override
  String get eaClassAll => 'Class';

  @override
  String get eaComplaint => 'Complaint';

  @override
  String get eaComplaintConfidential =>
      'Your complaint is confidential: only you and the education reviewers see it.';

  @override
  String get eaComplaintDescription => 'Description';

  @override
  String get eaComplaintSubject => 'Subject';

  @override
  String get eaComplaints => 'Complaints';

  @override
  String get eaComplaintSent => 'Complaint submitted';

  @override
  String get eaComplaintTooShort =>
      'Please write a subject and a description of at least 10 characters.';

  @override
  String get eaCsAwaitingInfo => 'Awaiting information';

  @override
  String get eaCsEscalated => 'Escalated';

  @override
  String get eaCsResolved => 'Resolved';

  @override
  String get eaCsSubmitted => 'Submitted';

  @override
  String get eaCsUnderReview => 'Under review';

  @override
  String get eaEnrollmentStatus => 'Enrollment status';

  @override
  String get eaEnteredBy => 'Entered by';

  @override
  String get eaHistory => 'History';

  @override
  String get eaImplemented => 'Implemented';

  @override
  String get eaInternalNote => 'Internal note';

  @override
  String get eaJClassChanged => 'Class changed';

  @override
  String get eaJEnrolled => 'Enrolled';

  @override
  String get eaJMarkAmended => 'Mark amended';

  @override
  String get eaJMarkApproved => 'Mark approved';

  @override
  String get eaJMarkPublished => 'Mark published';

  @override
  String get eaJMarkRejected => 'Mark returned for correction';

  @override
  String get eaJMarkSubmitted => 'Mark submitted';

  @override
  String get eaJourney => 'Academic journey';

  @override
  String get eaJRequestDecided => 'Request decided';

  @override
  String get eaJStreamChanged => 'Stream changed';

  @override
  String get eaJStudyModeChanged => 'Study mode changed';

  @override
  String get eaJSubjectAdded => 'Subject added';

  @override
  String get eaJSubjectDropped => 'Subject dropped';

  @override
  String get eaJTeacherAssigned => 'Assigned as teacher';

  @override
  String get eaJTeacherReactivated => 'Teacher assignment reactivated';

  @override
  String get eaJTeacherRemoved => 'Teacher assignment removed';

  @override
  String get eaJTeacherSuspended => 'Teacher assignment suspended';

  @override
  String get eaJWithdrawn => 'Withdrawn';

  @override
  String get eaLayoutLong => 'Long (student × subject)';

  @override
  String get eaLayoutWide => 'Wide (subjects as columns)';

  @override
  String get eaMarkDraft => 'Draft';

  @override
  String get eaMarkEmpty => 'Not entered';

  @override
  String get eaMarkPublished => 'Published';

  @override
  String get eaMarkRejected => 'Returned';

  @override
  String get eaMarks => 'Marks';

  @override
  String get eaMarksExport => 'Marks export';

  @override
  String get eaMarkStatus => 'Mark status';

  @override
  String get eaMarkSubmitted => 'Submitted';

  @override
  String get eaMarksWorkflowHint =>
      'Marks: draft → submit → approve → publish. Students only see published marks.';

  @override
  String get eaMissingIsDash => 'A missing mark is shown as \"—\" (not 0).';

  @override
  String get eaMyClass => 'My class';

  @override
  String get eaNewComplaint => 'New complaint';

  @override
  String get eaNewRequest => 'New request';

  @override
  String get eaNoComplaints => 'No complaints';

  @override
  String get eaNoJourney => 'Nothing recorded yet';

  @override
  String get eaNoRequests => 'No requests';

  @override
  String get eaNoStreams => 'This class has no streams.';

  @override
  String get eaNothingToReview => 'Nothing to review';

  @override
  String get eaNotSpecific => 'Not specific';

  @override
  String get eaPublishConfirm => 'Publish the approved marks to the students?';

  @override
  String get eaReactivate => 'Reactivate';

  @override
  String get eaRejectReason => 'Reason for returning';

  @override
  String get eaRemove => 'Remove';

  @override
  String get eaReplyHint => 'Reply or note…';

  @override
  String get eaReqAddClass => 'Join a class';

  @override
  String get eaReqAddSubject => 'Add a subject';

  @override
  String get eaReqClassChange => 'Class change';

  @override
  String get eaReqDropClass => 'Leave a class';

  @override
  String get eaReqDropSubject => 'Drop a subject';

  @override
  String get eaReqOther => 'Other change';

  @override
  String get eaReqStreamChange => 'Stream change';

  @override
  String get eaReqStudyMode => 'Study mode change';

  @override
  String get eaRequestedChange => 'Requested change';

  @override
  String get eaRequests => 'Requests';

  @override
  String get eaRequestSent => 'Request submitted';

  @override
  String get eaRequestType => 'Request type';

  @override
  String get eaResultPending => 'Pending';

  @override
  String get eaReviewCenter => 'Education review center';

  @override
  String get eaReviewCenterSub =>
      'Approve marks, requests, complaints and exports';

  @override
  String get eaSelfService => 'Requests, complaints & journey';

  @override
  String get eaSelfServiceSub =>
      'Change class or stream, add or drop subjects, file a complaint';

  @override
  String get eaSemester => 'Semester';

  @override
  String get eaSend => 'Submit';

  @override
  String get eaStream => 'Stream';

  @override
  String get eaStreams => 'Streams';

  @override
  String get eaStreamsHint => 'Separated by commas';

  @override
  String get eaStudentIdOrName => 'Student ID or name';

  @override
  String get eaStudyMode => 'Study mode';

  @override
  String get eaSubject => 'Subject';

  @override
  String get eaSubjectCode => 'Subject code';

  @override
  String get eaSubjects => 'Subjects';

  @override
  String get eaSubmitMarks => 'Submit for review';

  @override
  String get eaSubmitMarksConfirm =>
      'Send the entered marks for review? They cannot be changed while in review.';

  @override
  String get eaSuspend => 'Suspend';

  @override
  String get eaTargetClass => 'Requested class';

  @override
  String get eaTeacherRemoved => 'Removed';

  @override
  String get eaTeachers => 'Teachers';

  @override
  String get eaTeacherSuspended => 'Suspended';

  @override
  String eaComplaintRef(String ref) {
    return 'Your complaint reference: $ref';
  }

  @override
  String eaMarksCount(int n) {
    return '$n marks';
  }

  @override
  String eaMarksSubmitted(int n, int empty) {
    return '$n marks submitted; $empty still empty.';
  }

  @override
  String eaPublishApproved(int n) {
    return 'Publish approved ($n)';
  }

  @override
  String eaResolvedIn(String hours) {
    return 'Resolved in $hours h';
  }

  @override
  String eaTeachersOf(String course) {
    return 'Teachers of $course';
  }

  @override
  String get scMezmurExport => 'Mezmur selection report';

  @override
  String get recurrenceTwiceMonthly => 'Twice a month (every 2 weeks)';

  @override
  String get twiceMonthlyRuleDay => 'On two dates (e.g. 1st and 15th)';

  @override
  String get twiceMonthlyRuleWeekday => 'On a weekday (1st & 3rd or 2nd & 4th)';

  @override
  String twiceMonthlyDays(String first, String second) {
    return 'Every month on day $first and day $second';
  }

  @override
  String twiceMonthlyNth13(String weekday) {
    return 'The 1st and 3rd $weekday of every month';
  }

  @override
  String twiceMonthlyNth24(String weekday) {
    return 'The 2nd and 4th $weekday of every month';
  }

  @override
  String get vWeightsTotal => 'The weights must add up to the part\'s share.';

  @override
  String get vMinimumAboveWeight => 'A minimum cannot be above its weight.';

  @override
  String get elTabLearn => 'Learn';

  @override
  String get elTabClasses => 'Classes';

  @override
  String get elTabProgress => 'Progress';

  @override
  String get elTabMore => 'More';

  @override
  String get elHomeSubtitle => 'Food for the soul, a source of knowledge';

  @override
  String get elFeaturedLabel => 'Featured lesson';

  @override
  String get elFeatured => 'Featured banner';

  @override
  String get elStart => 'Start';

  @override
  String get elContinue => 'Continue';

  @override
  String get elContinueLearning => 'Continue learning';

  @override
  String elPositionOf(String pos, String total) {
    return 'Lesson $pos of $total';
  }

  @override
  String elDoneOf(String done, String total) {
    return '$done of $total done';
  }

  @override
  String elPercentDone(int p) {
    return '$p% completed';
  }

  @override
  String get elSubjects => 'Subjects';

  @override
  String get elSeeAll => 'See all';

  @override
  String get elNoCategories => 'No subject categories have been set up yet.';

  @override
  String get elThisWeek => 'This week';

  @override
  String get elWeeklyQuizzes => 'Weekly quizzes';

  @override
  String elQuizzesWaiting(int n) {
    return '$n quiz(zes) waiting — test your knowledge!';
  }

  @override
  String get elTakePart => 'Take part';

  @override
  String get elNothingThisWeek =>
      'No quizzes or assignments are waiting for you this week.';

  @override
  String elDue(String date) {
    return 'Due $date';
  }

  @override
  String get elOverdue => 'Overdue';

  @override
  String get elMyStudies => 'My studies';

  @override
  String elNotEnrolledOpen(int n) {
    return 'You are not enrolled in a class yet. $n class(es) are open for registration.';
  }

  @override
  String get elNotEnrolledNoOpen =>
      'You are not enrolled in a class yet. Registration will appear here when it opens; meanwhile, lessons open to everyone are under “Learn”.';

  @override
  String get elNoUpcomingClasses => 'No class sessions in the next 7 days.';

  @override
  String get elAttendance => 'Class attendance';

  @override
  String get elNoSessionsYet => 'No attendance taken yet';

  @override
  String get elLatestResults => 'Latest results';

  @override
  String get elNoPublishedResults => 'No published results yet.';

  @override
  String get elToGrade => 'Submissions to grade';

  @override
  String get elMarksRejected => 'Marks returned for correction';

  @override
  String get elMarksDraft => 'Draft marks not yet submitted';

  @override
  String get elQuizAnswersToGrade => 'Quiz answers to grade';

  @override
  String get elAdminTools => 'Education administration';

  @override
  String get elMarksToReview => 'Marks waiting for review';

  @override
  String get elMarksToPublish => 'Approved marks not yet published';

  @override
  String get elRequestsPending => 'Pending student requests';

  @override
  String get elComplaintsOpen => 'Open complaints';

  @override
  String get elSubjectsUnlinked => 'Class subjects without curriculum';

  @override
  String get elOtherSections => 'Other sections';

  @override
  String get elGuidanceCenter => 'Guidance Center';

  @override
  String get elSearchHint => 'Search lessons, subjects or references';

  @override
  String get elSearchStart => 'Type at least 2 letters';

  @override
  String get elSearchNone => 'Nothing found';

  @override
  String get elMySubjects => 'My subjects';

  @override
  String get elCategories => 'Categories';

  @override
  String get elCategory => 'Category';

  @override
  String get elNoCategory => 'No category';

  @override
  String get elOtherSubjects => 'Other subjects';

  @override
  String get elSubject => 'Subject';

  @override
  String get elLesson => 'Lesson';

  @override
  String get elLessons => 'Lessons';

  @override
  String get elMoreLessons => 'More lessons';

  @override
  String get elClass => 'Class';

  @override
  String elLessonCount(int n) {
    return '$n lessons';
  }

  @override
  String elSubjectCount(int n) {
    return '$n subjects';
  }

  @override
  String get elNoLessonsYet => 'No lessons yet';

  @override
  String get elNoSubjectsInCategory =>
      'No published subjects in this category yet.';

  @override
  String get elForStudents => 'For enrolled students';

  @override
  String get elSubjectForStudents =>
      'The content of this subject is for its enrolled students. You can see the lesson titles.';

  @override
  String get elObjectives => 'Learning objectives';

  @override
  String get elCompleted => 'Completed';

  @override
  String get elInProgress => 'In progress';

  @override
  String get elLocked => 'Locked';

  @override
  String elMinutes(int n) {
    return '$n min';
  }

  @override
  String elLessonN(String n) {
    return 'Lesson $n';
  }

  @override
  String get elTextSize => 'Text size';

  @override
  String get elBookmark => 'Bookmark';

  @override
  String get elBookmarks => 'Bookmarks';

  @override
  String get elShare => 'Share';

  @override
  String get elPrevious => 'Previous';

  @override
  String get elNext => 'Next';

  @override
  String get elListen => 'Listen';

  @override
  String get elMarkDone => 'Mark as completed';

  @override
  String get elMarkNotDone => 'Mark as not completed';

  @override
  String get elImages => 'Images';

  @override
  String get elMaterials => 'Learning materials';

  @override
  String get elTeacherNotes => 'Teacher notes';

  @override
  String get elVideoLink => 'Video link';

  @override
  String get elWebLink => 'Web link';

  @override
  String get elBadLink => 'This link is not valid (https:// is needed).';

  @override
  String get elLessonProgress => 'Lesson progress';

  @override
  String get elPublishedResults => 'Published results';

  @override
  String get elPending => 'Pending';

  @override
  String get elNoProgressYet =>
      'No progress yet. It appears here once you start learning.';

  @override
  String elAttendanceSummary(
    String rate,
    int present,
    int absent,
    int excused,
  ) {
    return '$rate · present $present · absent $absent · excused $excused';
  }

  @override
  String get elQuiz => 'Quiz';

  @override
  String get elQuizzes => 'Quizzes';

  @override
  String get elQuizOpen => 'Open';

  @override
  String get elQuizUpcoming => 'Not open yet';

  @override
  String get elQuizClosed => 'Closed';

  @override
  String get elQuizInProgress => 'In progress';

  @override
  String get elQuizDone => 'Done';

  @override
  String elQuizScore(String score) {
    return 'Score: $score';
  }

  @override
  String get elScorePending => 'Shown when results are published';

  @override
  String get elAwaitingTeacher =>
      'Waiting for the teacher to grade written answers';

  @override
  String get elOfficialQuiz => 'Official mark';

  @override
  String get elOfficialQuizNote =>
      'This quiz counts towards an official mark: its score is shown once the teacher and the education office approve and publish it.';

  @override
  String get elPracticeScoreNote =>
      'This score is for practice; it is not an official result.';

  @override
  String get elPolicyAfterClose =>
      'Correct answers are shown after the quiz closes.';

  @override
  String get elPolicyAfterSubmit =>
      'Correct answers are shown after you submit.';

  @override
  String get elPolicyPractice =>
      'Practice: you can check each answer right away.';

  @override
  String get elPolicyNever => 'Correct answers are not shown.';

  @override
  String get elQuizNotAvailable =>
      'This quiz is not available to you (it is for the students of its subject).';

  @override
  String elQuestionCount(int n) {
    return '$n questions';
  }

  @override
  String elAttemptsLeft(int left, int max) {
    return '$left of $max attempts left';
  }

  @override
  String elOpens(String date) {
    return 'Opens $date';
  }

  @override
  String get elInstructions => 'Instructions';

  @override
  String get elStartQuiz => 'Start the quiz';

  @override
  String get elTryAgain => 'Try again';

  @override
  String get elResume => 'Resume';

  @override
  String get elViewAttempt => 'View my last attempt';

  @override
  String elQuestionOf(String n, String total) {
    return 'Question $n of $total';
  }

  @override
  String get elCheckAnswer => 'Check your answer';

  @override
  String get elSubmit => 'Submit';

  @override
  String get elSubmitConfirm =>
      'Submit your answers now? They cannot be changed afterwards.';

  @override
  String elSubmitUnanswered(int n) {
    return '$n question(s) are unanswered. Submit now?';
  }

  @override
  String get elSubmitted => 'Submitted';

  @override
  String get elNoQuestions => 'No questions yet';

  @override
  String get elChooseAll => 'Choose all that apply';

  @override
  String get elYourAnswer => 'Write your answer';

  @override
  String get elTrue => 'True';

  @override
  String get elFalse => 'False';

  @override
  String get elModelAnswer => 'Model answer';

  @override
  String get elNewQuiz => 'New quiz';

  @override
  String get elNoQuizzes => 'No quizzes for this subject yet.';

  @override
  String get elStatusDraft => 'Draft';

  @override
  String get elStatusPublished => 'Published';

  @override
  String get elStatusArchived => 'Archived';

  @override
  String get elStatusActive => 'Active';

  @override
  String elAttemptsCount(int n) {
    return '$n attempts';
  }

  @override
  String elToGradeCount(int n) {
    return '$n to grade';
  }

  @override
  String get elResults => 'Results';

  @override
  String get elQuizLockedNote =>
      'Students have started this quiz, so its questions and scoring rules can no longer change. Dates, instructions and status still can.';

  @override
  String get elPublish => 'Publish';

  @override
  String get elCloseQuiz => 'Close';

  @override
  String get elReopenQuiz => 'Reopen';

  @override
  String get elQuizSettings => 'Quiz settings';

  @override
  String get elTitle => 'Title';

  @override
  String get elOpensAt => 'Opens at';

  @override
  String get elClosesAt => 'Closes at (deadline)';

  @override
  String get elTimeLimit => 'Time limit (minutes)';

  @override
  String get elTimeLimitHint => 'Empty = no limit';

  @override
  String get elMaxAttempts => 'Attempts allowed';

  @override
  String get elScoring => 'Score that counts';

  @override
  String get elScoringBest => 'Best attempt';

  @override
  String get elScoringLast => 'Last attempt';

  @override
  String get elReviewPolicy => 'When correct answers are shown';

  @override
  String get elLinkAssessment => 'Count towards an assessment';

  @override
  String get elLinkAssessmentHint =>
      'If linked, scores are sent to that score sheet as drafts, then submitted, approved and published as usual.';

  @override
  String get elNotOfficial => 'Not linked (practice)';

  @override
  String get elNotOfficialNote =>
      'This quiz is not linked to an assessment; its scores are for practice only.';

  @override
  String get elLinkLesson => 'Show under a lesson';

  @override
  String get elShuffle => 'Shuffle the question order';

  @override
  String get elQuestions => 'Questions';

  @override
  String get elAddQuestion => 'Add question';

  @override
  String get elSaveQuestions => 'Save questions';

  @override
  String get elDeleteQuizConfirm => 'Delete this quiz?';

  @override
  String elQuestionN(int n) {
    return 'Question $n';
  }

  @override
  String get elTypeSingle => 'Single choice';

  @override
  String get elTypeMultiple => 'Multiple choice';

  @override
  String get elTypeTrueFalse => 'True / false';

  @override
  String get elTypeShortText => 'Short answer';

  @override
  String get elPrompt => 'Question';

  @override
  String elOptionN(int n) {
    return 'Option $n';
  }

  @override
  String get elAddOption => 'Add option';

  @override
  String get elMarkCorrect => 'Mark the correct answer';

  @override
  String get elShortTextHint =>
      'Graded by the teacher; the model answer is shown when answers are revealed.';

  @override
  String get elPoints => 'Points';

  @override
  String get elExplanation => 'Explanation (optional)';

  @override
  String get elQuestionNeedsPrompt => 'Every question needs its text.';

  @override
  String get elQuestionNeedsOptions =>
      'A choice question needs at least 2 options.';

  @override
  String get elQuestionNeedsAnswer =>
      'Mark the correct answer of every question.';

  @override
  String get elTransfer => 'Send to score sheet';

  @override
  String get elTransferConfirm =>
      'Send the quiz scores to the linked score sheet as drafts? Marks already submitted or approved are not changed.';

  @override
  String elTransferResult(int sent, int pending, int locked) {
    return '$sent scores sent as drafts. $pending wait for your grading; $locked were already submitted or approved and were not changed. Submit them from the score sheet.';
  }

  @override
  String get elTransferred => 'Sent';

  @override
  String get elNeedsGrading => 'Needs grading';

  @override
  String get elNotTaken => 'Not taken';

  @override
  String get elNoStudents => 'No students';

  @override
  String get elAttempt => 'Attempt';

  @override
  String get elGradeAnswer => 'Grade answer';

  @override
  String elPointsOutOf(String max) {
    return 'Points (out of $max)';
  }

  @override
  String get elContentTitle => 'Learning content';

  @override
  String get elNoAuthoring =>
      'None of the subjects you teach is linked to a curriculum yet.';

  @override
  String get elNewCategory => 'New category';

  @override
  String get elEditCategory => 'Edit category';

  @override
  String get elDragToReorder => 'Drag to reorder';

  @override
  String get elNameAmharic => 'Name (Amharic)';

  @override
  String get elNameEnglish => 'Name (English)';

  @override
  String get elNameRequired => 'A name / title is required.';

  @override
  String get elDescription => 'Description';

  @override
  String get elIcon => 'Icon (until an image is added)';

  @override
  String get elAddImage => 'Add image';

  @override
  String get elChangeImage => 'Change image';

  @override
  String get elRemoveImage => 'Remove image';

  @override
  String get elImage => 'Image';

  @override
  String get elImageAfterSave => 'An image can be added after saving.';

  @override
  String get elArchiveHint =>
      'When off, it is archived and hidden from members.';

  @override
  String get elDeleteCategoryConfirm =>
      'Delete this category? A category with subjects cannot be deleted — archive it instead.';

  @override
  String get elNewSubject => 'New subject';

  @override
  String get elEditSubject => 'Edit subject';

  @override
  String get elNoSubjects => 'No subjects yet.';

  @override
  String get elCode => 'Code';

  @override
  String get elWhoCanRead => 'Who can read the content';

  @override
  String get elVisibilityEnrolled => 'Enrolled students only';

  @override
  String get elVisibilityMembers => 'All members';

  @override
  String get elStatus => 'Status';

  @override
  String get elSequential => 'Learn in order';

  @override
  String get elSequentialHint =>
      'Students open a lesson only after completing the previous one.';

  @override
  String get elEditCurriculum => 'Edit lessons';

  @override
  String get elPreview => 'Preview';

  @override
  String get elNewLesson => 'New lesson';

  @override
  String get elEditLesson => 'Edit lesson';

  @override
  String elMaterialCount(int n) {
    return '$n materials';
  }

  @override
  String get elNotLinkedYet =>
      'Not linked to any class subject yet (link it in course management).';

  @override
  String elTaughtIn(String list) {
    return 'Taught in: $list';
  }

  @override
  String get elUnits => 'Units';

  @override
  String get elUnit => 'Unit';

  @override
  String get elNewUnit => 'New unit';

  @override
  String get elRenameUnit => 'Rename unit';

  @override
  String get elNoUnits => 'No units — lessons are listed directly.';

  @override
  String get elDeleteUnitConfirm => 'Delete this unit? Its lessons are kept.';

  @override
  String get elSummary => 'Summary';

  @override
  String get elScriptureRefs => 'Scripture references';

  @override
  String get elScriptureRefsHint => 'e.g. Acts 2:1-4';

  @override
  String get elEstMinutes => 'Reading time (minutes)';

  @override
  String get elLessonText => 'Lesson text';

  @override
  String get elFormattingHelp =>
      '“# ” heading, “## ” sub-heading, “> ” quotation, “- ” list item; an empty line starts a new paragraph.';

  @override
  String get elTeacherNotesHint => 'Only teachers and editors see this.';

  @override
  String get elMaterialsHint =>
      'Upload PDFs, images, audio or documents; add video as a link. Files are downloadable only by those who may open the lesson.';

  @override
  String get elMaterialTitle => 'Material title';

  @override
  String get elUploadFile => 'Upload file';

  @override
  String get elAddLink => 'Add link';

  @override
  String get elDeleteMaterialConfirm => 'Delete this material?';

  @override
  String get elDeleteLessonConfirm =>
      'Delete this lesson? A lesson students have opened cannot be deleted — archive it instead.';

  @override
  String get elAddFeatured => 'Add to banner';

  @override
  String get elEditFeatured => 'Edit banner item';

  @override
  String get elNoFeatured => 'Nothing featured yet. Add a subject or lesson.';

  @override
  String get elTargetUnavailable => 'Content unpublished or removed';

  @override
  String get elInactive => 'Off';

  @override
  String get elDeleteFeaturedConfirm => 'Remove from the banner?';

  @override
  String get elChooseTarget => 'Choose what to feature.';

  @override
  String get elTitleOverride => 'Title (optional)';

  @override
  String get elTitleOverrideHint => 'Empty = the content’s own title';

  @override
  String get elSubtitle => 'Subtitle';

  @override
  String get elShowFrom => 'Show from';

  @override
  String get elShowUntil => 'Show until';

  @override
  String get elCatalogSubject => 'Curriculum subject';

  @override
  String get elCatalogSubjectHint =>
      'Students of this class subject see that subject’s lessons; its teacher can write them.';

  @override
  String get errModuleDisabled =>
      'This section is turned off for your account.';

  @override
  String get errHasRecords =>
      'It has academic records, so it cannot be deleted — archive it instead.';

  @override
  String get errLessonLocked => 'Complete the previous lesson first.';

  @override
  String get errNotEnrolledSubject =>
      'This is only for students enrolled in this subject.';

  @override
  String get errNotSubjectEditor => 'You are not allowed to edit this subject.';

  @override
  String get errQuizNotOpen => 'This quiz is not open yet.';

  @override
  String get errQuizClosed => 'This quiz is closed.';

  @override
  String get errNoAttemptsLeft => 'You have used all your attempts.';

  @override
  String get errAttemptExpired =>
      'The time for this attempt is over; your saved answers were submitted.';

  @override
  String get errAttemptSubmitted => 'This attempt was already submitted.';

  @override
  String get errQuizHasAttempts =>
      'Students already took this quiz, so this cannot change.';

  @override
  String get errQuizEmpty => 'Add questions before publishing.';

  @override
  String get errQuizNotLinked => 'Link the quiz to an assessment first.';

  @override
  String get errAlreadyTransferred =>
      'The score was already sent; change it in the score sheet.';

  @override
  String get perm_education_content =>
      'Manage learning content (categories, lessons, banner)';

  @override
  String get errSessionNotStarted =>
      'The taker has not started this attendance session yet.';

  @override
  String get errSessionNotAvailable =>
      'Attendance opens 15 minutes before the program starts.';

  @override
  String get errBeforeSessionStart =>
      'This was captured before the session was started.';

  @override
  String get errNotSessionTaker =>
      'Only the attendance taker assigned to this session can do this.';

  @override
  String get errNoTakerAssigned =>
      'No attendance taker is assigned yet — HR assigns one.';

  @override
  String get errSignatureRequired =>
      'The member must sign before attendance is recorded.';

  @override
  String get errLateRemoved =>
      'There is no \"late\" status any more; record Attended or Excused.';

  @override
  String get errOneTakerOnly => 'A program has exactly one attendance taker.';

  @override
  String get errCaptureTooOld =>
      'This offline record is older than 3 days and was sent to HR.';

  @override
  String get errOutsideOccurrence =>
      'The arrival time must be within the program time.';

  @override
  String get errConflictResolved => 'This item was already decided.';

  @override
  String get errSelfApproval => 'You cannot decide your own submission.';

  @override
  String get errLocalDataUnreadable =>
      'Saved offline data on this phone could not be read.';

  @override
  String get attSentToHr =>
      'Saved for HR review — it could not be applied as captured.';

  @override
  String get attSessionStartedSnack => 'Attendance session started';

  @override
  String get attSessionEndedSnack => 'Attendance session ended';

  @override
  String get attEndConfirm =>
      'End this attendance session? Afterwards only correction requests can change it.';

  @override
  String get attChangeTaker => 'Change taker';

  @override
  String get attSubstituteReason => 'Why is a substitute taking over?';

  @override
  String get attRemoveReason => 'Why remove this mark?';

  @override
  String attMinutesAfterStart(int minutes) {
    return '$minutes min after start';
  }

  @override
  String get attSigned => 'Signed';

  @override
  String get attLegacyMark => 'Recorded before attendance sessions';

  @override
  String attSessionEndedAuto(String time) {
    return 'Ended at the scheduled end ($time)';
  }

  @override
  String attSessionEndedAt(String time) {
    return 'Ended by the taker at $time';
  }

  @override
  String attSessionRunning(String start, String elapsed) {
    return 'Started $start · $elapsed';
  }

  @override
  String attSessionOpensAt(String time) {
    return 'Opens at $time (15 minutes before the start)';
  }

  @override
  String get attSessionReady => 'Ready — press Start when the program begins';

  @override
  String get attSessionWaiting => 'Waiting for the taker to start';

  @override
  String get attYou => 'You';

  @override
  String attSessionScheduled(String start, String end) {
    return 'Scheduled $start – $end';
  }

  @override
  String get attNoTakerAssigned => 'No attendance taker assigned';

  @override
  String attSessionTaker(String name) {
    return 'Taker: $name';
  }

  @override
  String get attStartedOffline =>
      'Started offline on this phone — the server confirms it when synced';

  @override
  String get attOnlyTakerRecords =>
      'Only the assigned taker records this session.';

  @override
  String get attStart => 'Start';

  @override
  String get attEnd => 'End';

  @override
  String get attTaker => 'Attendance taker';

  @override
  String get attTakerHint =>
      'One taker per program; you can assign a different taker to a single day from its roster.';

  @override
  String get attTakerHrOnly => 'Assigned by HR.';

  @override
  String get attSignaturePolicy => 'Attendance signatures';

  @override
  String get attSignaturePolicyHint =>
      'Members sign on the taker\'s phone before they are recorded present. Tick the member types that do not sign.';

  @override
  String get attSignatureExempt => 'Does not sign';

  @override
  String get attSignatureRequiredShort => 'Signs when recorded present';

  @override
  String get attConflicts => 'Offline attendance to review';

  @override
  String get attConflictsHint =>
      'Offline work the server could not apply as captured. Nothing is dropped: accept or reject each one with a note.';

  @override
  String get attConflictsEmpty => 'Nothing to review';

  @override
  String get attConflictAccept => 'Accept';

  @override
  String get attConflictReject => 'Reject';

  @override
  String get attDecisionNote => 'Decision note';

  @override
  String get attConflictRecord => 'Attendance record';

  @override
  String attCapturedAt(String time) {
    return 'captured $time';
  }

  @override
  String get attSubmittedBy => 'Submitted by';

  @override
  String get attArrivedAt => 'Arrived at';

  @override
  String get attSessionRuleHint =>
      'Attendance: HR assigns one taker; it opens 15 minutes before the start and counts from when the taker presses Start. Members sign when recorded.';

  @override
  String syncHeldForReview(String what) {
    return '$what could not be applied as captured and was sent to HR for review.';
  }

  @override
  String get perm_attendance_assign => 'Assign attendance takers (HR)';

  @override
  String get attTakeAttendance => 'Take attendance';

  @override
  String get attTakeAttendanceSub => 'Programs HR assigned you to record';

  @override
  String get eduAcademicCalendar => 'Academic Calendar';

  @override
  String get eduAcademicYears => 'Academic Years';

  @override
  String get eduAcademicYear => 'Academic Year';

  @override
  String get eduEthYear => 'Ethiopian Year';

  @override
  String get eduCurrentYear => 'Current Year';

  @override
  String get eduSetCurrent => 'Set Current';

  @override
  String get eduCloseYear => 'Close Year';

  @override
  String get eduCloseYearConfirm =>
      'Are you sure you want to close this academic year? All assessment marks must be published.';

  @override
  String get eduTerms => 'Terms';

  @override
  String get eduNewTerm => 'New Term';

  @override
  String get eduLevels => 'Grade Levels';

  @override
  String get eduLevel => 'Level';

  @override
  String get eduNewLevel => 'New Level';

  @override
  String get eduBuiltIn => 'Built-in';

  @override
  String get eduAllowMultiple => 'Allow concurrent classes (non-exclusive)';

  @override
  String get eduAllowMultipleHint =>
      'When enabled, students in this class can also be enrolled in other classes for the same year.';

  @override
  String get eduAssignStudents => 'Assign Students';

  @override
  String get eduAssignableStudents => 'Assignable Students';

  @override
  String get eduAlreadyInClass => 'Already in this class';

  @override
  String eduInOtherClass(Object className) {
    return 'In another class: $className';
  }

  @override
  String eduAssignedSuccess(Object count) {
    return '$count student(s) assigned successfully';
  }

  @override
  String get eduTransferStudent => 'Transfer Student';

  @override
  String get eduTransferTargetClass => 'Target Class';

  @override
  String get eduTransferReason => 'Reason for transfer';

  @override
  String get eduTransferSuccess => 'Student transferred successfully';

  @override
  String get eduCourseMode => 'Offering Mode';

  @override
  String get eduModePhysical => 'Physical (In-person)';

  @override
  String get eduModeOnline => 'Online';

  @override
  String get eduModeHybrid => 'Hybrid';

  @override
  String get eduPassMark => 'Pass Mark';

  @override
  String get eduEligibleGroups => 'Eligible Member Groups';

  @override
  String get eduAllGroups => 'All member groups in class';

  @override
  String get eduLinkedPrograms => 'Linked Programs';

  @override
  String get eduLinkedProgramsHint => 'Programs where this course meets';

  @override
  String get eduLate => 'Late';

  @override
  String get eduVersions => 'Submission history';

  @override
  String get eduVersion => 'Version';

  @override
  String get eduPublishAt => 'Publish at';

  @override
  String get eduLatePolicy => 'Late submissions';

  @override
  String get eduLatePolicyRefuse => 'Refuse late submissions';

  @override
  String get eduLatePolicyAccept => 'Accept marked as late';

  @override
  String get eduLateUntil => 'Late accepted until';

  @override
  String get eduAllowResubmit => 'Allow resubmissions';

  @override
  String get eduOutcomes => 'Course outcomes';

  @override
  String get eduComputeOutcomes => 'Compute outcomes';

  @override
  String get eduFinalizeOutcomes => 'Finalize outcomes';

  @override
  String get eduFinalizeConfirm =>
      'Finalize course outcomes? This will freeze the outcomes.';

  @override
  String get eduPassed => 'Passed';

  @override
  String get eduFailed => 'Failed';

  @override
  String get eduIncomplete => 'Incomplete';

  @override
  String get eduRetake => 'Retake';

  @override
  String get eduRequestRetake => 'Request online retake';

  @override
  String get eduRetakeRequested => 'Retake requested';

  @override
  String get eduRetakeRequestedSuccess =>
      'Online retake requested successfully';

  @override
  String get eduCountsForProgression => 'Counts for progression';

  @override
  String get eduCertificates => 'Certificates';

  @override
  String get eduMyCertificates => 'My Certificates';

  @override
  String get eduNoCertificates => 'No certificates issued yet.';

  @override
  String get eduCertificateNumber => 'Certificate No.';

  @override
  String get eduVerificationCode => 'Verification Code';

  @override
  String get eduIssueCertificates => 'Issue Certificates';

  @override
  String eduIssueCertificatesConfirm(Object count) {
    return 'Issue certificates to the selected $count student(s)?';
  }

  @override
  String eduIssuedSuccess(Object count) {
    return '$count certificate(s) issued successfully';
  }

  @override
  String get eduNoEligibleStudents =>
      'No eligible students found for certificates.';

  @override
  String get eduCertificateStatus => 'Status';

  @override
  String get eduCertificateValid => 'Valid';

  @override
  String get eduCertificateRevoked => 'Revoked';

  @override
  String get eduCertificateReplaced => 'Replaced';

  @override
  String get eduRevokeCertificate => 'Revoke Certificate';

  @override
  String get eduRevokeReason => 'Reason for revocation';

  @override
  String get eduRevokedSuccess => 'Certificate revoked successfully';

  @override
  String get eduAcademicPeriod => 'Academic Period';

  @override
  String get eduAcademicScore => 'Academic Score';

  @override
  String get eduEngagementScore => 'Engagement Score';

  @override
  String get eduActivityReport => 'Activity Report';

  @override
  String get eduScoresAndActivity => 'Scores & Activity';

  @override
  String get libFavorites => 'Favorites';

  @override
  String get libFavorite => 'Favorite';

  @override
  String get libAddToFavorites => 'Add to favorites';

  @override
  String get libRemoveFromFavorites => 'Remove from favorites';

  @override
  String libProgress(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String libPageCount(int count) {
    return '$count pages';
  }

  @override
  String get libResume => 'Resume reading';

  @override
  String get libNarration => 'Narration';

  @override
  String get libListenNarration => 'Listen to narration';

  @override
  String get libPauseNarration => 'Pause narration';

  @override
  String get libNarrationPlaying => 'Playing narration';

  @override
  String get libSearchInBook => 'Search in book';

  @override
  String get libJumpToPage => 'Jump to page';

  @override
  String get libPageNumber => 'Page number';

  @override
  String get libZoomIn => 'Zoom in';

  @override
  String get libZoomOut => 'Zoom out';

  @override
  String get libNextMatch => 'Next match';

  @override
  String get libPrevMatch => 'Previous match';

  @override
  String get libNoMatches => 'No matches found';

  @override
  String get libCopies => 'Copies';

  @override
  String libCopiesAvailable(int avail, int total) {
    return '$avail of $total copies available';
  }

  @override
  String get libCirculation => 'Circulation';

  @override
  String get libCheckout => 'Check out';

  @override
  String get libReturn => 'Return';

  @override
  String get libBorrower => 'Borrower';

  @override
  String get libSelectBorrower => 'Select borrower';

  @override
  String get libCopyCode => 'Copy code';

  @override
  String get libCondition => 'Condition';

  @override
  String get libConditionOut => 'Condition out';

  @override
  String get libConditionIn => 'Condition in';

  @override
  String get libGood => 'Good';

  @override
  String get libFair => 'Fair';

  @override
  String get libPoor => 'Poor';

  @override
  String get libDamaged => 'Damaged';

  @override
  String get libStatusAvailable => 'Available';

  @override
  String get libStatusOnLoan => 'On loan';

  @override
  String get libStatusLost => 'Lost';

  @override
  String get libStatusWithdrawn => 'Withdrawn';

  @override
  String get libOverdue => 'Overdue';

  @override
  String get libOverdueLoans => 'Overdue loans';

  @override
  String get libActiveLoans => 'Active loans';

  @override
  String get libDueOn => 'Due on';

  @override
  String get libSignToBorrow => 'Borrower signature';

  @override
  String get libSignatureRequired => 'Borrower must sign to checkout';

  @override
  String get libCheckoutSuccess => 'Book checked out successfully';

  @override
  String get libReturnSuccess => 'Book returned successfully';

  @override
  String get libConflictOnLoan =>
      'Copy is already checked out to another member';

  @override
  String get libScanQr => 'Scan copy code or member QR';

  @override
  String get libEnterCopyCode => 'Enter copy code';

  @override
  String get libCopyNotFound => 'Copy not found';

  @override
  String get libDownloadToReadOffline => 'Download to read offline';

  @override
  String get elAttemptsExhausted => 'Attempt limit reached';

  @override
  String get elAttemptsExhaustedDesc =>
      'You have used all permitted attempts for this quiz. You cannot start another attempt.';

  @override
  String get elNoAttemptsLeftAlert => '0 attempts remaining';

  @override
  String elAttemptsRemaining(int count) {
    return 'Attempts remaining: $count';
  }

  @override
  String get elDirectMaterials => 'Course Materials';

  @override
  String get elAddDirectMaterial => 'Add Material';

  @override
  String get elUploadMaterial => 'Upload file or document';

  @override
  String elDirectMaterialSubtitle(int grade) {
    return 'Grade $grade direct resource';
  }

  @override
  String get elNoAssignedGradeTitle => 'No Assigned Grade';

  @override
  String get elNoAssignedGradeDesc =>
      'You are not currently assigned to a grade level. Please contact your Sunday School administrator.';

  @override
  String get elAdminPanelHint =>
      'To manage all grades, please use the Education Admin panel.';

  @override
  String elGradeRestrictedNotice(int grade) {
    return 'You are assigned to Grade $grade only';
  }

  @override
  String get elAssignments => 'Assignments';

  @override
  String get elAssignmentDetail => 'Assignment Details';

  @override
  String get elSubmitAssignment => 'Submit Assignment';

  @override
  String get elTurnedIn => 'Turned in';

  @override
  String get elAssigned => 'Assigned';

  @override
  String get elDueSoon => 'Due soon';

  @override
  String get elUpcoming => 'Upcoming';

  @override
  String get elGraded => 'Graded';

  @override
  String get elMySubmission => 'Your Submission';

  @override
  String elGradeScore(String score, String max) {
    return 'Score: $score / $max';
  }

  @override
  String get elTeacherFeedback => 'Teacher Feedback';

  @override
  String get elResubmit => 'Resubmit';

  @override
  String elDueDate(String date) {
    return 'Due: $date';
  }

  @override
  String get elYourResponse => 'Your written response';

  @override
  String get elAttachFile => 'Attach File';

  @override
  String get elMaxScore => 'Maximum Score';

  @override
  String get elGradeSubmission => 'Grade Submission';

  @override
  String get elReleaseGrade => 'Release grade to student';

  @override
  String get elSubmissions => 'Submissions';

  @override
  String get elNoAssignments => 'No assignments available';

  @override
  String get elCreateAssignment => 'Create Assignment';

  @override
  String get elAnnouncements => 'Class Announcements';

  @override
  String get elClassFeed => 'Class Stream';

  @override
  String get elNewAnnouncement => 'New Announcement';

  @override
  String get elPostAnnouncement => 'Post Announcement';

  @override
  String elTeacherPosted(String name) {
    return 'Posted by $name';
  }

  @override
  String get elAnnouncementBody => 'Announcement message';

  @override
  String get elNoAnnouncements => 'No announcements posted yet';
}
