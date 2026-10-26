<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (! Schema::hasTable('edu_certificates')) {
            Schema::create('edu_certificates', function (Blueprint $table) {
                $table->id();
                $table->string('number', 64)->unique();
                $table->string('verify_code', 16)->unique();
                $table->foreignId('user_id')->constrained('users')->cascadeOnDelete();
                $table->foreignId('course_id')->constrained('edu_courses')->cascadeOnDelete();
                $table->foreignId('outcome_id')->constrained('edu_course_outcomes')->cascadeOnDelete();
                $table->dateTime('issued_at');
                $table->foreignId('issued_by')->constrained('users')->cascadeOnDelete();
                $table->string('status', 32)->default('valid'); // valid, revoked, replaced
                $table->unsignedBigInteger('replaced_by')->nullable();
                $table->text('revoked_reason')->nullable();
                $table->string('pdf_path', 255)->nullable();
                $table->json('snapshot');
                $table->timestamps();

                $table->index(['course_id', 'user_id']);
                $table->index(['status']);
            });
        }
    }

    public function down(): void
    {
        Schema::dropIfExists('edu_certificates');
    }
};
