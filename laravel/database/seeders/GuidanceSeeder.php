<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class GuidanceSeeder extends Seeder
{
    public function run(): void
    {
        $articles = [
            // 1. Welcome & Getting Started
            [
                'slug' => 'welcome-onboarding',
                'category' => 'getting_started',
                'title' => 'እንኳን ወደ መሠረተ ሕይወት መተግበሪያ በደህና መጡ! (Welcome)',
                'summary' => 'የመተግበሪያው አጠቃላይ መግቢያ፣ ዋና ዋና ክፍሎች እና የመጀመሪያ እርምጃዎች።',
                'content' => "የመሠረተ ሕይወት መተግበሪያ የሰንበት ት/ቤት አባላት፣ የመምሪያ መሪዎች እና አስተዳዳሪዎች የሚያስፈልጓቸውን መንፈሳዊ አገልግሎቶች በአንድ ላይ የያዘ መድረክ ነው።\n\nበዚህ መተግበሪያ መዝሙራትን ማዳመጥ፣ ግጥሞችን መመልከት፣ የሰንበት ት/ቤት ትምህርቶችን መከታተል፣ መርሐ ግብሮችን ማወቅ እና የአባልነት ካርድዎን በቀላሉ መጠቀም ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/hub',
                'required_permission' => null,
                'tour_id' => 'welcome_tour',
                'icon' => 'home_rounded',
                'sort_order' => 1,
                'steps' => json_encode([
                    ['title' => 'የመተግበሪያው ማዕከል (Hub)', 'description' => 'ሁሉንም አገልግሎቶች የሚያገኙበት ዋና ገጽ። ወደ ትምህርት እና መዝሙር በቀላሉ መሸጋገር ይችላሉ።', 'tip' => 'ከላይ ያሉትን ካርዶች በመጫን ወደፈለጉት ክፍል መሄድ ይችላሉ።'],
                    ['title' => 'የመዝሙር ክፍል', 'description' => 'በድምጽ እና በግጥም የተዘጋጁ መዝሙራት፣ ከመስመር ውጭ ማዳመጥ እና ተወዳጅ መዝሙራት ዝርዝር።', 'tip' => 'መዝሙራትን ወደ ስልክዎ አውርደው ያለ ኢንተርኔት ማዳመጥ ይችላሉ።'],
                    ['title' => 'መርሐ ግብሮች እና ማሳሰቢያዎች', 'description' => 'የሰንበት ት/ቤት እና የቤተክርስቲያን ሳምንታዊ እና ልዩ መርሐ ግብሮች ዝርዝር።', 'tip' => 'መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ማንቂያ (Alarm) እንዲያሰማ ማድረግ ይችላሉ።'],
                    ['title' => 'የአባልነት መታወቂያ ካርድ (QR Card)', 'description' => 'የግል መታወቂያ፣ የትምህርት ክፍል እና የዲፓርትመንት መረጃ የያዘ ዲጂታል ካርድ።', 'tip' => 'በቅንብሮች ውስጥ «ስለ እኔ» ገጽ ላይ በማንኛውም ጊዜ ማግኘት ይችላሉ።'],
                    ['title' => 'የመመሪያ ማዕከል (Guidance Center)', 'description' => 'በማንኛውም ጊዜ እገዛ ወይም መመሪያ ሲያስፈልግዎት በቅንብሮች በኩል መመሪያዎችን መመልከት ይችላሉ።', 'tip' => 'ጥያቄዎች ወይም የቴክኒክ ችግሮች ካጋጠሙዎት የFAQ እና የመፍትሔ ክፍሉን ይመልከቱ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ኢንተርኔት በማይኖርበት ጊዜ መተግበሪያው በሙሉ አቅም ከመስመር ውጭ (Offline) ይሰራል።',
                    'የይለፍ ቃልዎን ወይም ፒን ቁጥርዎን ለማንም አያጋሩ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'መተግበሪያውን ያለ ኢንተርኔት መጠቀም ይቻላል?', 'a' => 'አዎ! መዝሙራት፣ ግጥሞች፣ የቀን መቁጠሪያ እና መርሐ ግብሮች አስቀድመው ተቀምጠው ያለ ኢንተርኔት ይሰራሉ።'],
                    ['q' => 'የአባልነት መታወቂያዬን የት ማግኘት እችላለሁ?', 'a' => 'በቅንብሮች (Settings) ገጽ ውስጥ «የአባልነት ካርድ እና መረጃዬ» የሚለውን ይጫኑ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 2. Mezmurs & Audio
            [
                'slug' => 'mezmurs-and-audio',
                'category' => 'mezmurs',
                'title' => 'መዝሙራት እና የድምጽ ማጫወቻ (Mezmurs & Audio)',
                'summary' => 'መዝሙራትን በድምጽ ማዳመጥ፣ ግጥሞችን ማንበብ፣ ተወዳጆች እና ከመስመር ውጭ ማውረድ።',
                'content' => "በመዝሙር ክፍል ውስጥ በምድቦች የተከፋፈሉ መዝሙራትን ማግኘት ይችላሉ።\n\nድምጽ ያላቸው መዝሙራት ከበስተጀርባ (Background) ስልኩ ተዘግቶም ይጫወታሉ። ግጥሞቹን በግልጽ ማንበብ እና የሚወዷቸውን መዝሙራት በተወዳጆች ዝርዝር ውስጥ ማስቀመጥ ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/home',
                'required_permission' => null,
                'tour_id' => 'mezmur_tour',
                'icon' => 'music_note_rounded',
                'sort_order' => 2,
                'steps' => json_encode([
                    ['title' => 'የመዝሙር ምድቦች', 'description' => 'በበዓላት፣ በዘመናት እና በአርእስት የተከፋፈሉ የመዝሙር አቃፊዎች።', 'tip' => 'የዛሬ መዝሙራት የሚለውን ክፍል ለዕለቱ ተስማሚ መዝሙሮች ይመልከቱ።'],
                    ['title' => 'መፈለጊያ (Search)', 'description' => 'በመዝሙር ርዕስ፣ በግጥም ቃላት ወይም በምድብ ፈጣን ፍለጋ ያካሂዱ።', 'tip' => 'በግዕዝም ሆነ በአማርኛ ፊደላት መፈለግ ይችላሉ።'],
                    ['title' => 'ከመስመር ውጭ ማውረድ (Download)', 'description' => 'መዝሙሩን ወደ ስልክዎ በማውረድ ያለ ኢንተርኔት በቀላሉ ያዳምጡ።', 'tip' => 'የወረዱ መዝሙራት በ«የእኔ መዝሙራት» ገጽ «የወረዱ» ስር ይገኛሉ።'],
                    ['title' => 'የድምጽ መቆጣጠሪያ (Mini & Full Player)', 'description' => 'መዝሙሩን ማቆም፣ ማጫወት፣ ወደ ፊት/ኋላ መመለስ እና መድገም ይችላሉ።', 'tip' => 'ትንሹን ማጫወቻ ወደ ላይ በመጎተት ሙሉውን የድምጽ ገጽ መክፈት ይችላሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'መዝሙር ሲያዳምጡ ስልክዎ ቢዘጋም ድምጹ አይቋረጥም።',
                    'የግጥም መጠኑን በቅንብሮች ውስጥ መጨመር ወይም መቀነስ ይችላሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የወረዱ መዝሙራትን የት አገኛቸዋለሁ?', 'a' => 'በታችኛው ባር «የእኔ» (የእኔ መዝሙራት) የሚለውን መርጠው «የወረዱ» የሚለውን ታብ ይመልከቱ።'],
                    ['q' => 'ድምጹ ስልኩ ሲዘጋ ለምን ሊቆም ይችላል?', 'a' => 'የስልክዎ የባትሪ ቆጣቢ (Battery Saver) አገልግሎቱን ከከለከለው ሊቆም ይችላል፤ በቅንብሮች ውስጥ «ያለገደብ» (Unrestricted) ያድርጉት።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 3. Programs & Alarms
            [
                'slug' => 'programs-and-alarms',
                'category' => 'programs',
                'title' => 'መርሐ ግብሮች እና ማንቂያዎች (Programs & Alarms)',
                'summary' => 'የሰንበት ት/ቤት መርሐ ግብሮች፣ ተረኞች እና የ30 ደቂቃ ማንቂያ (Alarm) አጠቃቀም።',
                'content' => "በመርሐ ግብሮች ገጽ የዕለቱን እና የሚመጡትን የሰንበት ት/ቤት መርሐ ግብሮች ያገኛሉ።\n\nለእያንዳንዱ መርሐ ግብር ማንቂያ በማብራት መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ ጮክ ብሎ በማንቂያ ደወል እንዲያስታውስዎት ማድረግ ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/programs',
                'required_permission' => null,
                'tour_id' => 'programs_tour',
                'icon' => 'event_rounded',
                'sort_order' => 3,
                'steps' => json_encode([
                    ['title' => 'የመርሐ ግብር ዝርዝር', 'description' => 'የቀኑን መርሐ ግብር፣ ሰዓት እና አዳራሽ በግልጽ ይመልከቱ።', 'tip' => 'የቀን መቁጠሪያውን በመጫን ያለፉትን እና የሚመጡትን ቀናት ማየት ይችላሉ።'],
                    ['title' => 'የ30 ደቂቃ ማንቂያ (Alarm)', 'description' => 'መርሐ ግብሩ ከመጀመሩ 30 ደቂቃ በፊት ስልክዎ እንዲያስታውስዎት የማንቂያ ምልክቱን ይጫኑ።', 'tip' => 'ማንቂያው ስልክዎ ተቆልፎ ቢሆንም እንኳን ልክ እንደ ሰዓት ማንቂያ ይሰራል!'],
                    ['title' => 'ተሳታፊዎች እና ተረኞች', 'description' => 'ለመዝሙር፣ ለትምህርት ወይም ለስነ-ስርዓት የተመደቡ አባላትን ዝርዝር ይመልከቱ።', 'tip' => 'በመርሐ ግብሩ ላይ ተረኛ ከሆኑ ልዩ ምልክት ይታይዎታል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'በAndroid 12/13/14+ ላይ ትክክለኛ ማንቂያ እንዲሰራ የስልክዎን «Alarms & Reminders» ፈቃድ ይስጡ።',
                    'ያለፈ መርሐ ግብር ላይ ማንቂያ ማብራት አይቻልም።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ማንቂያው በሰዓቱ ካልደወለ ምን ማድረግ አለብኝ?', 'a' => 'በስልክዎ Settings ውስጥ የመተግበሪያውን «Alarms & Reminders» ፈቃድ ማብራትዎን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 4. Attendance & Member QR Card
            [
                'slug' => 'attendance-and-qr-card',
                'category' => 'attendance',
                'title' => 'የአባልነት ካርድ እና ክትትል (Attendance & QR Card)',
                'summary' => 'የግል QR ኮድ አጠቃቀም፣ የመገኘት ምዝገባ እና የክትትል የቀን መቁጠሪያ።',
                'content' => "እያንዳንዱ አባል ልዩ የQR ኮድ ያለው ዲጂታል መታወቂያ ካርድ አለው።\n\nበሰንበት ት/ቤት መርሐ ግብሮች ወይም በትምህርት ክፍለ ጊዜ አስተዳዳሪዎች ወይም አቴንዳንስ መዝጋቢዎች የእርስዎን QR ኮድ በመቃኘት መገኘትዎን ወዲያውኑ ይመዘግባሉ። የራስዎን የክትትል ታሪክም ማየት ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/settings/me',
                'required_permission' => null,
                'tour_id' => 'attendance_tour',
                'icon' => 'qr_code_rounded',
                'sort_order' => 4,
                'steps' => json_encode([
                    ['title' => 'የአባልነት QR ካርድ', 'description' => 'በቅንብሮች ውስጥ «ስለ እኔ» ገጽ ላይ የሚገኘው የእርስዎ የግል ዲጂታል መታወቂያ።', 'tip' => 'ካርዱን ለክትትል መዝጋቢዎች በማሳየት በቀላሉ ይመዝገቡ።'],
                    ['title' => 'የክትትል የቀን መቁጠሪያ (Calendar)', 'description' => 'የተገኙባቸውን እና የቀሩባቸውን ቀናት በቀለም በተለዩ ምልክቶች ያሳያል።', 'tip' => 'በቅንብሮች ስር «የአቴንዳንስ የቀን መቁጠሪያ» የሚለውን ይጫኑ።'],
                    ['title' => 'የማስተካከያ ጥያቄ (Correction)', 'description' => 'ተገኝተው ባልተመዘገቡበት ቀን ማስተካከያ እንዲደረግልዎት ጥያቄ ማቅረብ ይችላሉ።', 'tip' => 'ጥያቄዎ በመምሪያ መሪዎ ወይም በአስተዳዳሪው ሲረጋገጥ ይስተካከላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የQR ካርድዎን ስክሪን ሾት በማንሳትም ማሳየት ይቻላል።',
                    'የክትትል ደንቦችን ለማወቅ በክትትል ገጽ ላይ የደንብ መረጃውን ይመልከቱ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ካርዴ ላይ ፎቶ ከሌለ ምን ላድርግ?', 'a' => 'በመገለጫ (Profile) ገጽ ላይ ገብተው አዲስ ፎቶ ይስቀሉ ወይም ለአስተዳዳሪው ያሳውቁ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 5. Education System
            [
                'slug' => 'education-system',
                'category' => 'education',
                'title' => 'የሰንበት ት/ቤት ትምህርት (Education System)',
                'summary' => 'ትምህርቶች፣ ፈተናዎች፣ ክፍሎች፣ እድገት፣ ምዝገባ እና የትምህርት መጻሕፍት።',
                'content' => "የሰንበት ት/ቤት የትምህርት ማዕከል አምስት ትሮች አሉት፦ መነሻ (የዕለቱ ትምህርት፣ ምድቦች፣ የዚህ ሳምንት ፈተናዎችና የቤት ሥራዎች)፣ ተማር (ምድብ → የትምህርት ዓይነት → ምዕራፍ → ትምህርት)፣ ክፍሎች (ምዝገባ፣ ፕሮግራም፣ መገኘት፣ የቤት ሥራ)፣ እድገት (የትምህርት እድገት፣ መገኘት እና የታተሙ ውጤቶች) እና ተጨማሪ (ቤተ-መጽሐፍት፣ ጥያቄዎችና ቅሬታዎች፣ መርሐ ግብሮች፣ ቅንብሮች)።\n\nየፈተና ውጤቶች ይፋዊ የሚሆኑት በመምህሩ ቀርበው በትምህርት ክፍሉ ከጸደቁና ከታተሙ በኋላ ብቻ ነው።",
                'target_role' => 'all',
                'target_screen' => '/edu',
                'required_permission' => null,
                'tour_id' => 'edu_tour',
                'icon' => 'school_rounded',
                'sort_order' => 5,
                'steps' => json_encode([
                    ['title' => 'ተማር (Learn)', 'description' => 'ምድብ ይምረጡ፣ የትምህርት ዓይነቱን ይክፈቱ፣ ትምህርቱን ያንብቡ እና ሲጨርሱ «እንዳጠናቀቅሁ» ምልክት ያድርጉ።', 'tip' => 'ከላይ ያለው የፍለጋ ምልክት በትምህርቶችና በጥቅሶች ይፈልጋል።', 'action_route' => '/edu/learn'],
                    ['title' => 'ፈተናዎች (Quizzes)', 'description' => 'የዚህ ሳምንት ፈተና በመነሻ ገጹ ይታያል። «ተሳተፍ»ን ይጫኑ፤ የጊዜ ገደብ ካለው ሰዓቱ ከላይ ይታያል።', 'tip' => 'የልምምድ ፈተናዎች መልስዎን ወዲያውኑ እንዲፈትሹ ያስችላሉ።', 'action_route' => '/edu'],
                    ['title' => 'የክፍል መገኘት እና ውጤቶች', 'description' => 'በ«እድገት» ትር የተገኙበትን ምጣኔ እና የታተሙ የምዘና ውጤቶችን ይመልከቱ።', 'tip' => 'ያልታተመ ውጤት አይታይም፤ ሲታተም ማሳወቂያ ይደርስዎታል።', 'action_route' => '/edu/progress'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የትምህርት ክፍለ ጊዜ ከመጀመሩ በፊት የንባብ ጽሑፎችን አስቀድመው ያውርዱ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ክፍሌ ካልታየ ምን ላድርግ?', 'a' => 'ለትምህርት አስተዳዳሪው ወይም ለክፍል አስተባባሪዎ በማሳወቅ ምዝገባዎ እንዲረጋገጥ ያድርጉ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 6. Projects & Tasks
            [
                'slug' => 'projects-and-tasks',
                'category' => 'projects',
                'title' => 'የዲፓርትመንት ፕሮጀክቶች እና ተግባራት (Projects & Tasks)',
                'summary' => 'የመምሪያ የጋራ ስራዎች፣ የተሰጡ ተግባራት (Tasks)፣ በጀት እና አስተያየቶች።',
                'content' => "የሰንበት ት/ቤት ክፍላት የሚሰሯቸውን ልዩ ልዩ ፕሮጀክቶች እና ተግባራት በግልጽ ለመከታተል የሚያስችል ክፍል ነው።\n\nአባላት የተመደቡባቸውን ስራዎች ደረጃ ማዘመን፣ አስተያየት መስጠት እና የወጪ ጥያቄዎችን ማቅረብ ይችላሉ።",
                'target_role' => 'leader',
                'target_screen' => '/hub',
                'required_permission' => 'projects.view',
                'tour_id' => 'projects_tour',
                'icon' => 'assignment_rounded',
                'sort_order' => 6,
                'steps' => json_encode([
                    ['title' => 'የፕሮጀክቶች ዝርዝር', 'description' => 'የመምሪያዎ እና የሰንበት ት/ቤቱ አጠቃላይ ፕሮጀክቶች ዝርዝር።', 'tip' => 'በደረጃቸው (በሂደት ላይ፣ ያለቀ፣ የታቀደ) ተለይተው ይታያሉ።'],
                    ['title' => 'የተግባራት ሰሌዳ (Tasks)', 'description' => 'ለአባላት የተከፋፈሉ ተግባራት፣ የማጠናቀቂያ ቀን እና ቅድሚያ የሚሰጣቸው ስራዎች።', 'tip' => 'ስራዎን ሲያጠናቅቁ ደረጃውን ወደ «ተጠናቋል» ይለውጡ።'],
                    ['title' => 'የበጀት እና ወጪ ክትትል', 'description' => 'የተመደበ በጀት እና የወጡ ወጪዎችን በደረሰኝ የተደገፈ ማረጋገጫ።', 'tip' => 'የወጪ ጥያቄዎች በበላይ መሪዎች ሲጸድቁ ወደ ወጪ ይመዘገባሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ለእያንዳንዱ ተግባር አስተያየት በመጻፍ የቡድን አባላት መረጃ እንዲለዋወጡ ያድርጉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ወጪ ለመጠየቅ ምን ያስፈልጋል?', 'a' => 'በፕሮጀክቱ ስር የወጪ መስመር በመምረጥ መጠኑን እና የደረሰኝ ፎቶ በማያያዝ ያቅርቡ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 7. My Mezmurs (Favorites & Downloads)
            [
                'slug' => 'my-mezmurs-library',
                'category' => 'mezmurs',
                'title' => 'የእኔ መዝሙራት — የተወደዱ እና የወረዱ (My Mezmurs: Favorites & Downloads)',
                'summary' => 'የወደዷቸውን መዝሙራት (Favorites) እና ወደ ስልክዎ ያወረዷቸውን መዝሙራት (Offline Downloads) ያለ ኢንተርኔት ማዳመጥ።',
                'content' => "የመዝሙር ክፍል «የእኔ» (Library) ገጽ ዋና ዓላማ እርስዎ የመረጧቸውን የተወደዱ መዝሙራት (Favorites) እና ወደ ስልክዎ ያወረዷቸውን መዝሙራት (Downloads) ያለ ምንም ኢንተርኔት ኮኔክሽን በቀላሉ ለማዳመጥ እና ለማስተዳደር ነው።\n\nበማንኛውም ጊዜ መዝሙር ለማውረድ የመዝሙሩ ገጽ ላይ የማውረጃ ምልክቱን ይጫኑ።",
                'target_role' => 'all',
                'target_screen' => '/library',
                'required_permission' => null,
                'tour_id' => 'library_tour',
                'icon' => 'library_music_rounded',
                'sort_order' => 7,
                'steps' => json_encode([
                    ['title' => 'የተወደዱ መዝሙራት (Favorites)', 'description' => 'በማንኛውም መዝሙር ላይ የልብ ምልክት (Favorite) በመጫን እዚህ ዝርዝር ውስጥ ሰብስበው በቀላሉ ያጫውቱ።', 'tip' => 'በተደጋጋሚ የሚያዳምጧቸውን መዝሙራት በምልክት ይለዩ።'],
                    ['title' => 'የወረዱ መዝሙራት (Offline Downloads)', 'description' => 'የወረዱ መዝሙራትን ያለ ምንም ኢንተርኔት በከፍተኛ ጥራት ከመስመር ውጭ (Offline) ያዳምጡ።', 'tip' => 'የማውረጃ ምልክቱን በመጫን መዝሙሩን በስልክዎ ላይ ያከማቹ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'መዝሙራትን አስቀድመው በማውረድ ኢንተርኔት በሌለበት ሰዓት ወይም ጉዞ ላይ ያለ መቆራረጥ ያዳምጡ።',
                    'የወረዱ መዝሙራትን ከስልክዎ ማህደረ ትውስታ ለማጥፋት ከዝርዝሩ ላይ በቀላሉ ማስተዳደር ይችላሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ያወረድኳቸው መዝሙራት ኢንተርኔት ሳይኖር ይሠራሉ?', 'a' => 'አዎ፤ የወረዱ መዝሙራት በስልክዎ ማህደረ ትውስታ ውስጥ ስለሚቀመጡ ያለ ምንም ኢንተርኔት ይሠራሉ።'],
                    ['q' => 'መዝሙር እንዴት ወደ ተወደዱ ዝርዝር ማከል እችላለሁ?', 'a' => 'በመዝሙር ማጫወቻው ወይም በግጥሙ ገጽ ላይ ያለውን የልብ ምልክት (Favorite) በመጫን ማከል ይችላሉ።'],
                    ['q' => 'የመንፈሳዊ መጻሕፍት እና ንብረት ውሰት የት ይገኛል?', 'a' => 'የትምህርት መጻሕፍት እና ንብረት ውሰት በትምህርት ክፍል (Education) ወይም በቅንብሮች (Settings) ገጽ ውስጥ ይገኛሉ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 8. Choir Holiday Selection
            [
                'slug' => 'choir-holiday-selection',
                'category' => 'choir',
                'title' => 'የበዓላት መዝሙር መረጣ (Choir Selection)',
                'summary' => 'የበዓላት መዝሙር መራጭ ደንቦች፣ የምዘና ነጥቦች፣ ምድቦች እና ይፋዊ ውጤት።',
                'content' => "ለበዓላት እና ለልዩ መርሐ ግብሮች የመዘምራን መረጣ ፍትሃዊ እና ግልጽ በሆነ የአሰራር ደንብ ይከናወናል።\n\nየአባላት የፈተና ውጤት፣ የመገኘት ምጣኔ እና የአገልግሎት ምድቦች ተሰልተው በመጨረሻም ይፋዊ ዝርዝር ይወጣል።",
                'target_role' => 'all',
                'target_screen' => '/hub',
                'required_permission' => null,
                'tour_id' => 'choir_tour',
                'icon' => 'groups_rounded',
                'sort_order' => 8,
                'steps' => json_encode([
                    ['title' => 'የመረጣ መስፈርቶች', 'description' => 'የአቴንዳንስ ምጣኔ፣ የፈተና ውጤቶች እና የአገልግሎት ዝግጁነት መመዘኛዎች።', 'tip' => 'ዝቅተኛውን መስፈርት የሚያሟሉ አባላት ብቻ በዕጣው ወይም በመረጣው ይካተታሉ።'],
                    ['title' => 'የአገልግሎት ምድቦች', 'description' => 'የተመረጡ አባላት የሚመደቡባቸው የአገልግሎት ክፍላት።', 'tip' => 'ውጤቱ ሲታወጅ የተመደቡበትን ክፍል ማየት ይችላሉ።'],
                    ['title' => 'ውጤት መመልከት', 'description' => 'ውጤቱ በአስተዳዳሪዎች ሲጸድቅ እና ይፋ ሲደረግ በመተግበሪያው ላይ ይታያል።', 'tip' => 'ቅሬታ ወይም ጥያቄ ካለዎት ለክፍሉ አስተባባሪዎች ማቅረብ ይችላሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ውጤቱ ይፋ እስካልሆነ ድረስ በግምገማ (Under Review) ደረጃ ይቆያል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ውጤቴ ለምን አልወጣም?', 'a' => 'መረጣው በአስተዳዳሪዎች ገና ይፋ ካልተደረገ ውጤቱ አይታይም።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 9. Admin Workflows: Users Management
            [
                'slug' => 'admin-users-management',
                'category' => 'admin',
                'title' => 'የአባላት አስተዳደር (Admin: User Management)',
                'summary' => 'አዲስ አባላትን መመዝገብ፣ መረጃ ማስተካከል፣ መታወቂያ መስጠት እና ስልክ መቀየር።',
                'content' => "ይህ ክፍል ለአስተዳዳሪዎች ብቻ የተዘጋጀ ሲሆን የአባላትን መረጃ ሙሉ በሙሉ ለመቆጣጠር ያስችላል።\n\nአዲስ አባል መመዝገብ፣ የስልክ እና ሚና (Role) ማስተካከል፣ የይለፍ ቃል ሪሴት ማድረግ እና ስልክ ሲቀይሩ Device Reset ማከናወን ይቻላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/users',
                'required_permission' => 'users.view',
                'tour_id' => 'admin_users_tour',
                'icon' => 'manage_accounts_rounded',
                'sort_order' => 9,
                'steps' => json_encode([
                    ['title' => 'የአባላት ዝርዝር እና ፍለጋ', 'description' => 'በስም፣ በስልክ ቁጥር፣ በመታወቂያ ወይም በክፍል ፈጣን ፍለጋ ያካሂዱ።', 'tip' => 'የተዘጉ ወይም የተሰናበቱ አባላትንም ለይቶ ማየት ይቻላል።'],
                    ['title' => 'አዲስ አባል መመዝገብ', 'description' => 'ሙሉ ስም፣ ስልክ ቁጥር እና የመጀመሪያ ፒን በመስጠት ይመዝግቡ።', 'tip' => 'አባሉ ለመጀመሪያ ጊዜ ሲገባ ፒኑን እንዲቀይር ይገደዳል።'],
                    ['title' => 'Device Reset (ስልክ ማስቀየር)', 'description' => 'አባሉ ስልክ ሲቀይር ወይም ሲጠፋበት የነበረውን የስልክ ትስስር ያላቅቁለት።', 'tip' => 'Device Reset ሲደረግ አባሉ በአዲሱ ስልኩ መግባት ይችላል።'],
                    ['title' => 'ሚና እና ፈቃዶች (Roles & Permissions)', 'description' => 'ለተመረጡ አባላት የአስተዳዳሪ ወይም የመምሪያ መሪ ፈቃዶችን ይስጡ።', 'tip' => 'ያላስፈላጊ ፈቃዶችን አለመስጠት የስርዓቱን ደህንነት ይጠብቃል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የአባላትን ሚስጥራዊ መረጃ በአግባቡ እና በኃላፊነት ይጠብቁ።',
                    'ስልክ ቁጥር ሲቀይሩ ትክክለኛውን የሀገር ኮድ (+251) ይጠቀሙ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አባል «Device already linked» ሲለው ምን ይደረጋል?', 'a' => 'በአባላት ዝርዝር ውስጥ አባሉን ከፍተው «Reset Device» የሚለውን ይጫኑ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 10. Admin Workflows: Programs & Attendance Management
            [
                'slug' => 'admin-programs-and-attendance',
                'category' => 'admin',
                'title' => 'መርሐ ግብር እና አቴንዳንስ መዝጋት (Admin: Programs & Attendance)',
                'summary' => 'መርሐ ግብር ማቀድ፣ አቴንዳንስ መዝጋቢዎችን መመደብ፣ አቴንዳንስ መዝጋት እና ደንቦችን ማስተካከል。',
                'content' => "የሰንበት ት/ቤት መርሐ ግብሮችን ማቀድ፣ ተረኞችን መመደብ፣ በQR ኮድ ክትትል ማድረግ እና የአቴንዳንስ ቆጠራን መዝጋት (Close Attendance) የሚያስችል የአስተዳዳሪ የስራ ፍሰት ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/programs',
                'required_permission' => 'programs.manage',
                'tour_id' => 'admin_programs_tour',
                'icon' => 'fact_check_rounded',
                'sort_order' => 10,
                'steps' => json_encode([
                    ['title' => 'መርሐ ግብር መፍጠር', 'description' => 'ርዕስ፣ ምድብ፣ ቀን፣ የጀማሪ እና ማብቂያ ሰዓት ያስገቡ።', 'tip' => 'ተደጋጋሚ መርሐ ግብር ከሆነ የሳምንት ቀኑን መምረጥ ይቻላል።'],
                    ['title' => 'አንድ መዝጋቢ መመደብ (የሰው ሀብት ክፍል)', 'description' => 'ለእያንዳንዱ መርሐ ግብር አንድ የአቴንዳንስ መዝጋቢ ይመደባል፤ ለአንድ ቀን ሌላ መዝጋቢ ከዚያ ቀን ዝርዝር መመደብ ይቻላል።', 'tip' => 'የተመደበው መዝጋቢ ብቻ ይጀምራል፣ ይመዘግባል፣ ይጨርሳል።'],
                    ['title' => 'ጀምር እና ጨርስ (Start / End)', 'description' => 'መዝገቡ ከጅማሬው 15 ደቂቃ በፊት ይከፈታል፤ መዝጋቢው «ጀምር» ሲጫን ይጀምራል። አባላት በQR ወይም በስም ተመርጠው ከፈረሙ በኋላ ይመዘገባሉ። «ጨርስ» ሲጫን ወይም የማብቂያው ሰዓት ሲደርስ ይዘጋል፤ ያልተመዘገቡት እንደቀሩ ይቆጠራሉ።', 'tip' => '«ዘግይቷል» የሚባል ሁኔታ የለም፤ የደረሱበት ሰዓት ከጅማሬው ጀምሮ ይመዘገባል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ከመስመር ውጭም መጀመር፣ መመዝገብና መጨረስ ይቻላል፤ ኢንተርኔት ሲገኝ በተያዙበት ሰዓት ይላካሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የተዘጋ አቴንዳንስ ማስተካከል ይቻላል?', 'a' => 'ከተዘጋ በኋላ ለውጥ የሚደረገው በማስተካከያ ጥያቄ ብቻ ነው፤ የሰው ሀብት ክፍል ይገመግማል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 11. Admin Workflows: Notifications & Broadcasts
            [
                'slug' => 'admin-notifications',
                'category' => 'admin',
                'title' => 'ማሳወቂያዎችን መላክ (Admin: Notifications & Broadcasts)',
                'summary' => 'ለአባላት፣ ለክፍላት ወይም ለመላው ሰንበት ት/ቤት መልዕክት እና ማሳሰቢያ ማስተላለፍ።',
                'content' => "አስተዳዳሪዎች ለአባላት የሞባይል ፑሽ ማሳወቂያዎችን (Push Notifications) ለመላክ ይህንን ክፍል ይጠቀማሉ።\n\nመልዕክቶችን በቡድን፣ በክፍል፣ በዲፓርትመንት ወይም ለሁሉም አባላት መላክ ይቻላል። የማሳወቂያዎችን የደረሰበት ሁኔታም በNotification Health መከታተል ይቻላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/notify',
                'required_permission' => 'notifications.send',
                'tour_id' => 'admin_notify_tour',
                'icon' => 'campaign_rounded',
                'sort_order' => 11,
                'steps' => json_encode([
                    ['title' => 'ተቀባዮችን መምረጥ', 'description' => 'ሁሉንም አባላት፣ የተወሰነ ዲፓርትመንት ወይም የተመረጡ ሰዎችን ይወስኑ።', 'tip' => '«ለሁሉም» ለመላክ ልዩ ፈቃድ (notifications.send_all) ያስፈልጋል።'],
                    ['title' => 'ርዕስ እና መልዕክት መጻፍ', 'description' => 'አጭር፣ ግልጽ እና ማራኪ ርዕስ እና የመልዕክቱን ዝርዝር ያስገቡ።', 'tip' => 'አባላቱ ማሳወቂያውን ሲነኩት የሚከፈተውን ገጽ (Screen Route) ማያያዝ ይችላሉ።'],
                    ['title' => 'መላክ እና ጤንነት ማረጋገጥ', 'description' => 'መልዕክቱን ልከው ምን ያህል ሰዎች እንደደረሳቸው በሪፖርት ይመልከቱ።', 'tip' => 'ያልደረሳቸው አባላት ካሉ በድጋሚ መላክ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'አስፈላጊ ያልሆኑ መልዕክቶችን በተደጋጋሚ መላክ አባላትን እንዳያሰለች ይጠንቀቁ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ማሳወቂያው ለምን አልደረሰም?', 'a' => 'አባሉ በመተግበሪያው ላይ ማሳወቂያዎችን ዘግቶ ሊሆን ይችላል፤ ወይም ስልኩ ኦፍላይን ነው።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 12. Admin Workflows: Reports & Audits
            [
                'slug' => 'admin-reports-and-audits',
                'category' => 'admin',
                'title' => 'ሪፖርቶች እና ኦዲት (Admin: Reports & Audits)',
                'summary' => 'የአቴንዳንስ፣ የበጀት፣ የመዝሙር እና የአባላት ሪፖርቶችን በExcel/CSV/PDF ማውጣት።',
                'content' => "የሰንበት ት/ቤቱን አጠቃላይ የአገልግሎት እና የአስተዳደር ሁኔታ የሚያሳዩ ዳሽቦርዶች እና ሪፖርቶች የሚዘጋጁበት ክፍል ነው።\n\nየአቴንዳንስ ምጣኔ፣ የገንዘብ እንቅስቃሴ እና የስርዓት ኦዲት ሎግ (Audit & Activity Logs) በቀላሉ ማውጣት ይቻላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/reports',
                'required_permission' => 'reports.view',
                'tour_id' => 'admin_reports_tour',
                'icon' => 'bar_chart_rounded',
                'sort_order' => 12,
                'steps' => json_encode([
                    ['title' => 'የዳሽቦርድ ማጠቃለያ', 'description' => 'የአባላት ቁጥር፣ ሳምንታዊ የአቴንዳንስ ምጣኔ እና የንቁ አገልግሎቶች ገለጻ።', 'tip' => 'በቀን፣ በወር ወይም በዓመት ማጣራት ይችላሉ።'],
                    ['title' => 'ሪፖርት ማመንጨት እና ማውረድ', 'description' => 'ሪፖርቶችን በCSV ወይም Excel ፋይል ወደ ኮምፒውተር ወይም ስልክ ያውርዱ።', 'tip' => 'ለኮሚቴ እና ለአመራር ስብሰባዎች ዝግጁ የሆኑ ሰንጠረዦችን ይሰጣል።'],
                    ['title' => 'የኦዲት ሎግ ክትትል (Audit Trail)', 'description' => 'በስርዓቱ ላይ ማን ምን እንደቀየረ፣ እንዳጠፋ ወይም እንደፈጠረ በሰከንድ የተመዘገበ ታሪክ።', 'tip' => 'የደህንነት እና የተጠያቂነት ማረጋገጫ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ትላልቅ ሪፖርቶችን ከማውረድዎ በፊት የቀን ገደብ በመስጠት ፍለጋውን ያጥቡት።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የሪፖርት ፋይሉ አልወርድ ካለ ምን ላድርግ?', 'a' => 'የስልክዎን ፋይል ማውረጃ ፈቃድ ያረጋግጡ ወይም በዌብ በኩል ይክፈቱት።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 13. Troubleshooting: Offline Mode
            [
                'slug' => 'troubleshoot-offline-mode',
                'category' => 'troubleshooting',
                'title' => 'ከመስመር ውጭ አጠቃቀም እና ዳታ ማመሳከር (Offline Mode & Sync)',
                'summary' => 'ኢንተርኔት በማይኖርበት ጊዜ እንዴት እንደሚሰራ እና ዳታ ማመሳከር።',
                'content' => "የመሠረተ ሕይወት መተግበሪያ የተሰራው አስቀድሞ ከመስመር ውጭ (Offline-First) እንዲሰራ ተደርጎ ነው።\n\nየወረዱ መዝሙራት፣ ግጥሞች፣ የመርሐ ግብር መረጃዎች እና የአባልነት ካርድዎ ያለ ኢንተርኔት ይሰራሉ። ኢንተርኔት ሲያገኙ ደግሞ አዳዲስ መረጃዎች በራሳቸው ይዘምናሉ።",
                'target_role' => 'all',
                'target_screen' => '/settings',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'cloud_off_rounded',
                'sort_order' => 13,
                'steps' => json_encode([
                    ['title' => 'የመረጃ ቅጂ (Local Cache)', 'description' => 'አንዴ የተመለከቷቸው መዝሙራት እና መረጃዎች በስልክዎ ላይ ይቀመጣሉ።', 'tip' => 'በየጊዜው ወደ መተግበሪያው ገብተው አዳዲስ መረጃዎችን ያዘምኑ።'],
                    ['title' => 'የግጥም ጥቅል ማውረድ', 'description' => 'ሁሉንም መዝሙራት በአንድ ጊዜ ለማውረድ በቅንብሮች ውስጥ «የመዝሙር ግጥሞች ጥቅል» የሚለውን ይጫኑ።', 'tip' => 'ጥቂት ሜጋባይት ብቻ የሚወስድ ፈጣን ጥቅል ነው።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ለረጅም ጊዜ ኦፍላይን ከቆዩ አልፎ አልፎ ኢንተርኔት በማብራት የይለፍ ቃልዎን እና አዳዲስ መርሐ ግብሮችን ያመሳክሩ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ያለ ኢንተርኔት አዳዲስ መዝሙራትን ማግኘት እችላለሁ?', 'a' => 'አይ፤ አዳዲስ መዝሙራትን ለመጫን አንድ ጊዜ ኢንተርኔት ማገናኘት ያስፈልጋል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 14. Troubleshooting: Android Alarms & Notifications
            [
                'slug' => 'troubleshoot-alarms',
                'category' => 'troubleshooting',
                'title' => 'የመርሐ ግብር ማንቂያ ደወል ካልሰራ (Alarms & Permissions)',
                'summary' => 'የ30 ደቂቃ መርሐ ግብር ማንቂያ በAndroid 12/13/14+ ላይ ካልደወለ መፍትሔዎች።',
                'content' => "በአዳዲስ የአንድሮይድ ስልኮች ላይ የስልክ ባትሪ ቆጣቢ ስርዓቶች ማንቂያዎችን ሊያዘገዩ ወይም ሊከለክሉ ይችላሉ።\n\nማንቂያው ሁልጊዜ በትክክለኛው ሰዓት እንዲደውል የሚከተሉትን እርምጃዎች ይውሰዱ።",
                'target_role' => 'all',
                'target_screen' => '/programs',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'alarm_off_rounded',
                'sort_order' => 14,
                'steps' => json_encode([
                    ['title' => 'Alarms & Reminders ፈቃድ', 'description' => 'በስልክዎ Settings > Apps > መሠረተ ሕይወት > Alarms & Reminders የሚለውን አብሩ።', 'tip' => 'ይህ ፈቃድ መተግበሪያው በትክክለኛው ደቂቃ ማንቂያ እንዲያሰማ ይፈቅድለታል።'],
                    ['title' => 'Battery Optimization (ባትሪ ቆጣቢ)', 'description' => 'የመተግበሪያውን የባትሪ አጠቃቀም ወደ «Unrestricted» (ያልተገደበ) ይቀይሩት።', 'tip' => 'ስልኩ ተቆልፎ ቢቆይም ማንቂያው እንዳይዘጋ ያደርገዋል።'],
                    ['title' => 'Do Not Disturb (ረብሻ አትፍጠር)', 'description' => 'ስልክዎ በ«አትረብሽ» ሁኔታ ውስጥ ከሆነ የመተግበሪያውን ማንቂያዎች ፈቃድ ይስጡ።', 'tip' => 'ወሳኝ መርሐ ግብሮች እንዳያመልጡዎት ይረዳል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ማንቂያ ከሞከሩ በኋላ ስልክዎን አንድ ጊዜ ሪስታርት ማድረግ ጠቃሚ ነው።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ስልኬን ሳይለንት ካደረግኩት ማንቂያው ይጮኻል?', 'a' => 'አዎ! ልክ እንደ መደበኛ የጠዋት ማንቂያ ሰዓት ድምጹን ከፍ አድርጎ ያሰማል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 15. Profile & Profession
            [
                'slug' => 'profile-and-profession',
                'category' => 'settings',
                'title' => 'መገለጫ እና ሙያ (Profile & Profession)',
                'summary' => 'የግል መረጃ፣ ፎቶ፣ የስራ እና የትምህርት ሙያ ምዝገባ።',
                'content' => "የግል መገለጫዎን የሚያዘምኑበት ገጽ ነው። አባላት ሙያቸውን፣ የትምህርት ደረጃቸውን እና ልዩ ተሰጥኦአቸውን በመመዝገብ ለሰንበት ት/ቤቱ ልዩ ልዩ አገልግሎቶች የበኩላቸውን አስተዋጽኦ እንዲያበረክቱ ያስችላል።",
                'target_role' => 'all',
                'target_screen' => '/settings/profile',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'person_outline_rounded',
                'sort_order' => 15,
                'steps' => json_encode([
                    ['title' => 'የመገለጫ ፎቶ መቀየር', 'description' => 'የመታወቂያ ፎቶዎን ከጋለሪ በመምረጥ ወይም አዲስ በማንሳት ይጫኑ።', 'tip' => 'ጥራት ያለው እና ግልጽ ፎቶ ይጠቀሙ።'],
                    ['title' => 'የሙያ እና የትምህርት መረጃ', 'description' => 'የተመረቁበትን ወይም የሚሰሩበትን የስራ መስክ እና ክህሎት ይመዝግቡ።', 'tip' => 'በሰንበት ት/ቤት ፕሮጀክቶች ለመሳተፍ ይረዳል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'መረጃዎን በየጊዜው በማዘመን ሰንበት ት/ቤቱ እርስዎን በሙያዎ እንዲያሳትፍ ያግዙ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ስልክ ቁጥሬን መቀየር እችላለሁ?', 'a' => 'ስልክ ቁጥር ለመቀየር ለአስተዳዳሪው በማሳወቅ Device Reset መደረግ አለበት።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 16. Payments & Contributions
            [
                'slug' => 'payments-and-contributions',
                'category' => 'settings',
                'title' => 'ክፍያዎች እና መዋጮዎች (Payments & Dues)',
                'summary' => 'የወርሀዊ መዋጮ፣ የአባልነት ክፍያ እና የደረሰኝ ታሪክ።',
                'content' => "የአባልነት ክፍያዎችን፣ ወርሃዊ መዋጮዎችን እና የልዩ ፕሮጀክት ድጋፎችን ሁኔታ መከታተያ ክፍል ነው። የተከፈሉ ክፍያዎችን፣ የቀሩ ዕዳዎችን እና የክፍያ ደረሰኞችን በግልጽ ያሳያል።",
                'target_role' => 'all',
                'target_screen' => '/settings/payments',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'payment_rounded',
                'sort_order' => 16,
                'steps' => json_encode([
                    ['title' => 'የክፍያ ታሪክ መመልከት', 'description' => 'ያለፉትን የተከፈሉ እና ያልተከፈሉ ወራት ዝርዝር ይመልከቱ።', 'tip' => 'ያልተከፈለ ወር ካለ በቀይ ቀለም ተለይቶ ይታያል።'],
                    ['title' => 'ደረሰኝ ማያያዝ', 'description' => 'በባንክ የተከፈለበትን ደረሰኝ ፎቶ በማንሳት ለፋይናንስ ክፍል ያቅርቡ።', 'tip' => 'ደረሰኙ በግልጽ የሚነበብ መሆኑን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ክፍያዎ በፋይናንስ አስተዳዳሪው ሲረጋገጥ ደረጃው ወደ «ተረጋግጧል» ይቀየራል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የደረሰኝ ማረጋገጫ ምን ያህል ጊዜ ይወስዳል?', 'a' => 'ብዙውን ጊዜ በ24 ሰዓታት ውስጥ በፋይናንስ ክፍሉ ይረጋገጣል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 17. Notification Settings
            [
                'slug' => 'notification-settings-guide',
                'category' => 'settings',
                'title' => 'የማሳወቂያ ቅንብሮች (Notification Settings)',
                'summary' => 'የፑሽ ማሳወቂያዎች፣ የማንቂያ ድምጽ እና የሰዓት ማስተካከያ።',
                'content' => "የሚደርሷችሁን ማሳወቂያዎች አይነት (መርሐ ግብሮች፣ ትምህርት፣ ክፍያዎች፣ የቡድን መልዕክቶች) የሚቆጣጠሩበት ክፍል ነው። የማንቂያ ደወል ድምጽ እና የማስታወሻ ሰዓትንም እዚሁ ማስተካከል ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/settings/notifications',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'notifications_active_rounded',
                'sort_order' => 17,
                'steps' => json_encode([
                    ['title' => 'የማሳወቂያ አይነቶች', 'description' => 'ሊደርስዎት የሚፈልጉትን የማሳወቂያ አይነት ያብሩ ወይም ያጥፉ።', 'tip' => 'አስፈላጊ የአስተዳደር መልዕክቶች ሁልጊዜ ይደርሳሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ወሳኝ የሰንበት ት/ቤት መልዕክቶች እንዳያመልጥዎት ማሳወቂያዎችን ክፍት ያድርጉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ማሳወቂያዎችን ሙሉ በሙሉ ማጥፋት እችላለሁ?', 'a' => 'አጠቃላይ ማብሪያ/ማጥፊያውን በመጠቀም ሙሉ በሙሉ ማጥፋት ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 18. Admin Attendance Rules & Scoring
            [
                'slug' => 'admin-attendance-scoring-rules',
                'category' => 'admin',
                'title' => 'የአቴንዳንስ ፊርማ ደንብ (Attendance Signatures)',
                'summary' => 'አባላት ሲመዘገቡ የሚፈርሙበት ደንብ እና ከመስመር ውጭ የተያዙ መዝገቦች ግምገማ።',
                'content' => "አባላት «ተገኝቷል» ተብለው ከመመዝገባቸው በፊት በመዝጋቢው ስልክ ላይ ይፈርማሉ። የሰው ሀብት ክፍል የማይፈርሙ የአባል ዓይነቶችን እዚህ ይወስናል። «ዘግይቷል» የሚባል ሁኔታ የለም፤ የደረሱበት ሰዓት ከመዝገቡ ጅማሬ ጀምሮ ይመዘገባል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/attendance/rules',
                'required_permission' => 'attendance.configure',
                'tour_id' => null,
                'icon' => 'gavel_rounded',
                'sort_order' => 18,
                'steps' => json_encode([
                    ['title' => 'የማይፈርሙ የአባል ዓይነቶች', 'description' => 'የማይፈርሙትን የአባል ዓይነቶች ምልክት አድርገው ያስቀምጡ፤ ሌሎቹ ሁሉ ይፈርማሉ።', 'tip' => 'ለውጡ በኦዲት መዝገብ ይቀመጣል።'],
                    ['title' => 'ከመስመር ውጭ የተያዙ መዝገቦች', 'description' => 'አገልጋዩ እንደተያዙ ሊመዘግባቸው ያልቻሉ መዝገቦች «የሚገመገሙ ከመስመር ውጭ መዝገቦች» ገጽ ላይ ይታያሉ፤ እያንዳንዱን በማስታወሻ ይቀበሉ ወይም ይከልክሉ።', 'tip' => 'ያቀረቡትን ራስዎ መወሰን አይችሉም።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ፊርማዎች ከመላካቸው በፊት በስልኩ ላይ ተመስጥረው ይቀመጣሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ከመስመር ውጭ የተመዘገበ መገኘት ይጠፋል?', 'a' => 'አይጠፋም፤ ሊመዘገብ ያልቻለው ሁሉ ከፊርማውና ከተያዘበት ሰዓት ጋር ለሰው ሀብት ክፍል ግምገማ ይቀመጣል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 19. Admin Member IDs
            [
                'slug' => 'admin-member-ids',
                'category' => 'admin',
                'title' => 'የአባልነት መታወቂያ ካርዶች (Member ID Cards)',
                'summary' => 'የአባላት ዲጂታል እና የታተሙ የQR መታወቂያ ካርዶችን ማመንጨት እና ማስተዳደር።',
                'content' => "የሰንበት ት/ቤት አባላት የዲጂታል QR መታወቂያ ቁጥር የሚሰጥበት እና ካርዶች የሚዘጋጁበት ክፍል ነው። ለአዳዲስ አባላት መታወቂያ ቁጥር በራስ-ሰር ማመንጨት፣ የካርድ ሁኔታን (የታተመ/ያልታተመ) መከታተል እና ለህትመት ማዘጋጀት ይቻላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/member-ids',
                'required_permission' => 'member_id.configure',
                'tour_id' => null,
                'icon' => 'badge_rounded',
                'sort_order' => 19,
                'steps' => json_encode([
                    ['title' => 'ያልተሰጣቸው አባላትን መምረጥ', 'description' => 'መታወቂያ ቁጥር የሌላቸውን አባላት ያጣሩ።', 'tip' => 'በፍለጋ ማጣሪያው በቀላሉ ማግኘት ይቻላል።'],
                    ['title' => 'መታወቂያ ማመንጨት', 'description' => 'በቡድን ወይም በግል የካርድ ቁጥር ይስጡ።', 'tip' => 'ቁጥሩ በቋሚነት ይመዘገባል።'],
                    ['title' => 'ለህትመት ማዘጋጀት', 'description' => 'የQR ካርዶችን ለህትመት ያውርዱ።', 'tip' => 'በPDF ቅርጸት ማውረድ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የአባልነት ቁጥር አንድ ጊዜ ከተሰጠ በኋላ በስርዓቱ ውስጥ ልዩ (unique) ሆኖ ይቀመጣል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አባሉ መታወቂያውን ቢያጣው ምን ይደረጋል?', 'a' => 'ያለውን የካርድ ቁጥር ሳያስቀይሩ አዲስ ካርድ እንደገና ማመንጨት እና ማተም ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 20. Admin Member Groups
            [
                'slug' => 'admin-member-groups',
                'category' => 'admin',
                'title' => 'የአባላት ምድቦች (Member Groups)',
                'summary' => 'አባላትን በዕድሜ፣ በአገልግሎት ክፍል እና በቡድን መመደብ።',
                'content' => "አባላትን በሕፃናት፣ ወጣቶች፣ ጎልማሶች ወይም በአገልግሎት ቡድኖች ከፋፍሎ ለማስተዳደር ይጠቅማል። ይህ ምድብ በአቴንዳንስ እና በሪፖርቶች ላይ አባላትን በቀላሉ ለመለየት ያግዛል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/member-groups',
                'required_permission' => 'member_groups.manage',
                'tour_id' => null,
                'icon' => 'groups_rounded',
                'sort_order' => 20,
                'steps' => json_encode([
                    ['title' => 'ምድብ መምረጥ', 'description' => 'የሕፃናት፣ ወጣቶች ወይም ልዩ ቡድን ይምረጡ።', 'tip' => 'የምድቡን መስፈርት ያረጋግጡ።'],
                    ['title' => 'አባላትን መመደብ', 'description' => 'አባላትን ወደ ተመረጠው ምድብ ያዛውሩ።', 'tip' => 'በጅምላ መመደብ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የምድብ ለውጥ ሲደረግ የአባሉ የወርሃዊ መዋጮ ምጣኔ በራስ-ሰር ሊስተካከል ይችላል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አንድ አባል በሁለት ምድብ ውስጥ ሊሆን ይችላል?', 'a' => 'ዋናው ምድብ አንድ ሲሆን በአገልግሎት ክፍል ግን በበርካታ ክፍላት መሳተፍ ይችላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 21. Admin Profile Change Requests
            [
                'slug' => 'admin-change-requests',
                'category' => 'admin',
                'title' => 'የመረጃ ለውጥ ጥያቄዎች (Profile Change Requests)',
                'summary' => 'አባላት የላኳቸውን የስም፣ ስልክ፣ ፎቶ እና አድራሻ ለውጥ ጥያቄዎች መገምገም እና ማጽደቅ።',
                'content' => "አባላት በመተግበሪያቸው በኩል የስም፣ የስልክ ቁጥር ወይም የመገለጫ ፎቶ ለውጥ ሲጠይቁ በቀጥታ አይቀየርም፤ በዚህ ክፍል በአስተዳዳሪ ታይቶ ሲጸድቅ ብቻ በቋሚነት ይመዘገባል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/change-requests',
                'required_permission' => 'users.update',
                'tour_id' => null,
                'icon' => 'manage_accounts_rounded',
                'sort_order' => 21,
                'steps' => json_encode([
                    ['title' => 'ጥያቄዎችን መመልከት', 'description' => 'በመጠባበቅ ላይ ያሉትን ጥያቄዎች ከቀድሞው መረጃ ጋር ያነጻጽሩ።', 'tip' => 'ትክክለኛውን አባል መለየትዎን ያረጋግጡ።'],
                    ['title' => 'ማጽደቅ ወይም ውድቅ ማድረግ', 'description' => 'ትክክለኛ ከሆነ ያጽድቁ፤ ስህተት ካለበት ምክንያቱን ጽፈው ይመልሱ።', 'tip' => 'ምክንያት መጻፍ ግዴታ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ጥያቄው ሲጸድቅ ወይም ውድቅ ሲደረግ ለአባሉ ማሳወቂያ በስልኩ ይደርሰዋል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ውድቅ የተደረገ ጥያቄ እንደገና ሊቀርብ ይችላል?', 'a' => 'አዎ፤ አባሉ መረጃውን አስተካክሎ አዲስ ጥያቄ ማቅረብ ይችላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 22. Admin Payments
            [
                'slug' => 'admin-payments',
                'category' => 'admin',
                'title' => 'የአባላት ክፍያዎች አስተዳደር (Payments Admin)',
                'summary' => 'የወርሃዊ መዋጮ፣ የልዩ መዋጮ እና የደረሰኝ ምዝገባ መቆጣጠሪያ።',
                'content' => "የአባላትን ወርሃዊ መዋጮ፣ የመመዝገቢያ ክፍያ እና ሌሎች ገቢዎችን ለመመዝገብ እና ለመከታተል የሚያገለግል ክፍል ነው። የኢትዮጵያ ዘመን አቆጣጠርን መሰረት ባደረገ መልኩ ወርሃዊ ክፍያዎች ይመዘገባሉ፤ ያልከፈሉ አባላት ዝርዝርም ይወጣል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/payments',
                'required_permission' => 'payments.view',
                'tour_id' => null,
                'icon' => 'payments_rounded',
                'sort_order' => 22,
                'steps' => json_encode([
                    ['title' => 'አባሉን መፈለግ', 'description' => 'በስም ወይም በመታወቂያ ቁጥር ይፈልጉ።', 'tip' => 'በስልክ ቁጥርም መፈለግ ይቻላል።'],
                    ['title' => 'ክፍያ መመዝገብ', 'description' => 'የተከፈለበትን ወር፣ የገንዘብ መጠን እና የደረሰኝ ቁጥር ያስገቡ።', 'tip' => 'የኢትዮጵያ ወር በትክክል ይምረጡ።'],
                    ['title' => 'ደረሰኝ ማረጋገጥ', 'description' => 'የባንክ ማስተላለፊያ ደረሰኝ ከሆነ ፎቶውን አይተው ያጽድቁ።', 'tip' => 'ማስረጃውን በጥንቃቄ ይመልከቱ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የኢትዮጵያ ወራትን በትክክል መምረጥዎን ያረጋግጡ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የተሳሳተ ክፍያ ከተመዘገበ ማስተካከል ይቻላል?', 'a' => 'ክፍያውን የሰረዘው አስተዳዳሪ ምክንያት አስገብቶ ኦዲት በሚደረግበት አግባብ መሰረዝ ወይም ማስተካከል ይችላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 23. Admin Fines
            [
                'slug' => 'admin-fines',
                'category' => 'admin',
                'title' => 'የቅጣቶች አስተዳደር (Fines & Penalties)',
                'summary' => 'በመዘግየት እና በመቅረት የተጣሉ የገንዘብ ቅጣቶችን መከታተል እና ይቅርታ ማድረግ።',
                'content' => "በአቴንዳንስ ህግ መሰረት በመቅረት ወይም በመዘግየት የተጣሉ የገንዘብ ቅጣቶችን የሚያሳይ እና የሚያስተዳድር ክፍል ነው። አባሉ ቅጣቱን ሲከፍል መመዝገብ ወይም አሳማኝ ምክንያት ካለ በይቅርታ መሰረዝ ይቻላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/fines',
                'required_permission' => 'fines.manage',
                'tour_id' => null,
                'icon' => 'money_off_rounded',
                'sort_order' => 23,
                'steps' => json_encode([
                    ['title' => 'የተቀጡ አባላትን መመልከት', 'description' => 'ያልተከፈሉ ቅጣቶችን ዝርዝር ይመርምሩ።', 'tip' => 'በክፍል ወይም በወር ማጣራት ይቻላል።'],
                    ['title' => 'ክፍያ መመዝገብ ወይም ይቅርታ ማድረግ', 'description' => 'ክፍያ ከተከፈለ ያጽድቁ፤ ይቅርታ ከተደረገ ምክንያቱን ያስገቡ።', 'tip' => 'ይቅርታ ሲደረግ ምክንያት መጻፍ ግዴታ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ይቅርታ የተደረጉ ቅጣቶች በሙሉ በኦዲት ሎግ ውስጥ ይመዘገባሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ቅጣት በራስ-ሰር ነው የሚጣለው?', 'a' => 'አዎ፤ አቴንዳንስ ሲዘጋ በScoring Rules በተቀመጠው ደንብ መሰረት ስርዓቱ በራስ-ሰር ያሰላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 24. Admin Attendance Corrections
            [
                'slug' => 'admin-attendance-corrections',
                'category' => 'admin',
                'title' => 'የአቴንዳንስ ማስተካከያ ጥያቄዎች (Attendance Corrections)',
                'summary' => 'የተሳሳተ የመገኘት መረጃን ለማረም የቀረቡ ጥያቄዎችን በኃላፊዎች መርምሮ ማጽደቅ።',
                'content' => "የአቴንዳንስ መዝጋቢው ወይም የመምሪያ ኃላፊው በስህተት ያልተመዘገበ ወይም የተሳሳተ አቴንዳንስ እንዲታረም ሲጠይቅ፣ በፕሮግራሙ በተመደበው ገለልተኛ የሰው ኃይል (HR Approver) ብቻ ይገመገማል። ጠያቂው ራሱ የራሱን ጥያቄ ማጽደቅ በሕጉ በጥብቅ የተከለከለ ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/attendance/corrections',
                'required_permission' => 'attendance.correction.approve',
                'tour_id' => null,
                'icon' => 'rule_rounded',
                'sort_order' => 24,
                'steps' => json_encode([
                    ['title' => 'የቀረበውን ምክንያት መመርመር', 'description' => 'የማስተካከያ ጥያቄውን እና የተያያዘውን ማስረጃ ይመልከቱ።', 'tip' => 'ማስረጃውን በጥንቃቄ ይመልከቱ።'],
                    ['title' => 'ገለልተኛ ውሳኔ መስጠት', 'description' => 'ጥያቄውን ያቀረበው ሰው አለመሆንዎን አረጋግጠው ያጽድቁ ወይም ውድቅ ያድርጉ።', 'tip' => 'ራስን ማጽደቅ አይቻልም።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ተጠሪ የHR አጽዳቂ ካልተመደበ ስርዓቱ ማስተካከያውን ማጽደቅ ይከለክላል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ጠያቂው ኃላፊ ራሱ ማጽደቅ ይችላል?', 'a' => 'በፍጹም አይችልም፤ ስርዓቱ ራስን ማጽደቅ (Self-Approval) በጥብቅ ይከለክላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 25. Admin Absence Requests
            [
                'slug' => 'admin-permissions',
                'category' => 'admin',
                'title' => 'የፈቃድ እና የመቅረት ጥያቄዎች (Absence Requests)',
                'summary' => 'አባላት ከመርሐ ግብር አስቀድመው ያቀረቧቸውን የፈቃድ ጥያቄዎች መገምገም።',
                'content' => "አባላት በህመም፣ በትምህርት ወይም በስራ ምክንያት በሰንበት ት/ቤት መርሐ ግብር ላይ መገኘት በማይችሉበት ጊዜ የሚያቀርቡትን የፈቃድ ጥያቄ መርምሮ ውሳኔ የሚሰጥበት ክፍል ነው። የተፈቀደላቸው አባላት በአቴንዳንስ ወቅት እንደ «በፈቃድ የቀረ» ተቆጥረው ቅጣት አይጣልባቸውም።",
                'target_role' => 'admin',
                'target_screen' => '/admin/permissions',
                'required_permission' => 'attendance.view',
                'tour_id' => null,
                'icon' => 'event_busy_rounded',
                'sort_order' => 25,
                'steps' => json_encode([
                    ['title' => 'ጥያቄውን መክፈት', 'description' => 'የአባሉን ስም፣ መርሐ ግብሩን እና የቀረበውን ምክንያት ይመልከቱ።', 'tip' => 'የቀረበበትን ሰዓት ያረጋግጡ።'],
                    ['title' => 'መፍቀድ ወይም መከልከል', 'description' => 'ጥያቄውን ተቀብለው ይፍቀዱ ወይም ካላመኑበት ምክንያቱን ጽፈው ይከልክሉ።', 'tip' => 'ምክንያት ያካተተ ውሳኔ ይስጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ፈቃድ መጠየቅ ያለበት መርሐ ግብሩ ከመጀመሩ በፊት መሆን አለበት።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ፈቃድ የተሰጠው አባል ነጥብ ይቀነሳል?', 'a' => 'በፈቃድ ሲቀር እንደ ተራ መቅረት አይቆጠርም፤ እንደ ደንቡ አነስተኛ ወይም ምንም ቅጣት አይጣልበትም።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 26. Admin Notification Health
            [
                'slug' => 'admin-notification-health',
                'category' => 'admin',
                'title' => 'የማሳወቂያ ጤና እና ሁኔታ (Notification Health)',
                'summary' => 'የFCM ቶከኖች፣ የደረሱ ማሳወቂያዎች ምጣኔ እና የቴክኒክ ብልሽቶች ክትትል ዳሽቦርድ።',
                'content' => "ወደ አባላት ስልኮች የሚላኩ የፑሽ ማሳወቂያዎች በትክክል መድረሳቸውን፣ የFCM ቶከኖች ትክክለኛነት እና ያጋጠሙ ቴክኒካዊ ስህተቶችን ለመከታተል የሚያገለግል ዳሽቦርድ ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/notification-health',
                'required_permission' => 'notifications.send',
                'tour_id' => null,
                'icon' => 'mark_email_read_rounded',
                'sort_order' => 26,
                'steps' => json_encode([
                    ['title' => 'የማሳወቂያዎችን ስታትስቲክስ መመልከት', 'description' => 'የተላኩ፣ የደረሱ እና ያልተሳኩ ማሳወቂያዎችን ምጣኔ ይመርምሩ።', 'tip' => 'የስኬት ምጣኔውን ያረጋግጡ።'],
                    ['title' => 'ያልተሳኩትን እንደገና መላክ', 'description' => 'ቴክኒካዊ ችግር የገጠማቸውን መልዕክቶች በድጋሚ ይላኩ።', 'tip' => 'Retry ቁልፉን ይጠቀሙ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'አባላት በመተግበሪያ ቅንብሮች ማሳወቂያ ካልፈቀዱ ፑሽ ላይደርሳቸው ይችላል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ያረጁ ቶከኖች እንዴት ይጸዳሉ?', 'a' => 'ስርዓቱ ተጠቃሚው መተግበሪያውን ሲከፍት ቶከኑን በራስ-ሰር ያድሳል፤ የማይሰሩትም በየጊዜው ይሰረዛሉ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 27. Admin Departments
            [
                'slug' => 'admin-departments',
                'category' => 'admin',
                'title' => 'የክፍላት አስተዳደር (Departments Admin)',
                'summary' => 'የሰንበት ት/ቤት ክፍላትን ማቋቋም፣ መሪዎችን እና አባላትን ማስተዳደር።',
                'content' => "እንደ ትምህርት፣ መዝሙር፣ ልማት፣ ሒሳብ እና ንብረት ያሉ የአገልግሎት ክፍላትን ለመፍጠር፣ የመምሪያ ኃላፊዎችን ለመመደብ እና አባላትን በክፍላት ለማደራጀት ያገለግላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/departments',
                'required_permission' => 'departments.manage',
                'tour_id' => null,
                'icon' => 'corporate_fare_rounded',
                'sort_order' => 27,
                'steps' => json_encode([
                    ['title' => 'ክፍል መፍጠር ወይም መምረጥ', 'description' => 'የአገልግሎት ክፍሉን ስም እና መግለጫ ያስገቡ።', 'tip' => 'የክፍሉን አላማ ያብራሩ።'],
                    ['title' => 'ኃላፊ መመደብ', 'description' => 'የመምሪያውን መሪ እና ረዳት ከአባላት መካከል ይምረጡ።', 'tip' => 'ተገቢውን ፈቃድ ይስጡ።'],
                    ['title' => 'አባላትን ማካተት', 'description' => 'በክፍሉ ውስጥ የሚያገለግሉ አባላትን ያክሉ።', 'tip' => 'ዝርዝሩን ያዘምኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የክፍል መሪዎች ለክፍላቸው አባላት የውይይት ቡድን እና የተግባር ዝርዝር ማስተዳደር ይችላሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አንድ አባል ከአንድ በላይ ክፍል መምራት ይችላል?', 'a' => 'አዎ፤ አስተዳዳሪው አስፈላጊውን ፈቃድ ከሰጠው በርካታ ክፍላትን ማስተባበር ይችላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 28. Admin Chat Moderation
            [
                'slug' => 'admin-chat',
                'category' => 'admin',
                'title' => 'የክፍላት ውይይት ቁጥጥር (Department Chat Moderation)',
                'summary' => 'የክፍላት የውስጥ መልዕክቶችን እና ውይይቶችን መከታተል፣ ማስተካከል እና ማጽዳት።',
                'content' => "በክፍላት መካከል የሚደረጉ የውስጥ የጽሑፍ ውይይቶችን ስነ-ስርዓት ለመጠበቅ፣ አላስፈላጊ መልዕክቶችን ለማስወገድ እና ይፋዊ መግለጫዎችን ለማስተላለፍ የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/chat',
                'required_permission' => 'chat.supervise',
                'tour_id' => null,
                'icon' => 'forum_rounded',
                'sort_order' => 28,
                'steps' => json_encode([
                    ['title' => 'የክፍሉን ቻት መክፈት', 'description' => 'የሚፈልጉትን ክፍል የውይይት መስኮት ይምረጡ።', 'tip' => 'መልዕክቶቹን ይመርምሩ።'],
                    ['title' => 'መልዕክቶችን መቆጣጠር', 'description' => 'ተገቢ ያልሆኑ መልዕክቶችን መሰረዝ ወይም አስፈላጊ ማስታወቂያዎችን መስቀል።', 'tip' => 'ስነ-ምግባርን ያስጠብቁ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የተሰረዙ መልዕክቶች በአስተዳዳሪ ኦዲት ውስጥ ይቀመጣሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አባላት በግል መወያየት ይችላሉ?', 'a' => 'ውይይቱ የተዘጋጀው ለአገልግሎት ክፍላት ስራዎች ብቻ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 29. Admin Items & Inventory
            [
                'slug' => 'admin-items',
                'category' => 'admin',
                'title' => 'የንብረት እና መጻሕፍት አስተዳደር (Items & Inventory)',
                'summary' => 'የሰንበት ት/ቤት ንብረቶችን፣ መጻሕፍትን፣ አልባሳትን እና የድምጽ እቃዎችን መመዝገብ።',
                'content' => "የሰንበት ት/ቤቱን ቋሚ እና አላቂ ንብረቶች፣ የቤተ-መጽሐፍት መጻሕፍት፣ የመዘምራን አልባሳት እና የሙዚቃ መሳሪያዎችን ለመመዝገብ፣ መለያ ኮድ ለመስጠት እና ያለውን ብዛት ለመከታተል ይጠቅማል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/items',
                'required_permission' => 'items.manage',
                'tour_id' => null,
                'icon' => 'inventory_2_rounded',
                'sort_order' => 29,
                'steps' => json_encode([
                    ['title' => 'አዲስ እቃ መመዝገብ', 'description' => 'የእቃውን ስም፣ አይነት፣ መለያ ቁጥር እና ብዛት ያስገቡ።', 'tip' => 'መለያ ኮድ ይስጡ።'],
                    ['title' => 'ሁኔታውን ማዘመን', 'description' => 'ጥሩ፣ የተበላሸ ወይም በእድሳት ላይ መሆኑን ያመልክቱ።', 'tip' => 'የእቃውን ሁኔታ ይከታተሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ውድ እቃዎችን በመለያ ቁጥራቸው (Serial Number) መመዝገብ ለቁጥጥር አመቺ ነው።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የተበላሸ እቃ ከዝርዝር እንዴት ይወገዳል?', 'a' => 'የእቃውን ሁኔታ «የተወገደ» (Disposed) በማድረግ ከንቁ ዝርዝር ማውጣት ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 30. Admin Borrowings
            [
                'slug' => 'admin-borrowings',
                'category' => 'admin',
                'title' => 'የውሰት አስተዳደር (Borrowings Admin)',
                'summary' => 'የተወሰዱ ንብረቶችን እና መጻሕፍትን መከታተል፣ የተመላሽ ቀን እና ቅጣቶችን ማስተዳደር።',
                'content' => "አባላት ለግል ወይም ለአገልግሎት የተዋሷቸውን መጻሕፍት እና እቃዎች ለመቆጣጠር፣ የተወሰደበትን ቀን፣ መመለሻ ጊዜውን እና በሰዓቱ ያልተመለሱ እቃዎችን ለመከታተል የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/borrowings',
                'required_permission' => 'borrowing.manage',
                'tour_id' => null,
                'icon' => 'assignment_return_rounded',
                'sort_order' => 30,
                'steps' => json_encode([
                    ['title' => 'ውሰት መመዝገብ', 'description' => 'ተበዳሪውን አባል፣ እቃውን እና የሚመለስበትን ቀን ይወስኑ።', 'tip' => 'የመመለሻ ቀኑን ይግለጹ።'],
                    ['title' => 'መመለሱን ማረጋገጥ', 'description' => 'እቃው ሲመለስ ሁኔታውን አይተው «ተመልሷል» የሚለውን ይጫኑ።', 'tip' => 'የእቃውን ደህንነት ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የመመለሻ ቀኑ ካለፈ በኋላ ስርዓቱ ለአባሉ የማስጠንቀቂያ ማሳወቂያ ይልካል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'እቃው ቢጠፋ ወይም ቢበላሽ ምን ይደረጋል?', 'a' => 'በአስተዳዳሪው ውሳኔ የካሳ ወይም የመተኪያ ክፍያ በቅጣት መልክ ሊመዘገብ ይችላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 31. Admin Property Requests
            [
                'slug' => 'admin-property-requests',
                'category' => 'admin',
                'title' => 'የንብረት መጠየቂያዎች (Property Requests)',
                'summary' => 'ክፍላት ለአገልግሎት የሚጠይቋቸውን እቃዎች እና የንብረት ግዢዎች መገምገም።',
                'content' => "የተለያዩ የአገልግሎት ክፍላት ለስራቸው የሚያስፈልጓቸውን ንብረቶች ወይም አላቂ እቃዎች ለማግኘት የሚያቀርቡትን ጥያቄ የንብረት ክፍል ኃላፊዎች መርምረው የሚፈቅዱበት ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/property-requests',
                'required_permission' => 'property.review',
                'tour_id' => null,
                'icon' => 'shopping_cart_checkout_rounded',
                'sort_order' => 31,
                'steps' => json_encode([
                    ['title' => 'ጥያቄውን መመርመር', 'description' => 'የጠየቀውን ክፍል፣ የተጠየቀውን እቃ እና አገልግሎቱን ይመልከቱ።', 'tip' => 'የክምችት ሁኔታውን ያረጋግጡ።'],
                    ['title' => 'ማጽደቅ እና ማስረከብ', 'description' => 'በመጋዘን ውስጥ ካለ ፈቅደው ያስረክቡ፤ ከሌለ የግዢ ውሳኔ ይስጡ።', 'tip' => 'ርክክብ ያከናውኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የተፈቀዱ እቃዎች በራስ-ሰር ከንብረት ክምችት ላይ ይቀነሳሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ጥያቄው በከፊል ሊፈቀድ ይችላል?', 'a' => 'አዎ፤ ከተጠየቀው ብዛት ያነሰ መጠን ፈቅዶ ማስረከብ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 32. Admin Library Requests
            [
                'slug' => 'admin-library-requests',
                'category' => 'admin',
                'title' => 'የቤተ-መጽሐፍት መጠየቂያዎች (Library Requests)',
                'summary' => 'ተማሪዎች እና አባላት መጻሕፍት ለመዋስ የሚያቀርቧቸውን ጥያቄዎች ማስተዳደር።',
                'content' => "አባላት በመተግበሪያው በኩል የቤተ-መጽሐፍት ካታሎግ አይተው መጽሐፍ ለመዋስ ያቀረቧቸውን ጥያቄዎች መርምሮ መጽሐፉን ማስረከብ እና ውሰቱን ማጽደቅ የሚያስችል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/library-requests',
                'required_permission' => 'borrowing.manage',
                'tour_id' => null,
                'icon' => 'local_library_rounded',
                'sort_order' => 32,
                'steps' => json_encode([
                    ['title' => 'የተጠየቀውን መጽሐፍ ማረጋገጥ', 'description' => 'መጽሐፉ በመደርደሪያው ላይ መኖሩን ያረጋግጡ።', 'tip' => 'ኮዱን ያረጋግጡ።'],
                    ['title' => 'ውሰቱን ማጽደቅ', 'description' => 'አባሉ መጥቶ ሲወስድ መጽሐፉን አስረክበው ያጽድቁ።', 'tip' => 'የመመለሻ ቀን ይወስኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'አንድ አባል በአንድ ጊዜ ከአንድ ወይም ሁለት መጽሐፍ በላይ እንዳይወስድ መገደብ ይቻላል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የውሰት ጊዜው ስንት ቀን ነው?', 'a' => 'እንደ ቤተ-መጽሐፍቱ ደንብ አብዛኛውን ጊዜ ከ14 እስከ 21 ቀናት ነው።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 33. Edu Courses
            [
                'slug' => 'edu-courses',
                'category' => 'education',
                'title' => 'የትምህርት ኮርሶች አስተዳደር (Education Courses)',
                'summary' => 'የሰንበት ት/ቤት ኮርሶችን፣ ማስተማሪያ ስርአተ-ትምህርቶችን እና መምህራንን ማስተዳደር።',
                'content' => "በሰንበት ት/ቤቱ የሚሰጡትን መንፈሳዊ ኮርሶች ለመቅረጽ፣ ማስተማሪያ ጽሑፎችን ለመስቀል እና መምህራንን ለመመደብ የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/edu/courses',
                'required_permission' => 'education.manage',
                'tour_id' => null,
                'icon' => 'menu_book_rounded',
                'sort_order' => 33,
                'steps' => json_encode([
                    ['title' => 'አዲስ ኮርስ መፍጠር', 'description' => 'የኮርሱን ርዕስ፣ መግለጫ እና የትምህርት ሰዓት ያስገቡ።', 'tip' => 'ርዕሱን ያብራሩ።'],
                    ['title' => 'ስርአተ-ትምህርት ማዘጋጀት', 'description' => 'የኮርሱን ምዕራፎች እና ማጣቀሻ መጻሕፍት ያክሉ።', 'tip' => 'ፒዲኤፍ ማያያዝ ይቻላል።'],
                    ['title' => 'መምህር መመደብ', 'description' => 'ኮርሱን የሚያስተምረውን መምህር ይምረጡ።', 'tip' => 'ኃላፊውን ይመድቡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ተማሪዎች የኮርሱን ማጠቃለያ እና የፈተና ውጤት በመተግበሪያቸው ማየት ይችላሉ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ኮርሱን ለተወሰነ ክፍል ብቻ መወሰን ይቻላል?', 'a' => 'አዎ፤ ኮርሱ ለየትኛው ክፍል ክፍት እንደሆነ መወሰን ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 34. Edu Manage Classes
            [
                'slug' => 'edu-manage',
                'category' => 'education',
                'title' => 'የትምህርት ክፍሎች እና ባቾች (Classes & Batches)',
                'summary' => 'የትምህርት አመታትን፣ ሴሚስተሮችን፣ የክፍል ክፍለ-ጊዜዎችን እና ተማሪዎችን ማደራጀት።',
                'content' => "የትምህርት ክፍሎችን (ክፍል 1 እስከ 12) እና የትምህርት ባቾችን ለማስተዳደር፣ የጊዜ ሰሌዳ ለማውጣት እና የተማሪዎችን ውጤት ለመከታተል የሚያገለግል ዋና የትምህርት ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/edu/manage',
                'required_permission' => 'education.manage',
                'tour_id' => null,
                'icon' => 'class_rounded',
                'sort_order' => 34,
                'steps' => json_encode([
                    ['title' => 'ባች ወይም ክፍል መምረጥ', 'description' => 'የሚፈልጉትን የትምህርት ክፍል ይክፈቱ።', 'tip' => 'የትምህርት አመቱን ያረጋግጡ።'],
                    ['title' => 'የጊዜ ሰሌዳ ማውጣት', 'description' => 'የክፍለ-ጊዜውን ቀን እና ሰዓት ያስተካክሉ።', 'tip' => 'ሰዓቱን ይወስኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የትምህርት ሞጁል በስርዓት ቅንብሮች ከጠፋ ይህ ክፍል ለተጠቃሚዎች አይታይም።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ተማሪዎችን ከአንድ ክፍል ወደ ቀጣይ ክፍል ማዘዋወር ይቻላል?', 'a' => 'አዎ፤ አመቱ ሲጠናቀቅ ተማሪዎችን በጅምላ ወደ ቀጣዩ ክፍል ማሳደግ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 35. Edu Registrations
            [
                'slug' => 'edu-registrations',
                'category' => 'education',
                'title' => 'የተማሪዎች ምዝገባ (Student Registrations)',
                'summary' => 'አዳዲስ ተማሪዎች ወደ ሰንበት ት/ቤት ለመግባት ያቀረቧቸውን ማመልከቻዎች መገምገም።',
                'content' => "ወደ ሰንበት ት/ቤት ለመግባት በመተግበሪያው በኩል የተመዘገቡ አዳዲስ ተማሪዎችን መረጃ መርምሮ ለመቀበል ወይም ክፍል ለመመደብ የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/edu/registrations',
                'required_permission' => 'education.register',
                'tour_id' => null,
                'icon' => 'how_to_reg_rounded',
                'sort_order' => 35,
                'steps' => json_encode([
                    ['title' => 'አመልካቾችን መመልከት', 'description' => 'የተማሪውን የግል መረጃ፣ እድሜ እና የቀድሞ መንፈሳዊ ትምህርት ይመልከቱ።', 'tip' => 'መረጃውን ያረጋግጡ።'],
                    ['title' => 'ክፍል መመደብ እና ማጽደቅ', 'description' => 'ተገቢውን ክፍል መርጠው ምዝገባውን ያጽድቁ።', 'tip' => 'ክፍል ይመድቡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ምዝገባው ሲጸድቅ ተማሪው የአባልነት ቁጥር እና የመግቢያ ፈቃድ ያገኛል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ያልተሟላ መረጃ ያለው ተማሪ ምን ይደረጋል?', 'a' => 'ምዝገባውን ለጊዜው አግዶ ተጨማሪ መረጃ እንዲያቀርብ መልዕክት መላክ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 36. Admin Choir Selections & Service Bonuses
            [
                'slug' => 'admin-selections',
                'category' => 'admin',
                'title' => 'የበዓላት መዘምራን መረጣ (Choir Selections & Service Bonuses)',
                'summary' => 'ለዋና ዋና በዓላት የሚዘምሩ አባላትን በአቴንዳንስ ነጥብ እና በቦነስ ደንብ መምረጥ።',
                'content' => "ለበዓለ-ጥምቀት፣ ለፋሲካ፣ ለመስቀል እና ለንግስ በዓላት በመድረክ የሚያገለግሉ መዘምራንን በግልጽ መስፈርት ለመምረጥ የሚያገለግል ክፍል ነው። የመገኘት ምጣኔ፣ የትምህርት ውጤት እና የመዝሙር አገልግሎት ቦነስ ተደምረው አባላት በደረጃቸው ይመረጣሉ። ቦነስ በቋሚ ወይም በመቶኛ ሲሰላ ከመዝሙር አቴንዳንስ አካል ብቻ ይሰላል፤ ከፍተኛው የመዝሙር ነጥብም ከ100% አይበልጥም።",
                'target_role' => 'admin',
                'target_screen' => '/admin/selections',
                'required_permission' => 'selection.view',
                'tour_id' => null,
                'icon' => 'auto_awesome_rounded',
                'sort_order' => 36,
                'steps' => json_encode([
                    ['title' => 'የበዓሉን መረጣ መክፈት', 'description' => 'የበዓሉን ስም፣ የሚያስፈልጉ መዘምራን ብዛት እና መመዘኛ ነጥብ ያስገቡ።', 'tip' => 'መስፈርቱን ይወስኑ።'],
                    ['title' => 'የቦነስ ደንቦችን መተግበር', 'description' => 'የአገልግሎት ቦነስ ነጥብ በቋሚ ወይም በመቶኛ ያሰሉ፤ ከ100% እንዳይበልጥ ያረጋግጡ።', 'tip' => 'ከ100% አይበልጥም።'],
                    ['title' => 'የተመረጡትን ማጽደቅ', 'description' => 'ዝርዝሩን ገምግመው ለመዘምራኑ ይፋ ያድርጉ።', 'tip' => 'ይፋ ያድርጉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የመዝሙር ቦነስ ወደ ትምህርት ወይም ወደ ሌላ ክፍል ውጤት በፍጹም አይተላለፍም።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አባላት ውጤታቸውን ማየት ይችላሉ?', 'a' => 'አዎ፤ የተመረጡትም ሆኑ ተጠባባቂዎች ደረጃቸውን በግልፅ በመተግበሪያቸው ያያሉ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 37. Admin Wedding Choir
            [
                'slug' => 'admin-weddings',
                'category' => 'admin',
                'title' => 'የሰርግ መዘምራን አገልግሎት (Wedding Choir Service)',
                'summary' => 'የሰርግ መርሃ-ግብሮችን እና የአገልጋይ መዘምራንን ምደባ ማስተዳደር።',
                'content' => "የሰርግ መዝሙር አገልግሎት ጥያቄዎችን ለመመዝገብ፣ የሚዘምሩ አባላትን ለመመደብ እና የአገልግሎቱን አፈጻጸም ለመከታተል የሚረዳ ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/weddings',
                'required_permission' => 'choir.manage',
                'tour_id' => null,
                'icon' => 'celebration_rounded',
                'sort_order' => 37,
                'steps' => json_encode([
                    ['title' => 'የሰርግ መርሐ ግብር መመዝገብ', 'description' => 'የሙሽሮችን ስም፣ የሰርጉን ቀን፣ ሰዓት እና ቦታ ያስገቡ።', 'tip' => 'ቀኑን ያስገቡ።'],
                    ['title' => 'መዘምራንን መመደብ', 'description' => 'ተረኛ መዘምራንን ከአባላት ዝርዝር ይምረጡ።', 'tip' => 'መዘምራኑን ይመድቡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ለተመደቡት መዘምራን የቀኑ እና የቦታው ማስታወቂያ በስልካቸው ይላካል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የሰርግ አገልግሎት አቴንዳንስ ይያዝለታል?', 'a' => 'አዎ፤ እንደ አንድ ልዩ መርሐ ግብር ተቆጥሮ አቴንዳንስ ይመዘገብበታል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 38. Admin Mezmur Categories
            [
                'slug' => 'admin-categories',
                'category' => 'admin',
                'title' => 'የመዝሙር ምድቦች አስተዳደር (Mezmur Categories Admin)',
                'summary' => 'የመዝሙር አቃፊዎችን፣ ንዑሳን ምድቦችን እና ቅደም ተከተላቸውን ማስተካከል።',
                'content' => "በመተግበሪያው ውስጥ የሚታዩትን የመዝሙር ምድቦች ለመፍጠር፣ ቅደም ተከተል ለማስያዝ እና ምስል ለመስጠት የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/categories',
                'required_permission' => 'categories.manage',
                'tour_id' => null,
                'icon' => 'category_rounded',
                'sort_order' => 38,
                'steps' => json_encode([
                    ['title' => 'ምድብ መፍጠር', 'description' => 'የምድቡን ስም በአማርኛ እና በእንግሊዝኛ ያስገቡ።', 'tip' => 'ስሙን ይጻፉ።'],
                    ['title' => 'ምስል እና ቅደም ተከተል መስጠት', 'description' => 'አዶ ወይም ምስል መርጠው በስክሪኑ ላይ የሚታይበትን ቅደም ተከተል ይወስኑ።', 'tip' => 'ቅደም ተከተል ይስጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ምድብ ሲሰረዝ በውስጡ ያሉት መዝሙራት አይጠፉም፤ ወደ ሌላ ምድብ ማዛወር ይቻላል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ንዑስ ምድብ መፍጠር ይቻላል?', 'a' => 'አዎ፤ አንድን ምድብ የሌላ ምድብ ልጅ ማድረግ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 39. Admin Mezmurs
            [
                'slug' => 'admin-mezmurs',
                'category' => 'admin',
                'title' => 'የመዝሙራት ይዘት አስተዳደር (Mezmur Content Management)',
                'summary' => 'መዝሙራትን መመዝገብ፣ ግጥሞችን ማረም፣ የድምጽ ፋይሎችን መስቀል እና ማስተዳደር።',
                'content' => "አዳዲስ መዝሙራትን ወደ ስርዓቱ ለማስገባት፣ የግጥም ስንኞችን ለማስተካከል፣ የዜማ ደራሲ እና አዝማች መረጃዎችን ለማስቀመጥ እና የMP3 ድምጽ ፋይሎችን ለመስቀል የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/mezmurs',
                'required_permission' => 'mezmurs.view',
                'tour_id' => null,
                'icon' => 'queue_music_rounded',
                'sort_order' => 39,
                'steps' => json_encode([
                    ['title' => 'መዝሙር መመዝገብ', 'description' => 'ርዕስ፣ ምድብ እና ግጥም ያስገቡ።', 'tip' => 'ግጥሙን ያረጋግጡ።'],
                    ['title' => 'ድምጽ መስቀል', 'description' => 'ከፍተኛ ጥራት ያለው የድምጽ ፋይል ያያይዙ።', 'tip' => 'የድምጽ ጥራቱን ይመልከቱ።'],
                    ['title' => 'የግጥም ማመሳሰል (LRC)', 'description' => 'ድምጹ ሲጫወት ግጥሙ አብሮ እንዲሄድ የሰዓት ማመሳሰያ ያስገቡ።', 'tip' => 'LRC ያስገቡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ግጥሞችን በትክክለኛ የኢትዮጵያ ፊደላት መጻፍዎን ያረጋግጡ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ድምጽ የሌላቸው መዝሙራት ሊገቡ ይችላሉ?', 'a' => 'አዎ፤ ግጥም ብቻ ያላቸው መዝሙራት ተመዝግበው ተጠቃሚዎች እንዲያነቧቸው ማድረግ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 40. Admin Bulk Import
            [
                'slug' => 'admin-import',
                'category' => 'admin',
                'title' => 'የጅምላ መረጃ ማስገቢያ (Bulk Import & Data Migration)',
                'summary' => 'መዝሙራትን፣ አባላትን ወይም አቴንዳንስን በExcel/CSV ፋይል በጅምላ ማስገባት።',
                'content' => "በመቶዎች የሚቆጠሩ መዝሙራትን ወይም የአባላት መረጃዎችን በአንድ ጊዜ ከExcel ፋይል ወደ መተግበሪያው ዳታቤዝ ለማስገባት የሚያገለግል ፈጣን የውሂብ ማስገቢያ ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/import',
                'required_permission' => 'mezmurs.create',
                'tour_id' => null,
                'icon' => 'upload_file_rounded',
                'sort_order' => 40,
                'steps' => json_encode([
                    ['title' => 'የተዘጋጀውን ቴምፕሌት ማውረድ', 'description' => 'ትክክለኛውን የExcel ቅጽ ያውርዱ።', 'tip' => 'ቴምፕሌቱን ይጠቀሙ።'],
                    ['title' => 'መረጃውን ሞልቶ መስቀል', 'description' => 'መረጃውን በትክክለኛው አምድ ሞልተው ፋይሉን ይስቀሉ።', 'tip' => 'አምዶቹን አይቀይሩ።'],
                    ['title' => 'ስህተቶችን መመርመር', 'description' => 'ስርዓቱ ስህተት ያለባቸውን መስመሮች ሲያሳይ አርመው ያጽድቁ።', 'tip' => 'ስህተቶችን ያስተካክሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ፋይሉን ከመስቀልዎ በፊት የአምዶችን ስም አለመቀየርዎን ያረጋግጡ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የተደገሙ መረጃዎች ካሉ ስርዓቱ ምን ያደርጋል?', 'a' => 'የተደገሙ ስልኮች ወይም መታወቂያዎች ካሉ ስርዓቱ አስጠንቅቆ እንዳይገቡ ያግዳል ወይም ያዘምናል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 41. Admin Program Categories
            [
                'slug' => 'admin-program-categories',
                'category' => 'admin',
                'title' => 'የመርሐ ግብር ምድቦች (Program Categories)',
                'summary' => 'የሰንበት ት/ቤት መርሐ ግብራትን አይነቶች (ልምምድ፣ ጉባኤ፣ ውይይት) ማስተዳደር።',
                'content' => "መርሐ ግብሮችን በዓይነታቸው ለመከፋፈል (የመዝሙር ልምምድ፣ የትምህርት ክፍለ-ጊዜ፣ የጠቅላላ ጉባኤ፣ የጾም ጸሎት) የሚያገለግሉ ምድቦችን ለመፍጠር ይጠቅማል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/program-categories',
                'required_permission' => 'program_categories.manage',
                'tour_id' => null,
                'icon' => 'event_note_rounded',
                'sort_order' => 41,
                'steps' => json_encode([
                    ['title' => 'ምድብ መፍጠር', 'description' => 'የምድቡን ስም እና መለያ ቀለም ይምረጡ።', 'tip' => 'ቀለም ይምረጡ።'],
                    ['title' => 'ደንብ ማያያዝ', 'description' => 'ለዚህ ምድብ ተስማሚ የሆነውን የአቴንዳንስ ህግ ይወስኑ።', 'tip' => 'ደንቡን ይወስኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ቀለሞችን መለየት አባላት በመቁጠሪያ ገጻቸው ላይ መርሐ ግብሩን በቀላሉ እንዲለዩት ይረዳል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ምድብ ሲጠፋ የተፈጠሩት መርሐ ግብራት ይጠፋሉ?', 'a' => 'አይጠፉም፤ ወደ ነባሪው ምድብ ይዘዋወራሉ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 42. Admin Announcements & Banner Ads
            [
                'slug' => 'admin-ads',
                'category' => 'admin',
                'title' => 'የማስታወቂያዎች አስተዳደር (Announcements & Banner Ads)',
                'summary' => 'በመተግበሪያው ገጾች ላይ የሚታዩ መንፈሳዊ ማስታወቂያዎችን እና ባነሮችን ማዘጋጀት።',
                'content' => "አስፈላጊ የቤተክርስቲያን ጥሪዎችን፣ የበዓላት ማስታወቂያዎችን እና ልዩ ዝግጅቶችን በመተግበሪያው መነሻ ገጽ ላይ በባነር መልኩ ለማሳየት የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/ads',
                'required_permission' => 'ads.manage',
                'tour_id' => null,
                'icon' => 'campaign_rounded',
                'sort_order' => 42,
                'steps' => json_encode([
                    ['title' => 'ማስታወቂያ መፍጠር', 'description' => 'ርዕስ፣ ምስል እና የሚቆይበትን የቀን ወሰን ያስገቡ።', 'tip' => 'ቀን ይወስኑ።'],
                    ['title' => 'የሚከፈት ገጽ ማያያዝ', 'description' => 'ተጠቃሚው ሲጫነው የሚከፈተውን ገጽ ወይም ሊንክ ያያይዙ።', 'tip' => 'ሊንክ ያያይዙ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ምስሎች ጥራት ያላቸው እና መጠናቸው አነስተኛ መሆናቸውን ያረጋግጡ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የማስታወቂያው ጊዜ ሲያበቃ ምን ይሆናል?', 'a' => 'የቀን ገደቡ ሲያበቃ ማስታወቂያው በራስ-ሰር ከመነሻ ገጽ ላይ ይወርዳል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 43. Admin Static Pages
            [
                'slug' => 'admin-pages',
                'category' => 'admin',
                'title' => 'የገጾች እና መመሪያዎች አስተዳደር (Static Pages & Guidelines)',
                'summary' => 'የሰንበት ት/ቤቱን ታሪክ፣ ደንቦች፣ የአገልግሎት መመሪያዎች እና መረጃዎችን ማረም።',
                'content' => "በመተግበሪያው ውስጥ የሚታዩትን ቋሚ ገጾች (ስለ ሰንበት ት/ቤቱ፣ ደንብ እና መመሪያ፣ የክፍላት የስራ ድርሻ) ለመጻፍ እና ይዘታቸውን ለማዘመን የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/pages',
                'required_permission' => 'pages.manage',
                'tour_id' => null,
                'icon' => 'article_rounded',
                'sort_order' => 43,
                'steps' => json_encode([
                    ['title' => 'ገጽ መምረጥ', 'description' => 'የሚፈልጉትን ገጽ ይክፈቱ።', 'tip' => 'ገጹን ይምረጡ።'],
                    ['title' => 'ጽሑፉን ማረም', 'description' => 'ይዘቱን አዘምነው ለተጠቃሚዎች ይፋ ያድርጉ።', 'tip' => 'ይዘቱን ያዘምኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'አስፈላጊ ለውጦች ሲደረጉ ለአባላት ማሳወቂያ መላክ ይመረጣል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አዲስ ገጽ መጨመር ይቻላል?', 'a' => 'አዎ፤ አዳዲስ ገጾችን ፈጥሮ በቅንብሮች ወይም በመረጃ ዝርዝር ውስጥ ማካተት ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 44. Projects Tasks
            [
                'slug' => 'projects-my-tasks',
                'category' => 'admin',
                'title' => 'የፕሮጀክት ተግባራት (Project Tasks & Milestones)',
                'summary' => 'ለአገልግሎት ክፍላት እና ለአባላት የተሰጡ ተግባራትን መከታተል እና ማጠናቀቅ።',
                'content' => "የሰንበት ት/ቤት ፕሮጀክቶችን እና የልማት ስራዎችን በተግባር ከፋፍሎ ለመምራት፣ የፈጻሚዎችን ስም ለመመደብ፣ የማብቂያ ቀን ለመስጠት እና የእድገት ደረጃቸውን ለመከታተል ይጠቅማል።",
                'target_role' => 'admin',
                'target_screen' => '/projects/my-tasks',
                'required_permission' => 'projects.view',
                'tour_id' => null,
                'icon' => 'task_alt_rounded',
                'sort_order' => 44,
                'steps' => json_encode([
                    ['title' => 'ተግባር መመደብ', 'description' => 'የስራውን ዝርዝር፣ ኃላፊውን እና የማጠናቀቂያ ቀኑን ያስገቡ።', 'tip' => 'ቀን ይወስኑ።'],
                    ['title' => 'ሁኔታውን ማዘመን', 'description' => 'ተግባሩ ሲጀመር «በሂደት ላይ»፣ ሲያልቅ «ተጠናቋል» በማለት ምልክት ያድርጉ።', 'tip' => 'ሁኔታውን ያዘምኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የማጠናቀቂያ ቀኑ ሲቃረብ ለኃላፊው ማስታወሻ ይላካል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አባላት ተግባራቸውን የየት ያዩታል?', 'a' => 'በመተግበሪያው የፕሮጀክት ገጽ ውስጥ «የእኔ ተግባራት» ስር ያገኙታል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 45. Projects Approvals
            [
                'slug' => 'projects-approvals',
                'category' => 'admin',
                'title' => 'የወጪ እና በጀት ማጽደቂያዎች (Project Expense Approvals)',
                'summary' => 'ለፕሮጀክቶች እና ለክፍላት የተጠየቁ የወጪ ጥያቄዎችን መርምሮ ማጽደቅ።',
                'content' => "ለሰንበት ት/ቤት ስራዎች እና ፕሮጀክቶች የሚወጡ ወጪዎችን ለመቆጣጠር፣ ደረሰኞችን ለመመርመር እና የበጀት ክፍያን በፋይናንስ ኃላፊዎች ለማጽደቅ የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/projects/approvals',
                'required_permission' => 'projects.expenses.approve',
                'tour_id' => null,
                'icon' => 'fact_check_rounded',
                'sort_order' => 45,
                'steps' => json_encode([
                    ['title' => 'የወጪ ጥያቄውን መክፈት', 'description' => 'የተጠየቀውን የገንዘብ መጠን፣ ምክንያት እና የተያያዘውን ደረሰኝ ይመልከቱ።', 'tip' => 'ደረሰኙን ያረጋግጡ።'],
                    ['title' => 'ውሳኔ መስጠት', 'description' => 'በጀቱ የሚፈቅድ ከሆነ ያጽድቁ፤ ካልሆነ ምክንያቱን ጽፈው ይመልሱ።', 'tip' => 'ውሳኔ ይስጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ያለ ደረሰኝ የቀረቡ ጥያቄዎችን አለማጽደቅ ይመረጣል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የጸደቁ ወጪዎች በፋይናንስ ሪፖርት ውስጥ ይካተታሉ?', 'a' => 'አዎ፤ ወዲያውኑ በፕሮጀክቱ የወጪ መዝገብ እና በጠቅላላ የበጀት ሪፖርት ውስጥ ይመዘገባሉ።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 46. Admin Admins Management
            [
                'slug' => 'admin-admins',
                'category' => 'admin',
                'title' => 'የአስተዳዳሪዎች አስተዳደር (Staff Administrators)',
                'summary' => 'የስርዓት አስተዳዳሪዎችን መሾም፣ ሚናዎችን መስጠት እና የስራ ድርሻቸውን ማስተካከል።',
                'content' => "የሰንበት ት/ቤት አገልጋዮችን እና ኃላፊዎችን የስርዓት አስተዳዳሪ አድርጎ ለመሾም፣ የአስተዳዳሪነት ደረጃ ለመስጠት እና ስራቸውን ሲጨርሱ ፈቃዳቸውን ለመሰረዝ የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/admins',
                'required_permission' => 'admins.view',
                'tour_id' => null,
                'icon' => 'admin_panel_settings_rounded',
                'sort_order' => 46,
                'steps' => json_encode([
                    ['title' => 'አዲስ አስተዳዳሪ መመደብ', 'description' => 'አባሉን መርጠው የአስተዳዳሪ ሚና ይስጡ።', 'tip' => 'ሚናውን ይምረጡ።'],
                    ['title' => 'ፈቃዶችን ማረጋገጥ', 'description' => 'የሚሰጣቸውን የስራ ክፍል ፈቃዶች በጥንቃቄ ይምረጡ።', 'tip' => 'ፈቃዶችን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'ለእያንዳንዱ አስተዳዳሪ ለስራው የሚያስፈልገውን ፈቃድ ብቻ ይስጡ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የአስተዳዳሪነት ፈቃድ ወዲያውኑ ይሰራል?', 'a' => 'አዎ፤ አባሉ መተግበሪያውን እንደገና ሲከፍት የአስተዳዳሪ ካርዶቹ ይታዩታል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 47. Admin Roles & Permissions
            [
                'slug' => 'admin-roles',
                'category' => 'admin',
                'title' => 'ሚናዎች እና ፈቃዶች (Roles & Permissions Matrix)',
                'summary' => 'የስራ ሚናዎችን መፍጠር እና ለእያንዳንዱ ሚና ዝርዝር ፈቃዶችን መወሰን።',
                'content' => "በመተግበሪያው ውስጥ ያሉ የአስተዳዳሪ ሚናዎችን ለመፍጠር እና ለእያንዳንዱ ሚና የሚፈቀዱትን እና የሚከለከሉትን ድርጊቶች በዝርዝር ለመወሰን ያገለግላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/roles',
                'required_permission' => 'admins.view',
                'tour_id' => null,
                'icon' => 'security_rounded',
                'sort_order' => 47,
                'steps' => json_encode([
                    ['title' => 'ሚና መፍጠር ወይም መምረጥ', 'description' => 'የሚናውን ስም ያስገቡ።', 'tip' => 'ስሙን ይጻፉ።'],
                    ['title' => 'ፈቃዶችን መምረጥ', 'description' => 'ለሚናው የሚገቡትን ፈቃዶች በቼክቦክስ ይምረጡ።', 'tip' => 'ፈቃዶቹን ይምረጡ።'],
                    ['title' => 'ማስቀመጥ', 'description' => 'ለውጡን በቋሚነት ያጽድቁ።', 'tip' => 'አስቀምጥ ይጫኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የሱፐር አድሚን ሚና ሁሉንም ፈቃዶች በራስ-ሰር ይይዛል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የአንድ ሚና ፈቃድ ሲቀየር በዚያ ሚና ስር ያሉ ሰዎች ወዲያውኑ ይነካሉ?', 'a' => 'አዎ፤ በሚቀጥለው መግቢያቸው ላይ አዲሱ ፈቃድ ተፈጻሚ ይሆናል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 48. Admin System Settings & Modules
            [
                'slug' => 'admin-settings',
                'category' => 'admin',
                'title' => 'የስርዓት ቅንብሮች እና ሞጁሎች (System Settings & Modules)',
                'summary' => 'የመተግበሪያውን አጠቃላይ ቅንብሮች፣ የትምህርት እና መዝሙር ሞጁል መቆጣጠሪያዎችን ማስተዳደር።',
                'content' => "የሰንበት ት/ቤቱን አጠቃላይ የስርዓት መለኪያዎች ለመቆጣጠር ይጠቅማል። የትምህርት እና የመዝሙር ሞጁሎችን ለማብራት ወይም ለማጥፋት ያስችላል። አንድ ሞጁል ሲጠፋ መረጃው ሳይሰረዝ በሰላም ይቀመጣል፤ ለተጠቃሚዎች ግን እንዳይታይ ይታገዳል። አንዱ ብቻ ሲበራ ስርዓቱ ተጠቃሚውን በቀጥታ ወደዚያው ሞጁል ያሸጋግረዋል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/settings',
                'required_permission' => 'settings.manage',
                'tour_id' => null,
                'icon' => 'settings_suggest_rounded',
                'sort_order' => 48,
                'steps' => json_encode([
                    ['title' => 'የሞጁል ማብሪያ/ማጥፊያዎችን መቆጣጠር', 'description' => 'የትምህርት ወይም የመዝሙር አገልግሎትን እንደ አስፈላጊነቱ ያብሩ/ያጥፉ።', 'tip' => 'ሞጁሎችን ይቆጣጠሩ።'],
                    ['title' => 'የስርዓት መለኪያዎችን ማስተካከል', 'description' => 'የቀን መቁጠሪያ፣ የአባልነት መለያ ፎርማት እና የደወል ደንቦችን ይወስኑ።', 'tip' => 'መለኪያዎችን ያዘምኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የድብቁ ከፍተኛ ተቆጣጣሪ እና የሱፐር አድሚን ልዩነት እንደተጠበቀ ይቆያል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ሞጁል ሲጠፋ የቀድሞ መረጃ ይጠፋል?', 'a' => 'በፍጹም አይጠፋም፤ ሞጁሉ እንደገና ሲበራ ሁሉም መረጃ እንዳለ ይመለሳል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 49. Admin Releases
            [
                'slug' => 'admin-releases',
                'category' => 'admin',
                'title' => 'የመተግበሪያ እትሞች (App Releases & Updates)',
                'summary' => 'አዳዲስ የመተግበሪያ እትሞችን መመዝገብ እና የግዴታ ማደሻ መወሰን።',
                'content' => "አዲስ የመተግበሪያ እትም ሲዘጋጅ ለአባላት የማሻሻያ ማስታወቂያ ለመላክ፣ የለውጥ ዝርዝሮችን ለማስቀመጥ እና አሮጌ ስሪት ያላቸው አባላት እንዲያድሱ የግዴታ ማደሻ ለማብራት ያገለግላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/releases',
                'required_permission' => 'releases.manage',
                'tour_id' => null,
                'icon' => 'system_update_rounded',
                'sort_order' => 49,
                'steps' => json_encode([
                    ['title' => 'አዲስ እትም መመዝገብ', 'description' => 'የስሪት ቁጥር Version Code/Name እና የለውጥ ማስታወሻ ያስገቡ።', 'tip' => 'ስሪቱን ይግለጹ።'],
                    ['title' => 'የግዴታ ማደሻ መወሰን', 'description' => 'አሮጌው ስሪት እንዳይሰራ መከልከል ካስፈለገ Force Update ያብሩ።', 'tip' => 'አስፈላጊ ከሆነ ያብሩ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'አስፈላጊ የደህንነት ማሻሻያዎች ሲኖሩ የግዴታ ማደሻን ይጠቀሙ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ተጠቃሚዎች ማሻሻያውን እንዴት ያገኛሉ?', 'a' => 'መተግበሪያውን ሲከፍቱ አዲስ ስሪት መኖሩን የሚገልጽ መስኮት ወዲያውኑ ይመጣላቸዋል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 50. Admin Manage Guidance
            [
                'slug' => 'admin-guidance',
                'category' => 'admin',
                'title' => 'የመመሪያዎች አስተዳደር (Manage In-App Guidance)',
                'summary' => 'የመመሪያ ማዕከል ጽሑፎችን፣ የእርምጃዎችን ቅደም ተከተል እና አጋዥ ጥያቄዎችን ማረም።',
                'content' => "አስተዳዳሪዎች በመመሪያ ማዕከል ውስጥ የሚታዩትን ጽሑፎች፣ የእርምጃ መመሪያዎች፣ ጠቃሚ ምክሮች እና ተደጋጋሚ ጥያቄዎችን በቀላሉ ለማረም፣ ለማደራጀት እና ይፋ ለማድረግ የሚያገለግል ክፍል ነው። ትክክለኛ ያልሆኑ የስክሪን መዳረሻዎች እንዳይገቡ ያረጋግጣል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/guidance',
                'required_permission' => 'guidance.manage',
                'tour_id' => null,
                'icon' => 'help_center_rounded',
                'sort_order' => 50,
                'steps' => json_encode([
                    ['title' => 'መመሪያ መምረጥ ወይም ማከል', 'description' => 'የሚፈልጉትን የገጽ መመሪያ ይክፈቱ።', 'tip' => 'መመሪያ ይምረጡ።'],
                    ['title' => 'ጽሑፉን እና እርምጃዎችን ማረም', 'description' => 'ርዕስ፣ ማብራሪያ፣ ቅደም ተከተል እና ጥያቄዎችን ያዘምኑ።', 'tip' => 'ይዘቱን ያዘምኑ።'],
                    ['title' => 'መዳረሻዎችን ማረጋገጥ', 'description' => 'የስክሪን አድራሻው ትክክለኛ መሆኑን አረጋግጠው ይለጥፉ።', 'tip' => 'መዳረሻውን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የአስተዳዳሪ ብቻ የሆኑ መመሪያዎች ለተራ አባላት እንዳይታዩ የTarget Role እና የፈቃድ ገደብ ይስጡ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የተሰረዘ መመሪያ ወደ ነበረበት መመለስ ይቻላል?', 'a' => 'አዎ፤ መመሪያዎችን በረቂቅ መልክ ማስቀመጥ ወይም ነባሩን ማደስ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 51. Admin Audit Trail
            [
                'slug' => 'admin-audit',
                'category' => 'admin',
                'title' => 'የስርዓት ኦዲት ሎግ (System Audit Trail)',
                'summary' => 'በስርዓቱ ውስጥ የተከናወኑ ወሳኝ የአስተዳደር ድርጊቶችን፣ ለውጦችን እና ስረዛዎችን መመርመር።',
                'content' => "በመተግበሪያው ውስጥ የተከናወኑ ሁሉንም የአስተዳደር ስራዎች ማን፣ መቼ እና ከየትኛው መሳሪያ እንደሰራው በማያጠራጥር መልኩ የተመዘገበበት የደህንነት እና የኦዲት መዝገብ ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/audit',
                'required_permission' => 'audit_logs.view',
                'tour_id' => null,
                'icon' => 'history_rounded',
                'sort_order' => 51,
                'steps' => json_encode([
                    ['title' => 'ድርጊቶችን ማጣራት', 'description' => 'በቀን፣ በሰራው ሰው ስም ወይም በድርጊቱ አይነት ይፈልጉ።', 'tip' => 'በቀን ያጣሩ።'],
                    ['title' => 'ዝርዝሩን መመርመር', 'description' => 'ከለውጡ በፊት እና በኋላ የነበረውን መረጃ ያነጻጽሩ።', 'tip' => 'ልዩነቱን ያነጻጽሩ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የኦዲት ሎግ መረጃዎች በማንም ሰው ሊሰረዙ ወይም ሊለወጡ አይችሉም።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የኦዲት መዝገብ ለምን ያህል ጊዜ ይቆያል?', 'a' => 'ለደህንነት እና ለህጋዊ ተጠያቂነት በቋሚነት በስርዓቱ ውስጥ ተቀምጦ ይኖራል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 52. Admin User Activity Logs
            [
                'slug' => 'admin-activity',
                'category' => 'admin',
                'title' => 'የተጠቃሚዎች እንቅስቃሴ ሎግ (User Activity Logs)',
                'summary' => 'የአባላት የመተግበሪያ አጠቃቀም፣ የመግቢያ ሰዓታት እና የመስመር ውጭ ስራዎች ክትትል።',
                'content' => "አባላት መተግበሪያውን መቼ እንደከፈቱት፣ ምን መዝሙራት እንዳዳመጡ፣ ከመስመር ውጭ የሰሯቸውን ስራዎች እና መረጃዎችን መቼ እንዳመሳሰሉ የሚያሳይ የአጠቃቀም ክትትል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/activity',
                'required_permission' => 'activity_logs.view',
                'tour_id' => null,
                'icon' => 'insights_rounded',
                'sort_order' => 52,
                'steps' => json_encode([
                    ['title' => 'እንቅስቃሴዎችን መመልከት', 'description' => 'የቅርብ ጊዜ የተጠቃሚዎች መግቢያ እና ክንውን ይመልከቱ።', 'tip' => 'መግቢያዎችን ይመልከቱ።'],
                    ['title' => 'የማመሳሰል (Sync) ሁኔታን ማረጋገጥ', 'description' => 'ከመስመር ውጭ የተመዘገቡ መረጃዎች በሰላም መግባታቸውን ይከታተሉ።', 'tip' => 'ማመሳሰልን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የተጠቃሚዎችን ግላዊነት የሚነኩ ሚስጥራዊ መረጃዎች እዚህ አይመዘገቡም።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ከመስመር ውጭ የተደረጉ እንቅስቃሴዎች መቼ ይገባሉ?', 'a' => 'ስልኩ ኢንተርኔት ባገኘ ቅጽበት ከመስመር ውጭ የነበረው እንቅስቃሴ ተመሳስሎ ይገባል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 53. Admin Dashboard Overview
            [
                'slug' => 'admin-dashboard',
                'category' => 'admin',
                'title' => 'የአስተዳዳሪ ማዕከል (Admin Dashboard)',
                'summary' => 'የአስተዳዳሪዎች ዋና መቆጣጠሪያ ማዕከል፣ የፈቃድ መረጃ እና ሞጁሎች።',
                'content' => "የሰንበት ት/ቤት አስተዳዳሪዎች እንደተሰጣቸው ሚና እና ፈቃድ አባላትን፣ መርሐ ግብሮችን፣ ክፍያዎችን፣ አቴንዳንስን እና ሪፖርቶችን የሚያስተዳድሩበት ዋና ማዕከል ነው። እያንዳንዱ ካርድ የተመደበለትን አገልግሎት ይወክላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin',
                'required_permission' => null,
                'tour_id' => 'admin_tour',
                'icon' => 'shield_rounded',
                'sort_order' => 53,
                'steps' => json_encode([
                    ['title' => 'የሞጁል ካርዶችን መክፈት (Access Modules)', 'description' => 'የተፈቀደልዎትን ማንኛውንም የስራ ክፍል ካርድ በመጫን በቀጥታ ወደ ስራው ገጽ ይግቡ።', 'tip' => 'ካርዱን ይጫኑ።'],
                    ['title' => 'የእገዛ አዶን መጠቀም (Contextual Help)', 'description' => 'በእያንዳንዱ ካርድ የላይኛው ቀኝ ጥግ ላይ ያለውን የጥያቄ ምልክት (?) በመጫን የዚያን አገልግሎት ዝርዝር መመሪያ ያግኙ።', 'tip' => 'የጥያቄ ምልክቱን ይጫኑ።'],
                    ['title' => 'ማስጠንቀቂያዎችን መከታተል (Pending Alerts)', 'description' => 'የቀረቡ የፈቃድ ጥያቄዎችን እና የአቴንዳንስ ማስታወሻዎችን ከላይ ባሉት ካርዶች ይከታተሉ።', 'tip' => 'ማስታወሻዎችን ይከታተሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የማይፈቀድልዎ ካርድ በገጹ ላይ አይታይም፤ አዲስ ፈቃድ ካስፈለገዎት ለዋና አስተዳዳሪው ያመልክቱ።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'አንዳንድ ካርዶች ለምን አይታዩኝም? (Why are some cards hidden?)', 'a' => 'ካርዶች የሚታዩት ለተጠቃሚው በተሰጠው ፈቃድ (Permissions) መሰረት ብቻ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 54. Admin Attendance Hub
            [
                'slug' => 'admin-attendance-hub',
                'category' => 'attendance',
                'title' => 'የአቴንዳንስ አስተዳደር (Attendance Management)',
                'summary' => 'የአባላት እና ተማሪዎች የመገኘት ክትትል፣ የQR ቅኝት፣ ሰዓታት እና ማረጋገጫዎች።',
                'content' => "በመርሐ ግብሮች እና በትምህርት ክፍሎች ወቅት የአባላትን እና የተማሪዎችን መገኘት ለመመዝገብ፣ በQR ስካነር ለማረጋገጥ፣ የአቴንዳንስ ደንቦችን ለማውጣት እና የቀረቡ የእርማት ጥያቄዎችን ለመመርመር የሚያገለግል ክፍል ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/attendance',
                'required_permission' => 'attendance.manage',
                'tour_id' => null,
                'icon' => 'qr_code_scanner_rounded',
                'sort_order' => 54,
                'steps' => json_encode([
                    ['title' => 'መርሐ ግብር መምረጥ (Select Program)', 'description' => 'የቀኑን መርሐ ግብር በመምረጥ የአቴንዳንስ መዝገቡን ይክፈቱ።', 'tip' => 'መርሐ ግብር ይምረጡ።'],
                    ['title' => 'በQR ወይም በእጅ መመዝገብ (Mark Attendance)', 'description' => 'የአባላትን ዲጂታል መታወቂያ በካሜራ በመቃኘት ወይም ከዝርዝር ውስጥ በመፈለግ የመገኘት ሁኔታቸውን ያጽድቁ።', 'tip' => 'QR ይቃኙ።'],
                    ['title' => 'መዝገቡን መዝጋት (Finalize Attendance)', 'description' => 'የመገኘት ሰዓቱ ሲጠናቀቅ መዝገቡን በመቆለፍ ይፋዊ ያድርጉ።', 'tip' => 'መዝገቡን ቆልፉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የአቴንዳንስ ሰዓት ገደብ ሲያልፍ መዝገቡ በራስ-ሰር ይዘጋል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'በስህተት የቀረ ተብሎ የተመዘገበ አባል እንዴት ይስተካከላል? (How to correct attendance?)', 'a' => 'አባሉ የመገኘት እርማት ጥያቄ (Attendance Correction Request) ሲያቀርብ አስተዳዳሪው መርምሮ ሊያስተካክል ይችላል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 55. Education: student requests, complaints, academic journey
            [
                'slug' => 'edu-self-service',
                'category' => 'education',
                'title' => 'ጥያቄዎች፣ ቅሬታዎች እና የትምህርት ጉዞ (Requests, Complaints & Journey)',
                'summary' => 'የክፍል፣ የዘርፍ ወይም የትምህርት ዓይነት ለውጥ መጠየቅ፣ ትምህርት መጨመር/መተው፣ ሚስጥራዊ ቅሬታ ማቅረብ እና የትምህርት ታሪክን ማየት።',
                'content' => "ጥያቄዎ ከቀረበ በኋላ የትምህርት ክፍሉ ኃላፊ ያጸድቀዋል ወይም ውድቅ ያደርገዋል። ሲጸድቅ ለውጡ በምዝገባዎ ላይ ወዲያውኑ ይተገበራል። ቅሬታዎ ሚስጥራዊ ነው፤ የመለያ ቁጥር ይሰጥዎታል። የትምህርት ጉዞ ምዝገባ፣ ለውጦች እና የታተሙ ውጤቶችን በቅደም ተከተል ያሳያል።",
                'target_role' => 'member',
                'target_screen' => '/edu/services',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'assignment_ind_outlined',
                'sort_order' => 55,
                'steps' => json_encode([
                    ['title' => 'አዲስ ጥያቄ (New request)', 'description' => 'የጥያቄውን ዓይነት፣ ክፍሉን እና ምክንያቱን ይምረጡ፤ «አስገባ» ይጫኑ።', 'tip' => 'ምክንያቱን በግልጽ ይጻፉ።'],
                    ['title' => 'ቅሬታ ማቅረብ (File a complaint)', 'description' => 'ዓይነቱን ይምረጡ፣ ጉዳዩን ይግለጹ፣ ካለ ማስረጃ ያያይዙ። የሚሰጥዎትን መለያ ቁጥር ይያዙ።', 'tip' => 'የመለያ ቁጥሩን ያስቀምጡ።'],
                    ['title' => 'የትምህርት ጉዞ (Journey)', 'description' => 'ምዝገባዎ፣ ለውጦች እና የታተሙ ውጤቶች በቅደም ተከተል ይታያሉ።', 'tip' => 'ታሪክዎን ይመልከቱ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'በአንድ ጉዳይ ላይ በአንድ ጊዜ አንድ ጥያቄ ብቻ መጠባበቅ ይችላል።',
                    'ውጤትን የሚመለከት ቅሬታ ውጤቱን በራሱ አይቀይርም፤ ግምገማ ያስጀምራል።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'ውጤቴ ለምን «በሂደት ላይ» ይላል?', 'a' => 'ውጤቶች የሚታዩት በትምህርት ክፍሉ ጸድቀው ከታተሙ በኋላ ብቻ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 56. Education administrators: review center
            [
                'slug' => 'edu-review-center',
                'category' => 'education',
                'title' => 'የትምህርት ግምገማ ማዕከል (Education Review Center)',
                'summary' => 'መምህራን ያቀረቧቸውን ውጤቶች ማጽደቅ/መመለስ/ማተም፣ የተማሪ ጥያቄዎችን መወሰን፣ ቅሬታዎችን መመርመር እና የውጤት ሪፖርት ማውጣት።',
                'content' => "ውጤቶች፦ ረቂቅ → ለማጽደቅ ማቅረብ → ማጽደቅ ወይም መመለስ (ምክንያት ግዴታ) → ማተም። ያቀረቡትን ውጤት ራስዎ ማጽደቅ አይችሉም። የታተመ ውጤት የሚስተካከለው በምክንያት በሚደረግ ማስተካከያ ብቻ ነው። ጥያቄ ሲጸድቅ ለውጡ በምዝገባው ላይ ይተገበራል።",
                'target_role' => 'admin',
                'target_screen' => '/edu/review',
                'required_permission' => 'education.manage',
                'tour_id' => null,
                'icon' => 'fact_check_outlined',
                'sort_order' => 56,
                'steps' => json_encode([
                    ['title' => 'ውጤቶችን መገምገም (Review marks)', 'description' => '«ለማጽደቅ ቀርቧል» ውስጥ ፈተናውን ይክፈቱ፤ «አጽድቅ እና አትም» ወይም «ውድቅ አድርግ» ይጫኑ።', 'tip' => 'ሲመልሱ ምክንያት ይጻፉ።'],
                    ['title' => 'ጥያቄዎችን መወሰን (Decide requests)', 'description' => 'በጥያቄዎች ገጽ ላይ ያጽድቁ ወይም በምክንያት ውድቅ ያድርጉ።', 'tip' => 'ሲጸድቅ ለውጡ ይተገበራል።'],
                    ['title' => 'ሪፖርት (Export)', 'description' => 'ከላይ ያለውን የማውረጃ ምልክት ይጫኑ፤ ክፍል፣ ትምህርቶች እና አቀማመጥ ይምረጡ (CSV / Excel / PDF)።', 'tip' => 'ብዙ ትምህርቶችን በአንድ ሪፖርት ይምረጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode([
                    'የውስጥ ማስታወሻዎች ለተማሪው አይታዩም።',
                    'በሪፖርት ውስጥ ያልገባ ውጤት «—» ሆኖ ይታያል፤ 0 አይደለም።',
                ], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([
                    ['q' => 'የታተመ ውጤት እንዴት ይስተካከላል?', 'a' => 'በውጤት መመዝገቢያ ገጹ ላይ ከውጤቱ አጠገብ ያለውን የማስተካከያ ምልክት ይጫኑ፤ ምክንያት ግዴታ ነው፤ ታሪኩ ይቀመጣል።'],
                ], JSON_UNESCAPED_UNICODE),
            ],

            // 57. Class Assignment & Rosters
            [
                'slug' => 'class-assignment',
                'category' => 'education',
                'title' => 'የተማሪዎች ክፍል ምደባ (Class Assignment & Rosters)',
                'summary' => 'ተማሪዎችን በሰንበት ት/ቤት ክፍሎች መመደብ፣ ማዛወር እና የክፍል መዝገብ ማስተዳደር።',
                'content' => "ተማሪዎችን በየዕድሜያቸው እና የትምህርት ደረጃቸው መሠረት በተገቢው ክፍል ይመድቡ። የተማሪውን የክፍል ታሪክ (Journey) ለመጠበቅ ዝውውሮች በምክንያት ይመዘገባሉ።",
                'target_role' => 'admin',
                'target_screen' => '/admin/edu/assignments',
                'required_permission' => 'education.manage',
                'tour_id' => null,
                'icon' => 'group_add_rounded',
                'sort_order' => 57,
                'steps' => json_encode([
                    ['title' => 'ክፍል መምረጥ', 'description' => 'ከተዘረዘሩት ክፍሎች ተማሪዎችን ሊመድቡበት የሚፈልጉትን ይክፈቱ።', 'tip' => 'የክፍሉን የተማሪዎች ብዛት ይመልከቱ።'],
                    ['title' => 'ተማሪዎችን መመደብ', 'description' => '«ተማሪዎችን መድብ»ን በመጫን ያልተመደቡ ተማሪዎችን ይምረጡ።', 'tip' => 'በአንድ ጊዜ ብዙ ተማሪዎችን መምረጥ ይቻላል።'],
                    ['title' => 'ማዛወር', 'description' => 'ተማሪን ወደ ሌላ ክፍል ሲያዛውሩ የዝውውር ምክንያት በማስገባት ታሪኩን ይጠብቁ።', 'tip' => 'ዝውውሩ በትምህርት ጉዞ ላይ ይመዘገባል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['በአንድ ጊዜ በአንድ ንቁ ክፍል ብቻ መመደብ ይቻላል።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'የተማሪ ታሪክ ይጠፋል?', 'a' => 'አይጠፋም፤ በየትምህርት ጉዞ (Journey) ላይ ተመዝግቦ ይቀመጣል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 58. Academic Calendar Admin
            [
                'slug' => 'academic-calendar-admin',
                'category' => 'education',
                'title' => 'የትምህርት ዘመን እና ወሰነ-ትምህርት (Academic Calendar Admin)',
                'summary' => 'የትምህርት ዘመናትን፣ ወሰነ-ትምህርቶችን (Terms) እና ደረጃዎችን መፍጠር እና ማስተዳደር።',
                'content' => "የትምህርት ዘመን የኢትዮጵያ ዓመተ ምሕረትን መሠረት በማድረግ ይከፈታል። በአንድ ጊዜ አንድ ንቁ የትምህርት ዘመን ብቻ ይኖራል። ዓመቱ ሲዘጋ ክፍት ውጤቶች አለመኖራቸው ይረጋገጣል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/edu/academic-years',
                'required_permission' => 'education.manage',
                'tour_id' => null,
                'icon' => 'calendar_month_rounded',
                'sort_order' => 58,
                'steps' => json_encode([
                    ['title' => 'አዲስ የትምህርት ዘመን', 'description' => 'የኢትዮጵያ ዓ.ም እና ስያሜውን በማስገባት ይጀምሩ።', 'tip' => 'ዓ.ም ተደጋግሞ አይገባም።'],
                    ['title' => 'ወሰነ-ትምህርቶች (Terms)', 'description' => 'በዘመኑ ሥር ያሉ የትምህርት ወቅቶችን ይወስኑ።', 'tip' => 'ቀኖቹ እንዳይደራረቡ ይጠንቀቁ።'],
                    ['title' => 'ዘመን መዝጋት', 'description' => 'ዓመታዊ የትምህርት ሥራዎች ሲጠናቀቁ ዘመኑን ይዝጉ።', 'tip' => 'ያልታተሙ ውጤቶች መኖራቸው ይፈተሻል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['አንድ ንቁ ዘመን ብቻ ይኖራል።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ዘመን መዝጋት ለምን ተከለከለ?', 'a' => 'ያልተጠናቀቁ ወይም ያልታተሙ ውጤቶች ካሉ አይዘጋም።']], JSON_UNESCAPED_UNICODE),
            ],

            // 59. Academic Calendar Student
            [
                'slug' => 'academic-calendar-student',
                'category' => 'education',
                'title' => 'የትምህርት ቀን መቁጠሪያ (Academic Calendar)',
                'summary' => 'የትምህርት ዘመኑን፣ ወቅታዊ ወሰነ-ትምህርት እና የትምህርት መርሐ ግብሮችን መመልከት።',
                'content' => "በዚህ ገጽ ላይ የትምህርት ቀናትን፣ የፈተና ወቅቶችን እና የዕረፍት ቀናትን መከታተል ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/edu/calendar',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'date_range_rounded',
                'sort_order' => 59,
                'steps' => json_encode([
                    ['title' => 'ወቅታዊ ዘመን', 'description' => 'አሁን በሥራ ላይ ያለውን የትምህርት ዘመን ይመልከቱ።', 'tip' => 'ወቅታዊው ዘመን በምልክት ይታያል።'],
                    ['title' => 'መርሐ ግብሮች', 'description' => 'የክፍልዎ እና የትምህርት ቀኖችን በቀን መቁጠሪያው ላይ ይከታተሉ።', 'tip' => 'የፈተና ቀናት ተለይተው ይታያሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['የፈተና ቀናት በቀን መቁጠሪያው ላይ በደማቅ ምልክት ይታያሉ።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ቀን መቁጠሪያው ከመስመር ውጭ ይሰራል?', 'a' => 'አዎ! ያለ ኢንተርኔት ይታያል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 60. Class-Linked Programs
            [
                'slug' => 'class-linked-programs',
                'category' => 'education',
                'title' => 'ከክፍል ጋር የተሳሰሩ መርሐ ግብሮች (Class-Linked Programs)',
                'summary' => 'መርሐ ግብሮችን በቀጥታ ከሰንበት ት/ቤት ክፍሎች ጋር ማስተሳሰር።',
                'content' => "መርሐ ግብር ከክፍል ጋር ሲተሳሰር፣ የተማሪዎች አቴንዳንስ በቀጥታ በትምህርት መዝገባቸው ውስጥ ይካተታል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/edu/programs',
                'required_permission' => 'education.manage',
                'tour_id' => null,
                'icon' => 'link_rounded',
                'sort_order' => 60,
                'steps' => json_encode([
                    ['title' => 'መርሐ ግብር መምረጥ', 'description' => 'ከክፍል ጋር የሚገናኘውን መርሐ ግብር ይክፈቱ።', 'tip' => 'መደበኛ የትምህርት ክፍለ ጊዜዎችን ይምረጡ።'],
                    ['title' => 'ክፍል ማስተሳሰር', 'description' => 'መርሐ ግብሩ የሚመለከተውን የትምህርት ክፍል ይምረጡ።', 'tip' => 'የተሳሰሩ ክፍሎች ብቻ በአቴንዳንስ ይካተታሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ከክፍል ውጭ ያሉ አባላት በክፍል አቴንዳንስ ውስጥ አይካተቱም።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'አቴንዳንሱ የት ይመዘገባል?', 'a' => 'በቀጥታ በትምህርት ክትትል ውስጥ ይቀመጣል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 61. Selection Intervals
            [
                'slug' => 'selection-intervals',
                'category' => 'choir',
                'title' => 'የመረጣ ጊዜያት እና የአቴንዳንስ ነጥቦች (Selection Intervals & Attendance Rules)',
                'summary' => 'የበዓላት መዘምራን መረጣ የአቴንዳንስ ጊዜያት እና የነጥብ አሰላል ደንቦችን ማስተካከል (D2/D3/D5)።',
                'content' => "በዓላትን መሠረት ያደረገ የመዘምራን መረጣ የአቴንዳንስ ማነፃፀሪያ ጊዜያትን ይወስኑ። ክፍተቶችን እና መደራረቦችን የሚያስወግድ የሕግ ማረጋገጫ ተካቷል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/selections/intervals',
                'required_permission' => 'selection.configure',
                'tour_id' => null,
                'icon' => 'tune_rounded',
                'sort_order' => 61,
                'steps' => json_encode([
                    ['title' => 'የመረጣ ውቅር', 'description' => 'የመረጣውን ስም እና የክትትል የጊዜ ወሰን ይወስኑ።', 'tip' => 'የወር ክልልን በጥንቃቄ ይምረጡ።'],
                    ['title' => 'የነጥብ ደንቦች', 'description' => 'በተገኘባቸው ቀናት ብዛት መሠረት የሚሰጠውን ነጥብ ይተምኑ።', 'tip' => 'ክፍተቶች እና መደራረቦች አይፈቀዱም።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ደንቦቹ ከ1 ጀምረው ያለ ክፍተት መቀጠል አለባቸው።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'የነጥብ ስሌቱ እንዴት ይከናወናል?', 'a' => 'በተቀመጠው የጊዜ ወሰን ውስጥ ባለው የተሳትፎ ቀናት መሠረት ይሰላል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 62. Offline Sync Status
            [
                'slug' => 'offline-status',
                'category' => 'system',
                'title' => 'ከመስመር ውጭ አሠራር እና ማመሳሰል (Offline Sync Status)',
                'summary' => 'ያለ ኢንተርኔት የተከናወኑ ተግባራትን ሁኔታ እና ከዋናው ሰርቨር ጋር ማመሳሰልን መከታተል።',
                'content' => "ኢንተርኔት በማይኖርበት ጊዜ የተመዘገቡ አቴንዳንሶች፣ የቤተ-መጽሐፍት ውሰቶች እና የትምህርት ሂደቶች በስልክዎ ይቀመጣሉ፤ ኢንተርኔት ሲገኝ በራስ-ሰር ይላካሉ።",
                'target_role' => 'all',
                'target_screen' => '/offline-status',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'sync_rounded',
                'sort_order' => 62,
                'steps' => json_encode([
                    ['title' => 'የወረፋ ሁኔታ', 'description' => 'ያልተመሳሰሉ የተግባራት ብዛት ይመልከቱ።', 'tip' => 'የቀሩ ተግባራት በቁጥር ይታያሉ።'],
                    ['title' => 'በእጅ ማመሳሰል', 'description' => '«አሁን አመሳስል»ን በመጫን ወዲያውኑ ወደ ሰርቨር ይላኩ።', 'tip' => 'ኢንተርኔት መኖሩን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ከመውጣትዎ (Logout) በፊት ያልተላኩ ተግባራት መኖራቸውን ያረጋግጡ።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ያልተመሳሰለ መረጃ በስልክ ይቀመጣል?', 'a' => 'አዎ! በደህንነት በስልክዎ ውስጥ ተቀምጦ ይቆያል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 63. Assignments
            [
                'slug' => 'edu-assignments',
                'category' => 'education',
                'title' => 'የቤት ሥራዎች እና ምደባዎች (Assignments)',
                'summary' => 'የተሰጡ የቤት ሥራዎችን መመልከት፣ ፋይሎችን ማስገባት እና የማሻሻያ ታሪክን መከታተል።',
                'content' => "መምህራን የሚሰጧቸውን የቤት ሥራዎች በተሰጠው የጊዜ ገደብ ውስጥ ያስገቡ። የተሻሻለ ፋይል ማስገባት ሲፈቀድ ቀደምት ስሪቶች በታሪክ ይቀመጣሉ።",
                'target_role' => 'all',
                'target_screen' => '/edu/assignments',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'assignment_rounded',
                'sort_order' => 63,
                'steps' => json_encode([
                    ['title' => 'ሥራዎችን መመልከት', 'description' => 'ክፍት የሆኑ እና የጊዜ ገደባቸው ያልደረሱ ሥራዎችን ይምረጡ።', 'tip' => 'የማስረከቢያ ቀኑን ልብ ይበሉ።'],
                    ['title' => 'ፋይል መስቀል', 'description' => 'የተዘጋጀውን ፋይል ይስቀሉ እና አስገባ የሚለውን ይጫኑ።', 'tip' => 'PDF ወይም ምስል መሆኑን ያረጋግጡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ከቀነ-ገደብ በኋላ የሚገቡ ሥራዎች እንደ ዘግይተው ይመዘገባሉ።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'የገባውን ሥራ መቀየር ይቻላል?', 'a' => 'መምህሩ ማሻሻል ከፈቀደ አዲስ ስሪት ማስገባት ይቻላል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 64. Academic Results
            [
                'slug' => 'edu-results',
                'category' => 'education',
                'title' => 'የትምህርት ውጤቶች እና ግምገማ (Academic Results)',
                'summary' => 'የፈተና፣ የቤት ሥራ እና የጥያቄዎች ይፋዊ ውጤቶችን በክብደት መቶኛ መመልከት።',
                'content' => "በትምህርት ክፍሉ ጸድቀው የታተሙ ውጤቶች ብቻ ይታያሉ። እያንዳንዱ ውጤት የፈተናውን ክብደት፣ ያገኙትን ነጥብ እና የማለፍ ሁኔታን ያሳያል።",
                'target_role' => 'all',
                'target_screen' => '/edu/results',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'grade_rounded',
                'sort_order' => 64,
                'steps' => json_encode([
                    ['title' => 'የኮርስ ውጤቶች', 'description' => 'የወሰዷቸውን ትምህርቶች አጠቃላይ ውጤት ይከታተሉ።', 'tip' => 'የማለፊያ መቶኛ 50% ነው።'],
                    ['title' => 'ዝርዝር ነጥብ', 'description' => 'የእያንዳንዱን ምዘና ዝርዝር ውጤት ይመርምሩ።', 'tip' => 'የፈተና እና የቤት ሥራ ክብደቶች ተለይተው ይታያሉ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ያልታተሙ ውጤቶች ለተማሪዎች አይታዩም።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ውጤቴ ለምን አልታየም?', 'a' => 'ውጤቱ ገና በመምህሩ ወይም በትምህርት ክፍሉ አልታተመም።']], JSON_UNESCAPED_UNICODE),
            ],

            // 65. Retake Requests
            [
                'slug' => 'edu-retakes',
                'category' => 'education',
                'title' => 'የድጋሚ ፈተና ጥያቄዎች (Exam Retake Requests)',
                'summary' => 'ላላለፉባቸው ፈተናዎች ወይም ውጤት ለማሻሻል የድጋሚ ፈተና ጥያቄ ማቅረብ።',
                'content' => "ተማሪዎች ባልተሳካላቸው ፈተናዎች ላይ በደንቡ መሠረት የድጋሚ ፈተና ማመልከት ይችላሉ። ጥያቄው ሲጸድቅ ፈተናውን እንደገና መውሰድ ይቻላል።",
                'target_role' => 'all',
                'target_screen' => '/edu/retakes',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'replay_rounded',
                'sort_order' => 65,
                'steps' => json_encode([
                    ['title' => 'ጥያቄ ማቅረብ', 'description' => 'ድጋሚ ሊፈተኑበት የሚፈልጉትን ትምህርት እና ፈተና ይምረጡ።', 'tip' => 'ምክንያትዎን በግልጽ ያስቀምጡ።'],
                    ['title' => 'ውሳኔ መከታተል', 'description' => 'በትምህርት አስተዳዳሪው የጸደቀውን ውሳኔ ይመልከቱ።', 'tip' => 'ሲጸድቅ ፈተናው ይከፈታል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['የድጋሚ ፈተና ውጤት በቀድሞው ውጤት ላይ የበላይነት ይኖረዋል።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ስንት ጊዜ መጠየቅ ይቻላል?', 'a' => 'በትምህርት ክፍሉ በተፈቀደው የድጋሚ ፈተና ገደብ መሠረት።']], JSON_UNESCAPED_UNICODE),
            ],

            // 66. Exams & Assessments
            [
                'slug' => 'edu-exams',
                'category' => 'education',
                'title' => 'የፈተና ጥያቄዎች እና ምዘና (Exams & Assessments)',
                'summary' => 'ኦንላይን ፈተናዎችን መውሰድ፣ የጥያቄ ባንክ እና የማለፊያ ነጥቦችን ማወቅ።',
                'content' => "ፈተናዎች በተሰጣቸው የጊዜ ገደብ ውስጥ ይወሰዳሉ። የጥያቄ ባንክ ጥያቄዎችን በዘፈቀደ በማውጣት ፍትሐዊ ምዘናን ያረጋግጣል።",
                'target_role' => 'all',
                'target_screen' => '/edu/exams',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'quiz_rounded',
                'sort_order' => 66,
                'steps' => json_encode([
                    ['title' => 'ፈተና መጀመር', 'description' => 'የተፈቀደውን ፈተና በመክፈት መመሪያዎችን ያንብቡ።', 'tip' => 'የፈተናው ሰዓት ቆጣሪ መጀመሩን ያረጋግጡ።'],
                    ['title' => 'ጥያቄዎችን መመለስ', 'description' => 'በተሰጠው ሰዓት ውስጥ መልሶችን መርጠው ያጠናቅቁ።', 'tip' => 'ሰዓቱ ከማለቁ በፊት «አስገባ»ን ይጫኑ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ፈተናው ከተጀመረ በኋላ ማቋረጥ አይቻልም።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'መልሶቼ ተቀምጠዋል?', 'a' => 'አዎ! እያንዳንዱ መልስ ወዲያውኑ ይመዘገባል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 67. Student Certificates
            [
                'slug' => 'edu-certificates',
                'category' => 'education',
                'title' => 'የትምህርት ማስረጃዎች (My Certificates)',
                'summary' => 'ያጠናቀቋቸውን ኮርሶች ዲጂታል ሰርተፊኬቶች መመልከት፣ ማውረድ እና በQR ማረጋገጥ።',
                'content' => "ኮርሱን በተሳካ ሁኔታ ላጠናቀቁ ተማሪዎች የሚሰጡ ሰርተፊኬቶች በዲጂታል ፊርማ እና በ10 ዲጂት ማረጋገጫ ኮድ የተጠበቁ ናቸው።",
                'target_role' => 'all',
                'target_screen' => '/edu/certificates',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'workspace_premium_rounded',
                'sort_order' => 67,
                'steps' => json_encode([
                    ['title' => 'ሰርተፊኬት መክፈት', 'description' => 'ከተሰጡት ማስረጃዎች መካከል የሚፈልጉትን ይክፈቱ።', 'tip' => 'የማረጋገጫ ኮዱን ያረጋግጡ።'],
                    ['title' => 'PDF ማውረድ', 'description' => 'በከፍተኛ ጥራት የተዘጋጀውን ሰርተፊኬት በPDF ያውርዱ ወይም ያጋሩ።', 'tip' => 'የወረደውን ሰነድ በቀጥታ ማተም ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['በሰርተፊኬቱ ላይ ያለው QR ኮድ በማንኛውም ሰው ሊረጋገጥ ይችላል።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ሰርተፊኬት መቼ ይሰጣል?', 'a' => 'ትምህርቱን 100% አጠናቀው ውጤትዎ ሲጸድቅ።']], JSON_UNESCAPED_UNICODE),
            ],

            // 68. Certificate Issuance & Admin
            [
                'slug' => 'admin-edu-certificates',
                'category' => 'education',
                'title' => 'የሰርተፊኬት አሰጣጥ እና ቁጥጥር (Certificate Issuance & Management)',
                'summary' => 'መስፈርቱን ላሟሉ ተማሪዎች ሰርተፊኬት ማመንጨት፣ መሻር እና ድጋሚ ማውጣት።',
                'content' => "ያለፉ እና ትምህርቱን 100% ያጠናቀቁ ተማሪዎችን መርምረው ሰርተፊኬት ይስጡ። በስህተት የወጣ ሰርተፊኬት በምክንያት ተሽሮ በምትኩ አዲስ ሊሰጥ ይችላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/edu/certificates',
                'required_permission' => 'education.certify',
                'tour_id' => null,
                'icon' => 'verified_rounded',
                'sort_order' => 68,
                'steps' => json_encode([
                    ['title' => 'ብቁ ተማሪዎችን መለየት', 'description' => 'የማለፊያ መስፈርቱን ያሟሉ ተማሪዎችን ዝርዝር ይክፈቱ።', 'tip' => 'ብቁ ያልሆኑት በዝርዝሩ ውስጥ አይገቡም።'],
                    ['title' => 'ሰርተፊኬት ማመንጨት', 'description' => 'በኢትዮጵያ ዓ.ም ተከታታይ ቁጥር ያለው ሰርተፊኬት ያትሙ።', 'tip' => 'MH-{eth_year}-{number} ቅርጸት ይጠበቃል።'],
                    ['title' => 'መሻር/ማስተካከል', 'description' => 'አስፈላጊ ሲሆን የነበረውን በመሻር የተስተካከለ ይስጡ።', 'tip' => 'የመሻሪያ ምክንያት ግዴታ ነው።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['የተሻሩ ሰርተፊኬቶች በኦንላይን ማረጋገጫ ገጹ ላይ «ተሽሯል» ተብለው ይታያሉ።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'የተሻረ ሰርተፊኬት እንደገና ይሰራል?', 'a' => 'አይሰራም፤ የተተካበት አዲሱ ሰርተፊኬት ብቻ ይጸድቃል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 69. Digital Library & Narration
            [
                'slug' => 'library-books',
                'category' => 'library',
                'title' => 'ዲጂታል ቤተ-መጽሐፍት እና ትረካ (Digital Library & Narration)',
                'summary' => 'መንፈሳዊ መጻሕፍትን በPDF ማንበብ፣ ተወዳጆች ውስጥ ማስቀመጥ እና የድምጽ ትረካ ማዳመጥ።',
                'content' => "በምድብ የተከፋፈሉ መጻሕፍትን በገጽ ማስታወሻ ያንብቡ፤ ፈልገው ያግኙ። ትረካ ያላቸውን መጻሕፍት ስልኩ ተዘግቶም ከበስተጀርባ ማዳመጥ ይችላሉ።",
                'target_role' => 'all',
                'target_screen' => '/library/books',
                'required_permission' => null,
                'tour_id' => null,
                'icon' => 'menu_book_rounded',
                'sort_order' => 69,
                'steps' => json_encode([
                    ['title' => 'መጽሐፍ መምረጥ', 'description' => 'ከምድቦች ወይም ከተወዳጆች ዝርዝር መጽሐፉን ይክፈቱ።', 'tip' => 'የምድብ ማጣሪያዎችን ይጠቀሙ።'],
                    ['title' => 'ንባብ እና ገጽ ፍለጋ', 'description' => 'ባቆሙበት ገጽ ላይ ንባብዎን ይቀጥሉ፤ ቃላትን ይፈልጉ።', 'tip' => 'ገጹ በራስ-ሰር ይቀመጣል።'],
                    ['title' => 'ትረካ ማዳመጥ', 'description' => 'የድምጽ ማጫወቻውን በማስጀመር ትረካውን ያዳምጡ።', 'tip' => 'ስልኩ ተዘግቶም ማዳመጥ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['የወረዱ መጻሕፍት ያለ ኢንተርኔት በደህንነት ይከፈታሉ።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ባቆምኩበት ገጽ ይቀመጣል?', 'a' => 'አዎ! በመስመር ላይም ሆነ ከመስመር ውጭ ባቆሙበት ገጽ ይከፈታል።']], JSON_UNESCAPED_UNICODE),
            ],

            // 70. Sunday School Library Circulation
            [
                'slug' => 'library-circulation',
                'category' => 'library',
                'title' => 'የሰንበት ት/ቤት ቤተ-መጽሐፍት ውሰት (Library Circulation & Loans)',
                'summary' => 'የታተሙ መጻሕፍትን በተለየ ኮድ ማበደር፣ የውሰት ፊርማ መቀበል እና መመለስ።',
                'content' => "እያንዳንዱ የመጽሐፍ ቅጅ የማይለወጥ የቅጅ ኮድ (LIB-...) አለው። መጽሐፍ ሲበደር የተውሰው አባል በስክሪኑ ላይ ይፈርማል። አንድ መጽሐፍ ለሁለት ሰው እንዳይሰጥ በሰርቨር የተጠበቀ ነው።",
                'target_role' => 'admin',
                'target_screen' => '/admin/library/circulation',
                'required_permission' => 'library.circulate',
                'tour_id' => null,
                'icon' => 'local_library_rounded',
                'sort_order' => 70,
                'steps' => json_encode([
                    ['title' => 'ኮድ መፈለግ/መቃኘት', 'description' => 'የመጽሐፉን የቅጅ ኮድ በማስገባት ዝግጁነቱን ያረጋግጡ።', 'tip' => 'LIB-... መለያውን ያስገቡ።'],
                    ['title' => 'ተበዳሪ እና ፊርማ', 'description' => 'አባሉን ከመረጡ በኋላ በስክሪኑ ላይ ፊርማቸውን ያስቀምጡ።', 'tip' => 'የተበዳሪው ፊርማ ግዴታ ነው።'],
                    ['title' => 'መመለስ', 'description' => 'መጽሐፉ ሲመለስ የያዘበትን ሁኔታ መርምረው መዝገቡን ይዝጉ።', 'tip' => 'የመጽሐፉን ሁኔታ (Condition) ይመዝግቡ።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['የተበደረ መጽሐፍ ሳይመለስ ለሌላ ሰው ማበደር አይቻልም።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ከንብረት ውሰት ጋር ይቀላቀላል?', 'a' => 'አይቀላቀልም፤ የቤተ-መጽሐፍት ውሰት ራሱን የቻለ የተለየ አሠራር ነው።']], JSON_UNESCAPED_UNICODE),
            ],

            // 71. Education Scores & Activity
            [
                'slug' => 'admin-edu-scores',
                'category' => 'education',
                'title' => 'የትምህርት ውጤት እና የተሳትፎ ነጥቦች (Education Academic & Engagement Scores)',
                'summary' => 'የተማሪዎችን የትምህርት ውጤት እና የተሳትፎ ነጥብ በD8 ቀመር መሠረት መመርመር እና ሪፖርት ማውጣት።',
                'content' => "የአካዳሚክ ነጥብ እና የተሳትፎ ነጥብ ተለይተው ይሰላሉ። ተማሪው ሊደርስባቸው የማይችላቸው ትምህርቶች ነጥቡን እንዳይቀንሱ ይደረጋል። ውጤቶችን በPDF, Excel እና CSV ማውጣት ይቻላል።",
                'target_role' => 'admin',
                'target_screen' => '/admin/edu/scores',
                'required_permission' => 'education.reports',
                'tour_id' => null,
                'icon' => 'analytics_rounded',
                'sort_order' => 71,
                'steps' => json_encode([
                    ['title' => 'ወቅት እና ክፍል መምረጥ', 'description' => 'የሚመረመረውን የትምህርት ዘመን፣ ወሰነ-ትምህርት እና ክፍል ይምረጡ።', 'tip' => 'የክፍሉን የተማሪዎች ነጥብ ይመልከቱ።'],
                    ['title' => 'የነጥብ ዝርዝር', 'description' => 'በተማሪው ረድፍ ላይ በመጫን የነጥቡን ስሌት ማብራሪያ ይመልከቱ።', 'tip' => 'የፈተና እና የተሳትፎ ዝርዝር ይታያል።'],
                    ['title' => 'ሪፖርት ማውጣት', 'description' => 'በማውረጃ አዝራሩ አማካኝነት ዝርዝር ሪፖርት ያመንጩ።', 'tip' => 'በPDF፣ Excel ወይም CSV ማውረድ ይቻላል።'],
                ], JSON_UNESCAPED_UNICODE),
                'tips' => json_encode(['ውጤቱ በD8 ቀመር የተማሪዎችን እውነተኛ ተሳትፎ ያንፀባርቃል።'], JSON_UNESCAPED_UNICODE),
                'faq_items' => json_encode([['q' => 'ነጥቦቹ ለተማሪዎች ይታያሉ?', 'a' => 'አይታዩም፤ የተማሪዎች የደረጃ ዝርዝር ለአስተዳዳሪዎች ብቻ የተጠበቀ ነው።']], JSON_UNESCAPED_UNICODE),
            ],
        ];

        $now = date('Y-m-d H:i:s');
        DB::table('guidance_articles')->where('slug', 'library-and-property')->delete();
        foreach ($articles as $a) {
            $existing = DB::table('guidance_articles')->where('slug', $a['slug'])->first();
            if ($existing) {
                DB::table('guidance_articles')->where('slug', $a['slug'])->update(array_merge($a, [
                    'updated_at' => $now,
                ]));
            } else {
                DB::table('guidance_articles')->insert(array_merge($a, [
                    'status' => 'published',
                    'created_at' => $now,
                    'updated_at' => $now,
                ]));
            }
        }
    }
}
