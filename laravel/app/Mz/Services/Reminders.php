<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

/** Personal reminders, canonical server copy for offline devices (port of reminderService.js). */
final class Reminders
{
    public static function serialize(object $r): array
    {
        return [
            'id' => $r->id,
            'client_uuid' => $r->client_uuid,
            'program_id' => $r->program_id,
            'borrowing_id' => $r->borrowing_id,
            'title' => $r->title,
            'note' => $r->note,
            'remind_at' => $r->remind_at,
            'repeat' => $r->repeat,
            'is_enabled' => (bool) $r->is_enabled,
            'updated_at' => $r->updated_at,
            'deleted' => (bool) $r->deleted_at,
        ];
    }

    public static function list(int $userId, mixed $since = null): array
    {
        $qb = DB::table('reminders')->where('user_id', $userId)->orderBy('remind_at');
        // With ?since, tombstones are included so an offline device learns about deletions.
        if ($since) $qb->where('updated_at', '>', Dates::sql($since));
        else $qb->whereNull('deleted_at');
        return $qb->get()->map(fn ($r) => self::serialize($r))->all();
    }

    private static function assertBorrowing(int $userId, ?int $borrowingId): void
    {
        if ($borrowingId && ! DB::table('borrowings')->where(['id' => $borrowingId, 'user_id' => $userId])->exists()) throw ApiError::field('borrowing_id', 'BORROWING_NOT_FOUND');
    }

    private static function assertProgram(?int $programId): void
    {
        if ($programId && ! DB::table('programs')->where('id', $programId)->whereIn('status', ['published', 'completed'])->exists()) throw ApiError::field('program_id', 'PROGRAM_NOT_FOUND');
    }

    /** Idempotent on (user, client_uuid). */
    public static function create(int $userId, array $in): array
    {
        return DB::transaction(function () use ($userId, $in) {
            $existing = DB::table('reminders')->where(['user_id' => $userId, 'client_uuid' => $in['client_uuid']])->first();
            if ($existing) return ['reminder' => self::serialize($existing), 'created' => false];
            self::assertProgram($in['program_id'] ?? null);
            self::assertBorrowing($userId, $in['borrowing_id'] ?? null);
            $at = Dates::sql($in['remind_at']);
            $dup = null;
            if (! empty($in['program_id'])) {
                $dup = DB::table('reminders')->where(['user_id' => $userId, 'program_id' => $in['program_id'], 'remind_at' => $at])->whereNull('deleted_at')->first(['id']);
            } elseif (! empty($in['borrowing_id'])) {
                $dup = DB::table('reminders')->where(['user_id' => $userId, 'borrowing_id' => $in['borrowing_id'], 'remind_at' => $at])->whereNull('deleted_at')->first(['id']);
            }
            if ($dup) throw ApiError::conflict('DUPLICATE_REMINDER', 'A reminder already exists for this time');
            try {
                $id = DB::table('reminders')->insertGetId([
                    'user_id' => $userId,
                    'client_uuid' => $in['client_uuid'],
                    'program_id' => $in['program_id'] ?? null,
                    'borrowing_id' => $in['borrowing_id'] ?? null,
                    'title' => $in['title'],
                    'note' => $in['note'] ?? null,
                    'remind_at' => $at,
                    'repeat' => $in['repeat'] ?? 'none',
                    'is_enabled' => $in['is_enabled'] ?? true,
                ]);
            } catch (QueryException $e) {
                if (($e->errorInfo[1] ?? null) === 1062) throw ApiError::conflict('DUPLICATE_REMINDER', 'A reminder already exists for this time');
                throw $e;
            }
            Activity::track($userId, Activity::REMINDER_CREATE, 'reminder', $id, inTrx: true);
            return ['reminder' => self::serialize(DB::table('reminders')->where('id', $id)->first()), 'created' => true];
        });
    }

    /** Optimistic concurrency: a newer server copy wins and is returned in the conflict. */
    public static function update(int $userId, int|string $idOrUuid, array $in): array
    {
        return DB::transaction(function () use ($userId, $idOrUuid, $in) {
            $q = DB::table('reminders')->where('user_id', $userId)->lockForUpdate();
            is_int($idOrUuid) ? $q->where('id', $idOrUuid) : $q->where('client_uuid', $idOrUuid);
            $r = $q->first();
            if (! $r || $r->deleted_at) throw ApiError::notFound('REMINDER_NOT_FOUND', 'Reminder not found');
            if (! empty($in['base_updated_at']) && Dates::of($r->updated_at) > Dates::of($in['base_updated_at'])) {
                throw ApiError::conflict('SYNC_CONFLICT', 'Reminder was changed elsewhere', [['field' => 'reminder', 'code' => 'SYNC_CONFLICT', 'message' => json_encode(self::serialize($r), JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES)]]);
            }
            $patch = array_intersect_key($in, array_flip(['title', 'note', 'remind_at', 'repeat', 'is_enabled']));
            if (isset($patch['remind_at'])) $patch['remind_at'] = Dates::sql($patch['remind_at']);
            if ($patch) DB::table('reminders')->where('id', $r->id)->update($patch);
            Activity::track($userId, Activity::REMINDER_UPDATE, 'reminder', $r->id, inTrx: true);
            return self::serialize(DB::table('reminders')->where('id', $r->id)->first());
        });
    }

    public static function remove(int $userId, int|string $idOrUuid): bool
    {
        $q = DB::table('reminders')->where('user_id', $userId)->whereNull('deleted_at');
        is_int($idOrUuid) ? $q->where('id', $idOrUuid) : $q->where('client_uuid', $idOrUuid);
        $n = $q->update(['deleted_at' => DB::raw('NOW()')]);
        if ($n) Activity::track($userId, Activity::REMINDER_DELETE, 'reminder');
        return $n > 0;
    }
}
