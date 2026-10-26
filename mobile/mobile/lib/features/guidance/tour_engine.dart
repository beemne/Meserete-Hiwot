import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';
import '../../repositories/guidance_repository.dart';

/// Predefined UI target keys that screens attach to for spotlight walkthroughs.
class TourKeys {
  static final hubCardEdu = GlobalKey(debugLabel: 'tour_hub_edu');
  static final hubCardMezmur = GlobalKey(debugLabel: 'tour_hub_mezmur');
  static final hubHeader = GlobalKey(debugLabel: 'tour_hub_header');
  static final homeSearch = GlobalKey(debugLabel: 'tour_home_search');
  static final homeCategories = GlobalKey(debugLabel: 'tour_home_categories');
  static final programAlarm = GlobalKey(debugLabel: 'tour_program_alarm');
  static final memberCard = GlobalKey(debugLabel: 'tour_member_card');
  static final adminUsers = GlobalKey(debugLabel: 'tour_admin_users');
  static final adminAttendance = GlobalKey(debugLabel: 'tour_admin_attendance');
  static final adminNotify = GlobalKey(debugLabel: 'tour_admin_notify');
  static final adminReports = GlobalKey(debugLabel: 'tour_admin_reports');

  static final hubSettings = GlobalKey(debugLabel: 'tour_hub_settings');
  static final mezmurPlay = GlobalKey(debugLabel: 'tour_mezmur_play');
  static final programsFilterKey = GlobalKey(debugLabel: 'tour_programs_filter');
  static final programsAttendanceKey = GlobalKey(debugLabel: 'tour_programs_att');
  static final libraryFavoritesTab = GlobalKey(debugLabel: 'tour_lib_fav');
  static final libraryDownloadsTab = GlobalKey(debugLabel: 'tour_lib_down');

  static GlobalKey get hubEduCard => hubCardEdu;
  static GlobalKey get hubMezmurCard => hubCardMezmur;
  static GlobalKey get hubSettingsCard => hubSettings;
  static GlobalKey get mezmurSearchBar => homeSearch;
  static GlobalKey get mezmurPlayButton => mezmurPlay;
  static GlobalKey get programsFilter => programsFilterKey;
  static GlobalKey get programsAttendanceBtn => programsAttendanceKey;

  /// Dynamic route key registry for admin cards to support exact spotlight and auto-scroll
  static final Map<String, GlobalKey> moduleKeys = {
    '/admin/users': adminUsers,
    '/admin/member-ids': GlobalKey(debugLabel: 'tour_mid'),
    '/admin/member-groups': GlobalKey(debugLabel: 'tour_mg'),
    '/admin/change-requests': GlobalKey(debugLabel: 'tour_cr'),
    '/admin/payments': GlobalKey(debugLabel: 'tour_pay'),
    '/admin/attendance': adminAttendance,
    '/admin/fines': GlobalKey(debugLabel: 'tour_fines'),
    '/admin/notify': adminNotify,
    '/admin/notification-health': GlobalKey(debugLabel: 'tour_nh'),
    '/admin/departments': GlobalKey(debugLabel: 'tour_dept'),
    '/admin/chat': GlobalKey(debugLabel: 'tour_chat'),
    '/admin/items': GlobalKey(debugLabel: 'tour_items'),
    '/admin/borrowings': GlobalKey(debugLabel: 'tour_borrow'),
    '/admin/property-requests': GlobalKey(debugLabel: 'tour_pr'),
    '/edu/courses': GlobalKey(debugLabel: 'tour_courses'),
    '/admin/library-requests': GlobalKey(debugLabel: 'tour_lib_req'),
    '/edu/manage': GlobalKey(debugLabel: 'tour_edu_manage'),
    '/edu/registrations': GlobalKey(debugLabel: 'tour_edu_reg'),
    '/admin/selections': GlobalKey(debugLabel: 'tour_selections'),
    '/admin/categories': GlobalKey(debugLabel: 'tour_categories'),
    '/admin/mezmurs': GlobalKey(debugLabel: 'tour_mezmurs'),
    '/admin/import': GlobalKey(debugLabel: 'tour_import'),
    '/admin/program-categories': GlobalKey(debugLabel: 'tour_prog_cat'),
    '/admin/programs': GlobalKey(debugLabel: 'tour_programs'),
    '/admin/ads': GlobalKey(debugLabel: 'tour_ads'),
    '/admin/pages': GlobalKey(debugLabel: 'tour_pages'),
    '/projects': GlobalKey(debugLabel: 'tour_projects'),
    '/projects/my-tasks': GlobalKey(debugLabel: 'tour_my_tasks'),
    '/projects/approvals': GlobalKey(debugLabel: 'tour_approvals'),
    '/admin/admins': GlobalKey(debugLabel: 'tour_admins'),
    '/admin/roles': GlobalKey(debugLabel: 'tour_roles'),
    '/admin/settings': GlobalKey(debugLabel: 'tour_settings'),
    '/admin/releases': GlobalKey(debugLabel: 'tour_releases'),
    '/admin/guidance': GlobalKey(debugLabel: 'tour_guidance'),
    '/admin/reports': adminReports,
    '/admin/audit': GlobalKey(debugLabel: 'tour_audit'),
    '/admin/activity': GlobalKey(debugLabel: 'tour_activity'),
  };
}

