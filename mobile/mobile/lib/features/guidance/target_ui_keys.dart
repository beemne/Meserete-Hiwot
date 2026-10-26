import 'package:flutter/material.dart';

/// Element types supported by the Target UI Key system.
enum TargetElementType {
  button,
  card,
  tab,
  field,
  toggle,
  banner,
  section,
  dialog,
  menuItem,
  badge,
}

/// Metadata description for an exact, stable Target UI Key in the application.
class TargetUiKey {
  const TargetUiKey({
    required this.key,
    required this.nameAm,
    required this.nameEn,
    required this.module,
    required this.route,
    required this.parentSection,
    required this.element,
    required this.elementType,
    required this.descriptionAm,
    required this.descriptionEn,
    this.requiredPermission,
    this.editingModeOnly = false,
    this.isConditional = false,
  });

  /// Unique, stable dot-separated key (e.g. `education.home.books.shortcut`).
  final String key;

  /// Human-readable title in Amharic.
  final String nameAm;

  /// Human-readable title in English.
  final String nameEn;

  /// Module scope: 'shared', 'mezmur', 'education', or 'admin'.
  final String module;

  /// Page route where the target lives (e.g. `/edu`, `/admin/attendance`).
  final String route;

  /// Parent section or category on the screen.
  final String parentSection;

  /// Exact UI element or control described.
  final String element;

  /// Element type (button, card, tab, field, toggle, banner, section, dialog, menuItem).
  final TargetElementType elementType;

  /// Purpose and description in Amharic.
  final String descriptionAm;

  /// Purpose and description in English.
  final String descriptionEn;

  /// Required permission string if restricted.
  final String? requiredPermission;

  /// Visible only when frontend editing mode is turned on.
  final bool editingModeOnly;

  /// Conditionally visible depending on user state or content availability.
  final bool isConditional;

  String localizedName(bool isEn) => isEn ? nameEn : nameAm;
  String localizedDescription(bool isEn) => isEn ? descriptionEn : descriptionAm;

  ValueKey<String> get valueKey => ValueKey(key);
}

/// Centralized, searchable, validated registry of Target UI Keys across all application screens.
class TargetUiKeyRegistry {
  TargetUiKeyRegistry._();

