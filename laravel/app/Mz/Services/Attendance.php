<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Db\UtcDateTime;
use App\Mz\Notifications\Notifications;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\Num;
use App\Mz\Support\Page;
use App\Mz\Support\T;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * Program attendance per occurrence (port of attendanceService.js), taken inside the occurrence's
 * attendance session (AttendanceSessions): only the one assigned taker records, only between the
 * official Start and the end. Each "present" mark keeps its real capture time, the seconds since
 * the official start and the member's signature (unless HR exempts the member's group); "excused"
 * needs a reason; unmarked = absent once the occurrence has closed. There is no late status any
 * more — how early someone came is scored from the elapsed time where it is needed (selection).
 * Rows recorded before sessions existed ("legacy", possibly "late") are kept and read as before.
 */
final class Attendance
{
    public const MARKABLE = ['present', 'excused'];
    private const PROGRAM_COLS = ['id', 'title', 'status', 'starts_at', 'ends_at', 'recurrence', 'monthly_rule', 'recurrence_until', 'ethiopian_days', 'audience', 'category_id', 'requires_attendance', 'member_groups', 'is_additional', 'counts_for_selection'];
    private const DAY_PRIORITY = ['absent', 'late', 'excused', 'present', 'today', 'upcoming'];

    public static function getProgram(int $id): object
    {
        $p = DB::table('programs')->where('id', $id)->first(self::PROGRAM_COLS);
        if (! $p || $p->status === 'draft') throw ApiError::notFound('PROGRAM_NOT_FOUND', 'Program not found');
        Schedule::loadOverrides($p);
        return $p;
    }

    /** The given date, else today's, else the most recent past occurrence, else the next. */
    public static function resolveOccurrence(object $p, ?string $date, ?\DateTimeInterface $now = null): ?array
    {
        if ($date) {
            $o = Schedule::on($p, $date);
            if (! $o) throw ApiError::field('date', 'NOT_AN_OCCURRENCE');
            return $o;
        }
        $now ??= Dates::now();
        $today = Dates::todayLocal($now);
        $past = Schedule::between($p, Dates::addDays($today, -400), $today);
        if ($past) return end($past);
        $next = Schedule::next($p, $now);
        if ($next) return $next;
        $all = Schedule::between($p, '1900-01-01', '2999-12-31');
        return $all ? end($all) : null;
    }

    public static function isActive(array $o, ?\DateTimeInterface $now = null): bool
    {
        return Schedule::localDate($o['starts_at']) <= Dates::todayLocal($now);
    }

    private static function hasEnded(array $o, ?\DateTimeInterface $now = null): bool
    {
        return $o['ends_at'] < ($now ?? Dates::now());
    }

    private static function closureOf(int $programId, string $date): ?object
    {
        return DB::table('attendance_closures')->where(['program_id' => $programId, 'occurrence_date' => $date])->first(['closed_at', 'closed_by']);
    }

    private static function isClosed(object $p, array $o, ?\DateTimeInterface $at = null): bool
    {
        $at ??= Dates::now();
        if (self::hasEnded($o, $at)) return true;
        $c = self::closureOf($p->id, $o['date']);
        return (bool) ($c && Dates::of($c->closed_at) <= $at);
    }

    /** Members of these groups mark attendance without signing (HR setting, audited). */
    public static function signatureExempt(?string $memberGroup): bool
    {
        return $memberGroup !== null && in_array($memberGroup, Settings::signaturePolicy()['exempt_groups'], true);
    }

    public static function groupsOf(object $p): array
    {
        return $p->member_groups ? array_values(array_filter(explode(',', $p->member_groups))) : [];
    }

    private static function inGroups(Builder $qb, object $p): Builder
    {
        $groups = self::groupsOf($p);
        if ($groups) $qb->whereIn('u.member_group', $groups);
        return $qb;
    }

    private static function assertInGroups(object $p, int $userId): void
    {
        if (! self::inGroups(MemberIds::memberAccounts(DB::table('users as u')), $p)->where('u.id', $userId)->exists()) {
            throw ApiError::conflict('MEMBER_NOT_EXPECTED', "This member is not in the program's target group");
        }
    }

    public static function hasLinkedClasses(int $programId): bool
    {
        return Schema::hasTable('program_edu_classes')
            && DB::table('program_edu_classes')->where('program_id', $programId)->exists();
    }

    private static function expectedMembers(object $p, string $occurrenceDate): Builder
    {
        if (self::hasLinkedClasses($p->id)) {
            $classIds = DB::table('program_edu_classes')->where('program_id', $p->id)->pluck('class_id')->all();
            $q = MemberIds::memberAccounts(DB::table('users as u'))
                ->join('edu_enrollments as e', 'e.user_id', '=', 'u.id')
                ->where('e.status', 'active')
                ->whereIn('e.class_id', $classIds ?: [0])
                ->where(['u.status' => 'active', 'u.membership_status' => 'active']);

            // Filter by occurrence's academic year if defined
            $yearId = null;
            if (Schema::hasTable('edu_academic_years')) {
                $yearId = DB::table('edu_academic_years')
                    ->where('starts_on', '<=', $occurrenceDate)
                    ->where('ends_on', '>=', $occurrenceDate)
                    ->value('id');
                if (! $yearId) {
                    $yearId = DB::table('edu_academic_years')->where('is_current', 1)->value('id');
                }
            }
            if ($yearId) {
                $q->where(fn ($w) => $w->where('e.academic_year_id', $yearId)->orWhereNull('e.academic_year_id'));
            }

            // Filter by course eligible groups where courses are linked
            if (Schema::hasTable('program_edu_courses')) {
                $linkedCourses = DB::table('program_edu_courses as pc')
                    ->join('edu_courses as co', 'co.id', '=', 'pc.course_id')
                    ->where('pc.program_id', $p->id)
                    ->whereNotNull('co.member_groups')
                    ->where('co.member_groups', '!=', '')
                    ->pluck('co.member_groups')
                    ->all();
                if ($linkedCourses) {
                    $allowedGroups = [];
                    foreach ($linkedCourses as $csv) {
                        foreach (explode(',', (string) $csv) as $g) {
                            $g = trim($g);
                            if ($g !== '') $allowedGroups[$g] = true;
                        }
                    }
                    if ($allowedGroups) {
                        $q->whereIn('u.member_group', array_keys($allowedGroups));
                    }
                }
            }

            $q->distinct();
            return $q;
        }

        $q = MemberIds::memberAccounts(DB::table('users as u'))->where(['u.status' => 'active', 'u.membership_status' => 'active']);
        self::inGroups($q, $p);
        if ($p->audience === 'participants') {
            $q->join('program_participants as pp', 'pp.user_id', '=', 'u.id')->where('pp.program_id', $p->id)->whereIn('pp.status', ['invited', 'registered']);
        } else {
            // joined by the end of that local day
            $q->where('u.created_at', '<', Dates::sql(Dates::fromLocal("$occurrenceDate 23:59:59")));
        }
        return $q;
    }

