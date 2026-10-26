<?php

namespace App\Mz\Services;

use App\Mz\Support\V;
use App\Mz\Support\Z;
use App\Mz\Support\ZType;
use Illuminate\Support\Facades\DB;

/** Settings: every setting has a schema and is validated before it is stored (port of settingsService.js). */
final class Settings
{
    /** @var array<string,ZType>|null */
    private static ?array $schemas = null;

    /** @return array<string,ZType> */
    public static function schemas(): array
    {
        if (self::$schemas !== null) {
            return self::$schemas;
        }
        $categoryIds = Z::array(Z::number()->int()->positive())->max(50);
        $idList = Z::array(Z::number()->int()->positive())->max(200);
        $fourWeights = Z::object([
            'education' => Z::number()->min(0)->max(100),
            'mezmur' => Z::number()->min(0)->max(100),
            'payment' => Z::number()->min(0)->max(100),
            'participation' => Z::number()->min(0)->max(100),
        ]);
        return self::$schemas = [
            'fines.policy' => Z::object([
                'enabled' => Z::boolean(),
                'amount' => Z::number()->min(0, 'NEGATIVE_AMOUNT')->max(100000),
                'period' => Z::enum(['day', 'week']),
                'grace_days' => Z::number()->int()->min(0)->max(365),
                'max_amount' => Z::number()->min(0, 'NEGATIVE_AMOUNT')->max(1000000)->nullable(),
                'currency' => Z::string()->min(1)->max(8)->default('ETB'),
            ])->strict(),
            'borrowing.reminders' => Z::object([
                'days_before' => Z::number()->int()->min(0)->max(14),
                'overdue_repeat_days' => Z::number()->int()->min(1)->max(60),
                'default_loan_days' => Z::number()->int()->min(1)->max(365),
            ])->strict(),
            'programs.reminder_defaults' => Z::object([
                'enabled' => Z::boolean(),
                'days_before' => Z::number()->int()->min(0)->max(30),
                // 0 = no fixed "starting soon" alarm (programs choose 2 d / 1 d / 6 h / 1 h instead).
                'minutes_before' => Z::number()->int()->min(0)->max(1440)->default(0),
                // Default reminder offsets of a new program (minutes before the start).
                'offsets' => \App\Mz\Support\ProgramSchemas::reminderOffsets()->optional(),
            ])->strict(),
            'notifications.retention_days' => Z::object(['days' => Z::number()->int()->min(30)->max(3650)])->strict(),
            'payments.policy' => Z::object([
                'currency' => Z::string()->min(1)->max(8),
                'start_period' => Z::string()->regex('/^\d{4}-(0[1-9]|1[0-2])$/')->nullable(),
                'grace_days' => Z::number()->int()->min(0)->max(60),
            ])->strict(),
            'attendance.permissions' => Z::object([
                'enabled' => Z::boolean(),
                'deadline_hours' => Z::number()->int()->min(0)->max(24 * 60),
                'monthly_limit' => Z::number()->int()->min(0)->max(100)->nullable(),
                'quarterly_limit' => Z::number()->int()->min(0)->max(300)->nullable(),
                'weight' => Z::number()->min(0)->max(1),
            ])->strict(),
            // HR: member groups whose attendance is recorded without a signature (e.g. small children).
            'attendance.signature' => Z::object([
                'exempt_groups' => V::memberGroups(),
            ])->strict(),
            'borrowing.direct' => Z::object([
                'member_groups' => V::memberGroups(),
                'approval_required' => Z::boolean(),
                'max_quantity' => Z::number()->int()->min(1)->max(1000)->nullable(),
                'max_days' => Z::number()->int()->min(1)->max(365)->nullable(),
            ])->strict(),
            'participation.policy' => Z::object(['max_score' => Z::number()->min(1)->max(100)])->strict(),
            'choir.policy' => Z::object([
                'weights' => $fourWeights->strict()->refine(fn ($w) => $w['education'] + $w['mezmur'] + $w['payment'] + $w['participation'] == 100, 'WEIGHTS_MUST_TOTAL_100'),
                'minimums' => $fourWeights->strict(),
                'total_minimum' => Z::number()->min(0)->max(100),
                'window_months' => Z::number()->int()->min(1)->max(36),
                'education' => Z::object([
                    'class_ids' => $idList,
                    'course_ids' => $idList,
                    'from' => Z::string()->regex('/^\d{4}-\d{2}-\d{2}$/')->nullable(),
                    'to' => Z::string()->regex('/^\d{4}-\d{2}-\d{2}$/')->nullable(),
                    'attendance_share' => Z::number()->min(0)->max(100),
                ])->strict(),
                'mezmur' => Z::object([
                    'attendance_category_ids' => $categoryIds,
                    'activity_program_ids' => $idList,
                    'attendance_share' => Z::number()->min(0)->max(100),
                ])->strict(),
                'payment' => Z::object(['late_credit' => Z::number()->min(0)->max(1)])->strict(),
            ])->strict()->refine(function ($p) {
                foreach (['education', 'mezmur', 'payment', 'participation'] as $k) {
                    if ($p['minimums'][$k] > $p['weights'][$k]) {
                        return false;
                    }
                }
                return true;
            }, 'MINIMUM_ABOVE_WEIGHT'),
            'modules.policy' => Z::object([
                'mezmur_enabled' => Z::boolean(),
                'education_enabled' => Z::boolean(),
                'group_overrides' => Z::record(Z::object([
                    'mezmur_enabled' => Z::boolean()->optional(),
                    'education_enabled' => Z::boolean()->optional(),
                ]))->optional(),
                'user_overrides' => Z::record(Z::object([
                    'mezmur_enabled' => Z::boolean()->optional(),
                    'education_enabled' => Z::boolean()->optional(),
                ]))->optional(),
            ])->strict(),
            'edu.attendance_cutover' => Z::string()->regex('/^\d{4}-\d{2}-\d{2}$/'),
        ];
    }

