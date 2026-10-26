<?php

namespace App\Mz\Services;

use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use App\Mz\Support\MemberSchemas;
use Illuminate\Support\Facades\DB;

/** The membership form and classification fields (port of memberProfileService.js). */
final class MemberProfile
{
    public const CLASSIFICATION_FIELDS = ['member_group', 'member_type', 'can_login', 'membership_status', 'membership_status_date', 'membership_status_detail', 'spiritual_level'];
    private const DATE_FIELDS = ['birth_date', 'baptism_date'];

    /** Insert or update the answers that were sent (unsent fields are left as they are). */
    public static function save(int $userId, ?array $profile): void
    {
        if (! $profile) {
            return;
        }
        $patch = [];
        foreach (MemberSchemas::profileFields() as $k) {
            if (array_key_exists($k, $profile)) {
                $patch[$k] = $profile[$k] === '' ? null : $profile[$k];
            }
        }
        if (! $patch) {
            return;
        }

        // Validate profession from catalogue if profession_id is provided
        if (! empty($patch['profession_id'])) {
            $profRow = DB::table('professions')->where('id', $patch['profession_id'])->first();
            if (! $profRow) {
                throw ApiError::notFound('PROFESSION_NOT_FOUND', 'Selected profession does not exist');
            }
            if (! $profRow->is_active) {
                $prevId = (int) DB::table('member_profiles')->where('user_id', $userId)->value('profession_id');
                if ($prevId !== (int) $profRow->id) {
                    throw ApiError::conflict('PROFESSION_DEACTIVATED', 'This profession has been deactivated and cannot be selected by new or modifying records');
                }
            }
            $patch['profession'] = $profRow->name;
            $patch['profession_category'] = $profRow->category;

            $isOther = mb_stripos($profRow->name, 'Other') !== false || mb_stripos($profRow->category, 'Other') !== false || mb_stripos($profRow->name, 'ሌላ') !== false;
            if ($isOther) {
                $otherDesc = trim((string) ($patch['profession_other'] ?? ''));
                if (empty($otherDesc)) {
                    throw ApiError::validation([['field' => 'profession_other', 'code' => 'PROFESSION_OTHER_REQUIRED', 'message' => 'Custom description is required when selecting Other as your profession']]);
                }
            }
        } elseif (! empty($patch['profession']) && (mb_stripos($patch['profession'], 'Other') !== false || mb_stripos($patch['profession'], 'ሌላ') !== false)) {
            $otherDesc = trim((string) ($patch['profession_other'] ?? ''));
            if (empty($otherDesc)) {
                throw ApiError::validation([['field' => 'profession_other', 'code' => 'PROFESSION_OTHER_REQUIRED', 'message' => 'Custom description is required when selecting Other as your profession']]);
            }
        }

        DB::table('member_profiles')->upsert([array_merge(['user_id' => $userId], $patch)], ['user_id'], array_keys($patch));
    }

    public static function get(int $userId): ?array
    {
        $row = DB::table('member_profiles')->where('user_id', $userId)->first();
        if (! $row) {
            return null;
        }
        $out = [];
        foreach (MemberSchemas::profileFields() as $k) {
            $out[$k] = in_array($k, self::DATE_FIELDS, true) ? Dates::toDateOnly($row->{$k} ?? null) : ($row->{$k} ?? null);
        }
        return $out;
    }

    /** Validate and pick the classification fields of an input (children, deceased, … rules). */
    public static function classification(array $input, array|object $current = []): array
    {
        $current = (array) $current;
        $out = [];
        foreach (self::CLASSIFICATION_FIELDS as $k) {
            if (array_key_exists($k, $input)) {
                $out[$k] = $input[$k];
            }
        }
        $group = $out['member_group'] ?? ($current['member_group'] ?? null);
        if (($out['member_group'] ?? null) === 'children' && ! array_key_exists('can_login', $input) && ($current['member_group'] ?? null) !== 'children') {
            $out['can_login'] = false;
        }
        if ($group === 'children') {
            $out['member_type'] = null; // children do not pay
        }
        $status = $out['membership_status'] ?? ($current['membership_status'] ?? null);
        if (array_key_exists('membership_status', $out)) {
            if ($status !== 'deceased') $out['membership_status_date'] = null;
            if (! in_array($status, ['university', 'abroad'], true)) $out['membership_status_detail'] = null;
            if ($status === 'deceased') $out['can_login'] = false;
        }
        if ($status === 'deceased' && ! ($out['membership_status_date'] ?? ($current['membership_status_date'] ?? null))) {
            throw ApiError::field('membership_status_date', 'REQUIRED');
        }
        if (in_array($status, ['university', 'abroad'], true) && ! ($out['membership_status_detail'] ?? ($current['membership_status_detail'] ?? null))) {
            throw ApiError::field('membership_status_detail', 'REQUIRED');
        }
        return $out;
    }

    /** Classification as returned by the API. */
    public static function classificationOf(object|array $u): array
    {
        $u = (object) $u;
        return [
            'member_group' => $u->member_group ?? 'youth_adult',
            'member_type' => $u->member_type ?? null,
            'can_login' => property_exists($u, 'can_login') ? (bool) $u->can_login : true,
            'membership_status' => $u->membership_status ?? 'active',
            'membership_status_date' => Dates::toDateOnly($u->membership_status_date ?? null),
            'membership_status_detail' => $u->membership_status_detail ?? null,
            'spiritual_level' => $u->spiritual_level ?? null,
        ];
    }
}
