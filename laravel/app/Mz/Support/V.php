<?php

namespace App\Mz\Support;

/** Shared validation schemas (port of validators/common.js). Error messages are stable codes. */
final class V
{
    /** Ethiopian mobile numbers (09…, 07…, +2519…, 2519…) → "+251XXXXXXXXX", or null. */
    public static function normalizePhone(mixed $raw): ?string
    {
        if (! is_string($raw)) {
            return null;
        }
        $digits = preg_replace('/[\s\-()]/', '', $raw);
        return preg_match('/^(?:\+?251|0)?([79]\d{8})$/', $digits, $m) ? '+251' . $m[1] : null;
    }

    public static function phone(): ZType
    {
        return Z::string(['required_error' => 'REQUIRED'])->trim()->transform(function ($v, ZCtx $ctx) {
            $n = self::normalizePhone($v);
            return $n ?? $ctx->addIssue('INVALID_PHONE');
        });
    }

    public static function email(): ZType
    {
        return Z::string()->trim()->toLowerCase()->max(190, 'TOO_LONG')->email('INVALID_EMAIL');
    }

    public static function optionalEmail(): ZType
    {
        return Z::union([self::email(), Z::literal(''), Z::null()])->optional()
            ->transform(fn ($v) => ($v === Z::$UNDEF || ! $v) ? null : $v);
    }

    /** Updates: absent stays absent; '' or null clears the email. */
    public static function patchEmail(): ZType
    {
        return Z::union([self::email(), Z::literal(''), Z::null()])->optional()
            ->transform(fn ($v) => $v === Z::$UNDEF ? Z::$UNDEF : ($v ?: null));
    }

    /**
     * Every account's secret is a PIN of 4 to 6 digits — members, administrators and the system
     * authority alike (repeated wrong attempts lock the account; the system authority also needs
     * its TOTP code). The old names stay as aliases so every endpoint follows the same rule.
     */
    public static function pin(): ZType
    {
        return Z::string(['required_error' => 'REQUIRED'])->regex('/^\d{4,6}$/', 'INVALID_PIN');
    }

    public static function isPin(mixed $v): bool
    {
        return is_string($v) && preg_match('/^\d{4,6}$/', $v) === 1;
    }

    public static function password(): ZType
    {
        return self::pin();
    }

    public static function pinOrPassword(): ZType
    {
        return self::pin();
    }

    /** Plain text: control characters removed, trimmed, HTML tags rejected. */
    public static function text(int $min, int $max): ZType
    {
        return Z::string(['required_error' => 'REQUIRED'])
            ->transform(fn ($v) => trim(preg_replace('/[\x{0000}-\x{0008}\x{000B}\x{000C}\x{000E}-\x{001F}\x{007F}]/u', '', $v)))
            ->pipe(
                Z::string()
                    ->min($min, $min <= 1 ? 'REQUIRED' : 'TOO_SHORT')
                    ->max($max, 'TOO_LONG')
                    ->refine(fn ($v) => ! preg_match('/<\s*\/?\s*[a-zA-Z][^>]*>/', $v), 'HTML_NOT_ALLOWED'),
            );
    }

    public static function optionalText(int $max): ZType
    {
        return Z::union([self::text(0, $max), Z::null()])->optional()->transform(fn ($v) => $v === '' ? null : $v);
    }

    public static function id(): ZNumber
    {
        return Z::coerceNumber(['invalid_type_error' => 'INVALID_ID'])->int('INVALID_ID')->positive('INVALID_ID');
    }

    public static function idParam(): ZObject
    {
        return Z::object(['id' => self::id()]);
    }

    public static function bool(): ZType
    {
        return Z::union([
            Z::boolean(),
            Z::enum(['true', 'false', '1', '0'])->transform(fn ($v) => $v === 'true' || $v === '1'),
        ]);
    }

    public static function dateOnly(): ZType
    {
        return Z::string(['required_error' => 'REQUIRED'])
            ->regex('/^\d{4}-\d{2}-\d{2}$/', 'INVALID_DATE')
            ->refine(function ($v) {
                [$y, $m, $d] = array_map('intval', explode('-', $v));
                return $m >= 1 && $m <= 12 && $d >= 1 && $d <= 31;
            }, 'INVALID_DATE');
    }

    /** DATETIME columns have second precision; the value is truncated to the second. */
    public static function dateTime(): ZType
    {
        return Z::coerceDate(['invalid_type_error' => 'INVALID_DATE', 'required_error' => 'REQUIRED'])
            ->transform(fn ($d) => $d->setTimestamp($d->getTimestamp()));
    }

