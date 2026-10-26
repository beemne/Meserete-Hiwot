<?php

namespace Tests\Integration;

use App\Mz\Db\UtcDateTime;
use App\Mz\Jobs\ReminderJobs;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

class ProgramRemindersTest extends IntegrationTestCase
{
    /** A UTC instant for a local (Addis Ababa) wall-clock time. */
    private function at(string $local): UtcDateTime
    {
        return new UtcDateTime('@' . (new \DateTimeImmutable($local, Dates::tz()))->getTimestamp());
    }

    private function sent(int $programId, ?int $userId = null): int
    {
        $q = DB::table('notifications')->where(['entity_type' => 'program', 'entity_id' => $programId])->where('dedupe_key', 'like', "program:$programId:every%");
        if ($userId) $q->where('user_id', $userId);
        return $q->count();
    }

    /** A weekly program running through 2026-12-31, reminding its participants every 15 days from 2026-10-01. */
    private function weekly(array $attrs = []): object
    {
        return $this->program($attrs + [
            'starts_at' => '2026-09-27 06:00:00', 'ends_at' => '2026-09-27 08:00:00', 'recurrence' => 'weekly', 'recurrence_until' => '2026-12-31',
            'audience' => 'participants', 'reminder_interval_days' => 15, 'reminder_interval_start' => '2026-10-01',
        ]);
    }

    private function participant(object $p): object
    {
        $u = $this->member();
        DB::table('program_participants')->insert(['program_id' => $p->id, 'user_id' => $u->id, 'status' => 'registered']);
        return $u;
    }

    public function test_one_reminder_per_15_day_cycle_and_no_duplicates(): void
    {
        $p = $this->weekly();
        $u = $this->participant($p);
        $outsider = $this->member();

        ReminderJobs::intervalReminders($this->at('2026-10-01 09:00'));
        ReminderJobs::intervalReminders($this->at('2026-10-01 15:00')); // same cycle again
        ReminderJobs::intervalReminders($this->at('2026-10-10 10:00')); // still cycle 0
        $this->assertSame(1, $this->sent($p->id, $u->id));
        $this->assertSame(0, $this->sent($p->id, $outsider->id), 'only the program audience');

        ReminderJobs::intervalReminders($this->at('2026-10-16 09:00')); // day 15 → cycle 1
        $this->assertSame(2, $this->sent($p->id, $u->id));
        $keys = DB::table('notifications')->where('user_id', $u->id)->where('dedupe_key', 'like', "program:{$p->id}:every%")->pluck('dedupe_key')->all();
        $this->assertEqualsCanonicalizing(["program:{$p->id}:every15:2026-10-01:c0:{$u->id}", "program:{$p->id}:every15:2026-10-01:c1:{$u->id}"], $keys);
        $this->assertNotNull(DB::table('programs')->where('id', $p->id)->value('reminder_interval_last_at'));
    }

    public function test_missed_cycles_are_not_replayed(): void
    {
        $p = $this->weekly();
        $u = $this->participant($p);
        ReminderJobs::intervalReminders($this->at('2026-11-20 09:00')); // cycles 0–2 were never run → only cycle 3
        $this->assertSame(1, $this->sent($p->id, $u->id));
        $this->assertStringContainsString(':c3:', DB::table('notifications')->where('user_id', $u->id)->where('dedupe_key', 'like', "program:{$p->id}:every%")->value('dedupe_key'));
    }

    public function test_no_reminders_at_night_before_the_start_or_after_the_last_day(): void
    {
        $p = $this->weekly();
        $u = $this->participant($p);
        ReminderJobs::intervalReminders($this->at('2026-10-01 23:30'));
        ReminderJobs::intervalReminders($this->at('2026-09-30 10:00'));
        ReminderJobs::intervalReminders($this->at('2027-01-05 10:00'));
        $this->assertSame(0, $this->sent($p->id, $u->id));
    }

    public function test_cancelled_completed_and_draft_programs_stop(): void
    {
        foreach (['cancelled', 'completed', 'draft'] as $status) {
            $p = $this->weekly(['status' => $status]);
            $u = $this->participant($p);
            ReminderJobs::intervalReminders($this->at('2026-10-01 09:00'));
            $this->assertSame(0, $this->sent($p->id, $u->id), $status);
        }
    }

    public function test_programs_without_the_setting_get_no_interval_reminders(): void
    {
        $p = $this->weekly(['reminder_interval_days' => null, 'reminder_interval_start' => null]);
        $u = $this->participant($p);
        ReminderJobs::intervalReminders($this->at('2026-10-01 09:00'));
        $this->assertSame(0, $this->sent($p->id, $u->id));
    }

    public function test_admin_sets_it_per_program_and_program_types_supply_defaults(): void
    {
        $admin = $this->member(['programs.manage', 'program_categories.manage']);
        $cat = $this->as($admin, 'POST', 'programs/categories', ['name' => 'IT ዓመታዊ', 'reminder_offsets' => [2880, 60], 'reminder_interval_days' => 15]);
        $cat->assertSuccessful()->assertJsonPath('data.reminder_interval_days', 15);
        $catId = (int) $cat->json('data.id');

        $start = gmdate('Y-m-d\TH:i:s\Z', time() + 40 * 86400);
        $res = $this->as($admin, 'POST', 'programs', ['title' => 'IT typed', 'starts_at' => $start, 'category_id' => $catId]);
        $res->assertSuccessful();
        $this->assertSame(15, $res->json('data.reminder.interval_days'));
        $this->assertSame(Dates::todayLocal(), $res->json('data.reminder.interval_start'), 'a program still ahead is reminded from today');
        $this->assertSame([2880, 60], $res->json('data.reminder.offsets'));

        $id = (int) $res->json('data.id');
        $this->as($admin, 'PATCH', "programs/$id", ['reminder_interval_days' => null])->assertOk()->assertJsonPath('data.reminder.interval_days', null);
        $this->as($admin, 'PATCH', "programs/$id", ['reminder_interval_days' => 15, 'reminder_interval_start' => '2026-11-01'])->assertOk()
            ->assertJsonPath('data.reminder.interval_start', '2026-11-01');
    }
}
