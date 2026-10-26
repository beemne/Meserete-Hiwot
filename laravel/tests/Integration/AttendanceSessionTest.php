<?php

namespace Tests\Integration;

use App\Mz\Support\Crypto;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;

/**
 * Attendance sessions: one HR-assigned taker per occurrence, Start / End, exact capture times and
 * signatures, no late status, per-occurrence reports, HR permissions, and offline replay with the
 * auditable conflict queue.
 */
class AttendanceSessionTest extends IntegrationTestCase
{
    private const PNG = 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==';

    private object $hr;
    private object $taker;
    private object $member;
    private object $program;
    private string $date;

    protected function setUp(): void
    {
        parent::setUp();
        $this->hr = $this->member(['attendance.assign', 'attendance.override', 'attendance.close', 'attendance.reports', 'attendance.correction.approve']);
        $this->taker = $this->member();
        $this->member = $this->member();
        // Starts in 10 minutes: the session is available (−15 min) but the program has not started.
        $this->program = $this->runningProgram(10);
        $this->date = Dates::localDateOf($this->program->starts_at);
        $this->as($this->hr, 'PUT', "programs/{$this->program->id}/attendance-takers", ['user_ids' => [$this->taker->id]])->assertOk();
    }

    /** A published one-off program starting $minutes from now (negative = already started), 2 h long. */
    private function runningProgram(int $minutes, array $attrs = []): object
    {
        $start = gmdate('Y-m-d H:i:s', time() + $minutes * 60);
        $end = gmdate('Y-m-d H:i:s', time() + $minutes * 60 + 7200);
        $id = DB::table('programs')->insertGetId($attrs + ['title' => 'IT Session ' . uniqid(), 'starts_at' => $start, 'ends_at' => $end, 'status' => 'published', 'requires_attendance' => 1, 'audience' => 'all']);
        return DB::table('programs')->where('id', $id)->first();
    }

    private function url(string $tail = ''): string
    {
        return "programs/{$this->program->id}/attendance$tail";
    }

    private function start(?object $who = null)
    {
        return $this->as($who ?? $this->taker, 'POST', $this->url('/session/start'), ['date' => $this->date]);
    }

    private function mark(object $member, array $body = [], ?object $who = null)
    {
        return $this->as($who ?? $this->taker, 'PUT', $this->url("/{$member->id}"), $body + ['status' => 'present', 'date' => $this->date, 'signature' => self::PNG]);
    }

    // ---------------------------------------------------------------- session lifecycle

    public function test_nothing_is_recorded_before_the_taker_starts_the_session(): void
    {
        $this->mark($this->member)->assertStatus(409)->assertJsonPath('code', 'SESSION_NOT_STARTED');
        $this->as($this->taker, 'GET', $this->url('/check') . "?user_id={$this->member->id}&date={$this->date}")->assertOk()->assertJsonPath('data.reason', 'SESSION_NOT_STARTED');
        // Too early: more than 15 minutes before the scheduled start.
        $later = $this->runningProgram(60);
        $this->as($this->hr, 'PUT', "programs/{$later->id}/attendance-takers", ['user_ids' => [$this->taker->id]])->assertOk();
        $this->as($this->taker, 'POST', "programs/{$later->id}/attendance/session/start", ['date' => Dates::localDateOf($later->starts_at)])->assertStatus(409)->assertJsonPath('code', 'SESSION_NOT_AVAILABLE');
    }

    public function test_elapsed_time_counts_from_the_official_start_not_the_schedule(): void
    {
        $s = $this->start()->assertOk()->json('data');
        $this->assertSame('active', $s['status']);
        $this->assertSame('server', $s['start_source']);
        // Pretend Start was pressed 5 minutes ago; the member is captured now.
        DB::table('attendance_sessions')->where('id', $s['id'])->update(['started_at' => gmdate('Y-m-d H:i:s', time() - 300)]);
        $r = $this->mark($this->member, ['via' => 'qr'])->assertOk()->json('data');
        $this->assertSame('present', $r['status']);
        $this->assertGreaterThanOrEqual(295, $r['elapsed_seconds']);
        $this->assertLessThanOrEqual(330, $r['elapsed_seconds']);
        $this->assertSame('server', $r['time_source']);
        $this->assertNotNull($r['signature_id']);
        $this->assertTrue(DB::table('attendance_signatures')->where(['id' => $r['signature_id'], 'user_id' => $this->member->id])->exists());
    }

