<?php

namespace App\Mz\Notifications;

use App\Mz\Support\ApiError;
use App\Mz\Support\Crypto;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Telegram bot (port of telegramService.js): account linking, password-reset codes, temporary
 * passwords. Production receives updates through the webhook; `php artisan mz:telegram poll` is
 * for local development.
 */
final class Telegram
{
    private const LINK_TTL_MIN = 15;

    public static function enabled(): bool
    {
        $t = config('mz.telegram');
        return (bool) ($t['token'] && $t['username']);
    }

    public static function escapeHtml(?string $s): string
    {
        return str_replace(['&', '<', '>'], ['&amp;', '&lt;', '&gt;'], (string) $s);
    }

    public static function api(string $method, array $body = [], int $timeout = 15): mixed
    {
        $t = config('mz.telegram');
        $res = Http::timeout($timeout)->asJson()->post("{$t['api_base']}/bot{$t['token']}/$method", (object) $body);
        $json = $res->json() ?? [];
        if (empty($json['ok'])) {
            throw new \RuntimeException("telegram $method failed: " . ($json['description'] ?? $res->status()));
        }
        return $json['result'] ?? null;
    }

    /** Best-effort HTML message; never throws. */
    public static function sendMessage(int|string|null $chatId, string $html): bool
    {
        if (! self::enabled() || ! $chatId) {
            return false;
        }
        try {
            self::api('sendMessage', ['chat_id' => $chatId, 'text' => $html, 'parse_mode' => 'HTML', 'disable_web_page_preview' => true]);
            return true;
        } catch (\Throwable $e) {
            Log::warning('telegram send failed', ['error' => $e->getMessage()]);
            return false;
        }
    }

    public static function sendToUser(int $userId, string $html): bool
    {
        $u = DB::table('users')->where('id', $userId)->first(['telegram_chat_id']);
        return $u?->telegram_chat_id ? self::sendMessage($u->telegram_chat_id, $html) : false;
    }

    public static function createLinkToken(int $userId): array
    {
        if (! self::enabled()) {
            throw new ApiError(503, 'TELEGRAM_NOT_CONFIGURED', 'Telegram bot is not configured');
        }
        $token = Crypto::randomToken(24);
        DB::transaction(function () use ($userId, $token) {
            DB::table('telegram_link_tokens')->where('user_id', $userId)->whereNull('used_at')->update(['used_at' => DB::raw('NOW()')]);
            DB::table('telegram_link_tokens')->insert([
                'user_id' => $userId,
                'token_hash' => Crypto::hmac("tg:$token"),
                'expires_at' => gmdate('Y-m-d H:i:s', time() + self::LINK_TTL_MIN * 60),
            ]);
        });
        $bot = config('mz.telegram.username');
        return ['url' => "https://t.me/$bot?start=$token", 'bot_username' => $bot, 'expires_in_minutes' => self::LINK_TTL_MIN];
    }

    public static function unlink(int $userId): void
    {
        $u = DB::table('users')->where('id', $userId)->first(['telegram_chat_id']);
        DB::table('users')->where('id', $userId)->update(['telegram_chat_id' => null, 'telegram_username' => null, 'telegram_linked_at' => null]);
        if ($u?->telegram_chat_id) {
            self::sendMessage($u->telegram_chat_id, T::t('telegram.unlinked'));
        }
    }

    private static function linkChat(string $token, array $chat, ?array $from): bool
    {
        $row = DB::table('telegram_link_tokens')
            ->where('token_hash', Crypto::hmac("tg:$token"))
            ->whereNull('used_at')
            ->where('expires_at', '>', gmdate('Y-m-d H:i:s'))
            ->first();
        if (! $row) {
            return self::sendMessage($chat['id'], T::t('telegram.invalid'));
        }
        $user = DB::transaction(function () use ($row, $chat, $from) {
            DB::table('telegram_link_tokens')->where('id', $row->id)->update(['used_at' => DB::raw('NOW()')]);
            // One Telegram account ↔ one app account: release it from anyone else first.
            DB::table('users')->where('telegram_chat_id', $chat['id'])->where('id', '<>', $row->user_id)->update(['telegram_chat_id' => null, 'telegram_username' => null, 'telegram_linked_at' => null]);
            DB::table('users')->where('id', $row->user_id)->update([
                'telegram_chat_id' => $chat['id'],
                'telegram_username' => ! empty($from['username']) ? mb_substr((string) $from['username'], 0, 64) : null,
                'telegram_linked_at' => DB::raw('NOW()'),
            ]);
            return DB::table('users')->where('id', $row->user_id)->first(['full_name']);
        });
        return self::sendMessage($chat['id'], T::t('telegram.linked', ['name' => self::escapeHtml($user->full_name)]));
    }

    /** Process one Telegram update (webhook or polling). */
    public static function handleUpdate(?array $update): void
    {
        $msg = $update['message'] ?? null;
        if (empty($msg['text']) || ($msg['chat']['type'] ?? null) !== 'private') {
            return;
        }
        $parts = preg_split('/\s+/', trim($msg['text']), 3);
        $command = $parts[0] ?? '';
        $arg = $parts[1] ?? null;
        if ($command === '/start' && $arg && preg_match('/^[A-Za-z0-9_-]{8,64}$/', $arg)) {
            self::linkChat($arg, $msg['chat'], $msg['from'] ?? null);
            return;
        }
        if ($command === '/stop') {
            $u = DB::table('users')->where('telegram_chat_id', $msg['chat']['id'])->first(['id']);
            if ($u) {
                self::unlink($u->id);
                return;
            }
        }
        self::sendMessage($msg['chat']['id'], T::t('telegram.welcome'));
    }

    public static function verifyWebhookSecret(?string $header): bool
    {
        $secret = (string) config('mz.telegram.webhook_secret');
        return $secret !== '' && hash_equals($secret, (string) $header);
    }
}