  static const List<TargetUiKey> all = [
    // =========================================================================
    // SHARED MODULE TARGETS
    // =========================================================================
    TargetUiKey(
      key: 'shared.home.greeting',
      nameAm: 'የመግቢያ ሰላምታ',
      nameEn: 'Hub Greeting Header',
      module: 'shared',
      route: '/hub',
      parentSection: 'Header',
      element: 'የተጠቃሚ ስም እና ሰላምታ ጽሑፍ',
      elementType: TargetElementType.section,
      descriptionAm: 'በመግቢያ ገጹ አናት ላይ የተጠቃሚውን ስም የሚያሳይ ሰላምታ።',
      descriptionEn: 'Greeting header displaying current user first name on Hub screen.',
    ),
    TargetUiKey(
      key: 'shared.home.promotion.carousel',
      nameAm: 'የማስታወቂያ እና ሁነቶች ካሮሴል',
      nameEn: 'Promotions Carousel',
      module: 'shared',
      route: '/hub',
      parentSection: 'Featured',
      element: 'ተንሸራታች የማስታወቂያ ባነሮች',
      elementType: TargetElementType.banner,
      descriptionAm: 'አዳዲስ ማስታወቂያዎችን እና የተፈቀዱ ሁነቶችን በቅደም ተከተል የሚያሳይ ባነር።',
      descriptionEn: 'Auto-scrolling carousel of active event banners and promotions.',
    ),
    TargetUiKey(
      key: 'shared.home.guidance.banner',
      nameAm: 'የመመሪያ መግቢያ ካርድ',
      nameEn: 'Guidance & Tour Card',
      module: 'shared',
      route: '/hub',
      parentSection: 'Onboarding',
      element: 'የመተግበሪያ ገለጻ እና መመሪያ መክፈቻ',
      elementType: TargetElementType.card,
      descriptionAm: 'ተጠቃሚዎች የመተግበሪያውን አጠቃቀም በቀላሉ እንዲረዱ የሚያግዝ የመመሪያ መግቢያ።',
      descriptionEn: 'Quick onboarding card to launch the interactive welcome tour.',
    ),
    TargetUiKey(
      key: 'shared.home.module_selector.mezmur',
      nameAm: 'የመዝሙር ክፍል መምረጫ ካርድ',
      nameEn: 'Mezmur Module Selector',
      module: 'shared',
      route: '/hub',
      parentSection: 'Module Selector',
      element: 'ወደ መዝሙር ክፍል የሚያስገባ ዋና ካርድ',
      elementType: TargetElementType.card,
      descriptionAm: 'ተጠቃሚውን በቀጥታ ወደ መዝሙራት፣ ዜማዎች እና ግጥሞች ክፍል ያደርሳል።',
      descriptionEn: 'Primary entry card to enter the Mezmur module.',
    ),
    TargetUiKey(
      key: 'shared.home.module_selector.education',
      nameAm: 'የትምህርት ክፍል መምረጫ ካርድ',
      nameEn: 'Education Module Selector',
      module: 'shared',
      route: '/hub',
      parentSection: 'Module Selector',
      element: 'ወደ ትምህርት ክፍል የሚያስገባ ዋና ካርድ',
      elementType: TargetElementType.card,
      descriptionAm: 'ተጠቃሚውን በቀጥታ ወደ ሰንበት ት/ቤት ትምህርቶች እና ኮርሶች ክፍል ያደርሳል።',
      descriptionEn: 'Primary entry card to enter the Education module.',
    ),
    TargetUiKey(
      key: 'shared.topbar.logo_hub',
      nameAm: 'የመተግበሪያው አርማ (ወደ Hub መመለሻ)',
      nameEn: 'App Logo (Return to Hub)',
      module: 'shared',
      route: '/hub',
      parentSection: 'App Top Bar',
      element: 'የመተግበሪያው አርማ እና ስም',
      elementType: TargetElementType.button,
      descriptionAm: 'ከማንኛውም ገጽ በቀጥታ ወደ ዋናው ሞጁል መምረጫ (Hub) ለመመለስ ያገለግላል።',
      descriptionEn: 'Top bar logo and title button that navigates back to the Module Selector Hub.',
    ),
    TargetUiKey(
      key: 'shared.topbar.search',
      nameAm: 'የፍለጋ ምልክት',
      nameEn: 'Contextual Search Button',
      module: 'shared',
      route: '/hub',
      parentSection: 'App Top Bar',
      element: 'የፍለጋ አይኮን ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'በትምህርት ክፍል ውስጥ ትምህርቶችን፣ በመዝሙር ውስጥ ደግሞ መዝሙራትን ይፈልጋል።',
      descriptionEn: 'Context-aware search button in top bar (searches lessons in Edu, songs in Mezmur).',
    ),
    TargetUiKey(
      key: 'shared.topbar.notifications',
      nameAm: 'የማሳወቂያዎች ምልክት',
      nameEn: 'Notifications Button',
      module: 'shared',
      route: '/hub',
      parentSection: 'App Top Bar',
      element: 'ያልተነበቡ ማሳወቂያዎች ቁጥር ያለበት ደወል',
      elementType: TargetElementType.button,
      descriptionAm: 'ሁሉንም የተላኩ ማሳወቂያዎች እና መልዕክቶች ዝርዝር ይከፍታል።',
      descriptionEn: 'Notifications bell button with unread badge counter.',
    ),
    TargetUiKey(
      key: 'shared.topbar.theme_toggle',
      nameAm: 'የቀለም ገጽታ መቀየሪያ',
      nameEn: 'Theme Toggle Button',
      module: 'shared',
      route: '/hub',
      parentSection: 'App Top Bar',
      element: 'የብርሃንና ጨለማ ገጽታ መቀየሪያ ምልክት',
      elementType: TargetElementType.button,
      descriptionAm: 'የመተግበሪያውን እይታ በብርሃን ወይም በጨለማ ገጽታ መካከል ይቀይራል።',
      descriptionEn: 'Toggle button between light and dark visual themes.',
    ),
    TargetUiKey(
      key: 'shared.topbar.sync_status',
      nameAm: 'የማመሳሰል እና መስመር ላይ/ውጭ አመልካች',
      nameEn: 'Sync & Network Indicator',
      module: 'shared',
      route: '/hub',
      parentSection: 'App Top Bar',
      element: 'የኔትወርክ እና የማመሳሰል ሁኔታ አመልካች ምልክት',
      elementType: TargetElementType.badge,
      descriptionAm: 'የመሣሪያውን የመስመር ላይ/ውጭ ሁኔታ እና ያልተላኩ ለውጦች ብዛት ያሳያል።',
      descriptionEn: 'Status indicator badge showing online/offline connectivity and pending sync mutations.',
    ),
    TargetUiKey(
      key: 'shared.settings.user_card',
      nameAm: 'የአባል መታወቂያ ካርድ ዝርዝር',
      nameEn: 'User Profile & QR Card',
      module: 'shared',
      route: '/settings',
      parentSection: 'User Info',
      element: 'የተጠቃሚ ፎቶ፣ ስም እና ስልክ ካርድ',
      elementType: TargetElementType.card,
      descriptionAm: 'የተጠቃሚውን የግል መረጃ እና ዲጂታል የQR መታወቂያ ካርድ ይከፍታል።',
      descriptionEn: 'Card opening personal user details, membership ID, and digital QR card.',
    ),
    TargetUiKey(
      key: 'shared.settings.attendance',
      nameAm: 'የእኔ ክትትል የቀን መቁጠሪያ',
      nameEn: 'My Attendance Calendar',
      module: 'shared',
      route: '/settings',
      parentSection: 'Member Services',
      element: 'የክትትል ቀን መቁጠሪያ ረድፍ',
      elementType: TargetElementType.menuItem,
      descriptionAm: 'የተገኙባቸው እና የቀሩባቸው ቀናት የቀን መቁጠሪያ ታሪክ።',
      descriptionEn: 'Settings tile leading to personal attendance calendar history.',
    ),
    TargetUiKey(
      key: 'shared.settings.chat',
      nameAm: 'የክፍል ውይይቶች (Chat)',
      nameEn: 'Department Chat',
      module: 'shared',
      route: '/settings',
      parentSection: 'Member Services',
      element: 'የመልእክት መላላኪያ ረድፍ',
      elementType: TargetElementType.menuItem,
      descriptionAm: 'የመምሪያ እና የአባላት መልእክት መላላኪያ ገጽ ይከፍታል።',
      descriptionEn: 'Settings tile opening department chat rooms and private threads.',
    ),
    TargetUiKey(
      key: 'shared.settings.language',
      nameAm: 'የቋንቋ ምርጫ',
      nameEn: 'Language Selection',
      module: 'shared',
      route: '/settings',
      parentSection: 'App Preferences',
      element: 'የቋንቋ መምረጫ ረድፍ',
      elementType: TargetElementType.menuItem,
      descriptionAm: 'የመተግበሪያውን ቋንቋ በአማርኛ ወይም በእንግሊዝኛ መካከል ለመቀየር።',
      descriptionEn: 'Language configuration tile (Amharic / English).',
    ),
    TargetUiKey(
      key: 'shared.settings.biometric_lock',
      nameAm: 'የጣት አሻራ መቆለፊያ',
      nameEn: 'Biometric Lock Switch',
      module: 'shared',
      route: '/settings',
      parentSection: 'Security',
      element: 'የጣት አሻራ ማብሪያ/ማጥፊያ',
      elementType: TargetElementType.toggle,
      descriptionAm: 'መተግበሪያው በስልክ የጣት አሻራ ወይም የፊት ገጽታ እንዲቆለፍ ያደርጋል።',
      descriptionEn: 'Switch to enable biometric authentication on app startup.',
    ),
    TargetUiKey(
      key: 'shared.settings.guidance_center',
      nameAm: 'የመመሪያ ማዕከል',
      nameEn: 'Guidance Center',
      module: 'shared',
      route: '/settings',
      parentSection: 'Help & Guidance',
      element: 'የመመሪያ ማዕከል ረድፍ',
      elementType: TargetElementType.menuItem,
      descriptionAm: 'ሁሉንም የመተግበሪያውን አጠቃቀም መመሪያዎች እና ተደጋጋሚ ጥያቄዎች ያቀርባል።',
      descriptionEn: 'Settings tile leading to centralized in-app help articles and tutorials.',
    ),
    TargetUiKey(
      key: 'shared.settings.sign_out',
      nameAm: 'ከመለያ መውጫ ቁልፍ',
      nameEn: 'Sign Out Button',
      module: 'shared',
      route: '/settings',
      parentSection: 'Account',
      element: 'የመውጫ ቀይ ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'ያልተመሳሰሉ ስራዎች ካሉ አስጠንቅቆ ከመለያ ለመውጣት ያገለግላል።',
      descriptionEn: 'Sign-out button with protection dialog preventing unsynced data loss.',
    ),

    // =========================================================================
    // MEZMUR MODULE TARGETS
    // =========================================================================
    TargetUiKey(
      key: 'mezmur.home.header',
      nameAm: 'የመዝሙር ክፍል አርዕስት',
      nameEn: 'Mezmur Header Title',
      module: 'mezmur',
      route: '/home',
      parentSection: 'Header',
      element: 'የከበሮ አርማ እና የመዝሙር ርዕስ',
      elementType: TargetElementType.section,
      descriptionAm: 'የመዝሙር ሞጁል መነሻ ገጽ አርዕስት።',
      descriptionEn: 'Mezmur section title and liturgical drum icon.',
    ),
    TargetUiKey(
      key: 'mezmur.home.editing_pen.toggle',
      nameAm: 'የመዝሙር ማስተካከያ ብዕር',
      nameEn: 'Mezmur Editing Pen Toggle',
      module: 'mezmur',
      route: '/home',
      parentSection: 'Header',
      element: 'የፊት ለፊት ማስተካከያ ሁነታ ማብሪያ/ማጥፊያ',
      elementType: TargetElementType.toggle,
      descriptionAm: 'የተፈቀደላቸው አስተዳዳሪዎች መዝሙራትንና ምድቦችን በቀጥታ እንዲያስተካክሉ ያደርጋል።',
      descriptionEn: 'Toggle to activate frontend content editing mode for authorized admins.',
      requiredPermission: 'mezmurs.update',
      editingModeOnly: false,
    ),
    TargetUiKey(
      key: 'mezmur.home.categories.shortcut',
      nameAm: 'የመዝሙር ምድቦች አቋራጭ',
      nameEn: 'Mezmur Categories Shortcut',
      module: 'mezmur',
      route: '/home',
      parentSection: 'Categories',
      element: 'ሁሉንም ምድቦች አሳይ ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'ሁሉንም የበዓላት፣ የዘመናት እና የአርእስት ምድቦች ዝርዝር ይከፍታል።',
      descriptionEn: 'Shortcut button opening the complete hymn categories grid.',
    ),
    TargetUiKey(
      key: 'mezmur.home.today_study',
      nameAm: 'የዕለቱ የመዝሙር ጥናት',
      nameEn: 'Today Study Mezmurs',
      module: 'mezmur',
      route: '/home',
      parentSection: 'Content',
      element: 'ለዛሬ የተመረጡ መዝሙራት ዝርዝር',
      elementType: TargetElementType.section,
      descriptionAm: 'በየዕለቱ ለጥናት የተመደቡ መዝሙራትን በቅድሚያ ያሳያል።',
      descriptionEn: 'Section displaying daily designated study hymns.',
    ),
    TargetUiKey(
      key: 'mezmur.player.mini_player',
      nameAm: 'የድምጽ ማጫወቻ አነስተኛ አሞሌ',
      nameEn: 'Mini Audio Player Bar',
      module: 'mezmur',
      route: '/home',
      parentSection: 'Playback',
      element: 'የሚጫወተውን መዝሙር ርዕስና መቆጣጠሪያ የሚያሳይ አሞሌ',
      elementType: TargetElementType.section,
      descriptionAm: 'በማንኛውም ገጽ ላይ ሳሉ ድምጽን ለማቆም፣ ለማስቀጠል ወይም ሙሉ ማጫወቻውን ለመክፈት ያገለግላል።',
      descriptionEn: 'Persistent mini player bar for quick audio control and playback status.',
    ),
    TargetUiKey(
      key: 'mezmur.library.downloads_tab',
      nameAm: 'ከመስመር ውጭ የወረዱ መዝሙራት',
      nameEn: 'Mezmur Downloads Tab',
      module: 'mezmur',
      route: '/library',
      parentSection: 'My Library',
      element: 'የወረዱ መዝሙራት ትር',
      elementType: TargetElementType.tab,
      descriptionAm: 'ያለ ኢንተርኔት ግንኙነት በማንኛውም ጊዜ የሚደመጡ መዝሙራትን ያሳያል።',
      descriptionEn: 'Tab showing downloaded hymns available for offline playback.',
    ),
    TargetUiKey(
      key: 'mezmur.programs.alarm_toggle',
      nameAm: 'የመርሐ ግብር 30 ደቂቃ ማንቂያ',
      nameEn: 'Program 30-Min Reminder Alarm',
      module: 'mezmur',
      route: '/programs',
      parentSection: 'Programs',
      element: 'የደወል ማንቂያ ምልክት',
      elementType: TargetElementType.button,
      descriptionAm: 'መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ በድምጽ እንዲያስታውስዎት ያደርጋል።',
      descriptionEn: 'Alarm toggle button setting a persistent local notification 30 minutes before program start.',
    ),

    // =========================================================================
    // EDUCATION MODULE TARGETS
    // =========================================================================
    TargetUiKey(
      key: 'education.home.header',
      nameAm: 'የትምህርት ክፍል አርዕስት',
      nameEn: 'Education Header Title',
      module: 'education',
      route: '/edu',
      parentSection: 'Header',
      element: 'የትምህርት አርማ እና ርዕስ',
      elementType: TargetElementType.section,
      descriptionAm: 'የትምህርት ሞጁል መነሻ ገጽ አርዕስት።',
      descriptionEn: 'Education section title and lectern icon.',
    ),
    TargetUiKey(
      key: 'education.home.editing_pen.toggle',
      nameAm: 'የትምህርት ማስተካከያ ብዕር',
      nameEn: 'Education Editing Pen Toggle',
      module: 'education',
      route: '/edu',
      parentSection: 'Header',
      element: 'የትምህርት ይዘቶችን በቀጥታ ማስተካከያ ማብሪያ/ማጥፊያ',
      elementType: TargetElementType.toggle,
      descriptionAm: 'ምድቦችን፣ ኮርሶችንና ትምህርቶችን ከፊት ለፊት ለማስተካከል ያገለግላል።',
      descriptionEn: 'Toggle enabling frontend curriculum editing mode for authorized educators.',
      requiredPermission: 'education.content',
      editingModeOnly: false,
    ),
    TargetUiKey(
      key: 'education.home.learn.shortcut',
      nameAm: 'ተማር (የትምህርት ዓይነቶች አቋራጭ)',
      nameEn: 'Learn Navigation Shortcut',
      module: 'education',
      route: '/edu',
      parentSection: 'Quick Navigation',
      element: 'ወደ ትምህርቶች መማሪያ የሚያደርስ ፈጣን ካርድ',
      elementType: TargetElementType.button,
      descriptionAm: 'ሁሉንም የትምህርት ምድቦች፣ ዓይነቶች እና ምዕራፎች ለመክፈት።',
      descriptionEn: 'Quick access navigation button to the curriculum learning screen.',
    ),
    TargetUiKey(
      key: 'education.home.books.shortcut',
      nameAm: 'የትምህርት መጻሕፍት (ቤተ መጻሕፍት አቋራጭ)',
      nameEn: 'Education Books Shortcut',
      module: 'education',
      route: '/edu',
      parentSection: 'Quick Navigation',
      element: 'ወደ ትምህርት መጻሕፍት የሚያደርስ ፈጣን ካርድ',
      elementType: TargetElementType.button,
      descriptionAm: 'የትምህርት ዲጂታል ፒዲኤፎችን እና የወረቀት መጻሕፍት ውሰሳን ይከፍታል።',
      descriptionEn: 'Direct shortcut opening the Education physical and digital library catalog.',
    ),
    TargetUiKey(
      key: 'education.home.progress.shortcut',
      nameAm: 'እድገት (ውጤቶችና ክትትል አቋራጭ)',
      nameEn: 'Progress Navigation Shortcut',
      module: 'education',
      route: '/edu',
      parentSection: 'Quick Navigation',
      element: 'የትምህርት እድገትን የሚያሳይ ፈጣን ካርድ',
      elementType: TargetElementType.button,
      descriptionAm: 'የተማሪውን የትምህርት አጠናቀቅ፣ የፈተና ውጤቶች እና የምስክር ወረቀቶች ያሳያል።',
      descriptionEn: 'Quick access navigation button to academic progress and assessment results.',
    ),
    TargetUiKey(
      key: 'education.home.more.shortcut',
      nameAm: 'ተጨማሪ (የትምህርት አገልግሎቶች አቋራጭ)',
      nameEn: 'Education More Shortcut',
      module: 'education',
      route: '/edu',
      parentSection: 'Quick Navigation',
      element: 'ተጨማሪ የትምህርት አማራጮች ካርድ',
      elementType: TargetElementType.button,
      descriptionAm: 'የትምህርት ጉዞ፣ ምዝገባ፣ ጥያቄዎች እና የኮርስ አስተዳደር መግቢያ።',
      descriptionEn: 'Shortcut opening additional education services, registrations, and courses.',
    ),
    TargetUiKey(
      key: 'education.home.add_subject_button',
      nameAm: 'አዲስ የትምህርት ዓይነት መጨመሪያ ቁልፍ',
      nameEn: 'Add Subject Button',
      module: 'education',
      route: '/edu',
      parentSection: 'Floating Actions',
      element: 'አዲስ የትምህርት ዓይነት መመዝገቢያ ተንሳፋፊ ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'በተመረጠ ምድብ ስር አዲስ የትምህርት ዓይነት ለመፍጠር ያገለግላል።',
      descriptionEn: 'FAB button to create and register a new curriculum subject.',
      requiredPermission: 'education.content',
      editingModeOnly: true,
    ),
    TargetUiKey(
      key: 'education.home.add_category_button',
      nameAm: 'አዲስ የትምህርት ምድብ መጨመሪያ ቁልፍ',
      nameEn: 'Add Category Button',
      module: 'education',
      route: '/edu',
      parentSection: 'Floating Actions',
      element: 'አዲስ ምድብ መፍጠሪያ ተንሳፋፊ ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'አዳዲስ የትምህርት ክፍፍል ምድቦችን ለመፍጠር ያገለግላል።',
      descriptionEn: 'FAB button to add a new top-level education category.',
      requiredPermission: 'education.content',
      editingModeOnly: true,
    ),
    TargetUiKey(
      key: 'education.subject.lessons.add_button',
      nameAm: 'አዲስ ትምህርት መጨመሪያ ቁልፍ',
      nameEn: 'Add Lesson Button',
      module: 'education',
      route: '/edu/content/subject/:id',
      parentSection: 'Subject Editor',
      element: 'በትምህርት ዓይነት ስር አዲስ ትምህርት መፍጠሪያ',
      elementType: TargetElementType.button,
      descriptionAm: 'ጽሑፍ፣ ምስል፣ ፒዲኤፍ እና የድምጽ ፋይል የያዘ አዲስ ትምህርት ይጨምራል።',
      descriptionEn: 'Button to add a new lesson with rich media, PDFs, or audio inside a subject.',
      requiredPermission: 'education.content',
      editingModeOnly: true,
    ),
    TargetUiKey(
      key: 'education.subject.quizzes.add_button',
      nameAm: 'አዲስ ጥያቄ/ፈተና መጨመሪያ ቁልፍ',
      nameEn: 'Add Quiz Button',
      module: 'education',
      route: '/edu/content/subject/:id',
      parentSection: 'Subject Editor',
      element: 'አዲስ ፈተና መፍጠሪያ ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'ምርጫና ጽሑፍ ጥያቄዎችን የያዘ አዲስ ፈተና ለመፍጠር ያገለግላል።',
      descriptionEn: 'Button to create, structure, and attach a new quiz or assessment to the subject.',
      requiredPermission: 'education.content',
      editingModeOnly: true,
    ),
    TargetUiKey(
      key: 'education.scores.activity_report',
      nameAm: 'የውጤትና እንቅስቃሴ ሪፖርት ገጽ',
      nameEn: 'Score & Activity Report Table',
      module: 'education',
      route: '/edu/admin/scores',
      parentSection: 'Academic Reports',
      element: 'የተማሪዎች ውጤትና የእንቅስቃሴ መረጃ ሰንጠረዥ',
      elementType: TargetElementType.section,
      descriptionAm: 'የእያንዳንዱን ክፍል ተማሪዎች የተሟላ የውጤት ዝርዝር እና የትምህርት ተሳትፎ ያሳያል።',
      descriptionEn: 'Real metrics and activity report table per class and student enrollment.',
      requiredPermission: 'education.manage',
    ),
    TargetUiKey(
      key: 'education.admin.library.physical_circulation',
      nameAm: 'የትምህርት መጻሕፍት ውሰሳ አስተዳደር',
      nameEn: 'Physical Library Circulation Manager',
      module: 'education',
      route: '/admin/library/circulation',
      parentSection: 'Library Admin',
      element: 'የመጻሕፍት ባርኮድ መቃኛ እና የውሰሳ መመዝገቢያ',
      elementType: TargetElementType.section,
      descriptionAm: 'የትምህርት መጻሕፍትን ማበደር፣ መረከብ እና ቅጣት መቆጣጠሪያ።',
      descriptionEn: 'Education physical library circulation desk (barcode scan, loans, returns).',
      requiredPermission: 'borrowing.manage',
    ),

    // =========================================================================
    // ADMIN MODULE TARGETS
    // =========================================================================
    TargetUiKey(
      key: 'admin.home.search_box',
      nameAm: 'የአስተዳዳሪ መሣሪያዎች መፈለጊያ',
      nameEn: 'Admin Tools Search Box',
      module: 'admin',
      route: '/admin',
      parentSection: 'Search',
      element: 'የመሣሪያዎችና ካርዶች መፈለጊያ ሳጥን',
      elementType: TargetElementType.field,
      descriptionAm: 'የአስተዳዳሪ ካርዶችን በስም በፍጥነት ፈልጎ ለመክፈት።',
      descriptionEn: 'Instant search bar filtering admin tools and operational cards.',
    ),
    TargetUiKey(
      key: 'admin.home.scope_filter',
      nameAm: 'የሞጁል አስተዳደር ማጣሪያ',
      nameEn: 'Admin Module Scope Filter',
      module: 'admin',
      route: '/admin',
      parentSection: 'Filter',
      element: 'የጋራ፣ የመዝሙር እና የትምህርት አስተዳደር መለያ ቁልፎች',
      elementType: TargetElementType.tab,
      descriptionAm: 'የአስተዳዳሪ ካርዶችን በጋራ፣ በመዝሙር እና በትምህርት ዘርፍ ለይቶ ለማሳየት።',
      descriptionEn: 'Segmented filter chips scoping admin cards to Shared, Mezmur, or Education.',
    ),
    TargetUiKey(
      key: 'admin.attendance.start_session',
      nameAm: 'የክትትል መመዝገቢያ መጀመሪያ ቁልፍ',
      nameEn: 'Start Attendance Session Button',
      module: 'admin',
      route: '/admin/attendance',
      parentSection: 'Attendance Taking',
      element: 'ክትትል ጀምር የሚል ዋና ቁልፍ',
      elementType: TargetElementType.button,
      descriptionAm: 'የተፈቀደለት መዝጋቢ ክትትል ከመጀመሩ 15 ደቂቃ በፊት ክፍለ ጊዜውን እንዲጀምር ያደርጋል።',
      descriptionEn: 'Start Attendance action activating authorized taker session window 15 min prior.',
      requiredPermission: 'attendance.manage',
    ),
    TargetUiKey(
      key: 'admin.attendance.qr_scanner',
      nameAm: 'የአባላት QR መታወቂያ መቃኛ ካሜራ',
      nameEn: 'Member Attendance QR Scanner',
      module: 'admin',
      route: '/admin/attendance',
      parentSection: 'Attendance Taking',
      element: 'የስልክ ካሜራ መቃኛ መስኮት',
      elementType: TargetElementType.button,
      descriptionAm: 'የአባላትን QR ኮድ በማንበብ ትክክለኛውን ሰዓት እና መገኘትን በሰከንድ ውስጥ ይመዘግባል።',
      descriptionEn: 'High-speed camera scanner recording verified attendance timestamps from member QR code.',
      requiredPermission: 'attendance.manage',
    ),
    TargetUiKey(
      key: 'admin.attendance.signature_pad',
      nameAm: 'የአባል ፊርማ ማኖሪያ ሰሌዳ',
      nameEn: 'Attendance Signature Pad',
      module: 'admin',
      route: '/admin/attendance',
      parentSection: 'Attendance Taking',
      element: 'የስክሪን ላይ ፊርማ ማኖሪያ መስኮት',
      elementType: TargetElementType.dialog,
      descriptionAm: 'በእጅ ወይም በQR የተመዘገበ አባል መገኘቱን በፊርማ የሚያረጋግጥበት ሰሌዳ።',
      descriptionEn: 'Digital signature capture pad securing attendance confirmation.',
      requiredPermission: 'attendance.manage',
    ),
  ];

