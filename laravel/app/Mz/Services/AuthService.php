<?php

namespace App\Mz\Services;

use App\Mz\Auth\Audit;
use App\Mz\Auth\AuthContext;
use App\Mz\Auth\Passwords;
use App\Mz\Auth\Tokens;
use App\Mz\Auth\Totp;
use App\Mz\Notifications\Mailer;
use App\Mz\Notifications\Notifications;
use App\Mz\Notifications\Telegram;
use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/** Registration, sign-in, tokens and passwords (port of authService.js). */
final class AuthService
{
    private const MAX_FAILED = 5;
    private const LOCK_MINUTES = 15;
    private const RESET_CODE_MINUTES = 15;
    private const RESET_MAX_ATTEMPTS = 5;

    private static function invalidCredentials(): ApiError
    {
        return ApiError::unauthorized('INVALID_CREDENTIALS', 'Invalid phone/email or password');
    }

    private static function buildSession(object $user, string $scope, ?string $deviceId, array $meta): array
    {
        $refresh = Tokens::issueRefresh((int) $user->id, $scope, $deviceId, null, $meta['ip'] ?? null, $meta['userAgent'] ?? null);
        $access = Tokens::signAccess($user, $scope, $deviceId, $refresh['familyId']);
        return ['access' => $access, 'refresh' => $refresh];
    }

    private static function sessionResponse(array $s, int $userId): array
    {
        $auth = AuthContext::load($userId);
        return [
            'token_type' => 'Bearer',
            'access_token' => $s['access']['token'],
            'access_expires_in' => $s['access']['expiresIn'],
            'refresh_token' => $s['refresh']['raw'],
            'refresh_expires_at' => $s['refresh']['expiresAt'],
            'user' => Users::toPublic(Users::findPublicById($userId), $auth),
        ];
    }

    private static function registerFailure(object $user): void
    {
        $failed = (int) $user->failed_login_count + 1;
        $patch = ['failed_login_count' => $failed];
        if ($failed >= self::MAX_FAILED) {
            $patch['locked_until'] = gmdate('Y-m-d H:i:s', time() + self::LOCK_MINUTES * 60);
            $patch['failed_login_count'] = 0;
        }
        DB::table('users')->where('id', $user->id)->update($patch);
    }

    private static function assertNotLocked(object $user): void
    {
        if ($user->locked_until && $user->locked_until->getTimestamp() > time()) {
            throw ApiError::tooMany('ACCOUNT_LOCKED', 'Too many failed attempts. Try again later.');
        }
    }

    // ------------------------------------------------------------------ registration
    public static function register(array $input, array $meta): array
    {
        $taken = Users::phoneOrEmailTaken($input['phone'] ?? null, $input['email'] ?? null);
        if ($taken) {
            throw ApiError::conflict('ACCOUNT_EXISTS', 'Account already exists', $taken);
        }
        if (Users::deviceOwnedByOther($input['device_id'], null)) {
            throw ApiError::conflict('DEVICE_IN_USE', 'This device is already registered to another account');
        }
        $hash = Passwords::hash($input['password']);
        // New accounts wait for an administrator's approval before they can sign in.
        $id = DB::transaction(function () use ($input, $meta, $hash) {
            $newId = DB::table('users')->insertGetId([
                'full_name' => $input['full_name'],
                'phone' => $input['phone'],
                'email' => $input['email'] ?? null,
                'password_hash' => $hash,
                'account_type' => 'user',
                'status' => 'pending',
                'device_id' => $input['device_id'],
                'device_name' => ($input['device_name'] ?? '') ?: null,
                'device_bound_at' => DB::raw('NOW()'),
                'password_changed_at' => DB::raw('NOW()'),
                'member_group' => $input['member_group'] ?? 'youth_adult',
                'member_type' => $input['member_type'] ?? null,
            ]);
            DB::table('user_preferences')->insert(['user_id' => $newId]);
            MemberIds::assign($newId);
            MemberProfile::save($newId, $input['profile'] ?? null);
            DB::table('device_history')->insert(['user_id' => $newId, 'device_id' => $input['device_id'], 'device_name' => ($input['device_name'] ?? '') ?: null, 'event' => 'bound', 'ip' => $meta['ip'] ?? null]);
            Activity::track($newId, Activity::REGISTER, inTrx: true);
            return $newId;
        });
        // The members who approve registrations, and the new member (email: "received, waiting").
        $params = ['name' => $input['full_name'], 'phone' => $input['phone']];
        Notifications::createForUsers(\App\Mz\Auth\Holders::of('users.disable'), [
            'type' => 'system', 'title' => T::t('account.registered.admin.title'), 'body' => T::t('account.registered.admin.body', $params),
            'entityType' => 'user', 'entityId' => $id, 'dedupeKey' => fn ($uid) => "register:$id:admin:$uid",
        ]);
        Notifications::createForUsers([$id], [
            'type' => 'system', 'title' => T::t('account.registered.title'), 'body' => T::t('account.registered.body', $params),
            'entityType' => 'user', 'entityId' => $id, 'email' => true, 'dedupeKey' => fn ($uid) => "register:$id:self",
        ]);
        return ['pending' => true, 'user_id' => $id];
    }

