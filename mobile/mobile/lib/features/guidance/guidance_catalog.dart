import '../../models/guidance.dart';
import '../../models/user.dart';

/// Exhaustive in-app Guidance Catalog providing rich, contextual help for every screen,
/// tab, dialog, and major function across both member-facing and administrative interfaces.
class GuidanceCatalog {
  GuidanceCatalog._();

  static GuidanceArticle? getForScreen(String screenRoute, {AppUser? user}) {
    final normalized = screenRoute.split('?').first;

    // Check exact match first
    var match = _registry[normalized];

    // If no direct match, check parent route prefix (e.g., /programs/12 -> /programs, /admin/users/4 -> /admin/users)
    if (match == null) {
      final parts = normalized.split('/').where((p) => p.isNotEmpty).toList();
      while (parts.length > 1) {
        parts.removeLast();
        final parent = '/${parts.join('/')}';
        if (_registry.containsKey(parent)) {
          match = _registry[parent];
          break;
        }
      }
    }

    // Role and permission gating
    if (match != null) {
      if (match.targetRole == 'admin' && !(user?.isAdmin ?? false)) {
        return null;
      }
      if (match.requiredPermission != null &&
          !(user?.isAccountAdmin ?? false) &&
          !(user?.can(match.requiredPermission!) ?? false)) {
        return null;
      }
    }

    return match;
  }

  static List<GuidanceArticle> getAllArticles({AppUser? user}) {
    return _registry.values.where((a) {
      if (a.targetRole == 'admin' && !(user?.isAdmin ?? false)) return false;
      if (a.requiredPermission != null &&
          !(user?.isAccountAdmin ?? false) &&
          !(user?.can(a.requiredPermission!) ?? false)) {
        return false;
      }
      return true;
    }).toList();
  }

  static List<GuidanceArticle> get articles => _registry.values.toList();

