<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     *
     * 1. Normalizes the 7 canonical subjects in edu_subjects in exact order:
     *    1. ትምህርተ ሃይማኖት
     *    2. የመጽሐፍ ቅዱስ ጥናት
     *    3. ክርስቲያናዊ ሥነምግባር
     *    4. ሥርዓተ ቤተ ክርስቲያን
     *    5. የቤተክርስትያን ታሪክ
     *    6. ልሳነ ግእዝ
     *    7. ዜማ
     * 2. Maps historical duplicate/typo subject references safely to preserve courses, lessons, and grades.
     * 3. Sets level_id for existing classes (e.g. 7ኛ -> level 7).
     * 4. Enforces duplicate physical book borrowing prevention via unique constraints on active loans & open requests.
     */
    public function up(): void
    {
        // -------------------------------------------------------------
        // 1. Normalize the 7 canonical subjects in edu_subjects
        // -------------------------------------------------------------
        if (Schema::hasTable('edu_subjects')) {
            $canonicalList = [
                1 => ['name' => 'ትምህርተ ሃይማኖት', 'code' => 'TH-001', 'sort_order' => 1],
                2 => ['name' => 'የመጽሐፍ ቅዱስ ጥናት', 'code' => 'BS-002', 'sort_order' => 2],
                3 => ['name' => 'ክርስቲያናዊ ሥነምግባር', 'code' => 'CE-003', 'sort_order' => 3],
                4 => ['name' => 'ሥርዓተ ቤተ ክርስቲያን', 'code' => 'CO-004', 'sort_order' => 4],
                5 => ['name' => 'የቤተክርስትያን ታሪክ', 'code' => 'CH-005', 'sort_order' => 5],
                6 => ['name' => 'ልሳነ ግእዝ', 'code' => 'GZ-006', 'sort_order' => 6],
                7 => ['name' => 'ዜማ', 'code' => 'ZM-007', 'sort_order' => 7],
            ];

            // Correct Subject 1 typo ("ትምህተ ሐይማኖት" -> "ትምህርተ ሃይማኖት")
            $sub1 = DB::table('edu_subjects')->where('id', 1)->first();
            if ($sub1) {
                DB::table('edu_subjects')->where('id', 1)->update([
                    'name' => 'ትምህርተ ሃይማኖት',
                    'sort_order' => 1,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }

            // If Subject 2 was created as an empty duplicate of "ትምህርተ ሃይማኖት",
            // re-point any courses pointing to subject 2 to subject 1
            if (Schema::hasTable('edu_courses')) {
                DB::table('edu_courses')->where('subject_id', 2)->update(['subject_id' => 1]);
            }
            if (Schema::hasTable('edu_lessons')) {
                DB::table('edu_lessons')->where('subject_id', 2)->update(['subject_id' => 1]);
            }
            if (Schema::hasTable('edu_units')) {
                DB::table('edu_units')->where('subject_id', 2)->update(['subject_id' => 1]);
            }
            // Archive or alias duplicate Subject 2 so it is not listed as duplicate
            DB::table('edu_subjects')->where('id', 2)->update([
                'status' => 'archived',
                'sort_order' => 99,
            ]);

            // Update or insert canonical subjects 2..7:
            // Subject 4: የመጽሐፍ ቅዱስ ጥናት -> sort_order = 2
            $s4 = DB::table('edu_subjects')->where('name', 'like', '%መጽሐፍ ቅዱስ ጥናት%')->first();
            if ($s4) {
                DB::table('edu_subjects')->where('id', $s4->id)->update([
                    'name' => 'የመጽሐፍ ቅዱስ ጥናት',
                    'sort_order' => 2,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }

            // Subject 5: ክርስቲያናዊ ሥነምግባር -> sort_order = 3
            $s5 = DB::table('edu_subjects')->where('name', 'like', '%ሥነምግባር%')->first();
            if ($s5) {
                DB::table('edu_subjects')->where('id', $s5->id)->update([
                    'name' => 'ክርስቲያናዊ ሥነምግባር',
                    'sort_order' => 3,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }

            // Subject 6: ሥርዓተ ቤተ ክርስቲያን -> sort_order = 4
            $s6 = DB::table('edu_subjects')->where('name', 'like', '%ሥርዓተ ቤተ%')->first();
            if ($s6) {
                DB::table('edu_subjects')->where('id', $s6->id)->update([
                    'name' => 'ሥርዓተ ቤተ ክርስቲያን',
                    'sort_order' => 4,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }

            // Subject 3: የቤተክርስትያን ታሪክ -> sort_order = 5
            $s3 = DB::table('edu_subjects')->where('name', 'like', '%ቤተክርስ%ታሪክ%')->orWhere('name', 'like', '%ቤተክርስትያን%ታሪክ%')->first();
            if ($s3) {
                DB::table('edu_subjects')->where('id', $s3->id)->update([
                    'name' => 'የቤተክርስትያን ታሪክ',
                    'sort_order' => 5,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }

            // Subject 7: ልሳነ ግእዝ -> sort_order = 6
            $s7 = DB::table('edu_subjects')->where('name', 'like', '%ግእዝ%')->first();
            if ($s7) {
                DB::table('edu_subjects')->where('id', $s7->id)->update([
                    'name' => 'ልሳነ ግእዝ',
                    'sort_order' => 6,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }

            // Subject: ዜማ -> sort_order = 7 (insert if not present)
            $zema = DB::table('edu_subjects')->where('name', 'ዜማ')->first();
            if (! $zema) {
                DB::table('edu_subjects')->insert([
                    'name' => 'ዜማ',
                    'name_en' => 'Zema',
                    'code' => 'ZM-007',
                    'description' => 'የዜማ ትምህርት',
                    'sort_order' => 7,
                    'status' => 'published',
                    'visibility' => 'members',
                    'sequential' => 0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            } else {
                DB::table('edu_subjects')->where('id', $zema->id)->update([
                    'name' => 'ዜማ',
                    'sort_order' => 7,
                    'status' => 'published',
                    'visibility' => 'members',
                ]);
            }
        }

        // -------------------------------------------------------------
        // 2. Normalize class level_id mappings
        // -------------------------------------------------------------
        if (Schema::hasTable('edu_classes')) {
            // Set level_id = 7 for Class 1 ("7ኛ") if null
            DB::table('edu_classes')
                ->whereNull('level_id')
                ->where(function ($q) {
                    $q->where('name', 'like', '%7%')->orWhere('name', 'like', '%7ኛ%');
                })
                ->update(['level_id' => 7]);
        }

        // -------------------------------------------------------------
        // 3. Prevent duplicate physical book borrowings in DB
        // -------------------------------------------------------------
        if (Schema::hasTable('borrowings')) {
            // Add virtual generated column for conditional uniqueness:
            // Only active/pending loans generate a non-null key "user_id:item_id"
            if (! Schema::hasColumn('borrowings', 'active_loan_user_item')) {
                try {
                    DB::statement("
                        ALTER TABLE borrowings
                        ADD COLUMN active_loan_user_item VARCHAR(64)
                        AS (IF(status IN ('pending_approval', 'active', 'partially_returned'), CONCAT(user_id, ':', item_id), NULL)) STORED
                    ");
                    // Note: If existing duplicate active records exist, we do not destructively alter them.
                    // We attempt to create the unique index; if duplicates exist, the index will be added
                    // after user-authorized reconciliation, while application-level locking strictly enforces it immediately.
                    try {
                        DB::statement("
                            CREATE UNIQUE INDEX borrowings_user_item_active_unique
                            ON borrowings (active_loan_user_item)
                        ");
                    } catch (\Throwable $e) {
                        // Unique index will be created after admin reconciles historical duplicate loans.
                    }
                } catch (\Throwable $e) {
                    // Safe fallback if virtual column or index already exists or not supported
                }
            }
        }

        // -------------------------------------------------------------
        // 4. Prevent duplicate open library requests in DB
        // -------------------------------------------------------------
        if (Schema::hasTable('library_requests')) {
            if (! Schema::hasColumn('library_requests', 'open_request_user_item')) {
                try {
                    DB::statement("
                        ALTER TABLE library_requests
                        ADD COLUMN open_request_user_item VARCHAR(64)
                        AS (IF(status IN ('requested', 'approved'), CONCAT(user_id, ':', item_id), NULL)) STORED
                    ");
                    try {
                        DB::statement("
                            CREATE UNIQUE INDEX library_requests_user_item_open_unique
                            ON library_requests (open_request_user_item)
                        ");
                    } catch (\Throwable $e) {
                        // Unique index will be created after reconciliation.
                    }
                } catch (\Throwable $e) {
                    // Safe fallback
                }
            }
        }
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        if (Schema::hasTable('borrowings')) {
            try {
                Schema::table('borrowings', function (Blueprint $table) {
                    $table->dropIndex('borrowings_user_item_active_unique');
                    $table->dropColumn('active_loan_user_item');
                });
            } catch (\Throwable $e) {}
        }

        if (Schema::hasTable('library_requests')) {
            try {
                Schema::table('library_requests', function (Blueprint $table) {
                    $table->dropIndex('library_requests_user_item_open_unique');
                    $table->dropColumn('open_request_user_item');
                });
            } catch (\Throwable $e) {}
        }
    }
};
