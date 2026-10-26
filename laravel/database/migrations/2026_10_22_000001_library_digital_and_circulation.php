<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Release 1.5.3+23: F16 (Digital Library) & F17 (Physical Sunday-School Library)
 *
 *  - library_categories: nested/hierarchical categories for books
 *  - items: library_category_id, narration_path, narration_mime, narration_duration
 *  - library_favorites: member book favorites
 *  - library_progress: reading page and audio narration position
 *  - library_copies: per-copy physical inventory with stable unique copy_code
 *  - library_loans: circulation loans with signatures and unique active loan per copy
 *  - library_sync_conflicts: offline circulation conflicts
 *  - permission: library.circulate
 */
return new class extends Migration
{
    public function up(): void
    {
        $isSqlite = DB::getDriverName() === 'sqlite';

        // 1. library_categories (F16)
        if (! Schema::hasTable('library_categories')) {
            Schema::create('library_categories', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('parent_id')->nullable();
                $table->string('domain', 32)->default('timhirt');
                $table->string('name', 200);
                $table->string('name_en', 200)->nullable();
                $table->string('code', 32)->nullable();
                $table->unsignedInteger('sort_order')->default(0);
                $table->timestamps();

                $table->index(['domain', 'sort_order']);
                $table->index('parent_id');
            });
        }

        // 2. Add columns to items (F16)
        if (! Schema::hasColumn('items', 'library_category_id')) {
            Schema::table('items', function (Blueprint $table) {
                $table->unsignedInteger('library_category_id')->nullable()->after('category');
                $table->string('narration_path', 255)->nullable()->after('file_size');
                $table->string('narration_mime', 100)->nullable()->after('narration_path');
                $table->unsignedInteger('narration_duration')->nullable()->after('narration_mime');

                $table->index('library_category_id');
            });
        }

        // Migrate existing category strings from items into library_categories
        $existingCats = DB::table('items')
            ->whereNotNull('category')
            ->where('category', '<>', '')
            ->select('category', 'domain')
            ->distinct()
            ->get();

        foreach ($existingCats as $row) {
            $catName = trim((string) $row->category);
            $domain = (string) ($row->domain ?: 'timhirt');
            $existingId = DB::table('library_categories')
                ->where('name', $catName)
                ->where('domain', $domain)
                ->value('id');

            if (! $existingId) {
                $code = strtoupper(substr(preg_replace('/[^a-zA-Z0-9]/', '', $catName) ?: 'CAT', 0, 4));
                $existingId = DB::table('library_categories')->insertGetId([
                    'domain' => $domain,
                    'name' => $catName,
                    'code' => $code,
                    'sort_order' => 0,
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            DB::table('items')
                ->where('category', $catName)
                ->where('domain', $domain)
                ->whereNull('library_category_id')
                ->update(['library_category_id' => $existingId]);
        }

        // 3. library_favorites (F16)
        if (! Schema::hasTable('library_favorites')) {
            Schema::create('library_favorites', function (Blueprint $table) {
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('item_id');
                $table->dateTime('created_at')->useCurrent();

                $table->primary(['user_id', 'item_id']);
                $table->index('item_id');
            });
        }

        // 4. library_progress (F16)
        if (! Schema::hasTable('library_progress')) {
            Schema::create('library_progress', function (Blueprint $table) {
                $table->unsignedInteger('user_id');
                $table->unsignedInteger('item_id');
                $table->unsignedInteger('page')->default(1);
                $table->unsignedInteger('page_count')->nullable();
                $table->unsignedInteger('audio_position_ms')->default(0);
                $table->dateTime('updated_at')->useCurrent();

                $table->primary(['user_id', 'item_id']);
                $table->index('item_id');
            });
        }

        // 5. library_copies (F17)
        if (! Schema::hasTable('library_copies')) {
            Schema::create('library_copies', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('item_id');
                $table->unsignedInteger('copy_no');
                $table->string('copy_code', 64)->unique();
                $table->string('condition', 20)->default('good'); // good, fair, poor, damaged
                $table->string('location', 100)->nullable();
                $table->string('status', 20)->default('available'); // available, on_loan, lost, withdrawn
                $table->timestamps();

                $table->index(['item_id', 'status']);
            });
        }

        // 6. library_loans (F17)
        if (! Schema::hasTable('library_loans')) {
            Schema::create('library_loans', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('copy_id');
                $table->unsignedInteger('user_id');
                $table->dateTime('checked_out_at')->useCurrent();
                $table->date('due_on');
                $table->dateTime('returned_at')->nullable();
                $table->string('condition_out', 20)->default('good');
                $table->string('condition_in', 20)->nullable();
                $table->unsignedInteger('issued_by');
                $table->unsignedInteger('received_by')->nullable();
                $table->string('signature_path', 255);
                $table->string('sha256', 64)->nullable();
                $table->string('notes', 500)->nullable();
                $table->string('status', 20)->default('active'); // active, returned, overdue, lost
                $table->timestamps();

                $table->index('copy_id');
                $table->index(['user_id', 'status']);
                $table->index(['due_on', 'status']);
            });

            // Add generated column and unique constraint for active loan per copy
            if (! Schema::hasColumn('library_loans', 'open_copy_id')) {
                $generatedSql = "ALTER TABLE library_loans ADD COLUMN open_copy_id int unsigned GENERATED ALWAYS AS (
                    CASE WHEN status = 'active' THEN copy_id ELSE NULL END
                ) STORED";
                DB::statement($generatedSql);
                DB::statement('ALTER TABLE library_loans ADD UNIQUE KEY uq_library_loans_open_copy (open_copy_id)');
            }
        }

        // 7. library_sync_conflicts (F17)
        if (! Schema::hasTable('library_sync_conflicts')) {
            Schema::create('library_sync_conflicts', function (Blueprint $table) {
                $table->increments('id');
                $table->string('kind', 20); // checkout, return
                $table->string('code', 64);
                $table->string('copy_code', 64);
                $table->unsignedInteger('copy_id')->nullable();
                $table->unsignedInteger('user_id')->nullable();
                $table->unsignedInteger('submitted_by');
                $table->string('client_event_id', 64)->nullable();
                $table->text('payload');
                $table->string('status', 20)->default('pending'); // pending, resolved, dismissed
                $table->string('resolution_note', 500)->nullable();
                $table->unsignedInteger('resolved_by')->nullable();
                $table->dateTime('resolved_at')->nullable();
                $table->timestamps();

                $table->index(['status', 'created_at']);
                $table->index('copy_code');
            });
        }

        // 8. Generate copies for existing physical Sunday-school books (Decision D6)
        $physicalBooks = DB::table('items')
            ->where('kind', 'physical')
            ->whereNull('deleted_at')
            ->get();

        foreach ($physicalBooks as $book) {
            $existingCopies = DB::table('library_copies')->where('item_id', $book->id)->count();
            if ($existingCopies === 0) {
                $qty = max(1, (int) $book->quantity);
                $avail = max(0, min($qty, (int) $book->available_quantity));
                $catCode = 'GEN';
                if ($book->library_category_id) {
                    $catCode = DB::table('library_categories')->where('id', $book->library_category_id)->value('code') ?: 'GEN';
                }

                for ($c = 1; $c <= $qty; $c++) {
                    $copyCode = sprintf('LIB-%s-%04d-%02d', $catCode, $book->id, $c);
                    $status = ($c <= $avail) ? 'available' : 'on_loan';
                    DB::table('library_copies')->insert([
                        'item_id' => $book->id,
                        'copy_no' => $c,
                        'copy_code' => $copyCode,
                        'condition' => 'good',
                        'location' => null,
                        'status' => $status,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        // 9. Permissions & Roles
        DB::table('permissions')->insertOrIgnore([
            'key' => 'library.circulate',
            'group_key' => 'library',
            'description' => 'Circulate Sunday-school library books (checkout, return, copy management)',
        ]);
        $permId = DB::table('permissions')->where('key', 'library.circulate')->value('id');

        if ($permId) {
            foreach (['high_admin', 'moderator', 'dept_education', 'librarian'] as $slug) {
                $rid = DB::table('roles')->where('slug', $slug)->value('id');
                if ($rid) {
                    DB::table('role_permissions')->insertOrIgnore([
                        'role_id' => $rid,
                        'permission_id' => $permId,
                    ]);
                }
            }
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('library_sync_conflicts');
        Schema::dropIfExists('library_loans');
        Schema::dropIfExists('library_copies');
        Schema::dropIfExists('library_progress');
        Schema::dropIfExists('library_favorites');

        if (Schema::hasColumn('items', 'library_category_id')) {
            Schema::table('items', function (Blueprint $table) {
                $table->dropIndex(['library_category_id']);
                $table->dropColumn(['library_category_id', 'narration_path', 'narration_mime', 'narration_duration']);
            });
        }

        Schema::dropIfExists('library_categories');

        $pid = DB::table('permissions')->where('key', 'library.circulate')->value('id');
        if ($pid) {
            DB::table('role_permissions')->where('permission_id', $pid)->delete();
            DB::table('permissions')->where('id', $pid)->delete();
        }
    }
};