  static final Map<String, GuidanceArticle> _registry = {
    // 1. HUB / HOME SUPER-APP
    '/hub': const GuidanceArticle(
      id: 1,
      slug: 'welcome-onboarding',
      category: 'getting_started',
      title: 'የመተግበሪያው ማዕከል (Hub Home)',
      summary: 'የመሠረተ ሕይወት መተግበሪያ ዋና ማዕከል እና አገልግሎቶች መሸጋገሪያ።',
      content:
          'የመተግበሪያው ማዕከል (Hub) ሁሉንም የሰንበት ት/ቤት አገልግሎቶች በአንድ ስክሪን ላይ የሚያስተሳስር መነሻ ነው። ከዚህ ገጽ በቀጥታ ወደ መዝሙር እና ትምህርት ክፍሎች መሸጋገር፣ የዛሬውን የመገኘት ሁኔታ መመልከት እና መመሪያዎችን መክፈት ይችላሉ።',
      targetRole: 'all',
      targetScreen: '/hub',
      tourId: 'welcome_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የመዝሙር ክፍል (Mezmur)',
          description: 'በድምጽ እና በግጥም የተዘጋጁ መዝሙራትን ለማዳመጥ እና ለማውረድ የመዝሙር ካርዱን ይጫኑ።',
          tip: 'ከላይ ያለውን ትልቅ የመዝሙር ካርድ በመጫን በቀጥታ ይከፈታል።',
          targetKey: 'hub-mezmur-card',
        ),
        GuidanceStep(
          step: 2,
          title: 'የትምህርት ክፍል (Education)',
          description: 'የሰንበት ት/ቤት ክፍሎችን፣ ኮርሶችን እና የትምህርት መጻሕፍትን ለመከታተል የትምህርት ካርዱን ይጫኑ።',
          tip: 'አዲስ ተማሪ ከሆኑ ምዝገባዎን እዚሁ ማከናወን ይችላሉ።',
          targetKey: 'hub-education-card',
        ),
        GuidanceStep(
          step: 3,
          title: 'የአባልነት QR መታወቂያ',
          description: 'በማንኛውም ጊዜ ወደ ቅንብሮች ገጽ «ስለ እኔ» በመሄድ ዲጂታል መታወቂያዎን ማሳየት ይችላሉ።',
          tip: 'በአቴንዳንስ ወቅት መዝጋቢዎች ካርድዎን እንዲቃኙ ያድርጉ።',
        ),
      ],
      tips: [
        'በHub ገጽ ላይ የላይኛው ካርድ ወደሚፈልጉት ክፍል በቀላሉ ያሸጋግርዎታል።',
        'የበስተጀርባ ምልክቱ እርስዎ ባሉበት የሰንበት ት/ቤት ክፍል መሰረት ይስተካከላል።',
      ],
      faqItems: [
        GuidanceFaq(
          question: 'ወደ መዝሙር ወይም ትምህርት እንዴት እሸጋገራለሁ?',
          answer: 'በHub ገጽ ላይ የሚታዩትን ሁለቱን ዋና ካርዶች በመጫን በቀላሉ ወደሚፈልጉት ክፍል መግባት ይችላሉ።',
        ),
        GuidanceFaq(
          question: 'የመተግበሪያው የመግቢያ ጉብኝት እንዴት ይጀምራል?',
          answer: 'በመመሪያ ማዕከል ውስጥ ገብተው «ጉብኝት ጀምር» የሚለውን በመጫን በማንኛውም ጊዜ ማየት ይችላሉ።',
        ),
      ],
    ),

    // 2. MEZMURS HOME
    '/home': const GuidanceArticle(
      id: 2,
      slug: 'mezmurs-and-audio',
      category: 'mezmurs',
      title: 'መዝሙራት እና የድምጽ ማጫወቻ (Mezmurs)',
      summary: 'መዝሙራትን በድምጽ ማዳመጥ፣ ግጥሞችን ማንበብ እና ከመስመር ውጭ ማውረድ።',
      content:
          'በመዝሙር ክፍል ውስጥ በዘመናት እና በበዓላት የተከፋፈሉ መዝሙራትን በድምጽ እና በግጥም ያገኛሉ። የድምጽ ማጫወቻው ስልክዎ ተቆልፎም ከበስተጀርባ (Background) ይጫወታል፤ ግጥሞችንም ያለ ኢንተርኔት ማንበብ ይችላሉ።',
      targetRole: 'all',
      targetScreen: '/home',
      tourId: 'mezmur_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የዕለቱ መዝሙራት',
          description: 'ለዕለቱ እና ለበዓሉ የተመረጡ መዝሙራትን በዋናው ገጽ የላይኛው ክፍል ያግኙ።',
          tip: 'መዝሙሩን በመጫን ወዲያውኑ ማዳመጥ መጀመር ይችላሉ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መፈለጊያ (Search)',
          description: 'በመዝሙር ርዕስ፣ በግጥም ወይም በምድብ ፈጣን ፍለጋ ለማካሄድ የመፈለጊያውን ምልክት ይጫኑ።',
          tip: 'በግዕዝም ሆነ በአማርኛ ፊደላት መፈለግ ይቻላል።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ከመስመር ውጭ ማውረድ (Download)',
          description: 'የማውረጃ ምልክቱን በመጫን መዝሙሩን ያለ ኢንተርኔት ወደሚያዳምጡበት «የእኔ መዝሙራት» ክፍል ያስቀምጡ።',
          tip: 'የወረዱ መዝሙራት በ«የእኔ መዝሙራት» ውስጥ «የወረዱ» በሚለው ዝርዝር ስር ይገኛሉ።',
        ),
      ],
      tips: [
        'የድምጽ ማጫወቻውን ወደ ላይ በመጎተት ሙሉውን የድምጽ እና የግጥም ገጽ መክፈት ይችላሉ።',
        'የግጥሙን የፊደል መጠን በቅንብሮች ውስጥ ማስተካከል ይችላሉ።',
      ],
      faqItems: [
        GuidanceFaq(
          question: 'መዝሙራትን ያለ ኢንተርኔት ማዳመጥ ይቻላል?',
          answer: 'አዎ! አስቀድመው ወደ ስልክዎ ያወረዷቸውን መዝሙራት ያለ ምንም ኢንተርኔት ማዳመጥ ይችላሉ።',
        ),
      ],
    ),

    // 3. MEZMUR CATEGORIES
    '/home/categories': const GuidanceArticle(
      id: 3,
      slug: 'mezmur-categories',
      category: 'mezmurs',
      title: 'የመዝሙር ምድቦች (Mezmur Categories)',
      summary: 'በዘመናት፣ በበዓላት እና በአርእስት የተከፋፈሉ የመዝሙር አቃፊዎች።',
      content:
          'የኦርቶዶክስ ተዋሕዶ ቤተክርስቲያን የመዝሙር ወቅቶችን (ዘመነ ዮሐንስ፣ መስቀል፣ ልደት፣ ጥምቀት፣ ፋሲካ፣ ወዘተ) መሰረት ያደረጉ ምድቦች ዝርዝር። እያንዳንዱ ምድብ በውስጡ በርካታ መዝሙራትን ይይዛል።',
      targetRole: 'all',
      targetScreen: '/home/categories',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ምድብ መምረጥ',
          description: 'የሚፈልጉትን የበዓል ወይም የወቅት ምድብ በመጫን በውስጡ ያሉትን መዝሙራት ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ንዑሳን ምድቦች',
          description: 'አንዳንድ ምድቦች (ለምሳሌ «የመስቀል» ስር የጠዋት፣ የማታ) ንዑሳን ክፍሎች አሏቸው።',
        ),
      ],
      tips: ['ወቅታዊ መዝሙራትን በቅድሚያ ለማግኘት የዛሬ በዓል የሚለውን ምልክት ይመልከቱ።'],
      faqItems: [
        GuidanceFaq(
          question: 'አዲስ ምድቦች እንዴት ይጨመራሉ?',
          answer: 'የሰንበት ት/ቤቱ የይዘት አስተዳዳሪዎች አዳዲስ የበዓላት ምድቦችን በየወቅቱ ያትማሉ።',
        ),
      ],
    ),

    // 4. MEZMUR SEARCH
    '/home/search': const GuidanceArticle(
      id: 4,
      slug: 'mezmur-search',
      category: 'mezmurs',
      title: 'መዝሙር መፈለጊያ (Search Mezmurs)',
      summary: 'በስም፣ በግጥም ቃላት ወይም በምድብ ፈጣን ፍለጋ።',
      content:
          'የመፈለጊያ ሳጥኑን በመጠቀም በሺዎች ከሚቆጠሩ መዝሙራት መካከል የሚፈልጉትን በሰከንዶች ውስጥ ያግኙ። ፍለጋው በግዕዝ እና በአማርኛ ቃላት፣ እንዲሁም በግጥሙ ውስጠ-መስመሮች ላይ ይሰራል።',
      targetRole: 'all',
      targetScreen: '/home/search',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የፍለጋ ቃል ማስገባት',
          description: 'የመዝሙሩን ርዕስ ወይም ከግጥሙ የሚያስታውሱትን ቃል ይተይቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ማጣሪያ መጠቀም',
          description: 'በድምጽ ያላቸው፣ የወረዱ ወይም የተወዳጆች ብቻ እንዲታዩ ማጣራት ይችላሉ።',
        ),
      ],
      tips: ['ፊደላት በግዕዝም (ለምሳሌ ጸ/ፀ፣ ሀ/ሐ/ኀ) ቢለያዩ ፍለጋው ተቀራራቢ ቃላትን ያገኛል።'],
      faqItems: [
        GuidanceFaq(
          question: 'መዝሙሩ በስሙ ካልተገኘ ምን ማድረግ አለብኝ?',
          answer: 'ከግጥሙ የሚያስታውሱትን ጥቂት ቃላት በመጻፍ ወይም የመዝሙር ምድቡን በመምረጥ ይፈልጉ።',
        ),
      ],
    ),

    // 5. EDUCATION MODULE
    '/edu': const GuidanceArticle(
      id: 5,
      slug: 'education-system',
      category: 'education',
      title: 'የሰንበት ት/ቤት ትምህርት ማዕከል (Education)',
      summary: 'ትምህርቶች፣ ፈተናዎች፣ ክፍሎች፣ እድገት፣ ምዝገባ እና የትምህርት መጻሕፍት።',
      content:
          'የሰንበት ት/ቤት የትምህርት ማዕከል አምስት ትሮች አሉት፦ መነሻ (የዕለቱ ትምህርት፣ ምድቦች፣ የዚህ ሳምንት ፈተናዎችና የቤት ሥራዎች)፣ ተማር (ምድብ → የትምህርት ዓይነት → ምዕራፍ → ትምህርት)፣ ክፍሎች (ምዝገባ፣ የክፍል ፕሮግራም፣ መገኘት፣ የቤት ሥራ)፣ እድገት (የትምህርት እድገት፣ መገኘት እና የታተሙ ውጤቶች) እና ተጨማሪ (ቤተ-መጽሐፍት፣ ጥያቄዎችና ቅሬታዎች፣ መርሐ ግብሮች፣ ቅንብሮች)። የፈተና ውጤቶች ይፋዊ የሚሆኑት በመምህሩ ቀርበው በትምህርት ክፍሉ ከጸደቁና ከታተሙ በኋላ ብቻ ነው።',
      targetRole: 'all',
      targetScreen: '/edu',
      tourId: 'edu_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ተማር (Learn)',
          description: 'ምድብ ይምረጡ፣ የትምህርት ዓይነቱን ይክፈቱ፣ ትምህርቱን ያንብቡ እና ሲጨርሱ «እንዳጠናቀቅሁ» ምልክት ያድርጉ።',
          actionRoute: '/edu/learn',
        ),
        GuidanceStep(
          step: 2,
          title: 'ፈተናዎች (Quizzes)',
          description: 'የዚህ ሳምንት ፈተና በመነሻ ገጹ ይታያል። «ተሳተፍ»ን ይጫኑ፤ የጊዜ ገደብ ካለው ሰዓቱ ከላይ ይታያል።',
          actionRoute: '/edu',
        ),
        GuidanceStep(
          step: 3,
          title: 'የክፍል መገኘት እና ውጤት',
          description: 'በ«እድገት» ትር የተገኙበትን ምጣኔ እና የታተሙ የምዘና ውጤቶችን ይመልከቱ።',
          actionRoute: '/edu/progress',
        ),
      ],
      tips: ['የትምህርት ክፍለ ጊዜ ከመጀመሩ በፊት የንባብ ጽሑፎችን አስቀድመው ያውርዱ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ክፍሌ ካልታየ ምን ላድርግ?',
          answer: 'ለትምህርት አስተዳዳሪው ወይም ለክፍል አስተባባሪዎ በማሳወቅ ምዝገባዎ እንዲረጋገጥ ያድርጉ።',
        ),
      ],
    ),

    // 6. PROGRAMS & ALARMS
    '/programs': const GuidanceArticle(
      id: 6,
      slug: 'programs-and-alarms',
      category: 'programs',
      title: 'መርሐ ግብሮች እና ማንቂያዎች (Programs & Alarms)',
      summary: 'የሰንበት ት/ቤት መርሐ ግብሮች፣ ተረኞች እና የ30 ደቂቃ ማንቂያ (Alarm) አጠቃቀም።',
      content:
          'በመርሐ ግብሮች ገጽ የዕለቱን እና የሚመጡትን የሰንበት ት/ቤት መርሐ ግብሮች ያገኛሉ። ለእያንዳንዱ መርሐ ግብር ማንቂያ በማብራት መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ ጮክ ብሎ በማንቂያ ደወል እንዲያስታውስዎት ማድረግ ይችላሉ።',
      targetRole: 'all',
      targetScreen: '/programs',
      tourId: 'programs_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የመርሐ ግብር ዝርዝር',
          description: 'የቀኑን መርሐ ግብር፣ ሰዓት እና አዳራሽ በግልጽ ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የ30 ደቂቃ ማንቂያ (Alarm)',
          description: 'መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ እንዲያስታውስዎት የማንቂያ ምልክቱን ይጫኑ።',
          tip: 'ማንቂያው ስልክዎ ተቆልፎ ቢሆንም እንኳን ልክ እንደ ሰዓት ማንቂያ ይሰራል!',
        ),
        GuidanceStep(
          step: 3,
          title: 'ተሳታፊዎች እና ተረኞች',
          description: 'ለመዝሙር፣ ለትምህርት ወይም ለስነ-ስርዓት የተመደቡ አባላትን ዝርዝር ይመልከቱ።',
        ),
      ],
      tips: [
        'በAndroid 12/13/14+ ላይ ትክክለኛ ማንቂያ እንዲሰራ የስልክዎን «Alarms & Reminders» ፈቃድ ይስጡ።',
        'ያለፈ መርሐ ግብር ላይ ማንቂያ ማብራት አይቻልም።',
      ],
      faqItems: [
        GuidanceFaq(
          question: 'ማንቂያው በሰዓቱ ካልደወለ ምን ማድረግ አለብኝ?',
          answer: 'በስልክዎ Settings ውስጥ የመተግበሪያውን «Alarms & Reminders» ፈቃድ ማብራትዎን ያረጋግጡ።',
        ),
      ],
    ),

    // 7. ATTENDANCE & MEMBER CARD
    '/attendance': const GuidanceArticle(
      id: 7,
      slug: 'attendance-and-qr-card',
      category: 'attendance',
      title: 'የአባልነት ካርድ እና ክትትል (Attendance & QR Card)',
      summary: 'የግል QR ኮድ አጠቃቀም፣ የመገኘት ምዝገባ እና የክትትል የቀን መቁጠሪያ።',
      content:
          'እያንዳንዱ አባል ልዩ የQR ኮድ ያለው ዲጂታል መታወቂያ ካርድ አለው። በሰንበት ት/ቤት መርሐ ግብሮች ወይም በትምህርት ክፍለ ጊዜ አስተዳዳሪዎች ወይም አቴንዳንስ መዝጋቢዎች የእርስዎን QR ኮድ በመቃኘት መገኘትዎን ይመዘግባሉ። የራስዎን የክትትል ታሪክም ማየት ይችላሉ።',
      targetRole: 'all',
      targetScreen: '/attendance',
      tourId: 'attendance_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የአባልነት QR ካርድ',
          description: 'በቅንብሮች ውስጥ «ስለ እኔ» ገጽ ላይ የሚገኘው የእርስዎ የግል ዲጂታል መታወቂያ።',
          tip: 'ካርዱን ለክትትል መዝጋቢዎች በማሳየት በቀላሉ ይመዝገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የክትትል የቀን መቁጠሪያ (Calendar)',
          description: 'የተገኙባቸውን እና የቀሩባቸውን ቀናት በቀለም በተለዩ ምልክቶች ያሳያል።',
        ),
        GuidanceStep(
          step: 3,
          title: 'የማስተካከያ ጥያቄ (Correction)',
          description: 'ተገኝተው ባልተመዘገቡበት ቀን ማስተካከያ እንዲደረግልዎት ጥያቄ ማቅረብ ይችላሉ።',
        ),
      ],
      tips: [
        'የQR ካርድዎን ስክሪን ሾት በማንሳትም ማሳየት ይቻላል።',
        'የክትትል ደንቦችን ለማወቅ በክትትል ገጽ ላይ የደንብ መረጃውን ይመልከቱ።',
      ],
      faqItems: [
        GuidanceFaq(
          question: 'ካርዴ ላይ ፎቶ ከሌለ ምን ላድርግ?',
          answer: 'በመገለጫ (Profile) ገጽ ላይ ገብተው አዲስ ፎቶ ይስቀሉ ወይም ለአስተዳዳሪው ያሳውቁ።',
        ),
      ],
    ),

    // 8. MY MEZMURS (FAVORITES & DOWNLOADS)
    '/library': const GuidanceArticle(
      id: 8,
      slug: 'my-mezmurs-library',
      category: 'mezmurs',
      title: 'የእኔ መዝሙራት — የተወደዱ እና የወረዱ (My Mezmurs: Favorites & Downloads)',
      summary: 'የወደዷቸውን መዝሙራት (Favorites) እና ወደ ስልክዎ ያወረዷቸውን መዝሙራት (Offline Downloads) ያለ ኢንተርኔት ማዳመጥ።',
      content:
          'የመዝሙር ክፍል «የእኔ» (Library) ገጽ ዋና ዓላማ እርስዎ የመረጧቸውን የተወደዱ መዝሙራት (Favorites) እና ወደ ስልክዎ ያወረዷቸውን መዝሙራት (Downloads) ያለ ምንም ኢንተርኔት ኮኔክሽን በቀላሉ ለማዳመጥ እና ለማስተዳደር ነው።',
      targetRole: 'all',
      targetScreen: '/library',
      tourId: 'library_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የተወደዱ መዝሙራት (Favorites)',
          description: 'በማንኛውም መዝሙር ላይ የልብ ምልክት (Favorite) በመጫን እዚህ ዝርዝር ውስጥ ሰብስበው በቀላሉ ያጫውቱ።',
          tip: 'በተደጋጋሚ የሚያዳምጧቸውን መዝሙራት በምልክት ይለዩ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የወረዱ መዝሙራት (Offline Downloads)',
          description: 'የወረዱ መዝሙራትን ያለ ምንም ኢንተርኔት በከፍተኛ ጥራት ከመስመር ውጭ (Offline) ያዳምጡ።',
          tip: 'የማውረጃ ምልክቱን በመጫን መዝሙሩን በስልክዎ ላይ ያከማቹ።',
        ),
      ],
      tips: [
        'መዝሙራትን አስቀድመው በማውረድ ኢንተርኔት በሌለበት ሰዓት ወይም ጉዞ ላይ ያለ መቆራረጥ ያዳምጡ።',
        'የወረዱ መዝሙራትን ከስልክዎ ማህደረ ትውስታ ለማጥፋት ከዝርዝሩ ላይ በቀላሉ ማስተዳደር ይችላሉ።',
      ],
      faqItems: [
        GuidanceFaq(
          question: 'ያወረድኳቸው መዝሙራት ኢንተርኔት ሳይኖር ይሠራሉ?',
          answer: 'አዎ፤ የወረዱ መዝሙራት በስልክዎ ማህደረ ትውስታ ውስጥ ስለሚቀመጡ ያለ ምንም ኢንተርኔት ይሠራሉ።',
        ),
        GuidanceFaq(
          question: 'መዝሙር እንዴት ወደ ተወደዱ ዝርዝር ማከል እችላለሁ?',
          answer: 'በመዝሙር ማጫወቻው ወይም በግጥሙ ገጽ ላይ ያለውን የልብ ምልክት (Favorite) በመጫን ማከል ይችላሉ።',
        ),
        GuidanceFaq(
          question: 'የመንፈሳዊ መጻሕፍት እና ንብረት ውሰት የት ይገኛል?',
          answer: 'የትምህርት መጻሕፍት እና ንብረት ውሰት በትምህርት ክፍል (Education) ወይም በቅንብሮች (Settings) ገጽ ውስጥ ይገኛሉ።',
        ),
      ],
    ),

    // 9. PROJECTS & TASKS
    '/projects': const GuidanceArticle(
      id: 9,
      slug: 'projects-and-tasks',
      category: 'projects',
      title: 'የዲፓርትመንት ፕሮጀክቶች እና ተግባራት (Projects & Tasks)',
      summary: 'የመምሪያ የጋራ ስራዎች፣ የተሰጡ ተግባራት (Tasks)፣ በጀት እና አስተያየቶች።',
      content:
          'የሰንበት ት/ቤት ክፍላት የሚሰሯቸውን ልዩ ልዩ ፕሮጀክቶች እና ተግባራት በግልጽ ለመከታተል የሚያስችል ክፍል ነው። አባላት የተመደቡባቸውን ስራዎች ደረጃ ማዘመን፣ አስተያየት መስጠት እና የወጪ ጥያቄዎችን ማቅረብ ይችላሉ።',
      targetRole: 'leader',
      targetScreen: '/projects',
      requiredPermission: 'projects.view',
      tourId: 'projects_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የፕሮጀክቶች ዝርዝር',
          description: 'የመምሪያዎ እና የሰንበት ት/ቤቱ አጠቃላይ ፕሮጀክቶች ዝርዝር።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የተግባራት ሰሌዳ (Tasks)',
          description: 'ለአባላት የተከፋፈሉ ተግባራት፣ የማጠናቀቂያ ቀን እና ቅድሚያ የሚሰጣቸው ስራዎች።',
        ),
      ],
      tips: ['ለእያንዳንዱ ተግባር አስተያየት በመጻፍ የቡድን አባላት መረጃ እንዲለዋወጡ ያድርጉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'በፕሮጀክት ውስጥ አዲስ ተግባር (Task) ማን መፍጠር ይችላል?',
          answer: 'የመምሪያው መሪዎች እና የፕሮጀክት አስተባባሪዎች።',
        ),
      ],
    ),

    // 10. CHOIR SELECTION
    '/choir': const GuidanceArticle(
      id: 10,
      slug: 'choir-holiday-selection',
      category: 'choir',
      title: 'የበዓላት መዝሙር መረጣ (Choir Selection)',
      summary: 'የበዓላት መዝሙር መራጭ ደንቦች፣ የምዘና ነጥቦች፣ ምድቦች እና ይፋዊ ውጤት።',
      content:
          'ለበዓላት እና ለልዩ መርሐ ግብሮች የመዘምራን መረጣ ፍትሃዊ እና ግልጽ በሆነ የአሰራር ደንብ ይከናወናል። የአባላት የፈተና ውጤት፣ የመገኘት ምጣኔ እና የአገልግሎት ምድቦች ተሰልተው በመጨረሻም ይፋዊ ዝርዝር ይወጣል።',
      targetRole: 'all',
      targetScreen: '/choir',
      tourId: 'choir_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የመረጣ መስፈርቶች',
          description: 'የአቴንዳንስ ምጣኔ፣ የፈተና ውጤቶች እና የአገልግሎት ዝግጁነት መመዘኛዎች።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ውጤት መመልከት',
          description: 'ውጤቱ በአስተዳዳሪዎች ሲጸድቅ እና ይፋ ሲደረግ በመተግበሪያው ላይ ይታያል።',
        ),
      ],
      tips: ['ውጤቱ ይፋ እስካልሆነ ድረስ በግምገማ (Under Review) ደረጃ ይቆያል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የበዓላት መዘምራን መረጣ ውጤት መቼ ይፋ ይሆናል?',
          answer: 'የፈተና እና የአቴንዳንስ ነጥቦች ተደምረው በአመራሩ ሲጸድቁ ወዲያውኑ ይፋ ይሆናል።',
        ),
      ],
    ),

    // 11. PROFILE & PROFESSION
    '/settings/profile': const GuidanceArticle(
      id: 11,
      slug: 'profile-and-profession',
      category: 'settings',
      title: 'መገለጫ እና ሙያ (Profile & Profession)',
      summary: 'የግል መረጃ፣ ፎቶ፣ የስራ እና የትምህርት ሙያ ምዝገባ።',
      content:
          'የግል መገለጫዎን የሚያዘምኑበት ገጽ ነው። አባላት ሙያቸውን፣ የትምህርት ደረጃቸውን እና ልዩ ተሰጥኦአቸውን በመመዝገብ ለሰንበት ት/ቤቱ ልዩ ልዩ አገልግሎቶች የበኩላቸውን አስተዋጽኦ እንዲያበረክቱ ያስችላል።',
      targetRole: 'all',
      targetScreen: '/settings/profile',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የመገለጫ ፎቶ መቀየር',
          description: 'የመታወቂያ ፎቶዎን ከጋለሪ በመምረጥ ወይም አዲስ በማንሳት ይጫኑ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የሙያ እና የትምህርት መረጃ',
          description: 'የተመረቁበትን ወይም የሚሰሩበትን የስራ መስክ እና ክህሎት ይመዝግቡ።',
        ),
      ],
      tips: ['መረጃዎን በየጊዜው በማዘመን ሰንበት ት/ቤቱ እርስዎን በሙያዎ እንዲያሳትፍ ያግዙ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የሙያ መረጃዬን ለምን መመዝገብ አስፈለገ?',
          answer: 'ሰንበት ት/ቤቱ በተለያዩ ዝግጅቶች እና ስራዎች ላይ አባላትን በሙያቸው እና በክህሎታቸው ለማሳተፍ ይጠቀምበታል።',
        ),
      ],
    ),

    // 12. PAYMENTS & CONTRIBUTIONS
    '/settings/payments': const GuidanceArticle(
      id: 12,
      slug: 'payments-and-contributions',
      category: 'settings',
      title: 'ክፍያዎች እና መዋጮዎች (Payments & Dues)',
      summary: 'የወርሀዊ መዋጮ፣ የአባልነት ክፍያ እና የደረሰኝ ታሪክ።',
      content:
          'የአባልነት ክፍያዎችን፣ ወርሃዊ መዋጮዎችን እና የልዩ ፕሮጀክት ድጋፎችን ሁኔታ መከታተያ ክፍል ነው። የተከፈሉ ክፍያዎችን፣ የቀሩ ዕዳዎችን እና የክፍያ ደረሰኞችን በግልጽ ያሳያል።',
      targetRole: 'all',
      targetScreen: '/settings/payments',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የክፍያ ታሪክ መመልከት',
          description: 'ያለፉትን የተከፈሉ እና ያልተከፈሉ ወራት ዝርዝር ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ደረሰኝ ማያያዝ',
          description: 'በባንክ የተከፈለበትን ደረሰኝ ፎቶ በማንሳት ለፋይናንስ ክፍል ያቅርቡ።',
        ),
      ],
      tips: ['ክፍያዎ በፋይናንስ አስተዳዳሪው ሲረጋገጥ ደረጃው ወደ «ተረጋግጧል» ይቀየራል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የከፈልኩት ክፍያ ያልተከፈለ ሆኖ ከታየ ምን ማድረግ አለብኝ?',
          answer: 'የክፍያ ደረሰኝዎን (Receipt) በመተግበሪያው ላይ ይስቀሉ ወይም የፋይናንስ ኃላፊውን ያነጋግሩ።',
        ),
      ],
    ),

    // 13. NOTIFICATION SETTINGS
    '/settings/notifications': const GuidanceArticle(
      id: 13,
      slug: 'notification-settings-guide',
      category: 'settings',
      title: 'የማሳወቂያ ቅንብሮች (Notification Settings)',
      summary: 'የፑሽ ማሳወቂያዎች፣ የማንቂያ ድምጽ እና የሰዓት ማስተካከያ።',
      content:
          'የሚደርሷችሁን ማሳወቂያዎች አይነት (መርሐ ግብሮች፣ ትምህርት፣ ክፍያዎች፣ የቡድን መልዕክቶች) የሚቆጣጠሩበት ክፍል ነው። የማንቂያ ደወል ድምጽ እና የማስታወሻ ሰዓትንም እዚሁ ማስተካከል ይችላሉ።',
      targetRole: 'all',
      targetScreen: '/settings/notifications',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የማሳወቂያ አይነቶች',
          description: 'ሊደርስዎት የሚፈልጉትን የማሳወቂያ አይነት ያብሩ ወይም ያጥፉ።',
        ),
      ],
      tips: ['ወሳኝ የሰንበት ት/ቤት መልዕክቶች እንዳያመልጥዎት ማሳወቂያዎችን ክፍት ያድርጉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የማንቂያ ድምጽ እንዴት እቀይራለሁ?',
          answer: 'በስልክዎ Notifications & Sounds ቅንብሮች ውስጥ የመተግበሪያውን የማሳወቂያ ቃና መምረጥ ይችላሉ።',
        ),
      ],
    ),

    // 14. ADMIN: USER MANAGEMENT
    '/admin/users': const GuidanceArticle(
      id: 14,
      slug: 'admin-users-management',
      category: 'admin',
      title: 'የአባላት አስተዳደር (Admin: User Management)',
      summary: 'አዲስ አባላትን መመዝገብ፣ መረጃ ማስተካከል፣ መታወቂያ መስጠት እና ስልክ መቀየር።',
      content:
          'ይህ ክፍል ለአስተዳዳሪዎች ብቻ የተዘጋጀ ሲሆን የአባላትን መረጃ ሙሉ በሙሉ ለመቆጣጠር ያስችላል። አዲስ አባል መመዝገብ፣ የስልክ እና ሚና (Role) ማስተካከል፣ የይለፍ ቃል ሪሴት ማድረግ እና ስልክ ሲቀይሩ Device Reset ማከናወን ይቻላል።',
      targetRole: 'admin',
      targetScreen: '/admin/users',
      requiredPermission: 'users.view',
      tourId: 'admin_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አዲስ አባል መመዝገብ',
          description: 'ሙሉ ስም፣ ስልክ ቁጥር እና የመጀመሪያ ፒን በመስጠት ይመዝግቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'Device Reset (ስልክ ማስቀየር)',
          description: 'አባሉ ስልክ ሲቀይር የቀድሞ ስልኩን ትስስር በማላቀቅ በአዲሱ እንዲገባ ፍቀዱለት።',
        ),
      ],
      tips: ['ስልክ ቁጥር ሲቀይሩ ትክክለኛውን የሀገር ኮድ (+251) ይጠቀሙ።'],
      faqItems: [
        GuidanceFaq(
          question: 'አባል ስልኩን ሲቀይር የቀድሞ መረጃው ይጠፋል?',
          answer: 'አይጠፋም፤ Device Reset ሲደረግ በአዲሱ ስልክ ሲገባ የቀድሞ መረጃው፣ አቴንዳንሱ እና ክፍያው በሙሉ ይጠበቃል።',
        ),
        GuidanceFaq(
          question: 'የአባላትን ሚና (Role) ማን መቀየር ይችላል?',
          answer: 'Superadmin ወይም users.manage ፈቃድ ያለው አስተዳዳሪ ብቻ ነው።',
        ),
      ],
    ),

    // 15. ADMIN: PROGRAMS & ATTENDANCE CLOSING
    '/admin/programs': const GuidanceArticle(
      id: 15,
      slug: 'admin-programs-and-attendance',
      category: 'admin',
      title: 'መርሐ ግብር እና አቴንዳንስ መዝጋት (Admin: Programs)',
      summary: 'መርሐ ግብር ማቀድ፣ አቴንዳንስ መዝጋቢዎችን መመደብ እና አቴንዳንስ መዝጋት።',
      content:
          'የሰንበት ት/ቤት መርሐ ግብሮችን ማቀድ፣ ተረኞችን መመደብ፣ በQR ኮድ ክትትል ማድረግ እና የአቴንዳንስ ቆጠራን መዝጋት (Close Attendance) የሚያስችል የአስተዳዳሪ የስራ ፍሰት ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/programs',
      requiredPermission: 'programs.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'መርሐ ግብር መፍጠር',
          description: 'ርዕስ፣ ምድብ፣ ቀን፣ የጀማሪ እና ማብቂያ ሰዓት ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'አንድ መዝጋቢ መመደብ (የሰው ሀብት ክፍል)',
          description: 'ለእያንዳንዱ መርሐ ግብር አንድ የአቴንዳንስ መዝጋቢ ይመደባል፤ ለአንድ ቀን ሌላ መዝጋቢ ከዚያ ቀን ዝርዝር መመደብ ይቻላል።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ጀምር እና ጨርስ (Start / End)',
          description:
              'መዝገቡ ከጅማሬው 15 ደቂቃ በፊት ይከፈታል፤ መዝጋቢው «ጀምር» ሲጫን ይጀምራል። አባላት ከፈረሙ በኋላ ይመዘገባሉ። «ጨርስ» ሲጫን ወይም የማብቂያው ሰዓት ሲደርስ ይዘጋል፤ ያልተመዘገቡት እንደቀሩ ይቆጠራሉ።',
        ),
      ],
      tips: ['«ዘግይቷል» የሚባል ሁኔታ የለም፤ የደረሱበት ሰዓት ከጅማሬው ጀምሮ ይመዘገባል።', 'ከመስመር ውጭም መጀመር፣ መመዝገብና መጨረስ ይቻላል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የተዘጋ አቴንዳንስን ማስተካከል ይቻላል?',
          answer: 'ከተዘጋ በኋላ ለውጥ የሚደረገው በማስተካከያ ጥያቄ ብቻ ነው፤ የሰው ሀብት ክፍል ይገመግማል።',
        ),
      ],
    ),

    // 16. ADMIN: SCORING & RULES
    '/admin/attendance/rules': const GuidanceArticle(
      id: 16,
      slug: 'admin-attendance-scoring-rules',
      category: 'admin',
      title: 'የአቴንዳንስ ፊርማ ደንብ (Attendance Signatures)',
      summary: 'አባላት ሲመዘገቡ የሚፈርሙበት ደንብ እና ከመስመር ውጭ የተያዙ መዝገቦች ግምገማ።',
      content:
          'አባላት «ተገኝቷል» ተብለው ከመመዝገባቸው በፊት በመዝጋቢው ስልክ ላይ ይፈርማሉ። የሰው ሀብት ክፍል የማይፈርሙ የአባል ዓይነቶችን እዚህ ይወስናል። «ዘግይቷል» የሚባል ሁኔታ የለም፤ የደረሱበት ሰዓት ከመዝገቡ ጅማሬ ጀምሮ ይመዘገባል።',
      targetRole: 'admin',
      targetScreen: '/admin/attendance/rules',
      requiredPermission: 'attendance.configure',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የማይፈርሙ የአባል ዓይነቶች',
          description: 'የማይፈርሙትን የአባል ዓይነቶች ምልክት አድርገው ያስቀምጡ፤ ሌሎቹ ሁሉ ይፈርማሉ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ከመስመር ውጭ የተያዙ መዝገቦች',
          description: 'አገልጋዩ እንደተያዙ ሊመዘግባቸው ያልቻሉ መዝገቦች «የሚገመገሙ ከመስመር ውጭ መዝገቦች» ገጽ ላይ ይታያሉ፤ እያንዳንዱን በማስታወሻ ይቀበሉ ወይም ይከልክሉ።',
        ),
      ],
      tips: ['ፊርማዎች ከመላካቸው በፊት በስልኩ ላይ ተመስጥረው ይቀመጣሉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ከመስመር ውጭ የተመዘገበ መገኘት ይጠፋል?',
          answer: 'አይጠፋም፤ ሊመዘገብ ያልቻለው ሁሉ ከፊርማውና ከተያዘበት ሰዓት ጋር ለሰው ሀብት ክፍል ግምገማ ይቀመጣል።',
        ),
      ],
    ),

    // 17. ADMIN: BROADCAST NOTIFICATIONS
    '/admin/notify': const GuidanceArticle(
      id: 17,
      slug: 'admin-notifications',
      category: 'admin',
      title: 'ማሳወቂያዎችን መላክ (Admin: Broadcast Notifications)',
      summary: 'ለአባላት፣ ለክፍላት ወይም ለመላው ሰንበት ት/ቤት ፑሽ ማሳወቂያ መላክ።',
      content:
          'አስተዳዳሪዎች ለአባላት የሞባይል ፑሽ ማሳወቂያዎችን ለመላክ ይህንን ክፍል ይጠቀማሉ። መልዕክቶችን በቡድን፣ በክፍል፣ በዲፓርትመንት ወይም ለሁሉም አባላት መላክ ይቻላል። የማሳወቂያዎችን የደረሰበት ሁኔታም በNotification Health መከታተል ይቻላል።',
      targetRole: 'admin',
      targetScreen: '/admin/notify',
      requiredPermission: 'notifications.send',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ተቀባዮችን መምረጥ',
          description: 'ሁሉንም አባላት፣ የተወሰነ ዲፓርትመንት ወይም የተመረጡ ሰዎችን ይወስኑ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ርዕስ እና መልዕክት መጻፍ',
          description: 'አጭር፣ ግልጽ እና ማራኪ ርዕስ እና የመልዕክቱን ዝርዝር ያስገቡ።',
        ),
      ],
      tips: ['«ለሁሉም» ለመላክ ልዩ ፈቃድ (notifications.send_all) ያስፈልጋል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ለአባላት የሚላከው ማሳወቂያ በስልካቸው ላይ ወዲያውኑ ይደርሳል?',
          answer: 'አዎ፤ ስልካቸው ኢንተርኔት እስካለው ድረስ በFirebase Cloud Messaging ፈጣን ፑሽ ይደርሳቸዋል።',
        ),
      ],
    ),

    // 18. ADMIN: REPORTS & AUDIT
    '/admin/reports': const GuidanceArticle(
      id: 18,
      slug: 'admin-reports-and-audits',
      category: 'admin',
      title: 'ሪፖርቶች እና ኦዲት (Admin: Reports & Analytics)',
      summary: 'የአቴንዳንስ፣ የበጀት፣ የመዝሙር እና የአባላት ሪፖርቶችን በExcel/CSV ማውጣት።',
      content:
          'የሰንበት ት/ቤቱን አጠቃላይ የአገልግሎት እና የአስተዳደር ሁኔታ የሚያሳዩ ዳሽቦርዶች እና ሪፖርቶች የሚዘጋጁበት ክፍል ነው። የአቴንዳንስ ምጣኔ፣ የገንዘብ እንቅስቃሴ እና የስርዓት ኦዲት ሎግ በቀላሉ ማውጣት ይቻላል።',
      targetRole: 'admin',
      targetScreen: '/admin/reports',
      requiredPermission: 'reports.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ሪፖርት ማመንጨት',
          description: 'የሚፈልጉትን አይነት (አቴንዳንስ፣ ፋይናንስ፣ አባላት) እና የቀን ወሰን ይምረጡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ወደ Excel/CSV ማውረድ',
          description: 'ሪፖርቱን በExcel ፋይል ወደ ስልክዎ ወይም ኮምፒውተርዎ ያውርዱ።',
        ),
      ],
      tips: ['ትላልቅ ሪፖርቶችን ከማውረድዎ በፊት የቀን ገደብ በመስጠት ፍለጋውን ያጥቡት።'],
      faqItems: [
        GuidanceFaq(
          question: 'ሪፖርቶችን በምን አይነት ፋይል ማውረድ ይቻላል?',
          answer: 'በExcel (.xlsx) እና በCSV ቅርጸት ማውረድ ይቻላል።',
        ),
      ],
    ),

    // 19. ADMIN: MEMBER ID CARDS
    '/admin/member-ids': const GuidanceArticle(
      id: 19,
      slug: 'admin-member-ids',
      category: 'admin',
      title: 'የአባልነት መታወቂያ ካርዶች (Member ID Cards)',
      summary: 'የአባላት ዲጂታል እና የታተሙ የQR መታወቂያ ካርዶችን ማመንጨት እና ማስተዳደር።',
      content:
          'የሰንበት ት/ቤት አባላት የዲጂታል QR መታወቂያ ቁጥር የሚሰጥበት እና ካርዶች የሚዘጋጁበት ክፍል ነው። ለአዳዲስ አባላት መታወቂያ ቁጥር በራስ-ሰር ማመንጨት፣ የካርድ ሁኔታን (የታተመ/ያልታተመ) መከታተል እና ለህትመት ማዘጋጀት ይቻላል።',
      targetRole: 'admin',
      targetScreen: '/admin/member-ids',
      requiredPermission: 'member_id.configure',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ያልተሰጣቸው አባላትን መምረጥ',
          description: 'መታወቂያ ቁጥር የሌላቸውን አባላት ያጣሩ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መታወቂያ ማመንጨት',
          description: 'በቡድን ወይም በግል የካርድ ቁጥር ይስጡ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ለህትመት ማዘጋጀት',
          description: 'የQR ካርዶችን ለህትመት ያውርዱ።',
        ),
      ],
      tips: ['የአባልነት ቁጥር አንድ ጊዜ ከተሰጠ በኋላ በስርዓቱ ውስጥ ልዩ (unique) ሆኖ ይቀመጣል።'],
      faqItems: [
        GuidanceFaq(
          question: 'አባሉ መታወቂያውን ቢያጣው ምን ይደረጋል?',
          answer: 'ያለውን የካርድ ቁጥር ሳያስቀይሩ አዲስ ካርድ እንደገና ማመንጨት እና ማተም ይቻላል።',
        ),
      ],
    ),

    // 20. ADMIN: MEMBER GROUPS
    '/admin/member-groups': const GuidanceArticle(
      id: 20,
      slug: 'admin-member-groups',
      category: 'admin',
      title: 'የአባላት ምድቦች (Member Groups)',
      summary: 'አባላትን በዕድሜ፣ በአገልግሎት ክፍል እና በቡድን መመደብ።',
      content:
          'አባላትን በሕፃናት፣ ወጣቶች፣ ጎልማሶች ወይም በአገልግሎት ቡድኖች ከፋፍሎ ለማስተዳደር ይጠቅማል። ይህ ምድብ በአቴንዳንስ እና በሪፖርቶች ላይ አባላትን በቀላሉ ለመለየት ያግዛል።',
      targetRole: 'admin',
      targetScreen: '/admin/member-groups',
      requiredPermission: 'member_groups.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ምድብ መምረጥ',
          description: 'የሕፃናት፣ ወጣቶች ወይም ልዩ ቡድን ይምረጡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'አባላትን መመደብ',
          description: 'አባላትን ወደ ተመረጠው ምድብ ያዛውሩ።',
        ),
      ],
      tips: ['የምድብ ለውጥ ሲደረግ የአባሉ የወርሃዊ መዋጮ ምጣኔ በራስ-ሰር ሊስተካከል ይችላል።'],
      faqItems: [
        GuidanceFaq(
          question: 'አንድ አባል በሁለት ምድብ ውስጥ ሊሆን ይችላል?',
          answer: 'ዋናው ምድብ አንድ ሲሆን በአገልግሎት ክፍል ግን በበርካታ ክፍላት መሳተፍ ይችላል።',
        ),
      ],
    ),

    // 21. ADMIN: CHANGE REQUESTS
    '/admin/change-requests': const GuidanceArticle(
      id: 21,
      slug: 'admin-change-requests',
      category: 'admin',
      title: 'የመረጃ ለውጥ ጥያቄዎች (Profile Change Requests)',
      summary: 'አባላት የላኳቸውን የስም፣ ስልክ፣ ፎቶ እና አድራሻ ለውጥ ጥያቄዎች መገምገም እና ማጽደቅ።',
      content:
          'አባላት በመተግበሪያቸው በኩል የስም፣ የስልክ ቁጥር ወይም የመገለጫ ፎቶ ለውጥ ሲጠይቁ በቀጥታ አይቀየርም፤ በዚህ ክፍል በአስተዳዳሪ ታይቶ ሲጸድቅ ብቻ በቋሚነት ይመዘገባል።',
      targetRole: 'admin',
      targetScreen: '/admin/change-requests',
      requiredPermission: 'users.update',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ጥያቄዎችን መመልከት',
          description: 'በመጠባበቅ ላይ ያሉትን ጥያቄዎች ከቀድሞው መረጃ ጋር ያነጻጽሩ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ማጽደቅ ወይም ውድቅ ማድረግ',
          description: 'ትክክለኛ ከሆነ ያጽድቁ፤ ስህተት ካለበት ምክንያቱን ጽፈው ይመልሱ።',
        ),
      ],
      tips: ['ጥያቄው ሲጸድቅ ወይም ውድቅ ሲደረግ ለአባሉ ማሳወቂያ በስልኩ ይደርሰዋል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ውድቅ የተደረገ ጥያቄ እንደገና ሊቀርብ ይችላል?',
          answer: 'አዎ፤ አባሉ መረጃውን አስተካክሎ አዲስ ጥያቄ ማቅረብ ይችላል።',
        ),
      ],
    ),

    // 22. ADMIN: PAYMENTS
    '/admin/payments': const GuidanceArticle(
      id: 22,
      slug: 'admin-payments',
      category: 'admin',
      title: 'የአባላት ክፍያዎች አስተዳደር (Payments Admin)',
      summary: 'የወርሃዊ መዋጮ፣ የልዩ መዋጮ እና የደረሰኝ ምዝገባ መቆጣጠሪያ።',
      content:
          'የአባላትን ወርሃዊ መዋጮ፣ የመመዝገቢያ ክፍያ እና ሌሎች ገቢዎችን ለመመዝገብ እና ለመከታተል የሚያገለግል ክፍል ነው። የኢትዮጵያ ዘመን አቆጣጠርን መሰረት ባደረገ መልኩ ወርሃዊ ክፍያዎች ይመዘገባሉ፤ ያልከፈሉ አባላት ዝርዝርም ይወጣል።',
      targetRole: 'admin',
      targetScreen: '/admin/payments',
      requiredPermission: 'payments.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አባሉን መፈለግ',
          description: 'በስም ወይም በመታወቂያ ቁጥር ይፈልጉ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ክፍያ መመዝገብ',
          description: 'የተከፈለበትን ወር፣ የገንዘብ መጠን እና የደረሰኝ ቁጥር ያስገቡ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ደረሰኝ ማረጋገጥ',
          description: 'የባንክ ማስተላለፊያ ደረሰኝ ከሆነ ፎቶውን አይተው ያጽድቁ።',
        ),
      ],
      tips: ['የኢትዮጵያ ወራትን በትክክል መምረጥዎን ያረጋግጡ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የተሳሳተ ክፍያ ከተመዘገበ ማስተካከል ይቻላል?',
          answer: 'ክፍያውን የሰረዘው አስተዳዳሪ ምክንያት አስገብቶ ኦዲት በሚደረግበት አግባብ መሰረዝ ወይም ማስተካከል ይችላል።',
        ),
      ],
    ),

    // 23. ADMIN: FINES
    '/admin/fines': const GuidanceArticle(
      id: 23,
      slug: 'admin-fines',
      category: 'admin',
      title: 'የቅጣቶች አስተዳደር (Fines & Penalties)',
      summary: 'በመዘግየት እና በመቅረት የተጣሉ የገንዘብ ቅጣቶችን መከታተል እና ይቅርታ ማድረግ።',
      content:
          'በአቴንዳንስ ህግ መሰረት በመቅረት ወይም በመዘግየት የተጣሉ የገንዘብ ቅጣቶችን የሚያሳይ እና የሚያስተዳድር ክፍል ነው። አባሉ ቅጣቱን ሲከፍል መመዝገብ ወይም አሳማኝ ምክንያት ካለ በይቅርታ መሰረዝ ይቻላል።',
      targetRole: 'admin',
      targetScreen: '/admin/fines',
      requiredPermission: 'fines.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የተቀጡ አባላትን መመልከት',
          description: 'ያልተከፈሉ ቅጣቶችን ዝርዝር ይመርምሩ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ክፍያ መመዝገብ ወይም ይቅርታ ማድረግ',
          description: 'ክፍያ ከተከፈለ ያጽድቁ፤ ይቅርታ ከተደረገ ምክንያቱን ያስገቡ።',
        ),
      ],
      tips: ['ይቅርታ የተደረጉ ቅጣቶች በሙሉ በኦዲት ሎግ ውስጥ ይመዘገባሉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ቅጣት በራስ-ሰር ነው የሚጣለው?',
          answer: 'አዎ፤ አቴንዳንስ ሲዘጋ በScoring Rules በተቀመጠው ደንብ መሰረት ስርዓቱ በራስ-ሰር ያሰላል።',
        ),
      ],
    ),

    // 24. ADMIN: ATTENDANCE CORRECTIONS
    '/admin/attendance/corrections': const GuidanceArticle(
      id: 24,
      slug: 'admin-attendance-corrections',
      category: 'admin',
      title: 'የአቴንዳንስ ማስተካከያ ጥያቄዎች (Attendance Corrections)',
      summary: 'የተሳሳተ የመገኘት መረጃን ለማረም የቀረቡ ጥያቄዎችን በኃላፊዎች መርምሮ ማጽደቅ።',
      content:
          'የአቴንዳንስ መዝጋቢው ወይም የመምሪያ ኃላፊው በስህተት ያልተመዘገበ ወይም የተሳሳተ አቴንዳንስ እንዲታረም ሲጠይቅ፣ በፕሮግራሙ በተመደበው ገለልተኛ የሰው ኃይል (HR Approver) ብቻ ይገመገማል። ጠያቂው ራሱ የራሱን ጥያቄ ማጽደቅ በሕጉ በጥብቅ የተከለከለ ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/attendance/corrections',
      requiredPermission: 'attendance.correction.approve',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የቀረበውን ምክንያት መመርመር',
          description: 'የማስተካከያ ጥያቄውን እና የተያያዘውን ማስረጃ ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ገለልተኛ ውሳኔ መስጠት',
          description: 'ጥያቄውን ያቀረበው ሰው አለመሆንዎን አረጋግጠው ያጽድቁ ወይም ውድቅ ያድርጉ።',
        ),
      ],
      tips: ['ተጠሪ የHR አጽዳቂ ካልተመደበ ስርዓቱ ማስተካከያውን ማጽደቅ ይከለክላል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ጠያቂው ኃላፊ ራሱ ማጽደቅ ይችላል?',
          answer: 'በፍጹም አይችልም፤ ስርዓቱ ራስን ማጽደቅ (Self-Approval) በጥብቅ ይከለክላል።',
        ),
      ],
    ),

    // 25. ADMIN: PERMISSIONS & ABSENCES
    '/admin/permissions': const GuidanceArticle(
      id: 25,
      slug: 'admin-permissions',
      category: 'admin',
      title: 'የፈቃድ እና የመቅረት ጥያቄዎች (Absence Requests)',
      summary: 'አባላት ከመርሐ ግብር አስቀድመው ያቀረቧቸውን የፈቃድ ጥያቄዎች መገምገም።',
      content:
          'አባላት በህመም፣ በትምህርት ወይም በስራ ምክንያት በሰንበት ት/ቤት መርሐ ግብር ላይ መገኘት በማይችሉበት ጊዜ የሚያቀርቡትን የፈቃድ ጥያቄ መርምሮ ውሳኔ የሚሰጥበት ክፍል ነው። የተፈቀደላቸው አባላት በአቴንዳንስ ወቅት እንደ «በፈቃድ የቀረ» ተቆጥረው ቅጣት አይጣልባቸውም።',
      targetRole: 'admin',
      targetScreen: '/admin/permissions',
      requiredPermission: 'attendance.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ጥያቄውን መክፈት',
          description: 'የአባሉን ስም፣ መርሐ ግብሩን እና የቀረበውን ምክንያት ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መፍቀድ ወይም መከልከል',
          description: 'ጥያቄውን ተቀብለው ይፍቀዱ ወይም ካላመኑበት ምክንያቱን ጽፈው ይከልክሉ።',
        ),
      ],
      tips: ['ፈቃድ መጠየቅ ያለበት መርሐ ግብሩ ከመጀመሩ በፊት መሆን አለበት።'],
      faqItems: [
        GuidanceFaq(
          question: 'ፈቃድ የተሰጠው አባል ነጥብ ይቀነሳል?',
          answer: 'በፈቃድ ሲቀር እንደ ተራ መቅረት አይቆጠርም፤ እንደ ደንቡ አነስተኛ ወይም ምንም ቅጣት አይጣልበትም።',
        ),
      ],
    ),

    // 26. ADMIN: NOTIFICATION HEALTH
    '/admin/notification-health': const GuidanceArticle(
      id: 26,
      slug: 'admin-notification-health',
      category: 'admin',
      title: 'የማሳወቂያ ጤና እና ሁኔታ (Notification Health)',
      summary: 'የFCM ቶከኖች፣ የደረሱ ማሳወቂያዎች ምጣኔ እና የቴክኒክ ብልሽቶች ክትትል ዳሽቦርድ።',
      content:
          'ወደ አባላት ስልኮች የሚላኩ የፑሽ ማሳወቂያዎች በትክክል መድረሳቸውን፣ የFCM ቶከኖች ትክክለኛነት እና ያጋጠሙ ቴክኒካዊ ስህተቶችን ለመከታተል የሚያገለግል ዳሽቦርድ ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/notification-health',
      requiredPermission: 'notifications.send',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የማሳወቂያዎችን ስታትስቲክስ መመልከት',
          description: 'የተላኩ፣ የደረሱ እና ያልተሳኩ ማሳወቂያዎችን ምጣኔ ይመርምሩ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ያልተሳኩትን እንደገና መላክ',
          description: 'ቴክኒካዊ ችግር የገጠማቸውን መልዕክቶች በድጋሚ ይላኩ።',
        ),
      ],
      tips: ['አባላት በመተግበሪያ ቅንብሮች ማሳወቂያ ካልፈቀዱ ፑሽ ላይደርሳቸው ይችላል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ያረጁ ቶከኖች እንዴት ይጸዳሉ?',
          answer: 'ስርዓቱ ተጠቃሚው መተግበሪያውን ሲከፍት ቶከኑን በራስ-ሰር ያድሳል፤ የማይሰሩትም በየጊዜው ይሰረዛሉ።',
        ),
      ],
    ),

    // 27. ADMIN: DEPARTMENTS
    '/admin/departments': const GuidanceArticle(
      id: 27,
      slug: 'admin-departments',
      category: 'admin',
      title: 'የክፍላት አስተዳደር (Departments Admin)',
      summary: 'የሰንበት ት/ቤት ክፍላትን ማቋቋም፣ መሪዎችን እና አባላትን ማስተዳደር።',
      content:
          'እንደ ትምህርት፣ መዝሙር፣ ልማት፣ ሒሳብ እና ንብረት ያሉ የአገልግሎት ክፍላትን ለመፍጠር፣ የመምሪያ ኃላፊዎችን ለመመደብ እና አባላትን በክፍላት ለማደራጀት ያገለግላል።',
      targetRole: 'admin',
      targetScreen: '/admin/departments',
      requiredPermission: 'departments.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ክፍል መፍጠር ወይም መምረጥ',
          description: 'የአገልግሎት ክፍሉን ስም እና መግለጫ ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ኃላፊ መመደብ',
          description: 'የመምሪያውን መሪ እና ረዳት ከአባላት መካከል ይምረጡ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'አባላትን ማካተት',
          description: 'በክፍሉ ውስጥ የሚያገለግሉ አባላትን ያክሉ።',
        ),
      ],
      tips: ['የክፍል መሪዎች ለክፍላቸው አባላት የውይይት ቡድን እና የተግባር ዝርዝር ማስተዳደር ይችላሉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'አንድ አባል ከአንድ በላይ ክፍል መምራት ይችላል?',
          answer: 'አዎ፤ አስተዳዳሪው አስፈላጊውን ፈቃድ ከሰጠው በርካታ ክፍላትን ማስተባበር ይችላል።',
        ),
      ],
    ),

    // 28. ADMIN: CHAT MODERATION
    '/admin/chat': const GuidanceArticle(
      id: 28,
      slug: 'admin-chat',
      category: 'admin',
      title: 'የክፍላት ውይይት ቁጥጥር (Department Chat Moderation)',
      summary: 'የክፍላት የውስጥ መልዕክቶችን እና ውይይቶችን መከታተል፣ ማስተካከል እና ማጽዳት።',
      content:
          'በክፍላት መካከል የሚደረጉ የውስጥ የጽሑፍ ውይይቶችን ስነ-ስርዓት ለመጠበቅ፣ አላስፈላጊ መልዕክቶችን ለማስወገድ እና ይፋዊ መግለጫዎችን ለማስተላለፍ የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/chat',
      requiredPermission: 'chat.supervise',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የክፍሉን ቻት መክፈት',
          description: 'የሚፈልጉትን ክፍል የውይይት መስኮት ይምረጡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መልዕክቶችን መቆጣጠር',
          description: 'ተገቢ ያልሆኑ መልዕክቶችን መሰረዝ ወይም አስፈላጊ ማስታወቂያዎችን መስቀል።',
        ),
      ],
      tips: ['የተሰረዙ መልዕክቶች በአስተዳዳሪ ኦዲት ውስጥ ይቀመጣሉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'አባላት በግል መወያየት ይችላሉ?',
          answer: 'ውይይቱ የተዘጋጀው ለአገልግሎት ክፍላት ስራዎች ብቻ ነው።',
        ),
      ],
    ),

    // 29. ADMIN: ITEMS & INVENTORY
    '/admin/items': const GuidanceArticle(
      id: 29,
      slug: 'admin-items',
      category: 'admin',
      title: 'የንብረት እና መጻሕፍት አስተዳደር (Items & Inventory)',
      summary: 'የሰንበት ት/ቤት ንብረቶችን፣ መጻሕፍትን፣ አልባሳትን እና የድምጽ እቃዎችን መመዝገብ።',
      content:
          'የሰንበት ት/ቤቱን ቋሚ እና አላቂ ንብረቶች፣ የቤተ-መጽሐፍት መጻሕፍት፣ የመዘምራን አልባሳት እና የሙዚቃ መሳሪያዎችን ለመመዝገብ፣ መለያ ኮድ (Barcode/Item Code) ለመስጠት እና ያለውን ብዛት ለመከታተል ይጠቅማል።',
      targetRole: 'admin',
      targetScreen: '/admin/items',
      requiredPermission: 'items.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አዲስ እቃ መመዝገብ',
          description: 'የእቃውን ስም፣ አይነት፣ መለያ ቁጥር እና ብዛት ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ሁኔታውን ማዘመን',
          description: 'ጥሩ፣ የተበላሸ ወይም በእድሳት ላይ መሆኑን ያመልክቱ።',
        ),
      ],
      tips: ['ውድ እቃዎችን በመለያ ቁጥራቸው (Serial Number) መመዝገብ ለቁጥጥር አመቺ ነው።'],
      faqItems: [
        GuidanceFaq(
          question: 'የተበላሸ እቃ ከዝርዝር እንዴት ይወገዳል?',
          answer: 'የእቃውን ሁኔታ «የተወገደ» (Disposed) በማድረግ ከንቁ ዝርዝር ማውጣት ይቻላል።',
        ),
      ],
    ),

    // 30. ADMIN: BORROWINGS
    '/admin/borrowings': const GuidanceArticle(
      id: 30,
      slug: 'admin-borrowings',
      category: 'admin',
      title: 'የውሰት አስተዳደር (Borrowings Admin)',
      summary: 'የተወሰዱ ንብረቶችን እና መጻሕፍትን መከታተል፣ የተመላሽ ቀን እና ቅጣቶችን ማስተዳደር።',
      content:
          'አባላት ለግል ወይም ለአገልግሎት የተዋሷቸውን መጻሕፍት እና እቃዎች ለመቆጣጠር፣ የተወሰደበትን ቀን፣ መመለሻ ጊዜውን እና በሰዓቱ ያልተመለሱ እቃዎችን ለመከታተል የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/borrowings',
      requiredPermission: 'borrowing.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ውሰት መመዝገብ',
          description: 'ተበዳሪውን አባል፣ እቃውን እና የሚመለስበትን ቀን ይወስኑ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መመለሱን ማረጋገጥ',
          description: 'እቃው ሲመለስ ሁኔታውን አይተው «ተመልሷል» የሚለውን ይጫኑ።',
        ),
      ],
      tips: ['የመመለሻ ቀኑ ካለፈ በኋላ ስርዓቱ ለአባሉ የማስጠንቀቂያ ማሳወቂያ ይልካል።'],
      faqItems: [
        GuidanceFaq(
          question: 'እቃው ቢጠፋ ወይም ቢበላሽ ምን ይደረጋል?',
          answer: 'በአስተዳዳሪው ውሳኔ የካሳ ወይም የመተኪያ ክፍያ በቅጣት መልክ ሊመዘገብ ይችላል።',
        ),
      ],
    ),

    // 31. ADMIN: PROPERTY REQUESTS
    '/admin/property-requests': const GuidanceArticle(
      id: 31,
      slug: 'admin-property-requests',
      category: 'admin',
      title: 'የንብረት መጠየቂያዎች (Property Requests)',
      summary: 'ክፍላት ለአገልግሎት የሚጠይቋቸውን እቃዎች እና የንብረት ግዢዎች መገምገም።',
      content:
          'የተለያዩ የአገልግሎት ክፍላት ለስራቸው የሚያስፈልጓቸውን ንብረቶች ወይም አላቂ እቃዎች ለማግኘት የሚያቀርቡትን ጥያቄ የንብረት ክፍል ኃላፊዎች መርምረው የሚፈቅዱበት ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/property-requests',
      requiredPermission: 'property.review',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ጥያቄውን መመርመር',
          description: 'የጠየቀውን ክፍል፣ የተጠየቀውን እቃ እና አገልግሎቱን ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ማጽደቅ እና ማስረከብ',
          description: 'በመጋዘን ውስጥ ካለ ፈቅደው ያስረክቡ፤ ከሌለ የግዢ ውሳኔ ይስጡ።',
        ),
      ],
      tips: ['የተፈቀዱ እቃዎች በራስ-ሰር ከንብረት ክምችት ላይ ይቀነሳሉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ጥያቄው በከፊል ሊፈቀድ ይችላል?',
          answer: 'አዎ፤ ከተጠየቀው ብዛት ያነሰ መጠን ፈቅዶ ማስረከብ ይቻላል።',
        ),
      ],
    ),

    // 32. ADMIN: LIBRARY REQUESTS
    '/admin/library-requests': const GuidanceArticle(
      id: 32,
      slug: 'admin-library-requests',
      category: 'admin',
      title: 'የቤተ-መጽሐፍት መጠየቂያዎች (Library Requests)',
      summary: 'ተማሪዎች እና አባላት መጻሕፍት ለመዋስ የሚያቀርቧቸውን ጥያቄዎች ማስተዳደር።',
      content:
          'አባላት በመተግበሪያው በኩል የቤተ-መጽሐፍት ካታሎግ አይተው መጽሐፍ ለመዋስ ያቀረቧቸውን ጥያቄዎች መርምሮ መጽሐፉን ማስረከብ እና ውሰቱን ማጽደቅ የሚያስችል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/library-requests',
      requiredPermission: 'borrowing.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የተጠየቀውን መጽሐፍ ማረጋገጥ',
          description: 'መጽሐፉ በመደርደሪያው ላይ መኖሩን ያረጋግጡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ውሰቱን ማጽደቅ',
          description: 'አባሉ መጥቶ ሲወስድ መጽሐፉን አስረክበው ያጽድቁ።',
        ),
      ],
      tips: ['አንድ አባል በአንድ ጊዜ ከአንድ ወይም ሁለት መጽሐፍ በላይ እንዳይወስድ መገደብ ይቻላል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የውሰት ጊዜው ስንት ቀን ነው?',
          answer: 'እንደ ቤተ-መጽሐፍቱ ደንብ አብዛኛውን ጊዜ ከ14 እስከ 21 ቀናት ነው።',
        ),
      ],
    ),

    // 33. EDU: COURSES
    '/edu/courses': const GuidanceArticle(
      id: 33,
      slug: 'edu-courses',
      category: 'education',
      title: 'የትምህርት ኮርሶች አስተዳደር (Education Courses)',
      summary: 'የሰንበት ት/ቤት ኮርሶችን፣ ማስተማሪያ ስርአተ-ትምህርቶችን እና መምህራንን ማስተዳደር።',
      content:
          'በሰንበት ት/ቤቱ የሚሰጡትን መንፈሳዊ ኮርሶች ለመቅረጽ፣ ማስተማሪያ ጽሑፎችን ለመስቀል እና መምህራንን ለመመደብ የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/edu/courses',
      requiredPermission: 'education.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አዲስ ኮርስ መፍጠር',
          description: 'የኮርሱን ርዕስ፣ መግለጫ እና የትምህርት ሰዓት ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ስርአተ-ትምህርት ማዘጋጀት',
          description: 'የኮርሱን ምዕራፎች እና ማጣቀሻ መጻሕፍት ያክሉ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'መምህር መመደብ',
          description: 'ኮርሱን የሚያስተምረውን መምህር ይምረጡ።',
        ),
      ],
      tips: ['ተማሪዎች የኮርሱን ማጠቃለያ እና የፈተና ውጤት በመተግበሪያቸው ማየት ይችላሉ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ኮርሱን ለተወሰነ ክፍል ብቻ መወሰን ይቻላል?',
          answer: 'አዎ፤ ኮርሱ ለየትኛው ክፍል (Level) ክፍት እንደሆነ መወሰን ይቻላል።',
        ),
      ],
    ),

    // 34. EDU: MANAGE CLASSES
    '/edu/manage': const GuidanceArticle(
      id: 34,
      slug: 'edu-manage',
      category: 'education',
      title: 'የትምህርት ክፍሎች እና ባቾች (Classes & Batches)',
      summary: 'የትምህርት አመታትን፣ ሴሚስተሮችን፣ የክፍል ክፍለ-ጊዜዎችን እና ተማሪዎችን ማደራጀት።',
      content:
          'የትምህርት ክፍሎችን (ክፍል 1 እስከ 12) እና የትምህርት ባቾችን ለማስተዳደር፣ የጊዜ ሰሌዳ ለማውጣት እና የተማሪዎችን ውጤት ለመከታተል የሚያገለግል ዋና የትምህርት ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/edu/manage',
      requiredPermission: 'education.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ባች ወይም ክፍል መምረጥ',
          description: 'የሚፈልጉትን የትምህርት ክፍል ይክፈቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የጊዜ ሰሌዳ ማውጣት',
          description: 'የክፍለ-ጊዜውን ቀን እና ሰዓት ያስተካክሉ።',
        ),
      ],
      tips: ['የትምህርት ሞጁል በስርዓት ቅንብሮች ከጠፋ ይህ ክፍል ለተጠቃሚዎች አይታይም።'],
      faqItems: [
        GuidanceFaq(
          question: 'ተማሪዎችን ከአንድ ክፍል ወደ ቀጣይ ክፍል ማዘዋወር ይቻላል?',
          answer: 'አዎ፤ አመቱ ሲጠናቀቅ ተማሪዎችን በጅምላ ወደ ቀጣዩ ክፍል ማሳደግ ይቻላል።',
        ),
      ],
    ),

    // 35. EDU: REGISTRATIONS
    '/edu/registrations': const GuidanceArticle(
      id: 35,
      slug: 'edu-registrations',
      category: 'education',
      title: 'የተማሪዎች ምዝገባ (Student Registrations)',
      summary: 'አዳዲስ ተማሪዎች ወደ ሰንበት ት/ቤት ለመግባት ያቀረቧቸውን ማመልከቻዎች መገምገም።',
      content:
          'ወደ ሰንበት ት/ቤት ለመግባት በመተግበሪያው በኩል የተመዘገቡ አዳዲስ ተማሪዎችን መረጃ መርምሮ ለመቀበል ወይም ክፍል ለመመደብ የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/edu/registrations',
      requiredPermission: 'education.register',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አመልካቾችን መመልከት',
          description: 'የተማሪውን የግል መረጃ፣ እድሜ እና የቀድሞ መንፈሳዊ ትምህርት ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ክፍል መመደብ እና ማጽደቅ',
          description: 'ተገቢውን ክፍል መርጠው ምዝገባውን ያጽድቁ።',
        ),
      ],
      tips: ['ምዝገባው ሲጸድቅ ተማሪው የአባልነት ቁጥር እና የመግቢያ ፈቃድ ያገኛል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ያልተሟላ መረጃ ያለው ተማሪ ምን ይደረጋል?',
          answer: 'ምዝገባውን ለጊዜው አግዶ ተጨማሪ መረጃ እንዲያቀርብ መልዕክት መላክ ይቻላል።',
        ),
      ],
    ),

    // 36. ADMIN: CHOIR SELECTIONS & SERVICE BONUSES
    '/admin/selections': const GuidanceArticle(
      id: 36,
      slug: 'admin-selections',
      category: 'admin',
      title: 'የበዓላት መዘምራን መረጣ (Choir Selections & Service Bonuses)',
      summary: 'ለዋና ዋና በዓላት የሚዘምሩ አባላትን በአቴንዳንስ ነጥብ እና በቦነስ ደንብ መምረጥ።',
      content:
          'ለበዓለ-ጥምቀት፣ ለፋሲካ፣ ለመስቀል እና ለንግስ በዓላት በመድረክ የሚያገለግሉ መዘምራንን በግልጽ መስፈርት ለመምረጥ የሚያገለግል ክፍል ነው። የመገኘት ምጣኔ፣ የትምህርት ውጤት እና የመዝሙር አገልግሎት ቦነስ ተደምረው አባላት በደረጃቸው ይመረጣሉ። ቦነስ በቋሚ ወይም በመቶኛ ሲሰላ ከመዝሙር አቴንዳንስ አካል ብቻ ይሰላል፤ ከፍተኛው የመዝሙር ነጥብም ከ100% አይበልጥም።',
      targetRole: 'admin',
      targetScreen: '/admin/selections',
      requiredPermission: 'selection.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የበዓሉን መረጣ መክፈት',
          description: 'የበዓሉን ስም፣ የሚያስፈልጉ መዘምራን ብዛት እና መመዘኛ ነጥብ ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የቦነስ ደንቦችን መተግበር',
          description: 'የአገልግሎት ቦነስ ነጥብ በቋሚ ወይም በመቶኛ ያሰሉ፤ ከ100% እንዳይበልጥ ያረጋግጡ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'የተመረጡትን ማጽደቅ',
          description: 'ዝርዝሩን ገምግመው ለመዘምራኑ ይፋ ያድርጉ።',
        ),
      ],
      tips: ['የመዝሙር ቦነስ ወደ ትምህርት ወይም ወደ ሌላ ክፍል ውጤት በፍጹም አይተላለፍም።'],
      faqItems: [
        GuidanceFaq(
          question: 'አባላት ውጤታቸውን ማየት ይችላሉ?',
          answer: 'አዎ፤ የተመረጡትም ሆኑ ተጠባባቂዎች ደረጃቸውን በግልፅ በመተግበሪያቸው ያያሉ።',
        ),
      ],
    ),

    // 37. ADMIN: WEDDINGS
    '/admin/weddings': const GuidanceArticle(
      id: 37,
      slug: 'admin-weddings',
      category: 'admin',
      title: 'የሰርግ መዘምራን አገልግሎት (Wedding Choir Service)',
      summary: 'የሰርግ መርሃ-ግብሮችን እና የአገልጋይ መዘምራንን ምደባ ማስተዳደር።',
      content:
          'የሰርግ መዝሙር አገልግሎት ጥያቄዎችን ለመመዝገብ፣ የሚዘምሩ አባላትን ለመመደብ እና የአገልግሎቱን አፈጻጸም ለመከታተል የሚረዳ ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/weddings',
      requiredPermission: 'choir.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የሰርግ መርሐ ግብር መመዝገብ',
          description: 'የሙሽሮችን ስም፣ የሰርጉን ቀን፣ ሰዓት እና ቦታ ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መዘምራንን መመደብ',
          description: 'ተረኛ መዘምራንን ከአባላት ዝርዝር ይምረጡ።',
        ),
      ],
      tips: ['ለተመደቡት መዘምራን የቀኑ እና የቦታው ማስታወቂያ በስልካቸው ይላካል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የሰርግ አገልግሎት አቴንዳንስ ይያዝለታል?',
          answer: 'አዎ፤ እንደ አንድ ልዩ መርሐ ግብር ተቆጥሮ አቴንዳንስ ይመዘገብበታል።',
        ),
      ],
    ),

    // 38. ADMIN: MEZMUR CATEGORIES
    '/admin/categories': const GuidanceArticle(
      id: 38,
      slug: 'admin-categories',
      category: 'admin',
      title: 'የመዝሙር ምድቦች አስተዳደር (Mezmur Categories Admin)',
      summary: 'የመዝሙር አቃፊዎችን፣ ንዑሳን ምድቦችን እና ቅደም ተከተላቸውን ማስተካከል።',
      content:
          'በመተግበሪያው ውስጥ የሚታዩትን የመዝሙር ምድቦች ለመፍጠር፣ ቅደም ተከተል ለማስያዝ እና ምስል ለመስጠት የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/categories',
      requiredPermission: 'categories.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ምድብ መፍጠር',
          description: 'የምድቡን ስም በአማርኛ እና በእንግሊዝኛ ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ምስል እና ቅደም ተከተል መስጠት',
          description: 'አዶ ወይም ምስል መርጠው በስክሪኑ ላይ የሚታይበትን ቅደም ተከተል ይወስኑ።',
        ),
      ],
      tips: ['ምድብ ሲሰረዝ በውስጡ ያሉት መዝሙራት አይጠፉም፤ ወደ ሌላ ምድብ ማዛወር ይቻላል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ንዑስ ምድብ (Sub-category) መፍጠር ይቻላል?',
          answer: 'አዎ፤ አንድን ምድብ የሌላ ምድብ ልጅ ማድረግ ይቻላል።',
        ),
      ],
    ),

    // 39. ADMIN: MEZMURS CONTENT
    '/admin/mezmurs': const GuidanceArticle(
      id: 39,
      slug: 'admin-mezmurs',
      category: 'admin',
      title: 'የመዝሙራት ይዘት አስተዳደር (Mezmur Content Management)',
      summary: 'መዝሙራትን መመዝገብ፣ ግጥሞችን ማረም፣ የድምጽ ፋይሎችን መስቀል እና ማስተዳደር።',
      content:
          'አዳዲስ መዝሙራትን ወደ ስርዓቱ ለማስገባት፣ የግጥም ስንኞችን ለማስተካከል፣ የዜማ ደራሲ እና አዝማች መረጃዎችን ለማስቀመጥ እና የMP3 ድምጽ ፋይሎችን ለመስቀል የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/mezmurs',
      requiredPermission: 'mezmurs.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'መዝሙር መመዝገብ',
          description: 'ርዕስ፣ ምድብ እና ግጥም ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ድምጽ መስቀል',
          description: 'ከፍተኛ ጥራት ያለው የድምጽ ፋይል ያያይዙ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'የግጥም ማመሳሰል (LRC)',
          description: 'ድምጹ ሲጫወት ግጥሙ አብሮ እንዲሄድ የሰዓት ማመሳሰያ ያስገቡ።',
        ),
      ],
      tips: ['ግጥሞችን በትክክለኛ የኢትዮጵያ ፊደላት መጻፍዎን ያረጋግጡ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ድምጽ የሌላቸው መዝሙራት ሊገቡ ይችላሉ?',
          answer: 'አዎ፤ ግጥም ብቻ ያላቸው መዝሙራት ተመዝግበው ተጠቃሚዎች እንዲያነቧቸው ማድረግ ይቻላል።',
        ),
      ],
    ),

    // 40. ADMIN: BULK IMPORT
    '/admin/import': const GuidanceArticle(
      id: 40,
      slug: 'admin-import',
      category: 'admin',
      title: 'የጅምላ መረጃ ማስገቢያ (Bulk Import & Data Migration)',
      summary: 'መዝሙራትን፣ አባላትን ወይም አቴንዳንስን በExcel/CSV ፋይል በጅምላ ማስገባት።',
      content:
          'በመቶዎች የሚቆጠሩ መዝሙራትን ወይም የአባላት መረጃዎችን በአንድ ጊዜ ከExcel ፋይል ወደ መተግበሪያው ዳታቤዝ ለማስገባት የሚያገለግል ፈጣን የውሂብ ማስገቢያ ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/import',
      requiredPermission: 'mezmurs.create',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የተዘጋጀውን ቴምፕሌት ማውረድ',
          description: 'ትክክለኛውን የExcel ቅጽ ያውርዱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'መረጃውን ሞልቶ መስቀል',
          description: 'መረጃውን በትክክለኛው አምድ ሞልተው ፋይሉን ይስቀሉ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ስህተቶችን መመርመር',
          description: 'ስርዓቱ ስህተት ያለባቸውን መስመሮች ሲያሳይ አርመው ያጽድቁ።',
        ),
      ],
      tips: ['ፋይሉን ከመስቀልዎ በፊት የአምዶችን ስም አለመቀየርዎን ያረጋግጡ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የተደገሙ መረጃዎች ካሉ ስርዓቱ ምን ያደርጋል?',
          answer: 'የተደገሙ ስልኮች ወይም መታወቂያዎች ካሉ ስርዓቱ አስጠንቅቆ እንዳይገቡ ያግዳል ወይም ያዘምናል።',
        ),
      ],
    ),

    // 41. ADMIN: PROGRAM CATEGORIES
    '/admin/program-categories': const GuidanceArticle(
      id: 41,
      slug: 'admin-program-categories',
      category: 'admin',
      title: 'የመርሐ ግብር ምድቦች (Program Categories)',
      summary: 'የሰንበት ት/ቤት መርሐ ግብራትን አይነቶች (ልምምድ፣ ጉባኤ፣ ውይይት) ማስተዳደር።',
      content:
          'መርሐ ግብሮችን በዓይነታቸው ለመከፋፈል (የመዝሙር ልምምድ፣ የትምህርት ክፍለ-ጊዜ፣ የጠቅላላ ጉባኤ፣ የጾም ጸሎት) የሚያገለግሉ ምድቦችን ለመፍጠር ይጠቅማል።',
      targetRole: 'admin',
      targetScreen: '/admin/program-categories',
      requiredPermission: 'program_categories.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ምድብ መፍጠር',
          description: 'የምድቡን ስም እና መለያ ቀለም ይምረጡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ደንብ ማያያዝ',
          description: 'ለዚህ ምድብ ተስማሚ የሆነውን የአቴንዳንስ ህግ ይወስኑ።',
        ),
      ],
      tips: ['ቀለሞችን መለየት አባላት በመቁጠሪያ ገጻቸው ላይ መርሐ ግብሩን በቀላሉ እንዲለዩት ይረዳል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ምድብ ሲጠፋ የተፈጠሩት መርሐ ግብራት ይጠፋሉ?',
          answer: 'አይጠፉም፤ ወደ ነባሪው ምድብ ይዘዋወራሉ።',
        ),
      ],
    ),

    // 42. ADMIN: ADS & ANNOUNCEMENTS
    '/admin/ads': const GuidanceArticle(
      id: 42,
      slug: 'admin-ads',
      category: 'admin',
      title: 'የማስታወቂያዎች አስተዳደር (Announcements & Banner Ads)',
      summary: 'በመተግበሪያው ገጾች ላይ የሚታዩ መንፈሳዊ ማስታወቂያዎችን እና ባነሮችን ማዘጋጀት።',
      content:
          'አስፈላጊ የቤተክርስቲያን ጥሪዎችን፣ የበዓላት ማስታወቂያዎችን እና ልዩ ዝግጅቶችን በመተግበሪያው መነሻ ገጽ ላይ በባነር መልኩ ለማሳየት የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/ads',
      requiredPermission: 'ads.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ማስታወቂያ መፍጠር',
          description: 'ርዕስ፣ ምስል እና የሚቆይበትን የቀን ወሰን ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የሚከፈት ገጽ ማያያዝ',
          description: 'ተጠቃሚው ሲጫነው የሚከፈተውን ገጽ ወይም ሊንክ ያያይዙ።',
        ),
      ],
      tips: ['ምስሎች ጥራት ያላቸው እና መጠናቸው አነስተኛ መሆናቸውን ያረጋግጡ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የማስታወቂያው ጊዜ ሲያበቃ ምን ይሆናል?',
          answer: 'የቀን ገደቡ ሲያበቃ ማስታወቂያው በራስ-ሰር ከመነሻ ገጽ ላይ ይወርዳል።',
        ),
      ],
    ),

    // 43. ADMIN: PAGES
    '/admin/pages': const GuidanceArticle(
      id: 43,
      slug: 'admin-pages',
      category: 'admin',
      title: 'የገጾች እና መመሪያዎች አስተዳደር (Static Pages & Guidelines)',
      summary: 'የሰንበት ት/ቤቱን ታሪክ፣ ደንቦች፣ የአገልግሎት መመሪያዎች እና መረጃዎችን ማረም።',
      content:
          'በመተግበሪያው ውስጥ የሚታዩትን ቋሚ ገጾች (ስለ ሰንበት ት/ቤቱ፣ ደንብ እና መመሪያ፣ የክፍላት የስራ ድርሻ) ለመጻፍ እና ይዘታቸውን ለማዘመን የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/pages',
      requiredPermission: 'pages.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ገጽ መምረጥ',
          description: 'የሚፈልጉትን ገጽ ይክፈቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ጽሑፉን ማረም',
          description: 'ይዘቱን አዘምነው ለተጠቃሚዎች ይፋ ያድርጉ።',
        ),
      ],
      tips: ['አስፈላጊ ለውጦች ሲደረጉ ለአባላት ማሳወቂያ መላክ ይመረጣል።'],
      faqItems: [
        GuidanceFaq(
          question: 'አዲስ ገጽ መጨመር ይቻላል?',
          answer: 'አዎ፤ አዳዲስ ገጾችን ፈጥሮ በቅንብሮች ወይም በመረጃ ዝርዝር ውስጥ ማካተት ይቻላል።',
        ),
      ],
    ),

    // 44. PROJECTS: MY TASKS
    '/projects/my-tasks': const GuidanceArticle(
      id: 44,
      slug: 'projects-my-tasks',
      category: 'admin',
      title: 'የፕሮጀክት ተግባራት (Project Tasks & Milestones)',
      summary: 'ለአገልግሎት ክፍላት እና ለአባላት የተሰጡ ተግባራትን መከታተል እና ማጠናቀቅ።',
      content:
          'የሰንበት ት/ቤት ፕሮጀክቶችን እና የልማት ስራዎችን በተግባር ከፋፍሎ ለመምራት፣ የፈጻሚዎችን ስም ለመመደብ፣ የማብቂያ ቀን ለመስጠት እና የእድገት ደረጃቸውን ለመከታተል ይጠቅማል።',
      targetRole: 'admin',
      targetScreen: '/projects/my-tasks',
      requiredPermission: 'projects.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ተግባር መመደብ',
          description: 'የስራውን ዝርዝር፣ ኃላፊውን እና የማጠናቀቂያ ቀኑን ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ሁኔታውን ማዘመን',
          description: 'ተግባሩ ሲጀመር «በሂደት ላይ»፣ ሲያልቅ «ተጠናቋል» በማለት ምልክት ያድርጉ።',
        ),
      ],
      tips: ['የማጠናቀቂያ ቀኑ ሲቃረብ ለኃላፊው ማስታወሻ ይላካል።'],
      faqItems: [
        GuidanceFaq(
          question: 'አባላት ተግባራቸውን የት ያዩታል?',
          answer: 'በመተግበሪያው የፕሮጀክት ገጽ ውስጥ «የእኔ ተግባራት» ስር ያገኙታል።',
        ),
      ],
    ),

    // 45. PROJECTS: APPROVALS
    '/projects/approvals': const GuidanceArticle(
      id: 45,
      slug: 'projects-approvals',
      category: 'admin',
      title: 'የወጪ እና በጀት ማጽደቂያዎች (Project Expense Approvals)',
      summary: 'ለፕሮጀክቶች እና ለክፍላት የተጠየቁ የወጪ ጥያቄዎችን መርምሮ ማጽደቅ።',
      content:
          'ለሰንበት ት/ቤት ስራዎች እና ፕሮጀክቶች የሚወጡ ወጪዎችን ለመቆጣጠር፣ ደረሰኞችን ለመመርመር እና የበጀት ክፍያን በፋይናንስ ኃላፊዎች ለማጽደቅ የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/projects/approvals',
      requiredPermission: 'projects.expenses.approve',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የወጪ ጥያቄውን መክፈት',
          description: 'የተጠየቀውን የገንዘብ መጠን፣ ምክንያት እና የተያያዘውን ደረሰኝ ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ውሳኔ መስጠት',
          description: 'በጀቱ የሚፈቅድ ከሆነ ያጽድቁ፤ ካልሆነ ምክንያቱን ጽፈው ይመልሱ።',
        ),
      ],
      tips: ['ያለ ደረሰኝ የቀረቡ ጥያቄዎችን አለማጽደቅ ይመረጣል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የጸደቁ ወጪዎች በፋይናንስ ሪፖርት ውስጥ ይካተታሉ?',
          answer: 'አዎ፤ ወዲያውኑ በፕሮጀክቱ የወጪ መዝገብ እና በጠቅላላ የበጀት ሪፖርት ውስጥ ይመዘገባሉ።',
        ),
      ],
    ),

    // 46. ADMIN: ADMINS MANAGEMENT
    '/admin/admins': const GuidanceArticle(
      id: 46,
      slug: 'admin-admins',
      category: 'admin',
      title: 'የአስተዳዳሪዎች አስተዳደር (Staff Administrators)',
      summary: 'የስርዓት አስተዳዳሪዎችን መሾም፣ ሚናዎችን መስጠት እና የስራ ድርሻቸውን ማስተካከል።',
      content:
          'የሰንበት ት/ቤት አገልጋዮችን እና ኃላፊዎችን የስርዓት አስተዳዳሪ አድርጎ ለመሾም፣ የአስተዳዳሪነት ደረጃ ለመስጠት እና ስራቸውን ሲጨርሱ ፈቃዳቸውን ለመሰረዝ የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/admins',
      requiredPermission: 'admins.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አዲስ አስተዳዳሪ መመደብ',
          description: 'አባሉን መርጠው የአስተዳዳሪ ሚና ይስጡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ፈቃዶችን ማረጋገጥ',
          description: 'የሚሰጣቸውን የስራ ክፍል ፈቃዶች በጥንቃቄ ይምረጡ።',
        ),
      ],
      tips: ['ለእያንዳንዱ አስተዳዳሪ ለስራው የሚያስፈልገውን ፈቃድ ብቻ ይስጡ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የአስተዳዳሪነት ፈቃድ ወዲያውኑ ይሰራል?',
          answer: 'አዎ፤ አባሉ መተግበሪያውን እንደገና ሲከፍት የአስተዳዳሪ ካርዶቹ ይታዩታል።',
        ),
      ],
    ),

    // 47. ADMIN: ROLES & PERMISSIONS
    '/admin/roles': const GuidanceArticle(
      id: 47,
      slug: 'admin-roles',
      category: 'admin',
      title: 'ሚናዎች እና ፈቃዶች (Roles & Permissions Matrix)',
      summary: 'የስራ ሚናዎችን መፍጠር እና ለእያንዳንዱ ሚና ዝርዝር ፈቃዶችን መወሰን።',
      content:
          'በመተግበሪያው ውስጥ ያሉ የአስተዳዳሪ ሚናዎችን ለመፍጠር እና ለእያንዳንዱ ሚና የሚፈቀዱትን እና የሚከለከሉትን ድርጊቶች በዝርዝር ለመወሰን ያገለግላል።',
      targetRole: 'admin',
      targetScreen: '/admin/roles',
      requiredPermission: 'admins.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ሚና መፍጠር ወይም መምረጥ',
          description: 'የሚናውን ስም ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ፈቃዶችን መምረጥ',
          description: 'ለሚናው የሚገቡትን ፈቃዶች በቼክቦክስ ይምረጡ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ማስቀመጥ',
          description: 'ለውጡን በቋሚነት ያጽድቁ።',
        ),
      ],
      tips: ['የሱፐር አድሚን ሚና ሁሉንም ፈቃዶች በራስ-ሰር ይይዛል።'],
      faqItems: [
        GuidanceFaq(
          question: 'የአንድ ሚና ፈቃድ ሲቀየር በዚያ ሚና ስር ያሉ ሰዎች ወዲያውኑ ይነካሉ?',
          answer: 'አዎ፤ በሚቀጥለው መግቢያቸው ላይ አዲሱ ፈቃድ ተፈጻሚ ይሆናል።',
        ),
      ],
    ),

    // 48. ADMIN: SETTINGS & MODULES
    '/admin/settings': const GuidanceArticle(
      id: 48,
      slug: 'admin-settings',
      category: 'admin',
      title: 'የስርዓት ቅንብሮች እና ሞጁሎች (System Settings & Modules)',
      summary: 'የመተግበሪያውን አጠቃላይ ቅንብሮች፣ የትምህርት እና መዝሙር ሞጁል መቆጣጠሪያዎችን ማስተዳደር።',
      content:
          'የሰንበት ት/ቤቱን አጠቃላይ የስርዓት መለኪያዎች ለመቆጣጠር ይጠቅማል። የትምህርት (Education) እና የመዝሙር (Mezmur) ሞጁሎችን ለማብራት ወይም ለማጥፋት ያስችላል። አንድ ሞጁል ሲጠፋ መረጃው ሳይሰረዝ በሰላም ይቀመጣል፤ ለተጠቃሚዎች ግን እንዳይታይ ይታገዳል። አንዱ ብቻ ሲበራ ስርዓቱ ተጠቃሚውን በቀጥታ ወደዚያው ሞጁል ያሸጋግረዋል።',
      targetRole: 'admin',
      targetScreen: '/admin/settings',
      requiredPermission: 'settings.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የሞጁል ማብሪያ/ማጥፊያዎችን መቆጣጠር',
          description: 'የትምህርት ወይም የመዝሙር አገልግሎትን እንደ አስፈላጊነቱ ያብሩ/ያጥፉ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የስርዓት መለኪያዎችን ማስተካከል',
          description: 'የቀን መቁጠሪያ፣ የአባልነት መለያ ፎርማት እና የደወል ደንቦችን ይወስኑ።',
        ),
      ],
      tips: ['የድብቁ ከፍተኛ ተቆጣጣሪ እና የሱፐር አድሚን ልዩነት እንደተጠበቀ ይቆያል።'],
      faqItems: [
        GuidanceFaq(
          question: 'ሞጁል ሲጠፋ የቀድሞ መረጃ ይጠፋል?',
          answer: 'በፍጹም አይጠፋም፤ ሞጁሉ እንደገና ሲበራ ሁሉም መረጃ እንዳለ ይመለሳል።',
        ),
      ],
    ),

    // 49. ADMIN: RELEASES
    '/admin/releases': const GuidanceArticle(
      id: 49,
      slug: 'admin-releases',
      category: 'admin',
      title: 'የመተግበሪያ እትሞች (App Releases & Updates)',
      summary: 'አዳዲስ የመተግበሪያ እትሞችን መመዝገብ እና የግዴታ ማደሻ መወሰን።',
      content:
          'አዲስ የመተግበሪያ እትም ሲዘጋጅ ለአባላት የማሻሻያ ማስታወቂያ ለመላክ፣ የለውጥ ዝርዝሮችን ለማስቀመጥ እና አሮጌ ስሪት ያላቸው አባላት እንዲያድሱ የግዴታ ማደሻ ለማብራት ያገለግላል።',
      targetRole: 'admin',
      targetScreen: '/admin/releases',
      requiredPermission: 'releases.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'አዲስ እትም መመዝገብ',
          description: 'የስሪት ቁጥር Version Code/Name እና የለውጥ ማስታወሻ ያስገቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የግዴታ ማደሻ መወሰን',
          description: 'አሮጌው ስሪት እንዳይሰራ መከልከል ካስፈለገ Force Update ያብሩ።',
        ),
      ],
      tips: ['አስፈላጊ የደህንነት ማሻሻያዎች ሲኖሩ የግዴታ ማደሻን ይጠቀሙ።'],
      faqItems: [
        GuidanceFaq(
          question: 'ተጠቃሚዎች ማሻሻያውን እንዴት ያገኛሉ?',
          answer: 'መተግበሪያውን ሲከፍቱ አዲስ ስሪት መኖሩን የሚገልጽ መስኮት ወዲያውኑ ይመጣላቸዋል።',
        ),
      ],
    ),

    // 50. ADMIN: MANAGE GUIDANCE
    '/admin/guidance': const GuidanceArticle(
      id: 50,
      slug: 'admin-guidance',
      category: 'admin',
      title: 'የመመሪያዎች አስተዳደር (Manage In-App Guidance)',
      summary: 'የመመሪያ ማዕከል ጽሑፎችን፣ የእርምጃዎችን ቅደም ተከተል እና አጋዥ ጥያቄዎችን ማረም።',
      content:
          'አስተዳዳሪዎች በመመሪያ ማዕከል ውስጥ የሚታዩትን ጽሑፎች፣ የእርምጃ መመሪያዎች፣ ጠቃሚ ምክሮች እና ተደጋጋሚ ጥያቄዎችን በቀላሉ ለማረም፣ ለማደራጀት እና ይፋ ለማድረግ የሚያገለግል ክፍል ነው። ትክክለኛ ያልሆኑ የስክሪን መዳረሻዎች እንዳይገቡ ያረጋግጣል።',
      targetRole: 'admin',
      targetScreen: '/admin/guidance',
      requiredPermission: 'guidance.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'መመሪያ መምረጥ ወይም ማከል',
          description: 'የሚፈልጉትን የገጽ መመሪያ ይክፈቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ጽሑፉን እና እርምጃዎችን ማረም',
          description: 'ርዕስ፣ ማብራሪያ፣ ቅደም ተከተል እና ጥያቄዎችን ያዘምኑ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'መዳረሻዎችን ማረጋገጥ',
          description: 'የስክሪን አድራሻው ትክክለኛ መሆኑን አረጋግጠው ይለጥፉ።',
        ),
      ],
      tips: ['የአስተዳዳሪ ብቻ የሆኑ መመሪያዎች ለተራ አባላት እንዳይታዩ የTarget Role እና የፈቃድ ገደብ ይስጡ።'],
      faqItems: [
        GuidanceFaq(
          question: 'የተሰረዘ መመሪያ ወደ ነበረበት መመለስ ይቻላል?',
          answer: 'አዎ፤ መመሪያዎችን በረቂቅ (Draft) መልክ ማስቀመጥ ወይም ነባሩን ማደስ ይቻላል።',
        ),
      ],
    ),

    // 51. ADMIN: AUDIT LOGS
    '/admin/audit': const GuidanceArticle(
      id: 51,
      slug: 'admin-audit',
      category: 'admin',
      title: 'የስርዓት ኦዲት ሎግ (System Audit Trail)',
      summary: 'በስርዓቱ ውስጥ የተከናወኑ ወሳኝ የአስተዳደር ድርጊቶችን፣ ለውጦችን እና ስረዛዎችን መመርመር።',
      content:
          'በመተግበሪያው ውስጥ የተከናወኑ ሁሉንም የአስተዳደር ስራዎች ማን፣ መቼ እና ከየትኛው መሳሪያ እንደሰራው በማያጠራጥር መልኩ የተመዘገበበት የደህንነት እና የኦዲት መዝገብ ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/audit',
      requiredPermission: 'audit_logs.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'ድርጊቶችን ማጣራት',
          description: 'በቀን፣ በሰራው ሰው ስም ወይም በድርጊቱ አይነት ይፈልጉ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'ዝርዝሩን መመርመር',
          description: 'ከለውጡ በፊት እና በኋላ የነበረውን መረጃ ያነጻጽሩ።',
        ),
      ],
      tips: ['የኦዲት ሎግ መረጃዎች በማንም ሰው ሊሰረዙ ወይም ሊለወጡ አይችሉም።'],
      faqItems: [
        GuidanceFaq(
          question: 'የኦዲት መዝገብ ለምን ያህል ጊዜ ይቆያል?',
          answer: 'ለደህንነት እና ለህጋዊ ተጠያቂነት በቋሚነት በስርዓቱ ውስጥ ተቀምጦ ይኖራል።',
        ),
      ],
    ),

    // 52. ADMIN: USER ACTIVITY LOGS
    '/admin/activity': const GuidanceArticle(
      id: 52,
      slug: 'admin-activity',
      category: 'admin',
      title: 'የተጠቃሚዎች እንቅስቃሴ ሎግ (User Activity Logs)',
      summary: 'የአባላት የመተግበሪያ አጠቃቀም፣ የመግቢያ ሰዓታት እና የመስመር ውጭ ስራዎች ክትትል።',
      content:
          'አባላት መተግበሪያውን መቼ እንደከፈቱት፣ ምን መዝሙራት እንዳዳመጡ፣ ከመስመር ውጭ የሰሯቸውን ስራዎች እና መረጃዎችን መቼ እንዳመሳሰሉ የሚያሳይ የአጠቃቀም ክትትል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/activity',
      requiredPermission: 'activity_logs.view',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'እንቅስቃሴዎችን መመልከት',
          description: 'የቅርብ ጊዜ የተጠቃሚዎች መግቢያ እና ክንውን ይመልከቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የማመሳሰል (Sync) ሁኔታን ማረጋገጥ',
          description: 'ከመስመር ውጭ የተመዘገቡ መረጃዎች በሰላም መግባታቸውን ይከታተሉ።',
        ),
      ],
      tips: ['የተጠቃሚዎችን ግላዊነት የሚነኩ ሚስጥራዊ መረጃዎች እዚህ አይመዘገቡም።'],
      faqItems: [
        GuidanceFaq(
          question: 'ከመስመር ውጭ የተደረጉ እንቅስቃሴዎች መቼ ይገባሉ?',
          answer: 'ስልኩ ኢንተርኔት ባገኘ ቅጽበት ከመስመር ውጭ የነበረው እንቅስቃሴ ተመሳስሎ ይገባል።',
        ),
      ],
    ),

    // 53. ADMIN: DASHBOARD OVERVIEW
    '/admin': const GuidanceArticle(
      id: 53,
      slug: 'admin-dashboard',
      category: 'admin',
      title: 'የአስተዳዳሪ ማዕከል (Admin Dashboard)',
      summary: 'የአስተዳዳሪዎች ዋና መቆጣጠሪያ ማዕከል፣ የፈቃድ መረጃ እና ሞጁሎች።',
      content:
          'የሰንበት ት/ቤት አስተዳዳሪዎች እንደተሰጣቸው ሚና እና ፈቃድ አባላትን፣ መርሐ ግብሮችን፣ ክፍያዎችን፣ አቴንዳንስን እና ሪፖርቶችን የሚያስተዳድሩበት ዋና ማዕከል ነው። እያንዳንዱ ካርድ የተመደበለትን አገልግሎት ይወክላል።',
      targetRole: 'admin',
      targetScreen: '/admin',
      tourId: 'admin_tour',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'የሞጁል ካርዶችን መክፈት (Access Modules)',
          description: 'የተፈቀደልዎትን ማንኛውንም የስራ ክፍል ካርድ በመጫን በቀጥታ ወደ ስራው ገጽ ይግቡ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'የእገዛ አዶን መጠቀም (Contextual Help)',
          description: 'በእያንዳንዱ ካርድ የላይኛው ቀኝ ጥግ ላይ ያለውን የጥያቄ ምልክት (?) በመጫን የዚያን አገልግሎት ዝርዝር መመሪያ ያግኙ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'ማስጠንቀቂያዎችን መከታተል (Pending Alerts)',
          description: 'የቀረቡ የፈቃድ ጥያቄዎችን እና የአቴንዳንስ ማስታወሻዎችን ከላይ ባሉት ካርዶች ይከታተሉ።',
        ),
      ],
      tips: ['የማይፈቀድልዎ ካርድ በገጹ ላይ አይታይም፤ አዲስ ፈቃድ ካስፈለገዎት ለዋና አስተዳዳሪው ያመልክቱ።'],
      faqItems: [
        GuidanceFaq(
          question: 'አንዳንድ ካርዶች ለምን አይታዩኝም? (Why are some cards hidden?)',
          answer: 'ካርዶች የሚታዩት ለተጠቃሚው በተሰጠው ፈቃድ (Permissions) መሰረት ብቻ ነው።',
        ),
      ],
    ),

    // 54. ADMIN: ATTENDANCE HUB
    '/admin/attendance': const GuidanceArticle(
      id: 54,
      slug: 'admin-attendance-hub',
      category: 'attendance',
      title: 'የአቴንዳንስ አስተዳደር (Attendance Management)',
      summary: 'የአባላት እና ተማሪዎች የመገኘት ክትትል፣ የQR ቅኝት፣ ሰዓታት እና ማረጋገጫዎች።',
      content:
          'በመርሐ ግብሮች እና በትምህርት ክፍሎች ወቅት የአባላትን እና የተማሪዎችን መገኘት ለመመዝገብ፣ በQR ስካነር ለማረጋገጥ፣ የአቴንዳንስ ደንቦችን ለማውጣት እና የቀረቡ የእርማት ጥያቄዎችን ለመመርመር የሚያገለግል ክፍል ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/attendance',
      requiredPermission: 'attendance.manage',
      steps: [
        GuidanceStep(
          step: 1,
          title: 'መርሐ ግብር መምረጥ (Select Program)',
          description: 'የቀኑን መርሐ ግብር በመምረጥ የአቴንዳንስ መዝገቡን ይክፈቱ።',
        ),
        GuidanceStep(
          step: 2,
          title: 'በQR ወይም በእጅ መመዝገብ (Mark Attendance)',
          description: 'የአባላትን ዲጂታል መታወቂያ በካሜራ በመቃኘት ወይም ከዝርዝር ውስጥ በመፈለግ የመገኘት ሁኔታቸውን ያጽድቁ።',
        ),
        GuidanceStep(
          step: 3,
          title: 'መዝገቡን መዝጋት (Finalize Attendance)',
          description: 'የመገኘት ሰዓቱ ሲጠናቀቅ መዝገቡን በመቆለፍ ይፋዊ ያድርጉ።',
        ),
      ],
      tips: ['የአቴንዳንስ ሰዓት ገደብ ሲያልፍ መዝገቡ በራስ-ሰር ይዘጋል።'],
      faqItems: [
        GuidanceFaq(
          question: 'በስህተት የቀረ ተብሎ የተመዘገበ አባል እንዴት ይስተካከላል? (How to correct attendance?)',
          answer: 'አባሉ የመገኘት እርማት ጥያቄ (Attendance Correction Request) ሲያቀርብ አስተዳዳሪው መርምሮ ሊያስተካክል ይችላል።',
        ),
      ],
    ),

    // 55. EDUCATION: STUDENT REQUESTS, COMPLAINTS, JOURNEY
    '/edu/services': const GuidanceArticle(
      id: 55,
      slug: 'edu-self-service',
      category: 'education',
      title: 'ጥያቄዎች፣ ቅሬታዎች እና የትምህርት ጉዞ (Requests, Complaints & Journey)',
      summary: 'የክፍል፣ የዘርፍ ወይም የትምህርት ዓይነት ለውጥ መጠየቅ፣ ትምህርት መጨመር/መተው፣ ሚስጥራዊ ቅሬታ ማቅረብ እና የትምህርት ታሪክን ማየት።',
      content:
          'ጥያቄዎ ከቀረበ በኋላ የትምህርት ክፍሉ ኃላፊ ያጸድቀዋል ወይም ውድቅ ያደርገዋል። ሲጸድቅ ለውጡ በምዝገባዎ ላይ ወዲያውኑ ይተገበራል። ቅሬታዎ ሚስጥራዊ ነው፤ የመለያ ቁጥር ይሰጥዎታል። የትምህርት ጉዞ ምዝገባ፣ ለውጦች እና የታተሙ ውጤቶችን በቅደም ተከተል ያሳያል።',
      targetRole: 'member',
      targetScreen: '/edu/services',
      steps: [
        GuidanceStep(step: 1, title: 'አዲስ ጥያቄ (New request)', description: 'የጥያቄውን ዓይነት፣ ክፍሉን እና ምክንያቱን ይምረጡ፤ «አስገባ» ይጫኑ።', actionRoute: '/edu/services'),
        GuidanceStep(step: 2, title: 'ቅሬታ ማቅረብ (File a complaint)', description: 'ዓይነቱን ይምረጡ፣ ጉዳዩን ይግለጹ፣ ካለ ማስረጃ ያያይዙ። የሚሰጥዎትን መለያ ቁጥር ይያዙ።', actionRoute: '/edu/services?tab=complaints'),
        GuidanceStep(step: 3, title: 'የትምህርት ጉዞ (Journey)', description: 'ምዝገባዎ፣ ለውጦች እና የታተሙ ውጤቶች በቅደም ተከተል ይታያሉ።', actionRoute: '/edu/services?tab=journey'),
      ],
      tips: ['በአንድ ጉዳይ ላይ በአንድ ጊዜ አንድ ጥያቄ ብቻ መጠባበቅ ይችላል።', 'ውጤትን የሚመለከት ቅሬታ ውጤቱን በራሱ አይቀይርም፤ ግምገማ ያስጀምራል።'],
      faqItems: [GuidanceFaq(question: 'ውጤቴ ለምን «በሂደት ላይ» ይላል?', answer: 'ውጤቶች የሚታዩት በትምህርት ክፍሉ ጸድቀው ከታተሙ በኋላ ብቻ ነው።')],
    ),

    // 56. EDUCATION ADMIN: REVIEW CENTER
    '/edu/review': const GuidanceArticle(
      id: 56,
      slug: 'edu-review-center',
      category: 'education',
      title: 'የትምህርት ግምገማ ማዕከል (Education Review Center)',
      summary: 'መምህራን ያቀረቧቸውን ውጤቶች ማጽደቅ/መመለስ/ማተም፣ የተማሪ ጥያቄዎችን መወሰን፣ ቅሬታዎችን መመርመር እና የውጤት ሪፖርት ማውጣት።',
      content:
          'ውጤቶች፦ ረቂቅ → ለማጽደቅ ማቅረብ → ማጽደቅ ወይም መመለስ (ምክንያት ግዴታ) → ማተም። ያቀረቡትን ውጤት ራስዎ ማጽደቅ አይችሉም። የታተመ ውጤት የሚስተካከለው በምክንያት በሚደረግ ማስተካከያ ብቻ ነው። ጥያቄ ሲጸድቅ ለውጡ በምዝገባው ላይ ይተገበራል።',
      targetRole: 'admin',
      targetScreen: '/edu/review',
      requiredPermission: 'education.manage',
      steps: [
        GuidanceStep(step: 1, title: 'ውጤቶችን መገምገም (Review marks)', description: '«ለማጽደቅ ቀርቧል» ውስጥ ፈተናውን ይክፈቱ፤ «አጽድቅ እና አትም» ወይም «ውድቅ አድርግ» ይጫኑ።', actionRoute: '/edu/review'),
        GuidanceStep(step: 2, title: 'ጥያቄዎችን መወሰን (Decide requests)', description: 'በጥያቄዎች ገጽ ላይ ያጽድቁ ወይም በምክንያት ውድቅ ያድርጉ።', actionRoute: '/edu/review'),
        GuidanceStep(step: 3, title: 'ሪፖርት (Export)', description: 'ከላይ ያለውን የማውረጃ ምልክት ይጫኑ፤ ክፍል፣ ትምህርቶች እና አቀማመጥ ይምረጡ (CSV / Excel / PDF)።', actionRoute: '/edu/review'),
      ],
      tips: ['የውስጥ ማስታወሻዎች ለተማሪው አይታዩም።', 'በሪፖርት ውስጥ ያልገባ ውጤት «—» ሆኖ ይታያል፤ 0 አይደለም።'],
      faqItems: [GuidanceFaq(question: 'የታተመ ውጤት እንዴት ይስተካከላል?', answer: 'በውጤት መመዝገቢያ ገጹ ላይ ከውጤቱ አጠገብ ያለውን የማስተካከያ ምልክት ይጫኑ፤ ምክንያት ግዴታ ነው፤ ታሪኩ ይቀመጣል።')],
    ),

    // 57. Class Assignment & Rosters
    '/admin/edu/assignments': const GuidanceArticle(
      id: 57,
      slug: 'class-assignment',
      category: 'education',
      title: 'የተማሪዎች ክፍል ምደባ (Class Assignment & Rosters)',
      summary: 'ተማሪዎችን በሰንበት ት/ቤት ክፍሎች መመደብ፣ ማዛወር እና የክፍል መዝገብ ማስተዳደር።',
      content:
          'ተማሪዎችን በየዕድሜያቸው እና የትምህርት ደረጃቸው መሠረት በተገቢው ክፍል ይመድቡ። የተማሪውን የክፍል ታሪክ (Journey) ለመጠበቅ ዝውውሮች በምክንያት ይመዘገባሉ።',
      targetRole: 'admin',
      targetScreen: '/admin/edu/assignments',
      requiredPermission: 'education.manage',
      steps: [
        GuidanceStep(step: 1, title: 'ክፍል መምረጥ', description: 'ከተዘረዘሩት ክፍሎች ተማሪዎችን ሊመድቡበት የሚፈልጉትን ይክፈቱ።', actionRoute: '/admin/edu/classes'),
        GuidanceStep(step: 2, title: 'ተማሪዎችን መመደብ', description: '«ተማሪዎችን መድብ»ን በመጫን ያልተመደቡ ተማሪዎችን ይምረጡ።', actionRoute: '/admin/edu/assignments'),
        GuidanceStep(step: 3, title: 'ማዛወር', description: 'ተማሪን ወደ ሌላ ክፍል ሲያዛውሩ የዝውውር ምክንያት በማስገባት ታሪኩን ይጠብቁ።', actionRoute: '/admin/edu/classes'),
      ],
      tips: ['በአንድ ጊዜ በአንድ ንቁ ክፍል ብቻ መመደብ ይቻላል።'],
      faqItems: [GuidanceFaq(question: 'የተማሪ ታሪክ ይጠፋል?', answer: 'አይጠፋም፤ በየትምህርት ጉዞ (Journey) ላይ ተመዝግቦ ይቀመጣል።')],
    ),

    // 58. Academic Administration
    '/admin/edu/academic-years': const GuidanceArticle(
      id: 58,
      slug: 'academic-calendar-admin',
      category: 'education',
      title: 'የትምህርት ዘመን እና አስተዳደር (Academic Admin)',
      summary: 'የትምህርት ዘመናትን፣ ወሰነ-ትምህርቶችን (Terms) እና ክፍሎችን ማስተዳደር።',
      content:
          'የትምህርት ዘመን የኢትዮጵያ ዓመተ ምሕረትን መሠረት በማድረግ ይከፈታል። ዓመታዊ የትምህርት ሥራዎች በክፍሎችና መርሐ ግብሮች ሥር ይከናወናሉ።',
      targetRole: 'admin',
      targetScreen: '/edu/manage',
      requiredPermission: 'education.manage',
      steps: [
        GuidanceStep(step: 1, title: 'ክፍሎችና ተማሪዎች', description: 'የክፍል አደረጃጀቶችንና የተማሪዎች ምደባን ይመልከቱ።', actionRoute: '/edu/manage'),
        GuidanceStep(step: 2, title: 'ወቅቶችና መርሐ ግብሮች', description: 'ወቅታዊ የትምህርት ክፍለ ጊዜዎችን ይከታተሉ።', actionRoute: '/edu/manage'),
      ],
      tips: ['የትምህርት ክፍሎች አስተዳደር በኮርስ ማኔጅመንት በኩል ይከናወናል።'],
      faqItems: [GuidanceFaq(question: 'ክፍሎችን እንዴት ማስተዳደር ይቻላል?', answer: 'በኮርስ ማኔጅመንት ገጽ ላይ አዳዲስ ክፍሎችን መክፈት ይችላሉ።')],
    ),

    // 59. Education Home
    '/edu/calendar': const GuidanceArticle(
      id: 59,
      slug: 'academic-calendar-student',
      category: 'education',
      title: 'የትምህርት ገጽ (Education Home)',
      summary: 'የትምህርት ዓይነቶችን፣ ክፍሎችንና ይዘቶችን መመልከት።',
      content: 'በዚህ ገጽ ላይ ሰባቱን ዓበይት የትምህርት ዘርፎችና የክፍል ይዘቶችን መከታተል ይችላሉ።',
      targetRole: 'member',
      targetScreen: '/edu',
      steps: [
        GuidanceStep(step: 1, title: 'የትምህርት ዓይነቶች', description: 'የተዘጋጁትን የትምህርት ዘርፎች ይመልከቱ።', actionRoute: '/edu'),
        GuidanceStep(step: 2, title: 'ክፍል ይምረጡ', description: 'ከ1ኛ እስከ 12ኛ ክፍል ያሉትን ትምህርቶች ይክፈቱ።', actionRoute: '/edu'),
      ],
      tips: ['ትምህርቶች ከመስመር ውጭም ይሠራሉ።'],
      faqItems: [GuidanceFaq(question: 'ይዘቶች ከመስመር ውጭ ይሠራሉ?', answer: 'አዎ! የወረዱ ሰነዶች ያለ ኢንተርኔት ይታያሉ።')],
    ),

    // 60. Class-Linked Programs
    '/admin/edu/programs': const GuidanceArticle(
      id: 60,
      slug: 'class-linked-programs',
      category: 'education',
      title: 'ከክፍል ጋር የተሳሰሩ መርሐ ግብሮች (Class-Linked Programs)',
      summary: 'መርሐ ግብሮችን በቀጥታ ከሰንበት ት/ቤት ክፍሎች ጋር ማስተሳሰር።',
      content: 'መርሐ ግብር ከክፍል ጋር ሲተሳሰር፣ የተማሪዎች አቴንዳንስ በቀጥታ በትምህርት መዝገባቸው ውስጥ ይካተታል።',
      targetRole: 'admin',
      targetScreen: '/admin/edu/programs',
      requiredPermission: 'education.manage',
      steps: [
        GuidanceStep(step: 1, title: 'መርሐ ግብር መምረጥ', description: 'ከክፍል ጋር የሚገናኘውን መርሐ ግብር ይክፈቱ።', actionRoute: '/admin/edu/programs'),
        GuidanceStep(step: 2, title: 'ክፍል ማስተሳሰር', description: 'መርሐ ግብሩ የሚመለከተውን የትምህርት ክፍል ይምረጡ።', actionRoute: '/admin/edu/programs'),
      ],
      tips: ['ከክፍል ውጭ ያሉ አባላት በክፍል አቴንዳንስ ውስጥ አይካተቱም።'],
      faqItems: [GuidanceFaq(question: 'አቴንዳንሱ የት ይመዘገባል?', answer: 'በቀጥታ በትምህርት ክትትል ውስጥ ይቀመጣል።')],
    ),

    // 61. Selection Intervals
    '/admin/selections/intervals': const GuidanceArticle(
      id: 61,
      slug: 'selection-intervals',
      category: 'choir',
      title: 'የመረጣ ጊዜያት እና የአቴንዳንስ ነጥቦች (Selection Intervals & Attendance Rules)',
      summary: 'የበዓላት መዘምራን መረጣ የአቴንዳንስ ጊዜያት እና የነጥብ አሰላል ደንቦችን ማስተካከል (D2/D3/D5)።',
      content: 'በዓላትን መሠረት ያደረገ የመዘምራን መረጣ የአቴንዳንስ ማነፃፀሪያ ጊዜያትን ይወስኑ። ክፍተቶችን እና መደራረቦችን የሚያስወግድ የሕግ ማረጋገጫ ተካቷል።',
      targetRole: 'admin',
      targetScreen: '/admin/selections/intervals',
      requiredPermission: 'selection.configure',
      steps: [
        GuidanceStep(step: 1, title: 'የመረጣ ውቅር', description: 'የመረጣውን ስም እና የክትትል የጊዜ ወሰን ይወስኑ።', actionRoute: '/admin/selections/intervals'),
        GuidanceStep(step: 2, title: 'የነጥብ ደንቦች', description: 'በተገኘባቸው ቀናት ብዛት መሠረት የሚሰጠውን ነጥብ ይተምኑ።', actionRoute: '/admin/selections/intervals'),
      ],
      tips: ['ደንቦቹ ከ1 ጀምረው ያለ ክፍተት መቀጠል አለባቸው።'],
      faqItems: [GuidanceFaq(question: 'የነጥብ ስሌቱ እንዴት ይከናወናል?', answer: 'በተቀመጠው የጊዜ ወሰን ውስጥ ባለው የተሳትፎ ቀናት መሠረት ይሰላል።')],
    ),

    // 62. Offline Sync Status
    '/offline-status': const GuidanceArticle(
      id: 62,
      slug: 'offline-status',
      category: 'system',
      title: 'ከመስመር ውጭ አሠራር እና ማመሳሰል (Offline Sync Status)',
      summary: 'ያለ ኢንተርኔት የተከናወኑ ተግባራትን ሁኔታ እና ከዋናው ሰርቨር ጋር ማመሳሰልን መከታተል።',
      content: 'ኢንተርኔት በማይኖርበት ጊዜ የተመዘገቡ አቴንዳንሶች፣ የቤተ-መጽሐፍት ውሰቶች እና የትምህርት ሂደቶች በስልክዎ ይቀመጣሉ፤ ኢንተርኔት ሲገኝ በራስ-ሰር ይላካሉ።',
      targetRole: 'all',
      targetScreen: '/offline-status',
      steps: [
        GuidanceStep(step: 1, title: 'የወረፋ ሁኔታ', description: 'ያልተመሳሰሉ የተግባራት ብዛት ይመልከቱ።', actionRoute: '/offline-status'),
        GuidanceStep(step: 2, title: 'በእጅ ማመሳሰል', description: '«አሁን አመሳስል»ን በመጫን ወዲያውኑ ወደ ሰርቨር ይላኩ።', actionRoute: '/offline-status'),
      ],
      tips: ['ከመውጣትዎ (Logout) በፊት ያልተላኩ ተግባራት መኖራቸውን ያረጋግጡ።'],
      faqItems: [GuidanceFaq(question: 'ያልተመሳሰለ መረጃ በስልክ ይቀመጣል?', answer: 'አዎ! በደህንነት በስልክዎ ውስጥ ተቀምጦ ይቆያል።')],
    ),

    // 63. Assignments
    '/edu/assignments': const GuidanceArticle(
      id: 63,
      slug: 'edu-assignments',
      category: 'education',
      title: 'የቤት ሥራዎች እና ምደባዎች (Assignments)',
      summary: 'የተሰጡ የቤት ሥራዎችን መመልከት፣ ፋይሎችን ማስገባት እና የማሻሻያ ታሪክን መከታተል።',
      content: 'መምህራን የሚሰጧቸውን የቤት ሥራዎች በተሰጠው የጊዜ ገደብ ውስጥ ያስገቡ። የተሻሻለ ፋይል ማስገባት ሲፈቀድ ቀደምት ስሪቶች በታሪክ ይቀመጣሉ።',
      targetRole: 'member',
      targetScreen: '/edu/assignments',
      steps: [
        GuidanceStep(step: 1, title: 'ሥራዎችን መመልከት', description: 'ክፍት የሆኑ እና የጊዜ ገደባቸው ያልደረሱ ሥራዎችን ይምረጡ።', actionRoute: '/edu/assignments'),
        GuidanceStep(step: 2, title: 'ፋይል መስቀል', description: 'የተዘጋጀውን ፋይል ይስቀሉ እና አስገባ የሚለውን ይጫኑ።', actionRoute: '/edu/assignments'),
      ],
      tips: ['ከቀነ-ገደብ በኋላ የሚገቡ ሥራዎች እንደ ዘግይተው ይመዘገባሉ።'],
      faqItems: [GuidanceFaq(question: 'የገባውን ሥራ መቀየር ይቻላል?', answer: 'መምህሩ ማሻሻል ከፈቀደ አዲስ ስሪት ማስገባት ይቻላል።')],
    ),

    // 64. Academic Results
    '/edu/results': const GuidanceArticle(
      id: 64,
      slug: 'edu-results',
      category: 'education',
      title: 'የትምህርት ውጤቶች እና ግምገማ (Academic Results)',
      summary: 'የፈተና፣ የቤት ሥራ እና የጥያቄዎች ይፋዊ ውጤቶችን በክብደት መቶኛ መመልከት።',
      content: 'በትምህርት ክፍሉ ጸድቀው የታተሙ ውጤቶች ብቻ ይታያሉ። እያንዳንዱ ውጤት የፈተናውን ክብደት፣ ያገኙትን ነጥብ እና የማለፍ ሁኔታን ያሳያል።',
      targetRole: 'member',
      targetScreen: '/edu/results',
      steps: [
        GuidanceStep(step: 1, title: 'የኮርስ ውጤቶች', description: 'የወሰዷቸውን ትምህርቶች አጠቃላይ ውጤት ይከታተሉ።', actionRoute: '/edu/results'),
        GuidanceStep(step: 2, title: 'ዝርዝር ነጥብ', description: 'የእያንዳንዱን ምዘና ዝርዝር ውጤት ይመርምሩ።', actionRoute: '/edu/results'),
      ],
      tips: ['ያልታተሙ ውጤቶች ለተማሪዎች አይታዩም።'],
      faqItems: [GuidanceFaq(question: 'ውጤቴ ለምን አልታየም?', answer: 'ውጤቱ ገና በመምህሩ ወይም በትምህርት ክፍሉ አልታተመም።')],
    ),

    // 65. Retake Requests
    '/edu/retakes': const GuidanceArticle(
      id: 65,
      slug: 'edu-retakes',
      category: 'education',
      title: 'የድጋሚ ፈተና ጥያቄዎች (Exam Retake Requests)',
      summary: 'ላላለፉባቸው ፈተናዎች ወይም ውጤት ለማሻሻል የድጋሚ ፈተና ጥያቄ ማቅረብ።',
      content: 'ተማሪዎች ባልተሳካላቸው ፈተናዎች ላይ በደንቡ መሠረት የድጋሚ ፈተና ማመልከት ይችላሉ። ጥያቄው ሲጸድቅ ፈተናውን እንደገና መውሰድ ይቻላል።',
      targetRole: 'member',
      targetScreen: '/edu/retakes',
      steps: [
        GuidanceStep(step: 1, title: 'ጥያቄ ማቅረብ', description: 'ድጋሚ ሊፈተኑበት የሚፈልጉትን ትምህርት እና ፈተና ይምረጡ።', actionRoute: '/edu/retakes'),
        GuidanceStep(step: 2, title: 'ውሳኔ መከታተል', description: 'በትምህርት አስተዳዳሪው የጸደቀውን ውሳኔ ይመልከቱ።', actionRoute: '/edu/retakes'),
      ],
      tips: ['የድጋሚ ፈተና ውጤት በቀድሞው ውጤት ላይ የበላይነት ይኖረዋል።'],
      faqItems: [GuidanceFaq(question: 'ስንት ጊዜ መጠየቅ ይቻላል?', answer: 'በትምህርት ክፍሉ በተፈቀደው የድጋሚ ፈተና ገደብ መሠረት።')],
    ),

    // 66. Exams & Assessments
    '/edu/exams': const GuidanceArticle(
      id: 66,
      slug: 'edu-exams',
      category: 'education',
      title: 'የፈተና ጥያቄዎች እና ምዘና (Exams & Assessments)',
      summary: 'ኦንላይን ፈተናዎችን መውሰድ፣ የጥያቄ ባንክ እና የማለፊያ ነጥቦችን ማወቅ።',
      content: 'ፈተናዎች በተሰጣቸው የጊዜ ገደብ ውስጥ ይወሰዳሉ። የጥያቄ ባንክ ጥያቄዎችን በዘፈቀደ በማውጣት ፍትሐዊ ምዘናን ያረጋግጣል።',
      targetRole: 'member',
      targetScreen: '/edu/exams',
      steps: [
        GuidanceStep(step: 1, title: 'ፈተና መጀመር', description: 'የተፈቀደውን ፈተና በመክፈት መመሪያዎችን ያንብቡ።', actionRoute: '/edu/exams'),
        GuidanceStep(step: 2, title: 'ጥያቄዎችን መመለስ', description: 'በተሰጠው ሰዓት ውስጥ መልሶችን መርጠው ያጠናቅቁ።', actionRoute: '/edu/exams'),
      ],
      tips: ['ፈተናው ከተጀመረ በኋላ ማቋረጥ አይቻልም።'],
      faqItems: [GuidanceFaq(question: 'መልሶቼ ተቀምጠዋል?', answer: 'አዎ! እያንዳንዱ መልስ ወዲያውኑ ይመዘገባል።')],
    ),

    // 67. Student Certificates
    '/edu/certificates': const GuidanceArticle(
      id: 67,
      slug: 'edu-certificates',
      category: 'education',
      title: 'የትምህርት ማስረጃዎች (My Certificates)',
      summary: 'ያጠናቀቋቸውን ኮርሶች ዲጂታል ሰርተፊኬቶች መመልከት፣ ማውረድ እና በQR ማረጋገጥ።',
      content: 'ኮርሱን በተሳካ ሁኔታ ላጠናቀቁ ተማሪዎች የሚሰጡ ሰርተፊኬቶች በዲጂታል ፊርማ እና በ10 ዲጂት ማረጋገጫ ኮድ የተጠበቁ ናቸው።',
      targetRole: 'member',
      targetScreen: '/edu/certificates',
      steps: [
        GuidanceStep(step: 1, title: 'ሰርተፊኬት መክፈት', description: 'ከተሰጡት ማስረጃዎች መካከል የሚፈልጉትን ይክፈቱ።', actionRoute: '/edu/certificates'),
        GuidanceStep(step: 2, title: 'PDF ማውረድ', description: 'በከፍተኛ ጥራት የተዘጋጀውን ሰርተፊኬት በPDF ያውርዱ ወይም ያጋሩ።', actionRoute: '/edu/certificates'),
      ],
      tips: ['በሰርተፊኬቱ ላይ ያለው QR ኮድ በማንኛውም ሰው ሊረጋገጥ ይችላል።'],
      faqItems: [GuidanceFaq(question: 'ሰርተፊኬት መቼ ይሰጣል?', answer: 'ትምህርቱን 100% አጠናቀው ውጤትዎ ሲጸድቅ።')],
    ),

    // 68. Certificate Issuance & Admin
    '/admin/edu/certificates': const GuidanceArticle(
      id: 68,
      slug: 'admin-edu-certificates',
      category: 'education',
      title: 'የሰርተፊኬት አሰጣጥ እና ቁጥጥር (Certificate Issuance & Management)',
      summary: 'መስፈርቱን ላሟሉ ተማሪዎች ሰርተፊኬት ማመንጨት፣ መሻር እና ድጋሚ ማውጣት።',
      content: 'ያለፉ እና ትምህርቱን 100% ያጠናቀቁ ተማሪዎችን መርምረው ሰርተፊኬት ይስጡ። በስህተት የወጣ ሰርተፊኬት በምክንያት ተሽሮ በምትኩ አዲስ ሊሰጥ ይችላል።',
      targetRole: 'admin',
      targetScreen: '/admin/edu/certificates',
      requiredPermission: 'education.certify',
      steps: [
        GuidanceStep(step: 1, title: 'ብቁ ተማሪዎችን መለየት', description: 'የማለፊያ መስፈርቱን ያሟሉ ተማሪዎችን ዝርዝር ይክፈቱ።', actionRoute: '/admin/edu/certificates'),
        GuidanceStep(step: 2, title: 'ሰርተፊኬት ማመንጨት', description: 'በኢትዮጵያ ዓ.ም ተከታታይ ቁጥር ያለው ሰርተፊኬት ያትሙ።', actionRoute: '/admin/edu/certificates'),
        GuidanceStep(step: 3, title: 'መሻር/ማስተካከል', description: 'አስፈላጊ ሲሆን የነበረውን በመሻር የተስተካከለ ይስጡ።', actionRoute: '/admin/edu/certificates'),
      ],
      tips: ['የተሻሩ ሰርተፊኬቶች በኦንላይን ማረጋገጫ ገጹ ላይ «ተሽሯል» ተብለው ይታያሉ።'],
      faqItems: [GuidanceFaq(question: 'የተሻረ ሰርተፊኬት እንደገና ይሰራል?', answer: 'አይሰራም፤ የተተካበት አዲሱ ሰርተፊኬት ብቻ ይጸድቃል።')],
    ),

    // 69. Digital Library & Narration
    '/library/books': const GuidanceArticle(
      id: 69,
      slug: 'library-books',
      category: 'library',
      title: 'ዲጂታል ቤተ-መጽሐፍት እና ትረካ (Digital Library & Narration)',
      summary: 'መንፈሳዊ መጻሕፍትን በPDF ማንበብ፣ ተወዳጆች ውስጥ ማስቀመጥ እና የድምጽ ትረካ ማዳመጥ።',
      content: 'በምድብ የተከፋፈሉ መጻሕፍትን በገጽ ማስታወሻ ያንብቡ፤ ፈልገው ያግኙ። ትረካ ያላቸውን መጻሕፍት ስልኩ ተዘግቶም ከበስተጀርባ ማዳመጥ ይችላሉ።',
      targetRole: 'all',
      targetScreen: '/library/books',
      steps: [
        GuidanceStep(step: 1, title: 'መጽሐፍ መምረጥ', description: 'ከምድቦች ወይም ከተወዳጆች ዝርዝር መጽሐፉን ይክፈቱ።', actionRoute: '/library/books'),
        GuidanceStep(step: 2, title: 'ንባብ እና ገጽ ፍለጋ', description: 'ባቆሙበት ገጽ ላይ ንባብዎን ይቀጥሉ፤ ቃላትን ይፈልጉ።', actionRoute: '/library/books'),
        GuidanceStep(step: 3, title: 'ትረካ ማዳመጥ', description: 'የድምጽ ማጫወቻውን በማስጀመር ትረካውን ያዳምጡ።', actionRoute: '/library/books'),
      ],
      tips: ['የወረዱ መጻሕፍት ያለ ኢንተርኔት በደህንነት ይከፈታሉ።'],
      faqItems: [GuidanceFaq(question: 'ባቆምኩበት ገጽ ይቀመጣል?', answer: 'አዎ! በመስመር ላይም ሆነ ከመስመር ውጭ ባቆሙበት ገጽ ይከፈታል።')],
    ),

    // 70. Sunday School Library Circulation
    '/admin/library/circulation': const GuidanceArticle(
      id: 70,
      slug: 'library-circulation',
      category: 'library',
      title: 'የሰንበት ት/ቤት ቤተ-መጽሐፍት ውሰት (Library Circulation & Loans)',
      summary: 'የታተሙ መጻሕፍትን በተለየ ኮድ ማበደር፣ የውሰት ፊርማ መቀበል እና መመለስ።',
      content: 'እያንዳንዱ የመጽሐፍ ቅጅ የማይለወጥ የቅጅ ኮድ (LIB-...) አለው። መጽሐፍ ሲበደር የተውሰው አባል በስክሪኑ ላይ ይፈርማል። አንድ መጽሐፍ ለሁለት ሰው እንዳይሰጥ በሰርቨር የተጠበቀ ነው።',
      targetRole: 'admin',
      targetScreen: '/admin/library/circulation',
      requiredPermission: 'library.circulate',
      steps: [
        GuidanceStep(step: 1, title: 'ኮድ መፈለግ/መቃኘት', description: 'የመጽሐፉን የቅጅ ኮድ በማስገባት ዝግጁነቱን ያረጋግጡ።', actionRoute: '/admin/library/circulation'),
        GuidanceStep(step: 2, title: 'ተበዳሪ እና ፊርማ', description: 'አባሉን ከመረጡ በኋላ በስክሪኑ ላይ ፊርማቸውን ያስቀምጡ።', actionRoute: '/admin/library/circulation'),
        GuidanceStep(step: 3, title: 'መመለስ', description: 'መጽሐፉ ሲመለስ የያዘበትን ሁኔታ መርምረው መዝገቡን ይዝጉ።', actionRoute: '/admin/library/circulation'),
      ],
      tips: ['የተበደረ መጽሐፍ ሳይመለስ ለሌላ ሰው ማበደር አይቻልም።'],
      faqItems: [GuidanceFaq(question: 'ከንብረት ውሰት ጋር ይቀላቀላል?', answer: 'አይቀላቀልም፤ የቤተ-መጽሐፍት ውሰት ራሱን የቻለ የተለየ አሠራር ነው።')],
    ),

    // 71. Education Scores & Activity
    '/admin/edu/scores': const GuidanceArticle(
      id: 71,
      slug: 'admin-edu-scores',
      category: 'education',
      title: 'የትምህርት ውጤት እና የተሳትፎ ነጥቦች (Education Academic & Engagement Scores)',
      summary: 'የተማሪዎችን የትምህርት ውጤት እና የተሳትፎ ነጥብ በD8 ቀመር መሠረት መመርመር እና ሪፖርት ማውጣት።',
      content: 'የአካዳሚክ ነጥብ እና የተሳትፎ ነጥብ ተለይተው ይሰላሉ። ተማሪው ሊደርስባቸው የማይችላቸው ትምህርቶች ነጥቡን እንዳይቀንሱ ይደረጋል። ውጤቶችን በPDF, Excel እና CSV ማውጣት ይቻላል።',
      targetRole: 'admin',
      targetScreen: '/admin/edu/scores',
      requiredPermission: 'education.reports',
      steps: [
        GuidanceStep(step: 1, title: 'ወቅት እና ክፍል መምረጥ', description: 'የሚመረመረውን የትምህርት ዘመን፣ ወሰነ-ትምህርት እና ክፍል ይምረጡ።', actionRoute: '/admin/edu/scores'),
        GuidanceStep(step: 2, title: 'የነጥብ ዝርዝር', description: 'በተማሪው ረድፍ ላይ በመጫን የነጥቡን ስሌት ማብራሪያ ይመልከቱ።', actionRoute: '/admin/edu/scores'),
        GuidanceStep(step: 3, title: 'ሪፖርት ማውጣት', description: 'በማውረጃ አዝራሩ አማካኝነት ዝርዝር ሪፖርት ያመንጩ።', actionRoute: '/admin/edu/scores'),
      ],
      tips: ['ውጤቱ በD8 ቀመር የተማሪዎችን እውነተኛ ተሳትፎ ያንፀባርቃል።'],
      faqItems: [GuidanceFaq(question: 'ነጥቦቹ ለተማሪዎች ይታያሉ?', answer: 'አይታዩም፤ የተማሪዎች የደረጃ ዝርዝር ለአስተዳዳሪዎች ብቻ የተጠበቀ ነው።')],
    ),
  };
}
