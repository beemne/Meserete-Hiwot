<?php

use App\Mz\Services\SelectionCriteria;
use Illuminate\Database\Migrations\Migration;

/**
 * First criteria drafts that nobody has changed yet started from a passing score of 50 and no
 * minimums, ignoring the selection's own settings. Seed them again from the selection (its
 * passing score, its minimums and its weights fitted to the 50 / 30 / 10 / 10 split). Drafts that
 * were edited, submitted or decided are left as they are.
 */
return new class extends Migration
{
    public function up(): void
    {
        SelectionCriteria::reseedUntouched();
    }

    public function down(): void
    {
        // Nothing to undo: the drafts only received their selection's own settings.
    }
};