    private static function assertExpected(object $p, string $date, int $userId): void
    {
        if (! self::expectedMembers($p, $date)->where('u.id', $userId)->exists()) {
            throw ApiError::conflict('MEMBER_NOT_EXPECTED', 'This member is not expected at this program');
        }
    }

    /** Roster of one occurrence: every expected member (plus anyone marked) with their status. */
    public static function roster(int $programId, array $f, array $page, ?AuthContext $auth = null): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $f['date'] ?? null);
        $session = AttendanceSessions::serialize(AttendanceSessions::of($p, $o), $p, $o, $auth);
        $closed = self::isClosed($p, $o);
        $expected = self::expectedMembers($p, $o['date'])->select('u.id');
        $qb = DB::table('users as u')
            ->leftJoin('attendance as a', fn ($j) => $j->on('a.user_id', '=', 'u.id')->where('a.program_id', '=', $programId)->where('a.occurrence_date', '=', $o['date']))
            ->leftJoin('program_participants as pp', fn ($j) => $j->on('pp.user_id', '=', 'u.id')->where('pp.program_id', '=', $programId))
            ->leftJoin('users as rec', 'rec.id', '=', 'a.recorded_by')
            ->leftJoin('roles as rr', 'rr.id', '=', 'rec.role_id');
        MemberIds::memberAccounts($qb);
        $qb->select('u.id as user_id', 'u.full_name', 'u.member_no', 'u.member_group', 'u.phone', 'u.profile_image', 'pp.status as participation', 'a.id as attendance_id', 'a.status', 'a.attended_at', 'a.notes', 'a.via',
            'a.session_id', 'a.elapsed_seconds', 'a.time_source', 'a.source', 'a.signature_id', 'a.signature_exempt', Actor::hiddenName('rec', 'rr', 'recorded_by_name'))
            ->orderBy('u.full_name');
        if (($f['source'] ?? 'participants') === 'participants') {
            $qb->where(fn ($w) => $w->whereIn('u.id', $expected)->orWhereNotNull('a.id'));
        } else {
            $pool = self::inGroups(MemberIds::memberAccounts(DB::table('users as u'))->where('u.status', 'active'), $p)->select('u.id');
            $qb->where(fn ($w) => $w->whereIn('u.id', $pool)->orWhereNotNull('a.id'));
        }
        MemberIds::search($qb, $f['q'] ?? null);
        $status = $f['status'] ?? null;
        if ($status === 'unmarked' || $status === 'absent') $qb->where(fn ($w) => $w->whereNull('a.id')->orWhere('a.status', 'absent'));
        elseif ($status === 'present') $qb->whereIn('a.status', ['present', 'late']);
        elseif ($status) $qb->where('a.status', $status);
        $res = Page::paginate($qb, $page);
        $items = array_map(function ($r) use ($closed) {
            $r->status = $r->status ?? ($closed ? 'absent' : 'unmarked');
            $r->marked = (bool) $r->attendance_id;
            // Recorded before attendance sessions existed (the old present / late marks).
            $r->legacy = $r->attendance_id && ! $r->session_id;
            // There is no late status any more: an old "late" mark is attendance (kept for history).
            $r->legacy_late = $r->status === 'late';
            if ($r->legacy_late) $r->status = 'present';
            $r->signed = (bool) $r->signature_id;
            return $r;
        }, MemberIds::decorate($res['items']));

        $uids = array_column($items, 'user_id');
        $userClasses = [];
        if ($uids && Schema::hasTable('edu_enrollments')) {
            $cRows = DB::table('edu_enrollments as e')
                ->join('edu_classes as c', 'c.id', '=', 'e.class_id')
                ->whereIn('e.user_id', $uids)
                ->where('e.status', 'active')
                ->select('e.user_id', 'c.name')
                ->get();
            foreach ($cRows as $cr) {
                $userClasses[$cr->user_id][] = $cr->name;
            }
        }
        foreach ($items as &$it) {
            $it->classes = implode(', ', array_unique($userClasses[$it->user_id] ?? []));
        }

        return [
            'items' => $items,
            'meta' => $res['meta'] + [
                'occurrence' => ['date' => $o['date'], 'starts_at' => $o['starts_at'], 'ends_at' => $o['ends_at'], 'active' => self::isActive($o), 'ended' => self::hasEnded($o), 'closed' => $closed, 'rescheduled' => ! empty($o['rescheduled'])],
                'session' => $session,
                'signature_policy' => Settings::signaturePolicy(),
                'summary' => self::summary($programId, $o['date']),
            ],
        ];
    }

    /** absent = expected but not marked (only once closed). */
    public static function summary(int $programId, ?string $date): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $date);
        $counts = ['present' => 0, 'late' => 0, 'excused' => 0, 'absent' => 0];
        foreach (DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $o['date']])->groupBy('status')->select('status', DB::raw('COUNT(*) as c'))->get() as $r) {
            $counts[$r->status] = (int) $r->c;
        }
        $expected = self::expectedMembers($p, $o['date'])->count();
        $marked = $counts['present'] + $counts['late'] + $counts['excused'];
        $unmarked = max(0, $expected - $marked - $counts['absent']);
        $ended = self::isClosed($p, $o);
        // No late status any more: a legacy "late" row counts as present (kept apart for history).
        $legacyLate = $counts['late'];
        unset($counts['late']);
        $counts['present'] += $legacyLate;
        // array_merge: the closed occurrence's unmarked members are absent (the "+" operator kept the raw count).
        return array_merge(['date' => $o['date'], 'expected' => $expected], $counts, ['legacy_late' => $legacyLate, 'absent' => $counts['absent'] + ($ended ? $unmarked : 0), 'unmarked' => $ended ? 0 : $unmarked, 'participants' => $expected]);
    }

    /**
     * Write one mark of a session. [$m]: status, notes, via, attended_at (the capture time),
     * client_captured_at, received_at, elapsed_seconds, time_source, session_id, signature_exempt,
     * source, client_event_id.
     */
    private static function upsert(array $actx, object $p, string $date, int $userId, array $m): array
    {
        $status = $m['status'];
        $existing = DB::table('attendance')->where(['program_id' => $p->id, 'occurrence_date' => $date, 'user_id' => $userId])->first(['id', 'status']);
        $row = [
            'status' => $status, 'attended_at' => isset($m['attended_at']) ? Dates::sql($m['attended_at']) : null, 'notes' => $m['notes'] ?? null, 'via' => $m['via'] ?? 'manual',
            'updated_by' => $actx['auth']->id,
            'session_id' => $m['session_id'] ?? null, 'client_captured_at' => isset($m['client_captured_at']) ? Dates::sql($m['client_captured_at']) : null,
            'received_at' => Dates::sql($m['received_at'] ?? Dates::now()), 'elapsed_seconds' => $m['elapsed_seconds'] ?? null, 'time_source' => $m['time_source'] ?? null,
            'signature_exempt' => ! empty($m['signature_exempt']) ? 1 : 0, 'source' => $m['source'] ?? null, 'client_event_id' => $m['client_event_id'] ?? null,
        ];
        if ($existing) {
            DB::table('attendance')->where('id', $existing->id)->update($row);
            $id = (int) $existing->id;
        } else {
            $id = (int) DB::table('attendance')->insertGetId($row + ['program_id' => $p->id, 'occurrence_date' => $date, 'user_id' => $userId, 'recorded_by' => $m['recorded_by'] ?? $actx['auth']->id]);
        }
        if ($status === 'present') {
            Activity::track($userId, Activity::ATTENDANCE, 'program', $p->id, ['status' => $status, 'date' => $date], inTrx: true);
        }
        return ['id' => $id, 'isNew' => ! $existing, 'previous' => $existing?->status];
    }

    private static function attachSignature(int $attendanceId, int $userId, array $sig, int $capturedBy, ?string $eventId, \DateTimeInterface $signedAt): void
    {
        $sid = DB::table('attendance_signatures')->insertGetId([
            'attendance_id' => $attendanceId, 'user_id' => $userId, 'path' => $sig['path'], 'sha256' => $sig['sha256'],
            'signed_at' => Dates::sql($signedAt), 'captured_by' => $capturedBy, 'client_event_id' => $eventId,
        ]);
        DB::table('attendance')->where('id', $attendanceId)->update(['signature_id' => $sid]);
    }

    /** The session's taker is the only one who records (HR assigns; holding a permission is not enough). */
    private static function assertTaker(AuthContext $auth, object $s): void
    {
        if (! $s->taker_id) throw ApiError::forbidden('NO_ATTENDANCE_TAKERS_ASSIGNED', 'HR has not assigned an attendance taker for this occurrence');
        if ((int) $s->taker_id !== $auth->id) throw ApiError::forbidden('NOT_SESSION_TAKER', 'Only the assigned attendance taker can record attendance for this occurrence');
    }

    /** Who recorded an existing mark, and when (for "already recorded"). */
    private static function recordOf(int $programId, string $date, int $userId): ?array
    {
        $r = DB::table('attendance as a')->leftJoin('users as rec', 'rec.id', '=', 'a.recorded_by')->leftJoin('roles as rr', 'rr.id', '=', 'rec.role_id')
            ->where(['a.program_id' => $programId, 'a.occurrence_date' => $date, 'a.user_id' => $userId])
            ->first(['a.status', 'a.via', 'a.attended_at', 'a.created_at', Actor::hiddenName('rec', 'rr', 'recorded_by_name')]);
        return $r ? ['status' => $r->status === 'late' ? 'present' : $r->status, 'via' => $r->via, 'attended_at' => $r->attended_at, 'recorded_at' => $r->created_at, 'recorded_by_name' => $r->recorded_by_name] : null;
    }

    /**
     * Step 1 of taking attendance (QR scan or manual pick): who is this, may they be recorded now,
     * and must they sign. Nothing is written; the taker checks the photo, the member signs, then
     * the mark is recorded.
     */
    public static function identify(AuthContext $auth, int $programId, array $in): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $in['date'] ?? null);
        $s = AttendanceSessions::of($p, $o);
        $userId = ! empty($in['uuid']) ? Members::idByUuid($in['uuid']) : (int) ($in['user_id'] ?? 0);
        $u = MemberIds::memberAccounts(DB::table('users as u'))->where('u.id', $userId)
            ->first(['u.id', 'u.full_name', 'u.profile_image', 'u.member_no', 'u.member_group', 'u.member_type', 'u.status', 'u.membership_status']);
        if (! $u) throw ApiError::notFound('MEMBER_NOT_FOUND', 'Member not found');
        $now = Dates::now();
        $existing = self::recordOf($programId, $o['date'], $userId);
        $groups = self::groupsOf($p);
        $reason = null;
        if (! $s->taker_id) $reason = 'NO_ATTENDANCE_TAKERS_ASSIGNED';
        elseif ((int) $s->taker_id !== $auth->id) $reason = 'NOT_SESSION_TAKER';
        elseif (! $s->started_at) $reason = 'SESSION_NOT_STARTED';
        elseif (! AttendanceSessions::acceptsAt($s, $o, $now)) $reason = 'ATTENDANCE_CLOSED';
        elseif ($userId === $auth->id) $reason = 'SELF_ATTENDANCE_NOT_ALLOWED';
        elseif (! self::hasLinkedClasses($p->id) && $groups && ! in_array($u->member_group, $groups, true)) $reason = 'MEMBER_NOT_IN_GROUP';
        elseif (! self::expectedMembers($p, $o['date'])->where('u.id', $userId)->exists()) $reason = 'MEMBER_NOT_EXPECTED';
        elseif ($existing && $existing['status'] === 'present') $reason = 'ATTENDANCE_ALREADY_RECORDED';
        return [
            'member' => [
                'id' => $u->id, 'full_name' => $u->full_name, 'avatar_url' => Storage::url($u->profile_image),
                'member_id' => MemberIds::format($u->member_no, $u->member_group), 'member_group' => $u->member_group,
                'member_group_name' => MemberGroups::name($u->member_group), 'member_group_name_en' => MemberGroups::name($u->member_group, 'en'),
                'member_type' => $u->member_type, 'membership_status' => $u->membership_status, 'status' => $u->status,
            ],
            'program' => ['id' => $p->id, 'title' => $p->title, 'member_groups' => $groups],
            'occurrence' => ['date' => $o['date'], 'starts_at' => $o['starts_at'], 'ends_at' => $o['ends_at'], 'active' => self::isActive($o, $now), 'closed' => self::isClosed($p, $o, $now)],
            'session' => AttendanceSessions::serialize($s, $p, $o, $auth),
            'eligible' => $reason === null,
            'reason' => $reason,
            'attendance' => $existing,
            'would_record' => $reason === null ? 'present' : null,
            'signature_required' => ! self::signatureExempt($u->member_group),
        ];
    }

    /**
     * Record one member (the session's taker). [$capture] for offline work: at (capture time,
     * adjusted to the server clock), client_raw (the phone's own time), offline, event_id.
     * present needs the member's signature (PNG data URL) unless their group is exempt; excused needs
     * a reason. Outside the session (not started / ended) nothing is written: corrections instead.
     */
    public static function set(array $actx, int $programId, int $userId, array $input, array $capture = []): array
    {
        $notify = false;
        $date = null;
        $duplicate = false;
        $savedSig = null;
        /** @var AuthContext $auth */
        $auth = $actx['auth'];
        $status = $input['status'] ?? 'present';
        if ($status === 'late') throw ApiError::field('status', 'LATE_REMOVED');
        if ($status === 'absent') throw ApiError::field('status', 'ABSENT_IS_AUTOMATIC');
        if (! in_array($status, self::MARKABLE, true)) throw ApiError::field('status', 'INVALID_STATUS');
        $run = function () use ($actx, $auth, $programId, $userId, $input, $capture, $status, &$notify, &$date, &$duplicate, &$savedSig) {
            $p = self::getProgram($programId);
            $o = self::resolveOccurrence($p, $input['date'] ?? null);
            $date = $o['date'];
            $s = AttendanceSessions::of($p, $o, true);
            self::assertTaker($auth, $s);
            $u = MemberIds::memberAccounts(DB::table('users as u'))->where('u.id', $userId)->first(['u.id', 'u.member_group']);
            if (! $u) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
            // Marks of the same member are serialised on the member's row.
            DB::table('users')->where('id', $userId)->lockForUpdate()->first(['id']);
            $now = Dates::now();
            $at = $capture['at'] ?? $now;
            if ($at > $now) $at = $now;
            if (! $s->started_at) throw ApiError::conflict('SESSION_NOT_STARTED', 'Start the attendance session first');
            if (! AttendanceSessions::acceptsAt($s, $o, $at)) {
                throw $at < Dates::of($s->started_at)
                    ? ApiError::conflict('BEFORE_SESSION_START', 'This was captured before the session started')
                    : ApiError::conflict('ATTENDANCE_CLOSED', 'Attendance for this session is closed; submit a correction request');
            }
            if ($userId === $auth->id) throw ApiError::forbidden('SELF_ATTENDANCE_NOT_ALLOWED', 'Another attendance taker must record your attendance');
            if (! self::hasLinkedClasses($p->id)) self::assertInGroups($p, $userId);
            self::assertExpected($p, $o['date'], $userId);
            $existing = DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $o['date'], 'user_id' => $userId])->lockForUpdate()->first(['id', 'status', 'client_event_id']);
            $eventId = $capture['event_id'] ?? null;
            if ($existing && $eventId && $existing->client_event_id === $eventId) {
                $duplicate = true; // the same event, replayed
                return;
            }
            // A second scan of someone already present changes nothing (no second signature either).
            if ($existing && in_array($existing->status, ['present', 'late'], true)) {
                $duplicate = true;
                return;
            }
            $exempt = false;
            if ($status === 'excused') {
                if (! trim((string) ($input['notes'] ?? ''))) throw ApiError::field('notes', 'REASON_REQUIRED');
            } else {
                $exempt = self::signatureExempt($u->member_group);
                if (! $exempt && empty($input['signature'])) throw ApiError::field('signature', 'SIGNATURE_REQUIRED');
                if (! empty($input['signature'])) $savedSig = Storage::save('signature', Storage::FOLDERS['SIGNATURES'], Storage::decodeDataUrl($input['signature']));
            }
            $offline = ! empty($capture['at']);
            $r = self::upsert($actx, $p, $o['date'], $userId, [
                'status' => $status, 'attended_at' => $status === 'present' ? $at : null, 'notes' => $input['notes'] ?? null, 'via' => $input['via'] ?? 'manual',
                'session_id' => (int) $s->id, 'client_captured_at' => $capture['client_raw'] ?? null, 'received_at' => $now,
                'elapsed_seconds' => $status === 'present' ? max(0, $at->getTimestamp() - Dates::of($s->started_at)->getTimestamp()) : null,
                'time_source' => $offline ? 'device' : 'server', 'signature_exempt' => $exempt && empty($input['signature']),
                'source' => ! empty($capture['offline']) ? 'offline' : 'online', 'client_event_id' => $eventId,
            ]);
            if ($savedSig) self::attachSignature($r['id'], $userId, $savedSig, $auth->id, $eventId, $at);
            if (self::hasLinkedClasses($p->id) && Schema::hasTable('attendance_edu_classes')) {
                $classIds = DB::table('program_edu_classes as pc')
                    ->join('edu_enrollments as e', 'e.class_id', '=', 'pc.class_id')
                    ->where('pc.program_id', $programId)
                    ->where('e.user_id', $userId)
                    ->where('e.status', 'active')
                    ->pluck('pc.class_id')
                    ->all();
                foreach ($classIds as $cid) {
                    DB::table('attendance_edu_classes')->upsert(
                        [['attendance_id' => $r['id'], 'class_id' => $cid]],
                        ['attendance_id', 'class_id'],
                        []
                    );
                }
            }
            Audit::log($actx, Audit::ATTENDANCE_SET, 'attendance', $programId, [
                'user_id' => $userId, 'date' => $o['date'], 'status' => $status, 'previous' => $r['previous'], 'via' => $input['via'] ?? 'manual', 'reason' => $input['notes'] ?? null,
                'session_id' => (int) $s->id, 'captured_at' => Dates::sql($at), 'signed' => (bool) $savedSig, 'source' => ! empty($capture['offline']) ? 'offline' : 'online',
            ], inTrx: true);
            if ($status === 'present') {
                $notify = Notifications::createForUsers([$userId], [
                    'type' => 'attendance',
                    'title' => T::t('attendance.recorded.title'),
                    'body' => T::t('attendance.recorded.body', ['title' => $p->title]),
                    'entityType' => 'program',
                    'entityId' => $programId,
                    'dedupeKey' => fn ($uid) => "attendance:$programId:{$o['date']}:$uid",
                ]) > 0;
            }
        };
        try {
            DB::transaction($run);
        } catch (\Illuminate\Database\QueryException $e) {
            if ($savedSig) Storage::remove($savedSig['path']);
            // The unique key (program, date, member) refused a second row: another request was first.
            if ((int) ($e->errorInfo[1] ?? 0) !== 1062 || $date === null) throw $e;
            $duplicate = true;
            $notify = false;
        } catch (\Throwable $e) {
            if ($savedSig) Storage::remove($savedSig['path']);
            throw $e;
        }
        if ($duplicate && $savedSig) Storage::remove($savedSig['path']);
        if ($notify) Notifications::kick();
        if (! $duplicate) Choir::scheduleEligibility([$userId]);
        $rec = DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $date, 'user_id' => $userId])->first();
        $out = array_merge((array) $rec, ['duplicate' => $duplicate]);
        if ($duplicate) $out['already_recorded'] = self::recordOf($programId, $date, $userId);
        return $out;
    }

    /** Several members excused at once (reason required). "Present" is signed one by one. */
    public static function bulkSet(array $actx, int $programId, array $in, bool $allowAll): array
    {
        $auth = $actx['auth'];
        if (($in['status'] ?? null) !== 'excused') throw ApiError::field('status', 'SIGNATURE_REQUIRED');
        $notes = $in['notes'] ?? null;
        if (! trim((string) $notes)) throw ApiError::field('notes', 'REASON_REQUIRED');
        return DB::transaction(function () use ($actx, $auth, $programId, $in, $allowAll, $notes) {
            $p = self::getProgram($programId);
            $o = self::resolveOccurrence($p, $in['date'] ?? null);
            $s = AttendanceSessions::of($p, $o, true);
            self::assertTaker($auth, $s);
            $now = Dates::now();
            if (! $s->started_at) throw ApiError::conflict('SESSION_NOT_STARTED', 'Start the attendance session first');
            if (! AttendanceSessions::acceptsAt($s, $o, $now)) throw ApiError::conflict('ATTENDANCE_CLOSED', 'Attendance for this session is closed; submit a correction request');
            $expected = array_flip(self::expectedMembers($p, $o['date'])->pluck('u.id')->all());
            $target = $in['target'];
            $picked = ! empty($target['user_ids']) ? array_values(array_filter($target['user_ids'], fn ($u) => ! in_array($u, $target['exclude_ids'] ?? [], true))) : Targeting::resolve($target, $allowAll);
            $present = array_flip(DB::table('attendance')->where(['program_id' => $programId, 'occurrence_date' => $o['date']])->whereIn('status', ['present', 'late'])->pluck('user_id')->all());
            $ids = [];
            foreach (array_values(array_unique($picked)) as $uid) {
                if ($uid !== $auth->id && isset($expected[$uid]) && ! isset($present[$uid])) $ids[] = $uid;
            }
            foreach ($ids as $uid) self::upsert($actx, $p, $o['date'], $uid, ['status' => 'excused', 'notes' => $notes, 'via' => 'manual', 'session_id' => (int) $s->id, 'received_at' => $now, 'time_source' => 'server', 'source' => 'online']);
            Choir::scheduleEligibility($ids);
            Audit::log($actx, Audit::ATTENDANCE_BULK, 'attendance', $programId, ['count' => count($ids), 'status' => 'excused', 'date' => $o['date'], 'reason' => $notes, 'session_id' => (int) $s->id], inTrx: true);
            return ['updated' => count($ids), 'status' => 'excused', 'date' => $o['date']];
        });
    }

    /** The taker removes a mistaken mark while the session runs (reason kept); afterwards: corrections. */
    public static function remove(array $actx, int $programId, int $userId, ?string $date, ?string $reason): void
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $date);
        $s = AttendanceSessions::of($p, $o);
        self::assertTaker($actx['auth'], $s);
        if (! $s->started_at || ! AttendanceSessions::acceptsAt($s, $o, Dates::now())) throw ApiError::conflict('ATTENDANCE_CLOSED', 'Attendance for this session is closed; submit a correction request');
        if (! trim((string) $reason)) throw ApiError::field('reason', 'REASON_REQUIRED');
        $key = ['program_id' => $programId, 'occurrence_date' => $o['date'], 'user_id' => $userId];
        $prev = DB::table('attendance')->where($key)->first(['id', 'status', 'signature_id']);
        if (! $prev) throw ApiError::notFound('ATTENDANCE_NOT_FOUND', 'Attendance not found');
        DB::table('attendance')->where('id', $prev->id)->delete();
        Choir::scheduleEligibility([$userId]);
        // The signature record stays (attendance_signatures) for the audit trail.
        Audit::log($actx, Audit::ATTENDANCE_SET, 'attendance', $programId, ['user_id' => $userId, 'date' => $o['date'], 'status' => 'removed', 'previous' => $prev->status, 'reason' => $reason, 'session_id' => (int) $s->id, 'signature_id' => $prev->signature_id]);
    }

    /** End the occurrence's session (HR: attendance.close; or the taker). */
    public static function close(array $actx, int $programId, ?string $date): array
    {
        $out = AttendanceSessions::end($actx, $programId, $date);
        return ['date' => $out['date'], 'closed' => true, 'session' => $out];
    }

    /**
     * Apply an offline record HR accepted from the conflict queue: written as captured (its own
     * capture time and signature, recorded by the taker who captured it). Null = already recorded.
     */
    public static function applyAcceptedConflict(array $actx, object $c, array $payload): ?int
    {
        $p = self::getProgram((int) $c->program_id);
        $d = Dates::toDateOnly($c->occurrence_date);
        $o = Schedule::on($p, $d);
        if (! $o) throw ApiError::conflict('NOT_AN_OCCURRENCE', 'This occurrence no longer exists');
        $existing = DB::table('attendance')->where(['program_id' => $p->id, 'occurrence_date' => $d, 'user_id' => $c->user_id])->first(['id', 'status']);
        $status = in_array($payload['status'] ?? 'present', self::MARKABLE, true) ? $payload['status'] : 'present';
        if ($existing && ($existing->status === 'present' || $existing->status === 'late' || $existing->status === $status)) return null;
        $s = AttendanceSessions::of($p, $o);
        $at = $c->captured_at ? Dates::of($c->captured_at) : null;
        $r = self::upsert($actx, $p, $d, (int) $c->user_id, [
            'status' => $status, 'attended_at' => $status === 'present' ? $at : null, 'notes' => $payload['notes'] ?? null, 'via' => $payload['via'] ?? 'manual',
            'session_id' => (int) $s->id, 'client_captured_at' => $c->client_captured_at, 'received_at' => Dates::now(),
            'elapsed_seconds' => $status === 'present' && $at && $s->started_at ? max(0, $at->getTimestamp() - Dates::of($s->started_at)->getTimestamp()) : null,
            'time_source' => 'device', 'source' => 'offline', 'recorded_by' => (int) $c->submitted_by,
        ]);
        if ($c->signature_path) self::attachSignature($r['id'], (int) $c->user_id, ['path' => $c->signature_path, 'sha256' => $c->signature_sha256], (int) $c->submitted_by, null, $at ?? Dates::now());
        return $r['id'];
    }

    /** The member's signature of a mark (HR / reports). */
    public static function signatureFile(int $attendanceId): array
    {
        $sid = DB::table('attendance')->where('id', $attendanceId)->value('signature_id');
        $sig = $sid ? DB::table('attendance_signatures')->where('id', $sid)->first(['path']) : null;
        if (! $sig) throw ApiError::notFound('SIGNATURE_NOT_FOUND', 'No signature');
        return ['abs' => Storage::privatePath($sig->path), 'mime' => 'image/png'];
    }

    // ------------------------------------------------------------------ comments and correction requests
    private static function currentStatus(object $p, array $o, int $userId): string
    {
        $a = DB::table('attendance')->where(['program_id' => $p->id, 'occurrence_date' => $o['date'], 'user_id' => $userId])->first(['status']);
        return $a?->status ?? (self::isClosed($p, $o) ? 'absent' : 'unmarked');
    }

    public static function requestCorrection(array $actx, int $programId, int $userId, array $in): array
    {
        $p = self::getProgram($programId);
        $o = self::resolveOccurrence($p, $in['date'] ?? null);
        if (! MemberIds::memberAccounts(DB::table('users as u'))->where('u.id', $userId)->exists()) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        self::assertInGroups($p, $userId);

        $reason = trim((string) ($in['reason'] ?? ''));
        if (empty($reason)) {
            throw ApiError::validation([['field' => 'reason', 'code' => 'REASON_REQUIRED', 'message' => 'A valid reason is required for attendance correction requests.']]);
        }

        // Block corrections when no independent HR approver is available
        $approvers = array_values(array_unique(array_merge(
            \App\Mz\Auth\Holders::of('attendance.correction.approve'),
            \App\Mz\Auth\Holders::of('hr.corrections')
        )));
        $eligibleApprovers = array_filter($approvers, fn ($u) => (int) $u !== $actx['auth']->id && (int) $u !== $userId);
        if (empty($eligibleApprovers)) {
            throw ApiError::conflict('NO_ELIGIBLE_HR_APPROVER', 'No authorized HR approver is currently available to review this correction. An independent HR approver must be designated.');
        }

        $original = self::currentStatus($p, $o, $userId);
        $requested = $in['requested_status'] ?? null;
        if ($requested === 'late') throw ApiError::field('requested_status', 'LATE_REMOVED');
        // "Present" may say when the member actually arrived (scored from the session's start).
        $arrived = $requested === 'present' && ! empty($in['attended_at']) ? Dates::of($in['attended_at']) : null;
        if ($arrived && ($arrived < Dates::of($o['starts_at'])->modify('-' . AttendanceSessions::AVAILABLE_BEFORE_MINUTES . ' minutes') || $arrived > Dates::of($o['ends_at']))) throw ApiError::field('attended_at', 'OUTSIDE_OCCURRENCE');
        $id = DB::table('attendance_corrections')->insertGetId([
            'program_id' => $programId, 'occurrence_date' => $o['date'], 'user_id' => $userId, 'original_status' => $original, 'requested_status' => $requested,
            'requested_attended_at' => $arrived ? Dates::sql($arrived) : null, 'reason' => $reason, 'requested_by' => $actx['auth']->id,
        ]);
        Audit::log($actx, Audit::ATTENDANCE_CORRECTION_REQUEST, 'attendance_correction', $id, ['program_id' => $programId, 'date' => $o['date'], 'user_id' => $userId, 'original' => $original, 'requested' => $requested, 'reason' => $reason]);
        $member = DB::table('users')->where('id', $userId)->value('full_name');
        Notifications::createForUsers(array_values(array_filter($eligibleApprovers, fn ($u) => (int) $u !== $actx['auth']->id)), [
            'type' => 'attendance',
            'title' => T::t('attendance.correction.requested.title'),
            'body' => T::t('attendance.correction.requested.body', ['name' => $member, 'title' => $p->title, 'date' => \App\Mz\Services\ReportExport::ethiopianDate($o['date'] . ' 12:00:00'), 'by' => $actx['auth']->fullName]),
            'entityType' => 'program',
            'entityId' => $programId,
            'dedupeKey' => fn ($uid) => "correction:$id:requested:$uid",
        ]);
        return self::correction($id);
    }

    private static function correctionQuery(): Builder
    {
        return DB::table('attendance_corrections as c')->join('programs as p', 'p.id', '=', 'c.program_id')->join('users as u', 'u.id', '=', 'c.user_id')
            ->leftJoin('users as rq', 'rq.id', '=', 'c.requested_by')->leftJoin('users as rv', 'rv.id', '=', 'c.reviewed_by');
    }

    public static function correction(int $id): array
    {
        $r = self::correctionQuery()->where('c.id', $id)->first(['c.*', 'p.title as program_title', 'u.full_name', 'rq.full_name as requested_by_name', 'rv.full_name as reviewed_by_name']);
        if (! $r) throw ApiError::notFound('CORRECTION_NOT_FOUND', 'Correction request not found');
        $r->occurrence_date = Dates::toDateOnly($r->occurrence_date);
        return (array) $r;
    }

    public static function listCorrections(AuthContext $auth, array $f, array $page): array
    {
        $qb = self::correctionQuery()->orderByDesc('c.created_at')->select('c.*', 'p.title as program_title', 'u.full_name', 'rq.full_name as requested_by_name', 'rv.full_name as reviewed_by_name');
        if (! $auth->can('attendance.correction.approve')) $qb->where('c.requested_by', $auth->id);
        if (! empty($f['status'])) $qb->where('c.status', $f['status']);
        if (! empty($f['program_id'])) $qb->where('c.program_id', $f['program_id']);
        $res = Page::paginate($qb, $page);
        $res['items'] = array_map(function ($r) {
            $r->occurrence_date = Dates::toDateOnly($r->occurrence_date);
            return $r;
        }, $res['items']);
        return $res;
    }

    /** Approve (applies the requested status, even after closure) or reject. */
    public static function reviewCorrection(array $actx, int $id, string $decision, ?string $note): array
    {
        $userId = null;
        DB::transaction(function () use ($actx, $id, $decision, $note, &$userId) {
            $c = DB::table('attendance_corrections')->where('id', $id)->lockForUpdate()->first();
            if (! $c) throw ApiError::notFound('CORRECTION_NOT_FOUND', 'Correction request not found');
            if ($c->status !== 'pending') throw ApiError::conflict('CORRECTION_REVIEWED', 'This request was already reviewed');

            $reviewer = $actx['auth'];
            if (! $reviewer->can('attendance.correction.approve') && ! $reviewer->can('hr.corrections')) {
                throw ApiError::forbidden('NOT_AUTHORIZED_HR_APPROVER', 'Only authorized HR approvers can review attendance corrections.');
            }
            if ($reviewer->id === (int) $c->requested_by || $reviewer->id === (int) $c->user_id) {
                throw ApiError::forbidden('SELF_APPROVAL_FORBIDDEN', 'Self-approval is strictly forbidden. Another authorized HR approver must decide this correction request.');
            }

            $userId = $c->user_id;
            $p = self::getProgram($c->program_id);
            $d = Dates::toDateOnly($c->occurrence_date);
            $o = Schedule::on($p, $d) ?? ['date' => $d, 'starts_at' => Dates::now(), 'ends_at' => new UtcDateTime('@0')];
            $before = self::currentStatus($p, $o, $c->user_id);
            $final = $before;
            if ($decision === 'approve' && $c->requested_status) {
                if ($c->requested_status === 'absent') {
                    DB::table('attendance')->where(['program_id' => $c->program_id, 'occurrence_date' => $o['date'], 'user_id' => $c->user_id])->delete();
                } else {
                    // A corrected "present" keeps the stated arrival time (scored from the session's
                    // official start); without one it has no elapsed time (time_source = correction).
                    $sess = isset($o['starts_at']) && Schedule::on($p, $o['date']) ? AttendanceSessions::of($p, $o) : null;
                    $arrived = $c->requested_status === 'present' && $c->requested_attended_at ? Dates::of($c->requested_attended_at) : null;
                    self::upsert($actx, $p, $o['date'], $c->user_id, [
                        'status' => $c->requested_status, 'notes' => mb_substr("correction #{$c->id}: {$c->reason}", 0, 500), 'via' => 'manual',
                        'attended_at' => $arrived, 'session_id' => $sess ? (int) $sess->id : null, 'time_source' => 'correction',
                        'elapsed_seconds' => $arrived && $sess && $sess->started_at ? max(0, $arrived->getTimestamp() - Dates::of($sess->started_at)->getTimestamp()) : null,
                    ]);
                }
                $final = $c->requested_status;
            }
            DB::table('attendance_corrections')->where('id', $id)->update(['status' => $decision === 'approve' ? 'approved' : 'rejected', 'reviewed_by' => $actx['auth']->id, 'review_note' => $note, 'final_status' => $final, 'reviewed_at' => DB::raw('NOW()')]);
            Audit::log($actx, Audit::ATTENDANCE_CORRECTION_REVIEW, 'attendance_correction', $id, [
                'decision' => $decision, 'original' => $c->original_status, 'requested' => $c->requested_status, 'before' => $before, 'final' => $final, 'note' => $note, 'program_id' => $c->program_id, 'date' => $o['date'], 'user_id' => $c->user_id,
            ], inTrx: true);
        });
        Choir::scheduleEligibility([$userId]);
        $c = self::correction($id);
        $key = $decision === 'approve' ? 'approved' : 'rejected';
        Notifications::createForUsers(array_filter([(int) $c['requested_by'], (int) $c['user_id']], fn ($u) => $u !== $actx['auth']->id), [
            'type' => 'attendance',
            'title' => T::t("attendance.correction.$key.title"),
            'body' => T::t("attendance.correction.$key.body", ['title' => $c['program_title'], 'date' => \App\Mz\Services\ReportExport::ethiopianDate($c['occurrence_date'] . ' 12:00:00'), 'note' => (string) $note]),
            'entityType' => 'program',
            'entityId' => (int) $c['program_id'],
            'email' => true,
            'dedupeKey' => fn ($uid) => "correction:$id:$key:$uid",
        ]);
        return $c;
    }

    // ------------------------------------------------------------------ member view
    private static function relevantPrograms(int $userId, ?array $categoryIds, ?array $programIds, ?string $memberGroup): array
    {
        $q = DB::table('programs as p')->leftJoin('program_categories as c', 'c.id', '=', 'p.category_id')
            ->whereIn('p.status', ['published', 'completed'])->where('p.requires_attendance', true)
            ->where(fn ($w) => $w->where('p.audience', 'all')->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_participants as pp')->whereColumn('pp.program_id', 'p.id')->where('pp.user_id', $userId)->whereIn('pp.status', ['invited', 'registered'])))
            ->select('p.*', 'c.name as category_name', 'c.name_en as category_name_en', 'c.color as category_color');
        if ($memberGroup) $q->where(fn ($w) => $w->whereNull('p.member_groups')->orWhere('p.member_groups', '')->orWhereRaw('FIND_IN_SET(?, p.member_groups)', [$memberGroup]));
        if (Schema::hasTable('program_edu_classes') && Schema::hasTable('edu_enrollments')) {
            $q->where(function ($w) use ($userId) {
                $w->whereNotExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec')->whereColumn('pec.program_id', 'p.id'))
                    ->orWhereExists(fn ($s) => $s->select(DB::raw(1))->from('program_edu_classes as pec')
                        ->join('edu_enrollments as ee', 'ee.class_id', '=', 'pec.class_id')
                        ->whereColumn('pec.program_id', 'p.id')
                        ->where('ee.user_id', $userId)
                        ->where('ee.status', 'active')
                    );
            });
        }
        if ($categoryIds) $q->whereIn('p.category_id', $categoryIds);
        if ($programIds) $q->whereIn('p.id', $programIds);
        return $q->get()->all();
    }

    /** Every occurrence a member was (or is) expected at: present|excused|absent|today|upcoming. */
    public static function memberOccurrences(int $userId, array $f = [], ?\DateTimeInterface $now = null): array
    {
        $now ??= Dates::now();
        $user = DB::table('users')->where('id', $userId)->first(['id', 'created_at', 'member_group']);
        if (! $user) throw ApiError::notFound('USER_NOT_FOUND', 'User not found');
        $joined = Schedule::localDate($user->created_at);
        $today = Dates::todayLocal($now);
        $start = max($f['from'] ?? $joined, $joined);
        $end = $f['to'] ?? $today;
        $programs = self::relevantPrograms($userId, $f['categoryIds'] ?? null, $f['programIds'] ?? null, $user->member_group);
        if (! $programs || $start > $end) return [];
        Schedule::loadOverrides($programs);
        $byKey = [];
        foreach (DB::table('attendance')->where('user_id', $userId)->whereIn('program_id', array_map(fn ($p) => $p->id, $programs))->whereBetween('occurrence_date', [$start, $end])->select('program_id', 'occurrence_date', 'status', 'attended_at', 'elapsed_seconds')->get() as $m) {
            // No late status any more: an old "late" mark counts (and shows) as attended.
            $byKey[$m->program_id . ':' . Dates::toDateOnly($m->occurrence_date)] = [
                'status' => $m->status === 'late' ? 'present' : $m->status,
                'attended_at' => $m->attended_at,
                'elapsed_seconds' => $m->elapsed_seconds !== null ? (int) $m->elapsed_seconds : null,
            ];
        }
        $out = [];
        foreach ($programs as $p) {
            foreach (Schedule::between($p, $start, $end) as $o) {
                $mark = $byKey["{$p->id}:{$o['date']}"] ?? null;
                $status = $mark ? $mark['status'] : ($o['ends_at'] < $now ? 'absent' : ($o['date'] === $today ? 'today' : 'upcoming'));
                $out[] = [
                    'program_id' => $p->id,
                    'title' => $p->title,
                    'location' => $p->location,
                    'category' => $p->category_id ? ['id' => $p->category_id, 'name' => $p->category_name, 'name_en' => $p->category_name_en, 'color' => $p->category_color] : null,
                    'date' => $o['date'],
                    'starts_at' => $o['starts_at'],
                    'ends_at' => $o['ends_at'],
                    'status' => $status,
                    'attended_at' => $mark['attended_at'] ?? null,
                    'elapsed_seconds' => $mark['elapsed_seconds'] ?? null,
                    'is_additional' => (bool) $p->is_additional,
                    'counts_for_selection' => (bool) $p->counts_for_selection,
                ];
            }
        }
        usort($out, fn ($a, $b) => $a['starts_at'] <=> $b['starts_at']);
        return $out;
    }

    public static function stats(int $userId, array $f = [], ?\DateTimeInterface $now = null): array
    {
        return self::statsOf(self::memberOccurrences($userId, $f, $now), Settings::permissionPolicy()['weight']);
    }

    /** The single attendance formula: present + excused×weight over past occurrences ('late' stays 0 for older apps). */
    public static function statsOf(array $occurrences, float|int $excusedWeight): array
    {
        $c = ['present' => 0, 'late' => 0, 'excused' => 0, 'absent' => 0];
        $upcoming = 0;
        foreach ($occurrences as $o) {
            if (isset($c[$o['status']])) $c[$o['status']]++;
            if ($o['status'] === 'upcoming' || $o['status'] === 'today') $upcoming++;
        }
        $total = $c['present'] + $c['late'] + $c['excused'] + $c['absent'];
        $score = $c['present'] + $c['late'] + $c['excused'] * $excusedWeight;
        return [
            'total_programs' => $total,
            'attended' => $c['present'],
            'late' => $c['late'],
            'excused' => $c['excused'],
            'absent' => $c['absent'],
            'excused_weight' => Num::clean($excusedWeight),
            'percentage' => $total ? Num::clean(floor(($score / $total) * 1000 + 0.5) / 10) : null,
            'upcoming' => $upcoming,
        ];
    }

    /** Calendar days in [from, to]: occurrences and the day's state (worst status wins). */
    public static function calendar(int $userId, string $from, string $to, ?array $categoryIds, ?\DateTimeInterface $now = null): array
    {
        $occ = self::memberOccurrences($userId, ['from' => $from, 'to' => $to, 'categoryIds' => $categoryIds], $now);
        $days = [];
        foreach ($occ as $o) $days[$o['date']][] = $o;
        $out = [];
        foreach ($days as $date => $items) {
            $state = null;
            foreach (self::DAY_PRIORITY as $s) {
                foreach ($items as $i) {
                    if ($i['status'] === $s) { $state = $s; break 2; }
                }
            }
            $out[] = ['date' => (string) $date, 'state' => $state, 'occurrences' => $items];
        }
        return ['from' => $from, 'to' => $to, 'days' => $out, 'stats' => self::statsOf($occ, Settings::permissionPolicy()['weight'])];
    }

    public static function forProgram(int $userId, int $programId, ?\DateTimeInterface $now = null): array
    {
        $now ??= Dates::now();
        $occ = self::memberOccurrences($userId, ['programIds' => [$programId], 'to' => Dates::addDays(Dates::todayLocal($now), 60)], $now);
        $past = array_values(array_filter($occ, fn ($o) => $o['status'] !== 'upcoming'));
        return [
            'occurrences' => array_map(fn ($o) => ['date' => $o['date'], 'starts_at' => $o['starts_at'], 'ends_at' => $o['ends_at'], 'status' => $o['status']], array_reverse($occ)),
            'stats' => self::statsOf($past, Settings::permissionPolicy()['weight']),
        ];
    }

    public static function forUser(int $userId, array $page): array
    {
        $all = array_reverse(array_values(array_filter(self::memberOccurrences($userId), fn ($o) => in_array($o['status'], ['present', 'late', 'excused', 'absent'], true))));
        $items = array_map(fn ($o) => [
            'id' => "{$o['program_id']}:{$o['date']}",
            'status' => $o['status'],
            'attended_at' => null,
            'program_id' => $o['program_id'],
            'program_title' => $o['title'],
            'starts_at' => $o['starts_at'],
            'location' => $o['location'],
            'date' => $o['date'],
            'category' => $o['category'],
        ], array_slice($all, $page['offset'], $page['limit']));
        return ['items' => $items, 'meta' => ['page' => $page['page'], 'limit' => $page['limit'], 'total' => count($all), 'pages' => max(1, (int) ceil(count($all) / $page['limit']))]];
    }

    public static function rateSummary(int $userId, array $f = []): array
    {
        $s = self::stats($userId, $f);
        return [
            'present' => $s['attended'],
            'late' => $s['late'],
            'excused' => $s['excused'],
            'absent' => $s['absent'],
            'total' => $s['total_programs'],
            'excused_weight' => $s['excused_weight'],
            'score' => Num::clean($s['attended'] + $s['late'] + $s['excused'] * $s['excused_weight']),
            'rate' => $s['percentage'],
        ];
    }
}