/// One step in an interactive tour with route navigation and target element key.
class InteractiveTourStep {
  const InteractiveTourStep({
    required this.title,
    required this.description,
    this.tip,
    this.targetKey,
    this.targetRoute,
    this.sectionAnchor,
    this.alignment = Alignment.center,
  });

  final String title;
  final String description;
  final String? tip;
  final GlobalKey? targetKey;
  final String? targetRoute;
  final String? sectionAnchor;
  final Alignment alignment;

  String titleFor(String lang) {
    if (lang == 'en') {
      final match = RegExp(r'\(([^)]+)\)').firstMatch(title);
      if (match != null && match.group(1)!.trim().isNotEmpty) {
        return match.group(1)!.trim();
      }
      return title;
    }
    if (title.contains('(')) {
      final am = title.split('(').first.trim();
      if (am.isNotEmpty) return am;
    }
    return title;
  }

  String descriptionFor(String lang) => description;

  String? tipFor(String lang) => tip;
}

/// Catalog of interactive tours.
class TourCatalog {
  static final Map<String, List<InteractiveTourStep>> tours = {
    'welcome_tour': [
      InteractiveTourStep(
        title: 'እንኳን ደህና መጡ! (Welcome)',
        description: 'የመሠረተ ሕይወት መተግበሪያ ዋና ማዕከል (Hub)። እዚህ ሁሉንም መንፈሳዊ አገልግሎቶች በአንድ ላይ ያገኛሉ።',
        tip: 'በማንኛውም ጊዜ ይህንን ጉብኝት በቅንብሮች ውስጥ የመመሪያ ማዕከል ገብተው መድገም ይችላሉ።',
        targetKey: TourKeys.hubHeader,
        targetRoute: '/hub',
        alignment: Alignment.topCenter,
      ),
      InteractiveTourStep(
        title: 'የሰንበት ት/ቤት ትምህርት (ትምህርት)',
        description: 'የትምህርት ክፍሎች፣ ኮርሶች፣ የንባብ መጻሕፍት እና የተማሪዎች ክትትል የሚገኝበት ክፍል።',
        tip: 'ካርዱን በመጫን በቀጥታ ወደ ትምህርት ክፍል መግባት ይችላሉ።',
        targetKey: TourKeys.hubCardEdu,
        targetRoute: '/hub',
        alignment: Alignment.center,
      ),
      InteractiveTourStep(
        title: 'የመዝሙር ክፍል (መዝሙር)',
        description: 'በድምጽ እና በግጥም የተዘጋጁ መዝሙራት፣ ከመስመር ውጭ ማዳመጥ እና ተወዳጅ መዝሙራት።',
        tip: 'መዝሙራትን ወደ ስልክዎ አውርደው ያለ ኢንተርኔት ማዳመጥ ይችላሉ።',
        targetKey: TourKeys.hubCardMezmur,
        targetRoute: '/hub',
        alignment: Alignment.center,
      ),
      InteractiveTourStep(
        title: 'መርሐ ግብሮች እና ማሳሰቢያዎች',
        description: 'ሳምንታዊ የሰንበት ት/ቤት መርሐ ግብሮች፣ ተረኞች እና የ30 ደቂቃ ማንቂያ (Alarm)።',
        tip: 'መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ እንዲያስታውስዎት ማንቂያ ማብራት ይችላሉ።',
        targetKey: TourKeys.programsFilter,
        targetRoute: '/programs',
        alignment: Alignment.topCenter,
      ),
      InteractiveTourStep(
        title: 'የግል መታወቂያ እና ቅንብሮች',
        description: 'የእርስዎን የQR መታወቂያ ካርድ፣ የአቴንዳንስ ታሪክ እና የመተግበሪያውን ቅንብሮች በቅንብሮች ገጽ ያግኙ።',
        tip: 'እገዛ እና ዝርዝር መመሪያ ሲፈልጉ በማንኛውም ጊዜ የመመሪያ ማዕከልን ይጠቀሙ።',
        targetKey: TourKeys.memberCard,
        targetRoute: '/settings/me',
        alignment: Alignment.center,
      ),
    ],
    'mezmur_tour': [
      InteractiveTourStep(
        title: 'የመዝሙር መፈለጊያ (Search)',
        description: 'በመዝሙር ርዕስ፣ በግጥም ቃላት ወይም በምድብ በቀላሉ ፈልገው ያግኙ።',
        tip: 'በግዕዝም ሆነ በአማርኛ ፊደላት መፈለግ ይቻላል።',
        targetKey: TourKeys.homeSearch,
        targetRoute: '/home',
        alignment: Alignment.topCenter,
      ),
      InteractiveTourStep(
        title: 'የመዝሙር ምድቦች (Categories)',
        description: 'በበዓላት፣ በዘመናት እና በአርእስት የተከፋፈሉ አቃፊዎች።',
        tip: 'ለዕለቱ የተመረጡትን በ«የዛሬ መዝሙራት» ስር ያገኛሉ።',
        targetKey: TourKeys.homeCategories,
        targetRoute: '/home/categories',
        alignment: Alignment.center,
      ),
      InteractiveTourStep(
        title: 'ከመስመር ውጭ ማዳመጥ (Offline)',
        description: 'የወረዱ መዝሙራትን በ«የእኔ መዝሙራት» (የወረዱ እና የተወደዱ) ገጽ ያለ ኢንተርኔት በከፍተኛ ጥራት ያዳምጡ።',
        tip: 'ስልኩ ቢዘጋም ከበስተጀርባ ድምጹ ይጫወታል።',
        targetKey: TourKeys.libraryDownloadsTab,
        targetRoute: '/library',
        alignment: Alignment.bottomCenter,
      ),
    ],
    'programs_tour': [
      InteractiveTourStep(
        title: 'መርሐ ግብሮች እና ማጣሪያ',
        description: 'መጪ፣ ያለፉ እና የእኔ መርሐ ግብሮችን በምድብ ለይተው ይመልከቱ።',
        tip: 'በማጣሪያው በመጠቀም የሚፈልጉትን መርሐ ግብር በፍጥነት ማግኘት ይችላሉ።',
        targetKey: TourKeys.programsFilter,
        targetRoute: '/programs',
        alignment: Alignment.topCenter,
      ),
      InteractiveTourStep(
        title: 'የ30 ደቂቃ ማንቂያ (Alarm)',
        description: 'መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ በድምጽ እንዲያስታውስዎት ይህንን ምልክት ይጫኑ።',
        tip: 'ስልክዎ ተቆልፎ ቢሆንም እንኳን ልክ እንደ ሰዓት ማንቂያ ደውሎ ያሳውቅዎታል።',
        targetKey: TourKeys.programAlarm,
        targetRoute: '/programs',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'ተሳታፊዎች እና ተረኞች',
        description: 'ለመዝሙር፣ ለትምህርት ወይም ለስነ-ስርዓት የተመደቡ አባላትን ዝርዝር ይመልከቱ።',
        tip: 'የተመደቡበት መርሐ ግብር ካለ በልዩ ምልክት ይታይዎታል።',
        targetRoute: '/programs',
        alignment: Alignment.bottomCenter,
      ),
    ],
    'attendance_tour': [
      InteractiveTourStep(
        title: 'የአባልነት ዲጂታል ካርድ (QR Code)',
        description: 'ይህ የእርስዎ የግል መታወቂያ ካርድ ነው። በአዳራሽ ሲገቡ ለክትትል መዝጋቢዎች ያሳዩ።',
        tip: 'መዝጋቢዎች ኮዱን በመቃኘት መገኘትዎን በሰከንድ ውስጥ ያረጋግጣሉ።',
        targetKey: TourKeys.memberCard,
        targetRoute: '/settings/me',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'የክትትል የቀን መቁጠሪያ (Calendar)',
        description: 'የተገኙባቸውን እና የቀሩባቸውን ቀናት በግልጽ ይመልከቱ።',
        tip: 'ተገኝተው ካልተመዘገቡ የማስተካከያ ጥያቄ (Correction Request) ማቅረብ ይችላሉ።',
        targetRoute: '/settings/attendance',
        alignment: Alignment.bottomCenter,
      ),
    ],
    'edu_tour': [
      InteractiveTourStep(
        title: 'የትምህርት ክፍሎች (Courses & Classes)',
        description: 'የትምህርት መነሻ ገጽ። ኮርሶች፣ የንባብ መጻሕፍት (PDFs) እና የተማሪዎች ዝርዝር።',
        tip: 'ካርዱን በመጫን በቀጥታ ወደ ኮርሶች ገጽ መግባት ይችላሉ።',
        targetKey: TourKeys.hubCardEdu,
        targetRoute: '/hub',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'የትምህርት መነሻ (Home)',
        description: 'የዕለቱ ትምህርት፣ ካቆሙበት መቀጠያ፣ የትምህርት ምድቦች እና የዚህ ሳምንት ፈተናዎችና የቤት ሥራዎች።',
        tip: 'ከታች ያሉት ትሮች፦ መነሻ · ተማር · ክፍሎች · እድገት · ተጨማሪ።',
        targetRoute: '/edu',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'ተማር (Learn)',
        description: 'ምድብ → የትምህርት ዓይነት → ምዕራፍ → ትምህርት። ትምህርቱን ያንብቡ፣ አጋዥ ፋይሎችን ይክፈቱ፣ ሲጨርሱ ምልክት ያድርጉ።',
        tip: 'የፈለጉትን ትምህርት ከላይ ባለው የፍለጋ ምልክት ያግኙ።',
        targetRoute: '/edu/learn',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'እድገት (Progress)',
        description: 'የትምህርት እድገትዎ፣ የክፍል መገኘትዎ እና የታተሙ ውጤቶችዎ። ያልታተመ ውጤት አይታይም።',
        tip: 'የፈተና ውጤቶች ከጸደቁና ከታተሙ በኋላ ይፋዊ ይሆናሉ።',
        targetRoute: '/edu/progress',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'ተጨማሪ፦ ቤተ-መጽሐፍት እና አገልግሎቶች',
        description: 'መንፈሳዊ መጻሕፍት (PDF)፣ ጥያቄዎችና ቅሬታዎች፣ የትምህርት ጉዞ፣ መርሐ ግብሮች እና ቅንብሮች።',
        tip: 'የተጠየቁ መጻሕፍት ሲፈቀዱ ማሳወቂያ ይደርስዎታል።',
        targetRoute: '/edu/more',
        alignment: Alignment.bottomCenter,
      ),
    ],
    'projects_tour': [
      const InteractiveTourStep(
        title: 'የመምሪያ ፕሮጀክቶች (Projects)',
        description: 'የመምሪያዎ እና የሰንበት ት/ቤቱ አጠቃላይ ፕሮጀክቶች፣ በጀት እና የዕድገት ደረጃ ዝርዝር።',
        tip: 'በደረጃቸው (በሂደት ላይ፣ ያለቀ፣ የታቀደ) ተለይተው ይታያሉ።',
        targetRoute: '/projects',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'የተግባራት ሰሌዳ (Tasks)',
        description: 'ለአባላት የተከፋፈሉ ተግባራት፣ የማጠናቀቂያ ቀን እና ቅድሚያ የሚሰጣቸው ስራዎች።',
        tip: 'ስራዎን ሲያጠናቅቁ ደረጃውን ወደ «ተጠናቋል» ይለውጡ።',
        targetRoute: '/projects/my-tasks',
        alignment: Alignment.bottomCenter,
      ),
    ],
    'library_tour': [
      InteractiveTourStep(
        title: 'የተወደዱ መዝሙራት (Favorites)',
        description: 'በመዝሙር ዝርዝር ውስጥ የወደዷቸውን (የልብ ምልክት ያደረጓቸውን) መዝሙራት በአንድ ላይ እዚህ ያገኛሉ።',
        tip: 'በማንኛውም ጊዜ የሚወዷቸውን መዝሙራት በቀላሉ በአንድ ጠቅታ ማጫወት ይችላሉ።',
        targetKey: TourKeys.libraryFavoritesTab,
        targetRoute: '/library',
        alignment: Alignment.topCenter,
      ),
      InteractiveTourStep(
        title: 'የወረዱ መዝሙራት (Offline Downloads)',
        description: 'ያወረዷቸውን መዝሙራት ያለ ኢንተርኔት (Offline) በከፍተኛ ጥራት እዚህ ያዳምጡ።',
        tip: 'ጉዞ ላይ ወይም ኢንተርኔት በሌለበት ጊዜ መዝሙራትን ያለ መቆራረጥ ለማዳመጥ አስቀድመው ያውርዷቸው።',
        targetKey: TourKeys.libraryDownloadsTab,
        targetRoute: '/library',
        alignment: Alignment.topCenter,
      ),
    ],
    'choir_tour': [
      const InteractiveTourStep(
        title: 'የመረጣ መስፈርቶች (Eligibility)',
        description: 'የአቴንዳንስ ምጣኔ፣ የፈተና ውጤቶች እና የአገልግሎት ዝግጁነት መመዘኛዎች።',
        tip: 'ዝቅተኛውን መስፈርት የሚያሟሉ አባላት ብቻ በመረጣው ይካተታሉ።',
        targetRoute: '/choir',
        alignment: Alignment.center,
      ),
      const InteractiveTourStep(
        title: 'የተመረጡ አባላት ዝርዝር',
        description: 'ውጤቱ በአስተዳዳሪዎች ሲጸድቅ እና ይፋ ሲደረግ የተመደቡበትን የአገልግሎት ክፍል ይመልከቱ።',
        tip: 'ቅሬታ ወይም ጥያቄ ካለዎት ለክፍሉ አስተባባሪዎች ማቅረብ ይችላሉ።',
        targetRoute: '/choir',
        alignment: Alignment.bottomCenter,
      ),
    ],
    'admin_tour': [
      InteractiveTourStep(
        title: 'የአባላት አስተዳደር (Users)',
        description: 'አዳዲስ አባላትን መመዝገብ፣ መረጃ ማስተካከል፣ መታወቂያ መስጠት እና Device Reset ማከናወን።',
        tip: 'አባሉ ስልክ ሲቀይር «Reset Device» በማድረግ በአዲሱ ስልኩ እንዲገባ ይፍቀዱለት።',
        targetKey: TourKeys.adminUsers,
        targetRoute: '/admin',
        alignment: Alignment.center,
      ),
      InteractiveTourStep(
        title: 'መርሐ ግብር እና አቴንዳንስ',
        description: 'መርሐ ግብሮችን ማቀድ፣ መዝጋቢዎችን መመደብ እና አቴንዳንስ መዝጋት።',
        tip: 'መርሐ ግብሩ ሲጠናቀቅ አቴንዳንሱ ሲዘጋ የቀሩ አባላት በራስ-ሰር ይሰላሉ።',
        targetKey: TourKeys.adminAttendance,
        targetRoute: '/admin',
        alignment: Alignment.center,
      ),
      InteractiveTourStep(
        title: 'ማሳወቂያዎች እና ሪፖርቶች',
        description: 'ለአባላት ፑሽ ማሳወቂያ መላክ እና የሰንበት ት/ቤቱን ሪፖርቶች በExcel/PDF ማመንጨት።',
        tip: 'ሁሉንም ሪፖርቶች በዳሽቦርዱ በኩል ማውጣት ይችላሉ።',
        targetKey: TourKeys.adminNotify,
        targetRoute: '/admin',
        alignment: Alignment.center,
      ),
    ],
  };
}