    public function test_present_needs_a_signature_unless_hr_exempts_the_group(): void
    {
        $this->start()->assertOk();
        $this->mark($this->member, ['signature' => null])->assertStatus(422)->assertJsonPath('errors.0.code', 'SIGNATURE_REQUIRED');
        $this->assertFalse(DB::table('attendance')->where(['program_id' => $this->program->id, 'user_id' => $this->member->id])->exists(), 'never marked before signing');
        $this->mark($this->member, ['status' => 'late'])->assertStatus(422);
        $this->as($this->taker, 'POST', $this->url('/bulk'), ['target' => ['user_ids' => [$this->member->id]], 'status' => 'present', 'date' => $this->date])->assertStatus(422);

        $hrConfig = $this->member(['attendance.configure']);
        $this->as($hrConfig, 'PUT', 'attendance/signature-policy', ['exempt_groups' => ['youth_adult']])->assertOk();
        $r = $this->mark($this->member, ['signature' => null])->assertOk()->json('data');
        $this->assertSame(1, (int) $r['signature_exempt']);
        $this->assertTrue(DB::table('audit_logs')->where('action', 'settings.update')->where('metadata', 'like', '%attendance.signature%')->exists());
    }

    public function test_exactly_one_taker_per_occurrence_and_hr_controls_it(): void
    {
        $other = $this->member(['attendance.manage']);
        // Holding attendance permissions is not enough: only the assigned taker starts and records.
        $this->start($other)->assertStatus(403)->assertJsonPath('code', 'NOT_SESSION_TAKER');
        $this->start()->assertOk();
        $this->mark($this->member, [], $other)->assertStatus(403);
        $this->mark($this->member, [], $this->hr)->assertStatus(403);
        // Only HR assigns, and a substitute while running needs a reason (kept in the audit log).
        $this->as($this->taker, 'PUT', $this->url('/session/taker'), ['date' => $this->date, 'user_id' => $other->id])->assertForbidden();
        $this->as($this->hr, 'PUT', $this->url('/session/taker'), ['date' => $this->date, 'user_id' => $other->id])->assertStatus(422);
        $this->as($this->hr, 'PUT', $this->url('/session/taker'), ['date' => $this->date, 'user_id' => $other->id, 'reason' => 'Taker left early'])->assertOk()->assertJsonPath('data.taker.id', $other->id);
        $this->mark($this->member)->assertStatus(403);
        $this->mark($this->member, [], $other)->assertOk();
        $this->assertSame(1, DB::table('attendance_sessions')->where(['program_id' => $this->program->id])->count(), 'one session per occurrence');
        $this->assertTrue(DB::table('audit_logs')->where('action', 'attendance.session_assign')->exists());
        $this->as($this->hr, 'PUT', "programs/{$this->program->id}/attendance-takers", ['user_ids' => [$this->taker->id, $other->id]])->assertStatus(422);
    }

