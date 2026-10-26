import paramiko
import sys
if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect('hersolan.pro', port=22, username='hersolot', password=r'v:89]yYLi:7t7O0E)0*')

php_code = """<?php
require 'vendor/autoload.php';
$app = require_once 'bootstrap/app.php';
$app->make('Illuminate\\Contracts\\Console\\Kernel')->bootstrap();

use Illuminate\\Support\\Facades\\DB;

DB::beginTransaction();

try {
    // 1. Categories configuration
    $categoriesConfig = [
        [
            'id' => 1,
            'name' => 'ትምህርተ ሃይማኖት',
            'name_en' => 'Theology & Doctrine',
            'description' => 'ስለ እግዚአብሔር አንድነትና ሦስትነት፣ ስለ አምስቱ አዕማደ ምሥጢር የሚማሩበት',
            'icon_key' => 'church',
            'sort_order' => 1,
            'status' => 'active',
            'prefix' => 'TH',
        ],
        [
            'id' => 4,
            'name' => 'የመጽሐፍ ቅዱስ ጥናት',
            'name_en' => 'Bible Study',
            'description' => 'ብሉይና ሐዲስ ኪዳን፣ መጻሕፍተ ብሉያትና ሐዲሳት ጥናት',
            'icon_key' => 'censer',
            'sort_order' => 2,
            'status' => 'active',
            'prefix' => 'BS',
        ],
        [
            'id' => 5,
            'name' => 'ክርስቲያናዊ ሥነምግባር',
            'name_en' => 'Christian Ethics',
            'description' => 'የክርስቲያን አኗኗር፣ ምግባርና ማኅበራዊ ሕይወት',
            'icon_key' => 'fasting',
            'sort_order' => 3,
            'status' => 'active',
            'prefix' => 'CE',
        ],
        [
            'id' => 6,
            'name' => 'ሥርዓተ ቤተ ክርስቲያን',
            'name_en' => 'Church Order & Rites',
            'description' => 'የቤተ ክርስቲያን ሥርዓት፣ አምልኮና ሰባቱ ምሥጢራት',
            'icon_key' => 'censer',
            'sort_order' => 4,
            'status' => 'active',
            'prefix' => 'CO',
        ],
        [
            'id' => 3,
            'name' => 'የቤተክርስትያን ታሪክ',
            'name_en' => 'Church History',
            'description' => 'የኢትዮጵያና የዓለም አብያተ ክርስቲያናት ታሪክ',
            'icon_key' => 'cross',
            'sort_order' => 5,
            'status' => 'active',
            'prefix' => 'CH',
        ],
        [
            'id' => 7,
            'name' => 'ልሳነ ግእዝ',
            'name_en' => 'Geez Language',
            'description' => 'የግእዝ ቋንቋ ሰዋስው፣ ንባብና የዜማ ምልክቶች',
            'icon_key' => 'school',
            'sort_order' => 6,
            'status' => 'active',
            'prefix' => 'GZ',
        ],
        [
            'id' => 8,
            'name' => 'ዜማ',
            'name_en' => 'Zema (Sacred Chants)',
            'description' => 'የቅዱስ ያሬድ ዜማ፣ ጾመ ድጓ፣ ዝማሬና ማሕሌት',
            'icon_key' => 'monk',
            'sort_order' => 7,
            'status' => 'active',
            'prefix' => 'ZM',
        ],
    ];

    // Archive all other categories
    $catIds = array_column($categoriesConfig, 'id');
    DB::table('edu_categories')->whereNotIn('id', $catIds)->update(['status' => 'archived']);

    // Upsert the 7 canonical categories
    foreach ($categoriesConfig as $c) {
        $prefix = $c['prefix'];
        unset($c['prefix']);
        $existing = DB::table('edu_categories')->where('id', $c['id'])->first();
        if ($existing) {
            DB::table('edu_categories')->where('id', $c['id'])->update($c);
        } else {
            DB::table('edu_categories')->insert($c);
        }
    }

    // 2. Map existing subjects to Grade 7 of each category (since existing classes are 7ኛ and 6ኛ)
    // Existing subjects: ID 1 -> TH Grade 7, ID 3 -> CH Grade 7, ID 4 -> BS Grade 7, ID 5 -> CE Grade 7, ID 6 -> CO Grade 7, ID 7 -> GZ Grade 7, ID 8 -> ZM Grade 7
    $existingMap = [
        1 => ['cat_id' => 1, 'grade' => 7, 'prefix' => 'TH'],
        2 => ['cat_id' => 1, 'grade' => 6, 'prefix' => 'TH'], // Course 7 was class 2 (6ኛ ክፍል)
        3 => ['cat_id' => 3, 'grade' => 7, 'prefix' => 'CH'],
        4 => ['cat_id' => 4, 'grade' => 7, 'prefix' => 'BS'],
        5 => ['cat_id' => 5, 'grade' => 7, 'prefix' => 'CE'],
        6 => ['cat_id' => 6, 'grade' => 7, 'prefix' => 'CO'],
        7 => ['cat_id' => 7, 'grade' => 7, 'prefix' => 'GZ'],
        8 => ['cat_id' => 8, 'grade' => 7, 'prefix' => 'ZM'],
    ];

    foreach ($existingMap as $subId => $info) {
        $g = $info['grade'];
        $catId = $info['cat_id'];
        $prefix = $info['prefix'];
        $code = sprintf("%s-G%02d", $prefix, $g);

        DB::table('edu_subjects')->where('id', $subId)->update([
            'category_id' => $catId,
            'name' => "{$g}ኛ ክፍል",
            'name_en' => "Grade {$g}",
            'code' => $code,
            'description' => "{$g}ኛ ክፍል የትምህርት ካሪኩለም",
            'visibility' => 'members',
            'status' => 'published',
            'sort_order' => $g,
        ]);
    }

    // Update Course 7 (which is for 6ኛ ክፍል) to point to Subject ID 2 (which is now Grade 6 under Category 1)
    DB::table('edu_courses')->where('id', 7)->update(['subject_id' => 2]);

    // 3. For each category, ensure grades 1 to 12 exist
    foreach ($categoriesConfig as $cat) {
        $catId = $cat['id'];
        $prefix = $cat['prefix'];

        for ($g = 1; $g <= 12; $g++) {
            $code = sprintf("%s-G%02d", $prefix, $g);
            // Check if a subject for this category and grade already exists
            $exists = DB::table('edu_subjects')
                ->where('category_id', $catId)
                ->where('sort_order', $g)
                ->first();

            if (! $exists) {
                DB::table('edu_subjects')->insert([
                    'category_id' => $catId,
                    'name' => "{$g}ኛ ክፍል",
                    'name_en' => "Grade {$g}",
                    'code' => $code,
                    'description' => "{$g}ኛ ክፍል የትምህርት ካሪኩለም",
                    'visibility' => 'members',
                    'sequential' => 0,
                    'status' => 'published',
                    'sort_order' => $g,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }
        }
    }

    DB::commit();
    echo "SUCCESS: Categories and grade subjects migrated successfully!\\n";

    // Summary count
    $catCount = DB::table('edu_categories')->where('status', 'active')->count();
    $subCount = DB::table('edu_subjects')->where('status', 'published')->count();
    echo "Active Categories: $catCount\\n";
    echo "Published Grade Subjects: $subCount\\n";

} catch (\\Exception $e) {
    DB::rollBack();
    echo "ERROR: " . $e->getMessage() . "\\n";
}
"""

cmd = f"""cd /home/hersolot/app.hersolan.pro && php << 'EOF'
{php_code}
EOF
"""
stdin, stdout, stderr = ssh.exec_command(cmd)
out = stdout.read().decode('utf-8', errors='replace')
print(out)
ssh.close()
