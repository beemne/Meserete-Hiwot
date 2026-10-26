<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. Add guidance.manage permission
        if (Schema::hasTable('permissions')) {
            $exists = DB::table('permissions')->where('key', 'guidance.manage')->exists();
            if (! $exists) {
                DB::table('permissions')->insert([
                    'key' => 'guidance.manage',
                    'group_key' => 'system',
                    'description' => 'Manage in-app guidance articles, FAQs, and interactive tours',
                ]);

                $permId = DB::table('permissions')->where('key', 'guidance.manage')->value('id');
                $targetPermIds = DB::table('permissions')->whereIn('key', ['settings.manage', 'admins.manage'])->pluck('id');

                $roles = DB::table('role_permissions')
                    ->whereIn('permission_id', $targetPermIds)
                    ->pluck('role_id')
                    ->unique();

                foreach ($roles as $roleId) {
                    DB::table('role_permissions')->insertOrIgnore([
                        'role_id' => $roleId,
                        'permission_id' => $permId,
                    ]);
                }
            }
        }

        // 2. guidance_articles table
        if (! Schema::hasTable('guidance_articles')) {
            Schema::create('guidance_articles', function (Blueprint $table) {
                $table->increments('id');
                $table->string('slug', 100)->unique();
                $table->string('category', 60)->index();
                $table->string('title', 255);
                $table->text('summary')->nullable();
                $table->longText('content');
                $table->string('target_role', 40)->default('all')->index();
                $table->string('target_screen', 100)->nullable()->index();
                $table->string('required_permission', 80)->nullable()->index();
                $table->longText('steps')->nullable();
                $table->longText('tips')->nullable();
                $table->longText('faq_items')->nullable();
                $table->string('tour_id', 60)->nullable()->index();
                $table->string('icon', 60)->nullable();
                $table->integer('sort_order')->default(0);
                $table->string('status', 20)->default('published')->index();
                $table->unsignedInteger('created_by')->nullable();
                $table->unsignedInteger('updated_by')->nullable();
                $table->timestamps();
            });
        }

        // 3. user_guidance_progress table
        if (! Schema::hasTable('user_guidance_progress')) {
            Schema::create('user_guidance_progress', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('user_id');
                $table->string('tour_id', 60);
                $table->boolean('completed')->default(false);
                $table->boolean('dismissed')->default(false);
                $table->dateTime('completed_at')->nullable();
                $table->timestamps();

                $table->unique(['user_id', 'tour_id']);
                $table->index('user_id');
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('user_guidance_progress');
        Schema::dropIfExists('guidance_articles');
        $permId = DB::table('permissions')->where('key', 'guidance.manage')->value('id');
        if ($permId) {
            DB::table('role_permissions')->where('permission_id', $permId)->delete();
            DB::table('permissions')->where('id', $permId)->delete();
        }
    }
};