    public function test_after_end_only_corrections_change_attendance(): void
    {
        $this->start()->assertOk();
        $this->as($this->taker, 'POST', $this->url('/session/end'), ['date' => $this->date])->assertOk()->assertJsonPath('data.end_reason', 'taker');
        $this->mark($this->member)->assertStatus(409)->assertJsonPath('code', 'ATTENDANCE_CLOSED');
        // Scheduled end reached: ended automatically (no grace period).
        $p = $this->runningProgram(-150);
        $this->as($this->hr, 'PUT', "programs/{$p->id}/attendance-takers", ['user_ids' => [$this->taker->id]])->assertOk();
        DB::table('attendance_sessions')->insert(['program_id' => $p->id, 'occurrence_date' => Dates::localDateOf($p->starts_at), 'taker_id' => $this->taker->id, 'status' => 'active', 'started_at' => gmdate('Y-m-d H:i:s', time() - 8000)]);
        $this->as($this->taker, 'GET', "programs/{$p->id}/attendance/session?date=" . Dates::localDateOf($p->starts_at))->assertOk()
            ->assertJsonPath('data.status', 'ended')->assertJsonPath('data.end_reason', 'scheduled_end');
    }

    public function test_recurring_programs_get_one_session_and_report_per_occurrence(): void
    {
        $this->start()->assertOk();
        $this->mark($this->member)->assertOk();
        foreach (['pdf', 'xlsx', 'csv'] as $fmt) {
            $res = $this->as($this->hr, 'GET', "reports/export/attendance?format=$fmt&program_id={$this->program->id}&date={$this->date}");
            $res->assertOk();
            $disp = (string) $res->headers->get('Content-Disposition');
            $this->assertStringContainsString($this->date, $disp, "$fmt filename names the occurrence date");
            $this->assertNotSame('', $res->getContent());
        }
        $csv = $this->as($this->hr, 'GET', "reports/export/attendance?format=csv&program_id={$this->program->id}&date={$this->date}")->getContent();
        $this->assertStringContainsString('signed', $csv);
    }

    // ---------------------------------------------------------------- permissions moved to HR

    public function test_hr_roles_hold_attendance_control_and_dept_info_does_not(): void
    {
        $keys = fn ($slug) => DB::table('role_permissions as rp')->join('roles as r', 'r.id', '=', 'rp.role_id')->join('permissions as p', 'p.id', '=', 'rp.permission_id')
            ->where('r.slug', $slug)->where('p.key', 'like', 'attendance.%')->pluck('p.key')->all();
        foreach (['dept_hr', 'hr_manager'] as $slug) {
            foreach (['attendance.manage', 'attendance.close', 'attendance.configure', 'attendance.assign', 'attendance.correction.approve', 'attendance.override', 'attendance.reports'] as $k) {
                $this->assertContains($k, $keys($slug), "$slug has $k");
            }
        }
        foreach (['attendance.manage', 'attendance.close', 'attendance.configure', 'attendance.assign', 'attendance.correction.approve', 'attendance.override'] as $k) {
            $this->assertNotContains($k, $keys('dept_info'));
        }
    }

    public function test_corrections_have_no_late_and_may_state_the_arrival_time(): void
    {
        $req = $this->member(['attendance.correction.request']);
        $this->as($req, 'POST', $this->url("/{$this->member->id}/corrections"), ['date' => $this->date, 'requested_status' => 'late', 'reason' => 'x x x'])->assertStatus(422);
        $this->start()->assertOk();
        $arrived = gmdate('Y-m-d\TH:i:s\Z', time() + 600);
        $c = $this->as($req, 'POST', $this->url("/{$this->member->id}/corrections"), ['date' => $this->date, 'requested_status' => 'present', 'attended_at' => $arrived, 'reason' => 'Phone was off'])->assertCreated()->json('data');
        $this->as($this->hr, 'POST', "attendance/corrections/{$c['id']}/review", ['decision' => 'approve'])->assertOk();
        $row = DB::table('attendance')->where(['program_id' => $this->program->id, 'user_id' => $this->member->id])->first();
        $this->assertSame('present', $row->status);
        $this->assertSame('correction', $row->time_source);
        $this->assertNotNull($row->elapsed_seconds);
    }

    // ---------------------------------------------------------------- offline

    private function sync(object $who, array $ops, ?string $clientNow = null)
    {
        return $this->as($who, 'POST', 'sync', ['operations' => $ops, 'client_now' => $clientNow ?? gmdate('Y-m-d\TH:i:s\Z')]);
    }

