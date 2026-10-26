<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Self-service account operations (port of accountService.js). */
final class Account
{
    private const PREF_FIELDS = ['notifications_enabled', 'audio_autoplay', 'download_audio', 'theme', 'reminder_time', 'language', 'lyrics_font_scale'];

    public static function profile(AuthContext $auth): array
    {
        $out = Users::toPublic(Users::findPublicById($auth->id), $auth);
        $out['pending_change_request'] = $auth->accountType === 'user' ? ProfileChanges::pendingFor($auth->id) : null;
        return $out;
    }

    /** Email applies immediately; members' name / phone become a request for administrator approval. */
    public static function updateProfile(AuthContext $auth, array $input): array
    {
        $current = DB::table('users')->where('id', $auth->id)->first();
        if (array_key_exists('email', $input)) {
            $taken = Users::phoneOrEmailTaken(null, $input['email'], $auth->id);
            if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Email already in use', $taken);
            DB::table('users')->where('id', $auth->id)->update(['email' => $input['email']]);
            ProfileChanges::recordHistory($auth->id, [['field' => 'email', 'old' => $current->email, 'new' => $input['email']]], 'self', $auth->id);
        }
        if ($auth->accountType === 'admin') {
            $taken = Users::phoneOrEmailTaken($input['phone'] ?? null, null, $auth->id);
            if ($taken) throw ApiError::conflict('ACCOUNT_EXISTS', 'Phone already in use', $taken);
            $patch = array_intersect_key($input, array_flip(['full_name', 'phone']));
            if ($patch) DB::table('users')->where('id', $auth->id)->update($patch);
            ProfileChanges::recordHistory($auth->id, array_map(fn ($k) => ['field' => $k, 'old' => $current->{$k}, 'new' => $patch[$k]], array_keys($patch)), 'self', $auth->id);
        } else {
            ProfileChanges::submit($auth->id, array_intersect_key($input, array_flip(['full_name', 'phone'])));
            if (array_key_exists('email', $input)) {
                Activity::track($auth->id, Activity::PROFILE_UPDATE, metadata: ['fields' => ['email']]);
            }
        }
        return self::profile($auth);
    }

    public static function setAvatar(AuthContext $auth, UploadedFile $file): array
    {
        $saved = Storage::save('image', Storage::FOLDERS['AVATARS'], $file);
        $old = DB::table('users')->where('id', $auth->id)->value('profile_image');
        DB::table('users')->where('id', $auth->id)->update(['profile_image' => $saved['path']]);
        Storage::remove($old);
        return Users::toPublic(Users::findPublicById($auth->id), $auth);
    }

    public static function removeAvatar(AuthContext $auth): void
    {
        $old = DB::table('users')->where('id', $auth->id)->value('profile_image');
        DB::table('users')->where('id', $auth->id)->update(['profile_image' => null]);
        Storage::remove($old);
    }

    public static function getPreferences(int $userId): array
    {
        $prefs = DB::table('user_preferences')->where('user_id', $userId)->first();
        if (! $prefs) {
            DB::table('user_preferences')->insertOrIgnore(['user_id' => $userId]);
            $prefs = DB::table('user_preferences')->where('user_id', $userId)->first();
        }
        $cats = DB::table('user_preferred_categories')->where('user_id', $userId)->pluck('category_id')->all();
        $out = [];
        foreach (self::PREF_FIELDS as $k) {
            $out[$k] = $prefs->{$k};
        }
        foreach (['notifications_enabled', 'audio_autoplay', 'download_audio'] as $k) {
            $out[$k] = (bool) $out[$k];
        }
        $out['preferred_category_ids'] = $cats;
        $out['updated_at'] = $prefs->updated_at;
        return $out;
    }