    // ------------------------------------------------------------------ login (users and admins)
    public static function login(array $in, array $meta): array
    {
        $user = Users::findByIdentifier($in['identifier']);
        if (! $user) {
            Passwords::burnVerify($in['password']);
            throw self::invalidCredentials();
        }
        self::assertNotLocked($user);
        $valid = Passwords::verify($user->password_hash, $in['password']);
        $isSystem = $user->account_type === 'admin' && (bool) $user->role_hidden;
        if (! $valid || $isSystem) {
            if ($valid && $isSystem) {
                // Correct system credentials on the public endpoint: reveal nothing, record it (hidden).
                Audit::log(['actorId' => $user->id] + $meta, Audit::SYSTEM_LOGIN_FAILED, null, null, ['reason' => 'wrong_endpoint'], true);
                throw self::invalidCredentials();
            }
            self::registerFailure($user);
            if ($user->account_type === 'admin') {
                Audit::log(['actorId' => $user->id] + $meta, Audit::ADMIN_LOGIN_FAILED, 'user', $user->id, null, $isSystem);
            } else {
                Activity::track($user->id, Activity::LOGIN_FAILED);
            }
            throw self::invalidCredentials();
        }
        if ($user->status === 'pending') {
            throw ApiError::forbidden('ACCOUNT_PENDING', 'Account is waiting for approval');
        }
        if ($user->status !== 'active') {
            throw ApiError::forbidden('ACCOUNT_DISABLED', 'Account disabled');
        }
        if ($user->account_type === 'user' && ! $user->can_login) {
            throw ApiError::forbidden('LOGIN_NOT_ALLOWED', 'This account cannot sign in');
        }
        $deviceId = $in['device_id'];
        $deviceName = ($in['device_name'] ?? '') ?: null;
        $password = $in['password'];
        $session = DB::transaction(function () use ($user, $deviceId, $deviceName, $meta, $password) {
            $locked = DB::table('users')->where('id', $user->id)->lockForUpdate()->first();
            $patch = ['failed_login_count' => 0, 'locked_until' => null, 'last_login_at' => DB::raw('NOW()')];
            if ($locked->account_type === 'user') {
                // ---- one device per user ----
                if ($locked->device_id && $locked->device_id !== $deviceId) {
                    DB::table('device_history')->insert(['user_id' => $locked->id, 'device_id' => $deviceId, 'device_name' => $deviceName, 'event' => 'login_rejected', 'ip' => $meta['ip'] ?? null]);
                    return ['rejected' => true];
                }
                if (! $locked->device_id) {
                    if (Users::deviceOwnedByOther($deviceId, (int) $locked->id)) {
                        return ['deviceInUse' => true];
                    }
                    $patch += ['device_id' => $deviceId, 'device_name' => $deviceName, 'device_bound_at' => DB::raw('NOW()')];
                    DB::table('device_history')->insert(['user_id' => $locked->id, 'device_id' => $deviceId, 'device_name' => $deviceName, 'event' => 'bound', 'ip' => $meta['ip'] ?? null]);
                    Activity::track($locked->id, Activity::DEVICE_CHANGE, metadata: ['device_name' => $deviceName], inTrx: true);
                } else {
                    DB::table('device_history')->insert(['user_id' => $locked->id, 'device_id' => $deviceId, 'device_name' => $deviceName, 'event' => 'login', 'ip' => $meta['ip'] ?? null]);
                }
                Activity::track($locked->id, Activity::LOGIN, inTrx: true);
                Audit::log(['actorId' => $locked->id] + $meta, Audit::AUTH_LOGIN, 'user', $locked->id, ['device_name' => $deviceName], inTrx: true);
            } else {
                // Administrators may stay signed in on several devices (web and phone): signing in here
                // no longer signs the others out. Each session is listed — and can be ended — under
                // Settings → Sessions; force-logout and password changes still end them all.
                Audit::log(['actorId' => $locked->id] + $meta, Audit::ADMIN_LOGIN, 'user', $locked->id, inTrx: true);
            }
            if (Passwords::needsRehash($locked->password_hash)) {
                $patch['password_hash'] = Passwords::hash($password);
            }
            if (! \App\Mz\Support\V::isPin($password)) {
                // Every account now uses a 4-6 digit PIN: an old password signs in once, then a PIN must be set.
                $patch['must_change_password'] = true;
                $locked->must_change_password = 1;
            }
            DB::table('users')->where('id', $locked->id)->update($patch);
            $locked->token_version = $patch['token_version'] ?? $locked->token_version;
            return self::buildSession($locked, 'app', $deviceId, $meta);
        });
        if (! empty($session['rejected'])) {
            throw ApiError::conflict('DEVICE_ALREADY_REGISTERED', 'This account is already registered on another device');
        }
        if (! empty($session['deviceInUse'])) {
            throw ApiError::conflict('DEVICE_IN_USE', 'This device is already registered to another account');
        }
        return self::sessionResponse($session, (int) $user->id);
    }