/// Tour Controller for managing active overlay and multi-screen sequencing.
class TourController {
  TourController._();
  static final TourController instance = TourController._();

  OverlayEntry? _overlayEntry;
  String? _activeTourId;
  int _currentStep = 0;
  List<InteractiveTourStep> _steps = [];
  WidgetRef? _ref;

  bool get isRunning => _overlayEntry != null;

  /// The repository through the caller's ref — unless that widget has already been closed (a tour
  /// is usually started by a sheet or page that navigates away first) — else the app's container.
  GuidanceRepository? _getRepo(BuildContext? context, WidgetRef? ref) {
    for (final r in [ref, _ref]) {
      if (r == null) continue;
      try {
        return r.read(guidanceRepositoryProvider);
      } catch (_) {}
    }
    for (final c in [context, rootNavigatorKey.currentContext]) {
      if (c == null || !c.mounted) continue;
      try {
        return ProviderScope.containerOf(c, listen: false).read(guidanceRepositoryProvider);
      } catch (_) {}
    }
    return null;
  }

  /// Start a tour by ID safely.
  void startTour(BuildContext context, String tourId, {WidgetRef? ref, bool force = false}) async {
    if (isRunning) dismiss(saveProgress: false);

    _ref = ref;
    _activeTourId = tourId;
    _steps = TourCatalog.tours[tourId] ?? [];
    if (_steps.isEmpty) return;

    final repo = _getRepo(context, ref);

    // Check if tour was already completed, unless forced
    if (!force && repo != null) {
      try {
        final progressMap = await repo.fetchTourProgressMap();
        final p = progressMap[tourId];
        if (p != null && (p.completed || p.dismissed)) {
          return; // already completed or dismissed
        }
      } catch (_) {}
    }

    _currentStep = 0;
    // Open the first step's screen; the caller's screen may already be gone (e.g. it switched tab
    // first), so the overlay lives on the root navigator rather than on the caller's context.
    _goTo(_steps.first.targetRoute);
    _showOverlay(context.mounted ? context : null);
  }