    public static function updatePreferences(int $userId, array $input): array
    {
        DB::transaction(function () use ($userId, $input) {
            $patch = array_intersect_key($input, array_flip(self::PREF_FIELDS));
            DB::table('user_preferences')->upsert([array_merge(['user_id' => $userId], $patch)], ['user_id'], $patch ? array_keys($patch) : ['user_id']);
            if (isset($input['preferred_category_ids'])) {
                $ids = array_values(array_unique($input['preferred_category_ids']));
                $valid = $ids ? DB::table('categories')->whereIn('id', $ids)->where('is_active', true)->pluck('id')->all() : [];
                DB::table('user_preferred_categories')->where('user_id', $userId)->delete();
                if ($valid) {
                    DB::table('user_preferred_categories')->insert(array_map(fn ($c) => ['user_id' => $userId, 'category_id' => $c], $valid));
                }
            }
        });
        return self::getPreferences($userId);
    }

    /**
     * Notification preferences per topic and channel. The in-app notification is always kept (it is
     * the record); push and email can be switched off per topic. Account / administrative messages
     * and property deadlines are mandatory and arrive regardless.
     */
    public static function notificationPreferences(int $userId): array
    {
        $row = DB::table('user_preferences')->where('user_id', $userId)->first(['notifications_enabled', 'notification_topics']);
        $prefs = \App\Mz\Notifications\Notifications::preferencesOf($row->notification_topics ?? null);
        $hasEmail = (bool) filter_var((string) DB::table('users')->where('id', $userId)->value('email'), FILTER_VALIDATE_EMAIL);
        return [
            'enabled' => $row ? (bool) $row->notifications_enabled : true,
            'has_email' => $hasEmail,
            'email_available' => \App\Mz\Notifications\Mailer::configured(),
            'topics' => array_map(fn ($t) => ['topic' => $t, 'push' => $prefs[$t]['push'], 'email' => $prefs[$t]['email'], 'mandatory' => $t === 'system'], \App\Mz\Notifications\Notifications::TOPICS),
        ];
    }

    public static function updateNotificationPreferences(int $userId, array $in): array
    {
        $row = DB::table('user_preferences')->where('user_id', $userId)->first(['notification_topics']);
        $prefs = \App\Mz\Notifications\Notifications::preferencesOf($row->notification_topics ?? null);
        foreach ($in['topics'] ?? [] as $t) {
            if (! isset($prefs[$t['topic']]) || $t['topic'] === 'system') continue; // administrative messages stay on
            foreach (\App\Mz\Notifications\Notifications::CHANNELS as $c) {
                if (array_key_exists($c, $t)) $prefs[$t['topic']][$c] = (bool) $t[$c];
            }
        }
        $patch = ['notification_topics' => json_encode($prefs)];
        if (array_key_exists('enabled', $in)) $patch['notifications_enabled'] = (bool) $in['enabled'];
        DB::table('user_preferences')->upsert([['user_id' => $userId] + $patch], ['user_id'], array_keys($patch));
        return self::notificationPreferences($userId);
    }

    /** A token moves to the latest user that registers it. */
    public static function registerFcmToken(AuthContext $auth, string $token, string $platform): void
    {
        DB::table('fcm_tokens')->upsert(
            [['user_id' => $auth->id, 'token' => $token, 'platform' => $platform, 'device_id' => $auth->tokenDeviceId, 'last_seen_at' => DB::raw('NOW()'), 'invalidated_at' => null]],
            ['token'],
            ['user_id', 'device_id', 'platform', 'last_seen_at', 'invalidated_at'],
        );
    }

    public static function removeFcmToken(AuthContext $auth, string $token): void
    {
        DB::table('fcm_tokens')->where(['user_id' => $auth->id, 'token' => $token])->update(['invalidated_at' => DB::raw('NOW()')]);
    }

    public static function myActivity(int $userId, array $page): array
    {
        return DB::table('activity_logs')->where('user_id', $userId)->orderByDesc('occurred_at')
            ->limit($page['limit'])->offset($page['offset'])
            ->select('id', 'action', 'entity_type', 'entity_id', 'occurred_at')->get()->all();
    }
}