    public static function schema(string $key): ZType
    {
        return self::schemas()[$key];
    }

    public static function eduAttendanceCutover(): string
    {
        $v = self::get('edu.attendance_cutover');
        if (is_array($v) && isset($v['date'])) return $v['date'];
        if (is_string($v) && $v) return $v;
        return '2026-10-20';
    }

    public const SIGNATURE_POLICY_DEFAULT = ['exempt_groups' => []];
    public const DIRECT_BORROWING_DEFAULT = ['member_groups' => ['youth_adult', 'married'], 'approval_required' => false, 'max_quantity' => null, 'max_days' => null];
    public const PERMISSION_POLICY_DEFAULT = ['enabled' => true, 'deadline_hours' => 24, 'monthly_limit' => 3, 'quarterly_limit' => 4, 'weight' => 0.5];
    public const CHOIR_POLICY_DEFAULT = [
        'weights' => ['education' => 50, 'mezmur' => 30, 'payment' => 10, 'participation' => 10],
        'minimums' => ['education' => 20, 'mezmur' => 15, 'payment' => 3, 'participation' => 5],
        'total_minimum' => 43,
        'window_months' => 6,
        'education' => ['class_ids' => [], 'course_ids' => [], 'from' => null, 'to' => null, 'attendance_share' => 50],
        'mezmur' => ['attendance_category_ids' => [], 'activity_program_ids' => [], 'attendance_share' => 50],
        'payment' => ['late_credit' => 0.5],
    ];

    public static function signaturePolicy(): array
    {
        $v = self::get('attendance.signature');
        return ['exempt_groups' => array_values(array_filter((array) ($v['exempt_groups'] ?? []), 'is_string'))];
    }

    public static function directBorrowingPolicy(): array
    {
        return array_merge(self::DIRECT_BORROWING_DEFAULT, self::get('borrowing.direct') ?? []);
    }

    public static function permissionPolicy(): array
    {
        return array_merge(self::PERMISSION_POLICY_DEFAULT, self::get('attendance.permissions') ?? []);
    }

    public static function choirPolicy(): array
    {
        $s = self::get('choir.policy') ?? [];
        $d = self::CHOIR_POLICY_DEFAULT;
        $out = array_merge($d, $s);
        foreach (['weights', 'minimums', 'education', 'mezmur', 'payment'] as $k) {
            $out[$k] = array_merge($d[$k], $s[$k] ?? []);
        }
        return $out;
    }

    public const MODULES_POLICY_DEFAULT = [
        'mezmur_enabled' => true,
        'education_enabled' => true,
        'group_overrides' => [],
        'user_overrides' => [],
    ];

    public static function modulesPolicy(): array
    {
        $raw = self::get('modules.policy');
        return is_array($raw) ? array_merge(self::MODULES_POLICY_DEFAULT, $raw) : self::MODULES_POLICY_DEFAULT;
    }

    public static function resolveModuleAccess(?int $userId, ?string $memberGroup = null): array
    {
        $policy = self::modulesPolicy();
        $mezmur = (bool) ($policy['mezmur_enabled'] ?? true);
        $education = (bool) ($policy['education_enabled'] ?? true);

        // Group override
        if ($memberGroup && ! empty($policy['group_overrides'][$memberGroup])) {
            $grp = $policy['group_overrides'][$memberGroup];
            if (isset($grp['mezmur_enabled'])) $mezmur = (bool) $grp['mezmur_enabled'];
            if (isset($grp['education_enabled'])) $education = (bool) $grp['education_enabled'];
        }

        // Individual user override (wins over group and global defaults)
        if ($userId && ! empty($policy['user_overrides'][(string) $userId])) {
            $usr = $policy['user_overrides'][(string) $userId];
            if (isset($usr['mezmur_enabled'])) $mezmur = (bool) $usr['mezmur_enabled'];
            if (isset($usr['education_enabled'])) $education = (bool) $usr['education_enabled'];
        }

        return [
            'mezmur' => $mezmur,
            'education' => $education,
        ];
    }

    public static function decode(mixed $v): mixed
    {
        return is_string($v) ? json_decode($v, true) : $v;
    }

    public static function get(string $key): mixed
    {
        $row = DB::table('settings')->where('key', $key)->first(['value']);
        return $row ? self::decode($row->value) : null;
    }

    public static function all(): array
    {
        $out = [];
        foreach (DB::table('settings')->select('key', 'value', 'updated_at')->get() as $r) {
            $out[$r->key] = self::decode($r->value);
        }
        return $out;
    }

    public static function set(string $key, mixed $value, ?int $actorId): mixed
    {
        $schema = self::schemas()[$key] ?? null;
        if (! $schema) {
            throw new \RuntimeException("unknown setting $key");
        }
        $parsed = Z::parse($schema, $value);
        $json = json_encode($parsed, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        DB::table('settings')->upsert([['key' => $key, 'value' => $json, 'updated_by' => $actorId]], ['key'], ['value', 'updated_by']);
        return $parsed;
    }

    /** Store an already-validated value (e.g. the member ID format). */
    public static function put(string $key, mixed $value, ?int $actorId): void
    {
        $json = json_encode($value, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        DB::table('settings')->upsert([['key' => $key, 'value' => $json, 'updated_by' => $actorId]], ['key'], ['value', 'updated_by']);
    }
}