  /// Show a step's screen — only when the app is not already on it (pushing the same route again
  /// stacked a copy of the page at every step).
  void _goTo(String? route) {
    final navCtx = rootNavigatorKey.currentContext;
    if (route == null || navCtx == null) return;
    try {
      final router = GoRouter.of(navCtx);
      if (router.routerDelegate.currentConfiguration.uri.path != route) router.go(route);
    } catch (_) {}
  }

  /// Reset tour progress so it can be re-launched.
  Future<void> resetTour(String tourId, {BuildContext? context, WidgetRef? ref}) async {
    final repo = _getRepo(context, ref ?? _ref);
    if (repo != null) {
      await repo.resetTourProgress(tourId: tourId);
    }
  }

  void _showOverlay([BuildContext? context]) {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      return;
    }

    // The root overlay stays on top of every tab and page the tour moves through.
    final overlay = rootNavigatorKey.currentState?.overlay ?? (context != null && context.mounted ? Overlay.maybeOf(context) : null);
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (ctx) => _TourOverlayWidget(
        tourId: _activeTourId!,
        stepIndex: _currentStep,
        totalSteps: _steps.length,
        step: _steps[_currentStep],
        onNext: _nextStep,
        onPrevious: _previousStep,
        onSkip: () => dismiss(saveProgress: true, dismissed: true),
        onFinish: () => dismiss(saveProgress: true, completed: true),
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      _currentStep++;
      _transitionToCurrentStep();
    } else {
      dismiss(saveProgress: true, completed: true);
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      _currentStep--;
      _transitionToCurrentStep();
    }
  }

  void _transitionToCurrentStep() {
    _goTo(_steps[_currentStep].targetRoute);
    _showOverlay();
  }

  void dismiss({bool saveProgress = true, bool completed = false, bool dismissed = false}) {
    _overlayEntry?.remove();
    _overlayEntry = null;

    final repo = _getRepo(null, _ref);
    if (saveProgress && _activeTourId != null && repo != null) {
      repo.saveTourProgress(
        _activeTourId!,
        completed: completed,
        dismissed: dismissed,
      );
    }

    _activeTourId = null;
    _currentStep = 0;
    _steps = [];
  }
}

