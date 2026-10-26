<?php

namespace App\Mz\Notifications;

use App\Mz\Support\Dates;
use Illuminate\Support\Facades\Log;
use Symfony\Component\Mailer\Mailer as SymfonyMailer;
use Symfony\Component\Mailer\Transport\Smtp\EsmtpTransport;
use Symfony\Component\Mime\Email;

/**
 * Email through the SMTP server of the environment (SMTP_HOST / SMTP_PORT / SMTP_USER /
 * SMTP_PASSWORD / SMTP_FROM — never in the code). Plain text (password reset) and the branded
 * notification template used by the notification center's email channel.
 */
final class Mailer
{
    private static ?SymfonyMailer $mailer = null;

    private const TOPIC_LABEL = [
        'program' => 'ፕሮግራም', 'attendance' => 'ክትትል', 'project' => 'ፕሮጀክት', 'department' => 'ክፍል',
        'education' => 'ትምህርት', 'property' => 'ንብረት', 'mezmur' => 'መዝሙር', 'system' => 'አስተዳደር',
    ];

    public static function configured(): bool
    {
        $c = config('mz.smtp');
        return (bool) ($c['host'] && $c['from']);
    }

    private static function mailer(): SymfonyMailer
    {
        if (! self::$mailer) {
            $c = config('mz.smtp');
            $transport = new EsmtpTransport($c['host'], $c['port'], $c['port'] === 465);
            if ($c['user']) {
                $transport->setUsername($c['user']);
                $transport->setPassword((string) $c['password']);
            }
            self::$mailer = new SymfonyMailer($transport);
        }
        return self::$mailer;
    }

    public static function send(string $to, string $subject, string $text): bool
    {
        if (! self::configured()) {
            if (! config('mz.is_prod')) {
                Log::info('[dev] email not sent (SMTP not configured)', ['to' => $to, 'subject' => $subject]);
            }
            return false;
        }
        try {
            self::mailer()->send((new Email())->from(config('mz.smtp.from'))->to($to)->subject($subject)->text($text));
            return true;
        } catch (\Throwable $e) {
            Log::error('failed to send email', ['error' => $e->getMessage()]);
            return false;
        }
    }

    /** One notification in the branded template. $n = [name, title, body, topic, at, link?]. */
    public static function sendNotification(string $to, array $n): bool
    {
        if (! self::configured()) return false;
        try {
            $html = self::render($n);
            $text = "{$n['title']}\n\n{$n['body']}\n\n" . self::when($n['at']) . ($n['link'] ? "\n\n{$n['link']}" : '') . "\n\n— መሠረተ ሕይወት ሰንበት ትምህርት ቤት";
            $email = (new Email())->from(config('mz.smtp.from'))->to($to)->subject('መሠረተ ሕይወት · ' . $n['title'])->text($text)->html($html);
            $logo = resource_path('static/logo.jpg');
            if (is_file($logo)) $email->embedFromPath($logo, 'logo', 'image/jpeg');
            self::mailer()->send($email);
            return true;
        } catch (\Throwable $e) {
            Log::error('failed to send notification email', ['error' => $e->getMessage()]);
            self::$mailer = null; // a broken connection is rebuilt on the next send
            return false;
        }
    }

    /** "12 መስከረም 2019 ዓ.ም. · 14:30" (local time, Ethiopian date). */
    public static function when(mixed $at): string
    {
        $d = Dates::of($at) ?? Dates::now();
        return \App\Mz\Services\ReportExport::ethiopianDate($d) . ' · ' . $d->setTimezone(Dates::tz())->format('H:i');
    }

    public static function render(array $n): string
    {
        $e = fn ($s) => htmlspecialchars((string) ($s ?? ''), ENT_QUOTES | ENT_HTML5, 'UTF-8');
        $body = nl2br($e($n['body']));
        $topic = self::TOPIC_LABEL[$n['topic']] ?? self::TOPIC_LABEL['system'];
        $button = $n['link'] ? '<tr><td style="padding:8px 28px 28px"><a href="' . $e($n['link']) . '" style="display:inline-block;background:#6e1423;color:#ffffff;text-decoration:none;font-weight:600;font-size:15px;padding:12px 26px;border-radius:100px">በመተግበሪያው ይክፈቱ</a></td></tr>' : '';
        $greeting = $n['name'] ? '<p style="margin:0 0 12px;color:#3d2e31;font-size:15px">ሰላም ' . $e($n['name']) . '፣</p>' : '';
        return '<!doctype html><html lang="am"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>' . $e($n['title']) . '</title></head>'
            . '<body style="margin:0;padding:0;background:#f6f1ea;font-family:\'Noto Sans Ethiopic\',\'Nyala\',system-ui,sans-serif">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f6f1ea;padding:24px 12px"><tr><td align="center">'
            . '<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:18px;overflow:hidden">'
            . '<tr><td style="background:#6e1423;padding:20px 28px"><table role="presentation" cellpadding="0" cellspacing="0"><tr>'
            . '<td><img src="cid:logo" width="44" height="44" alt="" style="border-radius:10px;display:block;border:2px solid #c8961e"></td>'
            . '<td style="padding-left:12px;color:#ffffff;font-size:17px;font-weight:700">መሠረተ ሕይወት<br><span style="font-size:12px;font-weight:400;color:#f1d9a3">ሰንበት ትምህርት ቤት</span></td>'
            . '</tr></table></td></tr>'
            . '<tr><td style="padding:24px 28px 4px"><span style="display:inline-block;background:#fbf3e2;color:#8a6412;font-size:12px;font-weight:600;padding:4px 12px;border-radius:100px">' . $e($topic) . '</span>'
            . '<h1 style="margin:14px 0 10px;color:#6e1423;font-size:21px;line-height:1.4">' . $e($n['title']) . '</h1>'
            . $greeting
            . '<p style="margin:0 0 14px;color:#3d2e31;font-size:15px;line-height:1.7">' . $body . '</p>'
            . '<p style="margin:0 0 8px;color:#8a7a7d;font-size:13px">🕒 ' . $e(self::when($n['at'])) . '</p></td></tr>'
            . $button
            . '<tr><td style="background:#faf7f2;padding:16px 28px;color:#8a7a7d;font-size:12px;line-height:1.6">ይህ መልዕክት ከመሠረተ ሕይወት ሰንበት ትምህርት ቤት መተግበሪያ በራስ-ሰር የተላከ ነው። የኢሜል ማሳወቂያዎችን በመተግበሪያው ቅንብሮች → ማሳወቂያዎች ማስተካከል ይችላሉ።</td></tr>'
            . '</table></td></tr></table></body></html>';
    }
}