    // ------------------------------------------------------------------ system authority (password + TOTP)
    public static function systemLogin(array $in, array $meta): array
    {
        $user = Users::findByIdentifier($in['identifier']);
        $fail = function (string $reason) use ($user, $meta) {
            if ($user) {
                self::registerFailure($user);
                Audit::log(['actorId' => $user->id] + $meta, Audit::SYSTEM_LOGIN_FAILED, null, null, ['reason' => $reason], true);
            }
            throw ApiError::notFound();
        };
        if (! $user) {
            Passwords::burnVerify($in['password']);
            throw ApiError::notFound();
        }
        self::assertNotLocked($user);
        $isSystem = $user->account_type === 'admin' && (bool) $user->role_hidden;
        if (! Passwords::verify($user->password_hash, $in['password']) || ! $isSystem) {
            $fail('credentials');
        }
        if (! $user->totp_secret_enc) {
            $fail('totp_not_configured');
        }
        try {
            $secret = Crypto::decryptSecret($user->totp_secret_enc);
        } catch (\Throwable) {
            $fail('totp_decrypt');
        }
        if (! Totp::check((string) $in['totp'], $secret)) {
            $fail('totp');
        }
        if ($user->status !== 'active') {
            $fail('disabled');
        }
        $session = DB::transaction(function () use ($user, $meta, $in) {
            $patch = ['failed_login_count' => 0, 'locked_until' => null, 'last_login_at' => DB::raw('NOW()')];
            if (! \App\Mz\Support\V::isPin((string) $in['password'])) {
                $patch['must_change_password'] = true;
                $user->must_change_password = 1;
            }
            DB::table('users')->where('id', $user->id)->update($patch);
            Audit::log(['actorId' => $user->id] + $meta, Audit::SYSTEM_LOGIN, hidden: true, inTrx: true);
            return self::buildSession($user, 'system', ($in['device_id'] ?? null) ?: null, $meta);
        });
        return self::sessionResponse($session, (int) $user->id);
    }