/// Stateful Tour Overlay with lifecycle-aware asynchronous polling and smooth auto-scroll.
class _TourOverlayWidget extends StatefulWidget {
  const _TourOverlayWidget({
    required this.tourId,
    required this.stepIndex,
    required this.totalSteps,
    required this.step,
    required this.onNext,
    required this.onPrevious,
    required this.onSkip,
    required this.onFinish,
  });

  final String tourId;
  final int stepIndex;
  final int totalSteps;
  final InteractiveTourStep step;
  final VoidCallback onNext;
  final VoidCallback onPrevious;
  final VoidCallback onSkip;
  final VoidCallback onFinish;

  @override
  State<_TourOverlayWidget> createState() => _TourOverlayWidgetState();
}

class _TourOverlayWidgetState extends State<_TourOverlayWidget> {
  Rect? _targetRect;
  Timer? _pollTimer;
  int _settleChecks = 0;

  @override
  void initState() {
    super.initState();
    _resolveTarget();
  }

  @override
  void didUpdateWidget(covariant _TourOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.step != widget.step || oldWidget.stepIndex != widget.stepIndex) {
      _resolveTarget();
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _resolveTarget() {
    _pollTimer?.cancel();
    _settleChecks = 0;
    final key = widget.step.targetKey;
    if (key == null) {
      if (mounted) setState(() => _targetRect = null);
      return;
    }

    final initialCtx = key.currentContext;
    if (initialCtx != null) {
      _scrollToAndMeasure(initialCtx);
      return;
    }

    // Target not yet mounted (e.g. async FutureProvider loading) - poll up to 1.5s
    int attempts = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      attempts++;
      final ctx = key.currentContext;
      if (ctx != null) {
        timer.cancel();
        _scrollToAndMeasure(ctx);
      } else if (attempts >= 15) {
        timer.cancel();
        if (mounted) setState(() => _targetRect = null);
      }
    });
  }

  void _scrollToAndMeasure(BuildContext ctx) {
    try {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.35,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (mounted && ctx.mounted) {
          _measureTarget(ctx);
        }
      }).catchError((_) {
        if (mounted && ctx.mounted) {
          _measureTarget(ctx);
        }
      });
    } catch (_) {
      _measureTarget(ctx);
    }
  }

  void _measureTarget(BuildContext ctx) {
    if (!mounted) return;
    try {
      final renderBox = ctx.findRenderObject();
      if (renderBox is RenderBox && renderBox.hasSize) {
        final offset = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        final rect = Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height);
        if (rect != _targetRect) setState(() => _targetRect = rect);
        // Measured during a page / tab transition the position is still moving: measure again once it settles.
        if (_settleChecks++ < 3) {
          Future<void>.delayed(const Duration(milliseconds: 400), () {
            if (mounted && ctx.mounted) _measureTarget(ctx);
          });
        }
        return;
      }
    } catch (_) {}
    setState(() => _targetRect = null);
  }

  @override
  Widget build(BuildContext context) {
    final isLast = widget.stepIndex == widget.totalSteps - 1;
    final isFirst = widget.stepIndex == 0;

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent backdrop with cutout for target if available
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onSkip,
            child: _targetRect != null
                ? CustomPaint(
                    size: MediaQuery.of(context).size,
                    painter: _HolePainter(targetRect: _targetRect!),
                  )
                : Container(color: Colors.black.withValues(alpha: 0.65)),
          ),

          // Guidance Card positioned safely as direct child of Stack
          _buildCard(context, _targetRect, isFirst, isLast),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, Rect? targetRect, bool isFirst, bool isLast) {
    final screenSize = MediaQuery.of(context).size;
    final viewPadding = MediaQuery.of(context).viewPadding;
    double? top;
    double? bottom;

    if (targetRect != null) {
      final inViewport = targetRect.top >= viewPadding.top && targetRect.bottom <= screenSize.height - viewPadding.bottom;
      if (inViewport) {
        if (targetRect.center.dy < screenSize.height / 2) {
          // Target is in top half, show card below
          top = targetRect.bottom + 16;
        } else {
          // Target is in bottom half, show card above
          bottom = screenSize.height - targetRect.top + 16;
        }
      } else {
        top = screenSize.height * 0.25;
      }
    } else {
      top = screenSize.height * 0.25;
    }

    if (top != null) {
      top = top.clamp(viewPadding.top + 16, screenSize.height - 320);
    }
    if (bottom != null) {
      bottom = bottom.clamp(viewPadding.bottom + 16, screenSize.height - 320);
    }

    return Positioned(
      left: 16,
      right: 16,
      top: top,
      bottom: bottom,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Card(
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(color: AppColors.maroon, width: 1.5),
            ),
            color: context.palette.card,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Step counter & close
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.maroon.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? 'Step ${widget.stepIndex + 1} of ${widget.totalSteps}'
                              : 'ደረጃ ${widget.stepIndex + 1} ከ ${widget.totalSteps}',
                          style: context.sans(12, weight: FontWeight.bold, color: AppColors.maroon),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        onPressed: widget.onSkip,
                        tooltip: Localizations.localeOf(context).languageCode == 'en' ? 'Skip' : 'ዝለል',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Step Title
                  Text(
                    widget.step.titleFor(Localizations.localeOf(context).languageCode),
                    style: context.serif(18, weight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),

                  // Description
                  Text(
                    widget.step.descriptionFor(Localizations.localeOf(context).languageCode),
                    style: context.sans(14, color: context.palette.text),
                  ),

                  // Tip Box if present
                  if (widget.step.tipFor(Localizations.localeOf(context).languageCode) != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded, size: 18, color: AppColors.gold),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              widget.step.tipFor(Localizations.localeOf(context).languageCode)!,
                              style: context.sans(12, color: context.palette.text),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 18),

                  // Action buttons row
                  Row(
                    children: [
                      if (!isFirst)
                        OutlinedButton(
                          onPressed: widget.onPrevious,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                          child: Text(Localizations.localeOf(context).languageCode == 'en' ? 'Back' : 'ወደ ኋላ'),
                        ),
                      const Spacer(),
                      TextButton(
                        onPressed: widget.onSkip,
                        child: Text(Localizations.localeOf(context).languageCode == 'en' ? 'Skip' : 'ዝለል'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: isLast ? widget.onFinish : widget.onNext,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.maroon,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        child: Text(
                          Localizations.localeOf(context).languageCode == 'en'
                              ? (isLast ? 'Finish ✓' : 'Next →')
                              : (isLast ? 'አጠናቅቅ ✓' : 'ቀጣይ →'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HolePainter extends CustomPainter {
  _HolePainter({required this.targetRect});
  final Rect targetRect;

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final inflated = targetRect.inflate(6);
    final holePath = Path()
      ..addRRect(RRect.fromRectAndRadius(inflated, const Radius.circular(12)));

    final path = Path.combine(PathOperation.difference, backgroundPath, holePath);
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.65);
    canvas.drawPath(path, paint);

    // Glowing highlight border around target
    final borderPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawRRect(RRect.fromRectAndRadius(inflated, const Radius.circular(12)), borderPaint);
  }

  @override
  bool shouldRepaint(_HolePainter oldDelegate) => oldDelegate.targetRect != targetRect;
}