    public function test_offline_session_and_signed_records_sync_once_with_device_times(): void
    {
        // The phone's clock is 2 minutes behind the server.
        $skew = -120;
        $phone = fn (int $secondsAgo) => gmdate('Y-m-d\TH:i:s\Z', time() + $skew - $secondsAgo);
        $startOp = ['op_id' => Crypto::uuid(), 'type' => 'attendance.session.start', 'payload' => ['program_id' => $this->program->id, 'date' => $this->date, 'session_uuid' => Crypto::uuid()], 'client_ts' => $phone(240)];
        $recOp = ['op_id' => Crypto::uuid(), 'type' => 'attendance.record', 'client_ts' => $phone(180),
            'payload' => ['program_id' => $this->program->id, 'user_id' => $this->member->id, 'date' => $this->date, 'status' => 'present', 'via' => 'qr', 'signature' => self::PNG, 'captured_offline' => true]];
        $res = $this->sync($this->taker, [$startOp, $recOp], $phone(0))->assertOk()->json('data.results');
        $this->assertSame(['applied', 'applied'], array_column($res, 'status'));
        $s = DB::table('attendance_sessions')->where('program_id', $this->program->id)->first();
        $this->assertSame('offline', $s->start_source);
        // Started ~4 minutes ago on the server clock (device time corrected by the skew).
        $this->assertEqualsWithDelta(time() - 240, Dates::of($s->started_at)->getTimestamp(), 15);
        $row = DB::table('attendance')->where(['program_id' => $this->program->id, 'user_id' => $this->member->id])->first();
        $this->assertSame('device', $row->time_source);
        $this->assertSame('offline', $row->source);
        $this->assertEqualsWithDelta(60, (int) $row->elapsed_seconds, 15);
        $this->assertNotNull($row->signature_id);

        // A retry of the same batch (lost response) changes nothing.
        $again = $this->sync($this->taker, [$startOp, $recOp], $phone(0))->assertOk()->json('data.results');
        $this->assertSame(['duplicate', 'duplicate'], array_column($again, 'status'));
        $this->assertSame(1, DB::table('attendance')->where(['program_id' => $this->program->id, 'user_id' => $this->member->id])->count());
        $this->assertSame(1, DB::table('attendance_signatures')->where('user_id', $this->member->id)->count());
    }

    public function test_conflicting_offline_records_go_to_hr_and_are_decided_with_an_audit_trail(): void
    {
        // Online the session was reassigned meanwhile: the old taker's offline capture is not applied…
        $other = $this->member();
        $this->as($this->hr, 'PUT', $this->url('/session/taker'), ['date' => $this->date, 'user_id' => $other->id])->assertOk();
        $this->as($other, 'POST', $this->url('/session/start'), ['date' => $this->date])->assertOk();
        $op = ['op_id' => Crypto::uuid(), 'type' => 'attendance.record', 'client_ts' => gmdate('Y-m-d\TH:i:s\Z', time() - 600),
            'payload' => ['program_id' => $this->program->id, 'user_id' => $this->member->id, 'date' => $this->date, 'status' => 'present', 'signature' => self::PNG, 'captured_offline' => true]];
        $r = $this->sync($this->taker, [$op])->assertOk()->json('data.results.0');
        $this->assertSame('conflict', $r['status']);
        $this->assertTrue($r['server']['sent_to_hr']);
        // …but kept, with its signature, for HR.
        $c = DB::table('attendance_sync_conflicts')->where('client_event_id', $op['op_id'])->first();
        $this->assertSame('NOT_SESSION_TAKER', $c->code);
        $this->assertNotNull($c->signature_path);
        $this->as($this->hr, 'GET', 'attendance/sync-conflicts?status=open')->assertOk()->assertJsonPath('data.0.id', $c->id);

        // The submitter cannot decide their own; HR accepts → recorded as captured, audited.
        $this->taker = DB::table('users')->where('id', $this->taker->id)->first();
        $selfHr = $this->member(['attendance.override']);
        DB::table('attendance_sync_conflicts')->where('id', $c->id)->update(['submitted_by' => $selfHr->id]);
        $this->as($selfHr, 'POST', "attendance/sync-conflicts/{$c->id}/resolve", ['decision' => 'accept', 'note' => 'mine'])->assertForbidden();
        $this->as($this->hr, 'POST', "attendance/sync-conflicts/{$c->id}/resolve", ['decision' => 'accept', 'note' => 'Verified with the old taker'])->assertOk()->assertJsonPath('data.status', 'accepted');
        $row = DB::table('attendance')->where(['program_id' => $this->program->id, 'user_id' => $this->member->id])->first();
        $this->assertSame('present', $row->status);
        $this->assertNotNull($row->signature_id);
        $this->assertTrue(DB::table('audit_logs')->where(['action' => 'attendance.conflict_accept', 'entity_id' => $c->id])->exists());
        $this->as($this->hr, 'POST', "attendance/sync-conflicts/{$c->id}/resolve", ['decision' => 'reject', 'note' => 'again'])->assertStatus(409);
    }

