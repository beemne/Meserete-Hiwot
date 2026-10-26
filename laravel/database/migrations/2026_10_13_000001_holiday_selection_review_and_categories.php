<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        // 1. selection_reviews table
        if (! Schema::hasTable('selection_reviews')) {
            Schema::create('selection_reviews', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('selection_id');
                $table->unsignedInteger('department_id')->nullable();
                $table->string('department_name', 150)->nullable();
                $table->unsignedInteger('reviewer_id')->nullable();
                $table->string('decision', 30); // 'approved' | 'rejected'
                $table->text('comments')->nullable();
                $table->string('config_version', 64)->nullable();
                $table->timestamps();

                $table->index(['selection_id', 'department_id']);
            });
        }

        // 2. holiday_selections publication and required reviewer departments
        if (Schema::hasTable('holiday_selections')) {
            Schema::table('holiday_selections', function (Blueprint $table) {
                if (! Schema::hasColumn('holiday_selections', 'is_published')) {
                    $table->boolean('is_published')->default(false)->after('status');
                }
                if (! Schema::hasColumn('holiday_selections', 'published_at')) {
                    $table->dateTime('published_at')->nullable()->after('is_published');
                }
                if (! Schema::hasColumn('holiday_selections', 'published_by')) {
                    $table->unsignedInteger('published_by')->nullable()->after('published_at');
                }
                if (! Schema::hasColumn('holiday_selections', 'required_departments')) {
                    $table->text('required_departments')->nullable()->after('published_by');
                }
            });
        }

        // 3. selection_results service category assignment and ranking
        if (Schema::hasTable('selection_results')) {
            Schema::table('selection_results', function (Blueprint $table) {
                if (! Schema::hasColumn('selection_results', 'service_category')) {
                    $table->string('service_category', 100)->nullable()->after('override_reason');
                }
                if (! Schema::hasColumn('selection_results', 'service_rank')) {
                    $table->unsignedInteger('service_rank')->nullable()->after('service_category');
                }
                if (! Schema::hasColumn('selection_results', 'category_assigned_by')) {
                    $table->unsignedInteger('category_assigned_by')->nullable()->after('service_rank');
                }
                if (! Schema::hasColumn('selection_results', 'category_assigned_at')) {
                    $table->dateTime('category_assigned_at')->nullable()->after('category_assigned_by');
                }
            });
        }

        // 4. selection_feedback table
        if (! Schema::hasTable('selection_feedback')) {
            Schema::create('selection_feedback', function (Blueprint $table) {
                $table->increments('id');
                $table->unsignedInteger('selection_id');
                $table->unsignedInteger('user_id');
                $table->text('comments');
                $table->string('status', 30)->default('submitted');
                $table->unsignedInteger('reviewed_by')->nullable();
                $table->text('response')->nullable();
                $table->timestamps();

                $table->index(['selection_id', 'user_id']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('selection_feedback');
        if (Schema::hasTable('selection_results')) {
            Schema::table('selection_results', function (Blueprint $table) {
                if (Schema::hasColumn('selection_results', 'service_category')) {
                    $table->dropColumn(['service_category', 'service_rank', 'category_assigned_by', 'category_assigned_at']);
                }
            });
        }
        if (Schema::hasTable('holiday_selections')) {
            Schema::table('holiday_selections', function (Blueprint $table) {
                if (Schema::hasColumn('holiday_selections', 'is_published')) {
                    $table->dropColumn(['is_published', 'published_at', 'published_by', 'required_departments']);
                }
            });
        }
        Schema::dropIfExists('selection_reviews');
    }
};
