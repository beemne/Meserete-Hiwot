<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\Dates;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * What a phone keeps for offline work, in one download (the app stores it in its SQLite database):
 *  - attendance takers (attendance.manage / .override): the member directory (QR uuid, name, photo,
 *    member ID, member type — never phone numbers), the programs they may take attendance for with
 *    their sessions from 3 days ago to 2 weeks ahead, the expected members of participant-only
 *    programs, the marks already recorded, and the timing rules;
 *  - borrowing staff (borrowing.manage): the member directory and the lendable items.
 * The QR scan, eligibility check and "already recorded" check then run on the phone without a
 * connection; marks / borrowings go into the offline queue and are checked again by the server
 * when they are synced (the server always has the last word).
 */
final class OfflinePack
{
    public static function build(AuthContext $auth): array
    {
        // Attendance work offline: the taker HR assigned (program default or an occurrence), and HR.
        $assigned = DB::table('program_attendance_takers')->where('user_id', $auth->id)->exists()
            || DB::table('attendance_sessions')->where('taker_id', $auth->id)->whereIn('status', ['scheduled', 'active'])->exists();
        $takes = $assigned || ($auth->isAdmin && ($auth->can('attendance.manage') || $auth->can('attendance.override')));
        $lends = $auth->isAdmin && $auth->can('borrowing.manage');
        $out = ['generated_at' => Dates::now(), 'me' => $auth->id, 'members' => [], 'programs' => [], 'marks' => [], 'items' => [], 'signature_policy' => null, 'roles' => ['attendance' => $takes, 'borrowing' => $lends]];
        if ($takes || $lends) $out['members'] = self::members();
        if ($takes) {
            [$out['programs'], $out['marks']] = self::programs($auth);
            $out['signature_policy'] = Settings::signaturePolicy();
        }
        if ($lends) $out['items'] = self::items();
        return $out;
    }

    private static function members(): array
    {
        $rows = MemberIds::memberAccounts(DB::table('users as u'))->where('u.status', 'active')->whereNotNull('u.member_uuid')
            ->orderBy('u.full_name')
            ->get(['u.id', 'u.member_uuid', 'u.full_name', 'u.member_no', 'u.member_group', 'u.member_type', 'u.membership_status', 'u.profile_image', 'u.created_at', 'u.account_type']);
        $fmt = MemberIds::currentFormat();
        return array_map(fn ($u) => [
            'id' => $u->id, 'uuid' => $u->member_uuid, 'full_name' => $u->full_name,
            'member_id' => MemberIds::format($u->member_no, $u->member_group, $fmt), 'member_group' => $u->member_group,
            'member_type' => $u->member_type, 'membership_status' => $u->membership_status,
            'avatar_url' => Storage::url($u->profile_image), 'joined_on' => Schedule::localDate($u->created_at),
        ], $rows->all());
    }

    private static function programs(AuthContext $auth): array
    {
        $today = Dates::todayLocal();
        $from = Dates::addDays($today, -3);
        $to = Dates::addDays($today, 14);
        $res = Programs::list($auth, ['scope' => 'all', 'takeable_by' => $auth], ['page' => 1, 'limit' => 200, 'offset' => 0], true);
        $ids = array_column($res['items'], 'id');
        if (! $ids) return [[], []];
        $rows = DB::table('programs')->whereIn('id', $ids)->get()->all();
        Schedule::loadOverrides($rows);
        $now = Dates::now();
        $programs = [];
        foreach ($rows as $p) {
            $occ = [];
            foreach (Schedule::between($p, $from, $to, null, true) as $o) {
                $closure = DB::table('attendance_closures')->where(['program_id' => $p->id, 'occurrence_date' => $o['date']])->value('closed_at');
                // The occurrence's session: who takes it and whether it runs (checked again on sync).
                $s = AttendanceSessions::of($p, $o);
                $occ[] = [
                    'date' => $o['date'], 'starts_at' => $o['starts_at'], 'ends_at' => $o['ends_at'], 'cancelled' => ! empty($o['cancelled']), 'closed_at' => $closure ? Dates::of($closure) : null,
                    'session' => [
                        'status' => $s->status, 'taker_id' => $s->taker_id ? (int) $s->taker_id : null, 'available_from' => AttendanceSessions::availableFrom($o),
                        'started_at' => $s->started_at, 'start_source' => $s->start_source, 'ended_at' => $s->ended_at, 'client_uuid' => $s->client_uuid,
                    ],
                ];
            }
            if (! $occ) continue;
            $hasLinkedClasses = Schema::hasTable('program_edu_classes')
                && DB::table('program_edu_classes')->where('program_id', $p->id)->exists();

            if ($hasLinkedClasses) {
                $classIds = DB::table('program_edu_classes')->where('program_id', $p->id)->pluck('class_id')->all();
                $participantIds = array_map('intval', DB::table('edu_enrollments')
                    ->whereIn('class_id', $classIds ?: [0])
                    ->where('status', 'active')
                    ->distinct()
                    ->pluck('user_id')
                    ->all());
            } elseif ($p->audience === 'participants') {
                $participantIds = array_map('intval', DB::table('program_participants')->where('program_id', $p->id)->whereIn('status', ['invited', 'registered'])->pluck('user_id')->all());
            } else {
                $participantIds = null;
            }

            $programs[] = [
                'id' => $p->id, 'title' => $p->title, 'status' => $p->status, 'audience' => $p->audience,
                'member_groups' => Attendance::groupsOf($p),
                'participant_ids' => $participantIds,
                'occurrences' => $occ,
            ];
        }
        // Legacy "late" marks read as present (there is no late status any more).
        $marks = DB::table('attendance')->whereIn('program_id', array_column($programs, 'id'))->whereBetween('occurrence_date', [$from, $to])
            ->get(['program_id', 'occurrence_date as date', 'user_id', 'status', 'via'])->map(fn ($m) => ['status' => $m->status === 'late' ? 'present' : $m->status] + (array) $m)->all();
        return [$programs, $marks];
    }

    private static function items(): array
    {
        $q = DB::table('items')->whereNull('deleted_at')->where('status', 'active')->orderBy('name');
        if (DB::getSchemaBuilder()->hasColumn('items', 'kind')) $q->where(fn ($w) => $w->whereNull('kind')->orWhere('kind', '<>', 'digital'));
        return $q->get(['id', 'name', 'code', 'domain', 'available_quantity', 'quantity', 'direct_borrowable', 'max_quantity', 'max_days', 'image'])
            ->map(fn ($i) => [
                'id' => $i->id, 'name' => $i->name, 'code' => $i->code, 'domain' => $i->domain ?? 'mezmur', 'available_quantity' => $i->available_quantity,
                'quantity' => $i->quantity, 'direct_borrowable' => (bool) $i->direct_borrowable, 'max_quantity' => $i->max_quantity, 'max_days' => $i->max_days,
                'image_url' => Storage::url($i->image),
            ])->all();
    }
}