    public static function deviceId(): ZType
    {
        return Z::string(['required_error' => 'DEVICE_REQUIRED'])->trim()->min(8, 'INVALID_DEVICE')->max(128, 'INVALID_DEVICE');
    }

    public static function deviceName(): ZType
    {
        return Z::string()->trim()->max(150)->optional()->default('');
    }

    public static function listQuery(): ZObject
    {
        return Z::object([
            'page' => Z::coerceNumber()->int()->positive()->optional(),
            'limit' => Z::coerceNumber()->int()->positive()->max(100)->optional(),
            'q' => Z::string()->trim()->max(100)->optional(),
        ]);
    }

    /** The built-in member types; administrators add more (App\Mz\Services\MemberGroups). */
    public const MEMBER_GROUPS = ['children', 'youth_adult', 'married'];

    /** A member type key (built-in or administrator-created); $activeOnly for new assignments by members themselves. */
    public static function memberGroup(bool $activeOnly = false): ZType
    {
        return Z::string()->trim()->max(40)->refine(fn ($v) => \App\Mz\Services\MemberGroups::exists($v, $activeOnly), 'INVALID_MEMBER_GROUP');
    }

    /** A list of member type keys (a program's / selection's target groups). */
    public static function memberGroups(int $max = 50): ZType
    {
        return Z::array(self::memberGroup())->max($max);
    }

    public const MEMBERSHIP_STATUSES = ['active', 'deceased', 'inactive', 'university', 'abroad'];

    public static function userFilter(): ZObject
    {
        return Z::object([
            'q' => Z::string()->trim()->max(100)->optional(),
            'status' => Z::enum(['active', 'disabled'])->optional(),
            'program_id' => self::id()->optional(),
            'registered_from' => self::dateOnly()->optional(),
            'registered_to' => self::dateOnly()->optional(),
            'has_active_borrowing' => Z::boolean()->optional(),
            'member_group' => self::memberGroup()->optional(),
            'membership_status' => Z::enum(self::MEMBERSHIP_STATUSES)->optional(),
            'department_id' => self::id()->optional(),
            'class_id' => self::id()->optional(),
            'gender' => Z::enum(['male', 'female'])->optional(),
            'marital_status' => Z::enum(['married', 'single'])->optional(),
            'member_type' => Z::enum(['student', 'worker'])->optional(),
            'account_type' => Z::enum(['user', 'admin'])->optional(),
            'spiritual_level' => Z::number()->int()->min(1)->max(20)->optional(),
            'age_min' => Z::number()->int()->min(0)->max(120)->optional(),
            'age_max' => Z::number()->int()->min(0)->max(120)->optional(),
            'has_device' => Z::boolean()->optional(),
            'telegram_linked' => Z::boolean()->optional(),
            'active_within_days' => Z::number()->int()->min(1)->max(3650)->optional(),
        ])->strict();
    }

    /** The same filters as query-string fields (GET lists). */
    public static function userFilterQuery(): array
    {
        $bool = fn () => Z::enum(['true', 'false'])->transform(fn ($v) => $v === 'true')->optional();
        $int = fn (int $min, int $max) => Z::coerceNumber()->int()->min($min)->max($max)->optional();
        return [
            'department_id' => Z::coerceNumber()->int()->positive()->optional(),
            'class_id' => Z::coerceNumber()->int()->positive()->optional(),
            'gender' => Z::enum(['male', 'female'])->optional(),
            'marital_status' => Z::enum(['married', 'single'])->optional(),
            'member_type' => Z::enum(['student', 'worker'])->optional(),
            'account_type' => Z::enum(['user', 'admin'])->optional(),
            'spiritual_level' => $int(1, 20),
            'age_min' => $int(0, 120),
            'age_max' => $int(0, 120),
            'has_device' => $bool(),
            'telegram_linked' => $bool(),
            'active_within_days' => $int(1, 3650),
        ];
    }

    public static function bulkTarget(): ZType
    {
        return Z::object([
            'user_ids' => Z::array(self::id())->max(5000, 'TOO_MANY')->optional(),
            'filter' => self::userFilter()->optional(),
            'all' => Z::boolean()->optional(),
            'exclude_ids' => Z::array(self::id())->max(5000)->optional(),
        ])->refine(
            fn ($v) => (! empty($v['user_ids']) ? 1 : 0) + (isset($v['filter']) ? 1 : 0) + (! empty($v['all']) ? 1 : 0) === 1,
            ['message' => 'TARGET_REQUIRED', 'path' => ['user_ids']],
        );
    }
}