  /// Find a registered key by exact identifier.
  static TargetUiKey? find(String key) {
    for (final item in all) {
      if (item.key == key) return item;
    }
    return null;
  }

  /// Search registry by query, module, and optional element type.
  static List<TargetUiKey> search(
    String query, {
    String? module,
    TargetElementType? elementType,
  }) {
    final q = query.trim().toLowerCase();
    return all.where((item) {
      if (module != null && module.isNotEmpty && module != 'all' && item.module != module) {
        return false;
      }
      if (elementType != null && item.elementType != elementType) {
        return false;
      }
      if (q.isEmpty) return true;
      return item.key.toLowerCase().contains(q) ||
          item.nameAm.toLowerCase().contains(q) ||
          item.nameEn.toLowerCase().contains(q) ||
          item.route.toLowerCase().contains(q) ||
          item.parentSection.toLowerCase().contains(q) ||
          item.descriptionAm.toLowerCase().contains(q) ||
          item.descriptionEn.toLowerCase().contains(q);
    }).toList();
  }

  /// Automated validation verifying:
  /// - No duplicate keys
  /// - Valid key formatting (lowercase dot notation)
  /// - Non-empty names and routes
  /// - Valid element types
  static List<String> validate() {
    final errors = <String>[];
    final seenKeys = <String>{};

    for (final item in all) {
      if (seenKeys.contains(item.key)) {
        errors.add('Duplicate Target UI Key detected: "${item.key}"');
      }
      seenKeys.add(item.key);

      if (!RegExp(r'^[a-z0-9_]+(\.[a-z0-9_]+)+$').hasMatch(item.key)) {
        errors.add('Invalid key naming format (must be dot-separated snake_case): "${item.key}"');
      }

      if (item.nameAm.trim().isEmpty || item.nameEn.trim().isEmpty) {
        errors.add('Missing localized name in key: "${item.key}"');
      }

      if (item.route.trim().isEmpty || !item.route.startsWith('/')) {
        errors.add('Invalid route in key "${item.key}": "${item.route}"');
      }
    }

    return errors;
  }
}