    // ------------------------------------------------------------------ tokens
    public static function refresh(array $in, array $meta, string $scope = 'app'): array
    {
        $rotated = Tokens::rotate($in['refresh_token'], $scope, $in['device_id'] ?? null, $meta['ip'] ?? null, $meta['userAgent'] ?? null);
        $ctx = AuthContext::load((int) $rotated['userId']);
        if (! $ctx || $ctx->status !== 'active') {
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        if ($ctx->isSystem !== ($scope === 'system')) {
            throw ApiError::unauthorized('INVALID_REFRESH_TOKEN', 'Invalid refresh token');
        }
        // After a device reset the old device's refresh token must not keep working.
        if ($ctx->accountType === 'user' && $ctx->deviceId !== $rotated['deviceId']) {
            Tokens::revokeFamily($rotated['refresh']['raw']);
            throw ApiError::unauthorized('SESSION_REVOKED', 'Session revoked');
        }
        $access = Tokens::signAccess(['id' => $ctx->id, 'token_version' => $ctx->tokenVersion], $scope, $rotated['deviceId'], $rotated['refresh']['familyId'] ?? null);
        return self::sessionResponse(['access' => $access, 'refresh' => $rotated['refresh']], $ctx->id);
    }

    public static function logout(?AuthContext $auth, array $in): void
    {
        if (! empty($in['refresh_token'])) {
            Tokens::revokeFamily($in['refresh_token']);
        }
        // The access token used to sign out is refused from now on (not only when it expires).
        if ($auth?->tokenId && $auth->tokenExpires) {
            DB::table('revoked_access_tokens')->insertOrIgnore(['jti' => $auth->tokenId, 'user_id' => $auth->id, 'expires_at' => gmdate('Y-m-d H:i:s', $auth->tokenExpires)]);
        }
        if ($auth?->tokenDeviceId) {
            DB::table('fcm_tokens')->where(['user_id' => $auth->id, 'device_id' => $auth->tokenDeviceId])->whereNull('invalidated_at')->update(['invalidated_at' => DB::raw('NOW()')]);
        }
        if ($auth && $auth->accountType === 'user') {
            Activity::track($auth->id, Activity::LOGOUT);
        }
        if ($auth) Audit::log(['actorId' => $auth->id], Audit::AUTH_LOGOUT, 'user', $auth->id, null, $auth->isSystem);
    }

    // ------------------------------------------------------------------ passwords
    public static function changePassword(AuthContext $auth, array $in, array $meta): array
    {
        $user = Users::findCredentialsById($auth->id);
        if (! Passwords::verify($user->password_hash, $in['current_password'])) {
            throw ApiError::field('current_password', 'WRONG_PASSWORD');
        }
        if (Passwords::verify($user->password_hash, $in['new_password'])) {
            throw ApiError::field('new_password', 'PASSWORD_REUSED');
        }
        $hash = Passwords::hash($in['new_password']);
        $scope = $auth->isSystem ? 'system' : 'app';
        $session = DB::transaction(function () use ($user, $hash, $auth, $scope, $meta) {
            DB::table('users')->where('id', $user->id)->update([
                'password_hash' => $hash,
                'password_changed_at' => DB::raw('NOW()'),
                'must_change_password' => false,
                'token_version' => DB::raw('token_version + 1'),
            ]);
            Tokens::revokeAllForUser((int) $user->id);
            if ($auth->accountType === 'user') {
                Activity::track($user->id, Activity::PASSWORD_CHANGE, inTrx: true);
            }
            // Never the password / PIN itself.
            Audit::log(['actorId' => $user->id] + $meta, Audit::AUTH_PASSWORD_CHANGE, 'user', $user->id, ['kind' => 'pin'], $auth->isSystem, inTrx: true);
            $fresh = DB::table('users')->where('id', $user->id)->first();
            return self::buildSession($fresh, $scope, $auth->tokenDeviceId, $meta);
        });
        return self::sessionResponse($session, (int) $user->id);
    }

    public static function forgotPassword(array $in): void
    {
        $user = Users::findByIdentifier($in['identifier']);
        // Always the same response, whether or not the account exists.
        if (! $user || $user->status !== 'active' || $user->role_hidden) {
            return;
        }
        $code = Crypto::randomNumericCode(6);
        DB::transaction(function () use ($user, $code) {
            DB::table('password_resets')->where('user_id', $user->id)->whereNull('used_at')->update(['used_at' => DB::raw('NOW()')]);
            DB::table('password_resets')->insert([
                'user_id' => $user->id,
                'code_hash' => Crypto::hmac("{$user->id}:$code"),
                'expires_at' => gmdate('Y-m-d H:i:s', time() + self::RESET_CODE_MINUTES * 60),
            ]);
        });
        $text = T::t('password.reset.body', ['code' => $code, 'minutes' => self::RESET_CODE_MINUTES]);
        $viaTelegram = $user->telegram_chat_id
            ? Telegram::sendMessage($user->telegram_chat_id, T::t('telegram.reset.code', ['code' => $code, 'minutes' => self::RESET_CODE_MINUTES]))
            : false;
        if ($viaTelegram) {
            return;
        }
        if ($user->email) {
            Mailer::send($user->email, T::t('password.reset.subject'), $text);
        } elseif (! config('mz.is_prod')) {
            Log::info("[dev] password reset code: $code", ['userId' => $user->id]);
        }
    }

    public static function resetPassword(array $in): void
    {
        $user = Users::findByIdentifier($in['identifier']);
        $invalid = fn () => ApiError::badRequest('INVALID_RESET_CODE', 'Invalid or expired code');
        if (! $user || $user->role_hidden) {
            throw $invalid();
        }
        $hash = Passwords::hash($in['new_password']);
        $r = DB::transaction(function () use ($user, $in, $hash, $invalid) {
            $reset = DB::table('password_resets')->where('user_id', $user->id)->whereNull('used_at')
                ->where('expires_at', '>', gmdate('Y-m-d H:i:s'))->orderByDesc('id')->lockForUpdate()->first();
            if (! $reset || $reset->attempts >= self::RESET_MAX_ATTEMPTS) {
                throw $invalid();
            }
            if (! hash_equals($reset->code_hash, Crypto::hmac("{$user->id}:{$in['code']}"))) {
                DB::table('password_resets')->where('id', $reset->id)->increment('attempts');
                return 'wrong';
            }
            DB::table('password_resets')->where('id', $reset->id)->update(['used_at' => DB::raw('NOW()')]);
            DB::table('users')->where('id', $user->id)->update([
                'password_hash' => $hash,
                'password_changed_at' => DB::raw('NOW()'),
                'must_change_password' => false,
                'failed_login_count' => 0,
                'locked_until' => null,
                'token_version' => DB::raw('token_version + 1'),
            ]);
            Tokens::revokeAllForUser((int) $user->id);
            Activity::track($user->id, Activity::PASSWORD_RESET, inTrx: true);
            Audit::log(['actorId' => $user->id], Audit::AUTH_PASSWORD_RESET, 'user', $user->id, ['via' => 'code'], inTrx: true);
            return 'ok';
        });
        if ($r === 'wrong') {
            throw $invalid();
        }
    }
}
