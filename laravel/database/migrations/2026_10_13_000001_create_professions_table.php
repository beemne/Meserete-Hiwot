<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasTable('professions')) {
            Schema::create('professions', function (Blueprint $table) {
                $table->increments('id');
                $table->string('category', 100)->index();
                $table->string('name', 150);
                $table->boolean('is_active')->default(true)->index();
                $table->integer('sort_order')->default(0);
                $table->timestamps();

                $table->unique(['category', 'name']);
            });
        }

        if (Schema::hasTable('member_profiles')) {
            if (! Schema::hasColumn('member_profiles', 'profession_id')) {
                Schema::table('member_profiles', function (Blueprint $table) {
                    $table->unsignedInteger('profession_id')->nullable()->after('employer_type')->index();
                });
            }
            if (! Schema::hasColumn('member_profiles', 'profession_category')) {
                Schema::table('member_profiles', function (Blueprint $table) {
                    $table->string('profession_category', 100)->nullable()->after('profession_id')->index();
                });
            }
            if (! Schema::hasColumn('member_profiles', 'profession_other')) {
                Schema::table('member_profiles', function (Blueprint $table) {
                    $table->string('profession_other', 255)->nullable()->after('profession');
                });
            }
        }

        // Seed initial standard church community professions
        $seeds = [
            'ቴክኖሎጂ እና ኢንጂነሪንግ (Technology & Engineering)' => [
                'የሶፍትዌር ኢንጂነር (Software Engineer)',
                'የኢንፎርሜሽን ቴክኖሎጂ ባለሙያ (IT Specialist)',
                'የኮምፒውተር ሳይንቲስት (Computer Scientist)',
                'የሲቪል ኢንጂነር (Civil Engineer)',
                'የኤሌክትሪካል ኢንጂነር (Electrical Engineer)',
                'የመካኒካል ኢንጂነር (Mechanical Engineer)',
                'አርክቴክት (Architect)',
                'የኔትወርክ ባለሙያ (Network Engineer)',
            ],
            'ጤና እና ሕክምና (Health & Medicine)' => [
                'ሐኪም / ሜዲካል ዶክተር (Medical Doctor)',
                'ነርስ (Nurse)',
                'ፋርማሲስት (Pharmacist)',
                'የላብራቶሪ ባለሙያ (Lab Technician)',
                'የሕዝብ ጤና ባለሙያ (Public Health Officer)',
                'የጥርስ ሐኪም (Dentist)',
                'የማኅበረሰብ ጤና ረዳት (Health Extension Worker)',
            ],
            'ትምህርት እና አካዳሚክ (Education & Academia)' => [
                'የመጀመሪያ/ሁለተኛ ደረጃ መምህር (School Teacher)',
                'የዩኒቨርሲቲ/ኮሌጅ መምህር (University Lecturer)',
                'የትምህርት አመራር እና አስተዳደር (Education Administrator)',
                'ተመራማሪ (Academic Researcher)',
            ],
            'ንግድ እና ፋይናንስ (Business & Finance)' => [
                'አካውንታንት / የሒሳብ ባለሙያ (Accountant)',
                'የባንክ ባለሙያ (Banker)',
                'ኢኮኖሚስት (Economist)',
                'ኦዲተር (Auditor)',
                'የንግድ ስራ አስኪያጅ (Business Manager)',
                'ነጋዴ / ስራ ፈጣሪ (Business Owner / Entrepreneur)',
                'የግብይት ባለሙያ (Marketing Specialist)',
            ],
            'ሕግ እና አስተዳደር (Law & Governance)' => [
                'ጠበቃ (Lawyer / Attorney)',
                'ዳኛ (Judge)',
                'የሕግ አማካሪ (Legal Advisor)',
                'የሕዝብ አስተዳደር ባለሙያ (Public Administrator)',
            ],
            'እደ-ጥበብ እና ቴክኒክ (Trades & Craftsmanship)' => [
                'የኤሌክትሪክ ቴክኒሻን (Electrician)',
                'የቧንቧ ሰራተኛ (Plumber)',
                'የግንባታ ባለሙያ (Builder / Mason)',
                'አናፂ (Carpenter)',
                'ሾፌር (Driver)',
                'ስፌት እና ዲዛይን (Tailor / Designer)',
                'ፎቶግራፍ እና ቪዲዮ (Photographer / Videographer)',
            ],
            'ስነ-መለኮት እና መንፈሳዊ አገልግሎት (Theology & Clergy)' => [
                'ቀሲስ / ካህን (Priest)',
                'ዲያቆን (Deacon)',
                'የሰንበት ት/ቤት መምህር (Sunday School Teacher)',
                'የቤተክርስቲያን አገልጋይ (Church Minister)',
                'የዜማ / የመዝሙር መምህር (Hymn Instructor)',
            ],
            'ሌላ ሙያ (Other)' => [
                'ሌላ (Other)',
            ],
        ];

        $order = 1;
        $now = date('Y-m-d H:i:s');
        foreach ($seeds as $cat => $names) {
            foreach ($names as $name) {
                DB::table('professions')->insertOrIgnore([
                    'category' => $cat,
                    'name' => $name,
                    'is_active' => true,
                    'sort_order' => $order++,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }
    }

    public function down(): void
    {
        if (Schema::hasTable('member_profiles')) {
            Schema::table('member_profiles', function (Blueprint $table) {
                if (Schema::hasColumn('member_profiles', 'profession_other')) {
                    $table->dropColumn('profession_other');
                }
                if (Schema::hasColumn('member_profiles', 'profession_category')) {
                    $table->dropColumn('profession_category');
                }
                if (Schema::hasColumn('member_profiles', 'profession_id')) {
                    $table->dropColumn('profession_id');
                }
            });
        }
        Schema::dropIfExists('professions');
    }
};
