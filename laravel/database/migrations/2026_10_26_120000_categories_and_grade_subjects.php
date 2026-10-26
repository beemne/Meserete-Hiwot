<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration {
    public function up(): void
    {
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

        // Archive non-canonical categories
        $catIds = array_column($categoriesConfig, 'id');
        DB::table('edu_categories')->whereNotIn('id', $catIds)->update(['status' => 'archived']);

        // Upsert canonical categories
        foreach ($categoriesConfig as $c) {
            unset($c['prefix']);
            $existing = DB::table('edu_categories')->where('id', $c['id'])->first();
            if ($existing) {
                DB::table('edu_categories')->where('id', $c['id'])->update($c);
            } else {
                DB::table('edu_categories')->insert($c);
            }
        }

        // Map existing subjects to Grade 7 of each category
        $existingMap = [
            1 => ['cat_id' => 1, 'grade' => 7, 'prefix' => 'TH'],
            2 => ['cat_id' => 1, 'grade' => 6, 'prefix' => 'TH'],
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
            $code = sprintf('%s-G%02d', $prefix, $g);

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

        // Link Course 7 to Subject 2 (Grade 6 under Category 1)
        DB::table('edu_courses')->where('id', 7)->update(['subject_id' => 2]);

        // Ensure 12 grades per category exist
        foreach ($categoriesConfig as $cat) {
            $catId = $cat['id'];
            $prefix = $cat['prefix'] ?? 'ED';

            for ($g = 1; $g <= 12; $g++) {
                $code = sprintf('%s-G%02d', $prefix, $g);
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
    }

    public function down(): void
    {
    }
};