    public function test_old_app_unsigned_offline_marks_are_kept_for_hr_not_dropped(): void
    {
        $s = $this->start()->assertOk()->json('data');
        DB::table('attendance_sessions')->where('id', $s['id'])->update(['started_at' => gmdate('Y-m-d H:i:s', time() - 300)]);
        $op = ['op_id' => Crypto::uuid(), 'type' => 'attendance.set', 'client_ts' => gmdate('Y-m-d\TH:i:s\Z', time() - 30),
            'payload' => ['program_id' => $this->program->id, 'user_id' => $this->member->id, 'date' => $this->date, 'status' => 'late']];
        $r = $this->sync($this->taker, [$op])->assertOk()->json('data.results.0');
        $this->assertSame('conflict', $r['status']);
        $this->assertSame('SIGNATURE_REQUIRED', DB::table('attendance_sync_conflicts')->where('client_event_id', $op['op_id'])->value('code'));

        // An old offline "mark all present" becomes one HR item per member (unsigned), replay-safe.
        $m2 = $this->member();
        $bulk = ['op_id' => Crypto::uuid(), 'type' => 'attendance.bulk', 'client_ts' => gmdate('Y-m-d\TH:i:s\Z', time() - 20),
            'payload' => ['program_id' => $this->program->id, 'user_ids' => [$this->member->id, $m2->id], 'date' => $this->date, 'status' => 'present']];
        $r = $this->sync($this->taker, [$bulk])->assertOk()->json('data.results.0');
        $this->assertSame(2, $r['server']['sent_to_hr']);
        $this->sync($this->taker, [$bulk])->assertOk();
        $this->assertSame(1, DB::table('attendance_sync_conflicts')->where(['user_id' => $m2->id, 'program_id' => $this->program->id])->count());
        $this->assertFalse(DB::table('attendance')->where(['program_id' => $this->program->id, 'user_id' => $m2->id])->exists());
    }

    public function test_offline_pack_carries_sessions_and_the_signature_policy(): void
    {
        $pack = $this->as($this->taker, 'GET', 'offline/pack')->assertOk()->json('data');
        $this->assertTrue($pack['roles']['attendance']);
        $prog = collect($pack['programs'])->firstWhere('id', $this->program->id);
        $this->assertNotNull($prog);
        $this->assertSame($this->taker->id, $prog['occurrences'][0]['session']['taker_id']);
        $this->assertArrayHasKey('exempt_groups', $pack['signature_policy']);
        $this->assertArrayNotHasKey('on_time_minutes', $prog);
        // A member with nothing assigned gets no attendance data.
        $this->assertFalse($this->as($this->member, 'GET', 'offline/pack')->json('data.roles.attendance'));
    }
}
