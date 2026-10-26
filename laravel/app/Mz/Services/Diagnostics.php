<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\Dates;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

final class Diagnostics
{
    /**
     * Submit an automated diagnostic report or user-submitted problem report.
     */
    public static function submitReport(?AuthContext $auth, array $input, ?UploadedFile $screenshot = null): array
    {
        $isUserReport = !empty($input['is_user_report']) || !empty($input['user_description']);
        $module = trim((string) ($input['module'] ?? 'general'));
        $screen = !empty($input['screen']) ? trim((string) $input['screen']) : null;
        $operation = !empty($input['operation']) ? trim((string) $input['operation']) : null;
        $category = trim((string) ($input['category'] ?? ($isUserReport ? 'user_report' : 'error')));
        $severity = in_array($input['severity'] ?? '', ['info', 'warning', 'error', 'critical'], true)
            ? (string) $input['severity']
            : ($isUserReport ? 'warning' : 'error');

        $rawMessage = (string) ($input['message'] ?? $input['user_description'] ?? 'No description provided');
        $safeMessage = self::sanitize($rawMessage);
        $rawTrace = !empty($input['stack_trace']) ? (string) $input['stack_trace'] : null;
        $safeTrace = $rawTrace !== null ? self::sanitize($rawTrace) : null;

        $endpoint = !empty($input['endpoint']) ? substr(self::sanitizeEndpoint((string) $input['endpoint']), 0, 255) : null;
        $httpStatus = isset($input['http_status']) ? (int) $input['http_status'] : null;
        $appVersion = !empty($input['app_version']) ? substr(trim((string) $input['app_version']), 0, 32) : null;
        $platform = !empty($input['platform']) ? substr(trim((string) $input['platform']), 0, 32) : null;
        $isOffline = !empty($input['is_offline']);

        $userDesc = !empty($input['user_description']) ? self::sanitize((string) $input['user_description']) : null;
        $reproduceSteps = !empty($input['reproduce_steps']) ? self::sanitize((string) $input['reproduce_steps']) : null;

        // Screenshot storage (private)
        $screenshotPath = null;
        if ($screenshot !== null && $screenshot->isValid()) {
            $saved = Storage::save('diagnostic', Storage::FOLDERS['DIAGNOSTICS'], $screenshot);
            $screenshotPath = $saved['path'];
        }

        $now = now();

        // Automated error deduplication: if identical automated error seen in last 2 hours, increment occurrence count
        if (!$isUserReport) {
            $existing = DB::table('diagnostic_reports')
                ->where('is_user_report', false)
                ->where('module', $module)
                ->where('category', $category)
                ->where('screen', $screen)
                ->where('message', $safeMessage)
                ->where('status', 'new')
                ->where('last_seen_at', '>=', now()->subHours(2))
                ->first();

            if ($existing) {
                DB::table('diagnostic_reports')
                    ->where('id', $existing->id)
                    ->update([
                        'occurrences' => DB::raw('occurrences + 1'),
                        'last_seen_at' => $now,
                        'updated_at' => $now,
                    ]);

                return [
                    'report_id' => $existing->report_id,
                    'status' => 'deduplicated',
                    'occurrences' => (int) $existing->occurrences + 1,
                    'recorded_at' => Dates::sql($now),
                ];
            }
        }

        // Generate human-readable reference Report ID (e.g. ERR-20261025-A1B2C3)
        $clientReportId = !empty($input['report_id']) ? trim((string) $input['report_id']) : null;
        if ($clientReportId && preg_match('/^[A-Za-z0-9_-]{6,64}$/', $clientReportId)) {
            $reportId = $clientReportId;
        } else {
            $datePrefix = date('Ymd');
            $randomHex = strtoupper(bin2hex(random_bytes(3)));
            $reportId = ($isUserReport ? 'REP-' : 'ERR-') . "{$datePrefix}-{$randomHex}";
        }

        // Ensure report_id uniqueness
        $attempt = 0;
        $baseReportId = $reportId;
        while (DB::table('diagnostic_reports')->where('report_id', $reportId)->exists() && $attempt < 10) {
            $attempt++;
            $reportId = $baseReportId . '-' . strtoupper(Str::random(3));
        }

        $id = DB::table('diagnostic_reports')->insertGetId([
            'report_id' => $reportId,
            'user_id' => $auth?->id,
            'is_user_report' => $isUserReport,
            'module' => $module,
            'screen' => $screen,
            'operation' => $operation,
            'category' => $category,
            'severity' => $severity,
            'message' => $safeMessage,
            'stack_trace' => $safeTrace,
            'endpoint' => $endpoint,
            'http_status' => $httpStatus,
            'app_version' => $appVersion,
            'platform' => $platform,
            'is_offline' => $isOffline,
            'screenshot_path' => $screenshotPath,
            'user_description' => $userDesc,
            'reproduce_steps' => $reproduceSteps,
            'status' => 'new',
            'occurrences' => 1,
            'first_seen_at' => $now,
            'last_seen_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return [
            'id' => $id,
            'report_id' => $reportId,
            'status' => 'recorded',
            'is_user_report' => $isUserReport,
            'recorded_at' => Dates::sql($now),
        ];
    }

    /**
     * List diagnostic reports for authorized administrators.
     */
    public static function listReports(AuthContext $auth, array $filters = [], array $pageParams = []): array
    {
        if (! $auth->isAdmin && ! $auth->isSuperAdmin()) {
            throw ApiError::forbidden('FORBIDDEN', 'Administrative privilege required');
        }

        $query = DB::table('diagnostic_reports as d')
            ->leftJoin('users as u', 'u.id', '=', 'd.user_id')
            ->select(
                'd.id',
                'd.report_id',
                'd.user_id',
                'd.is_user_report',
                'd.module',
                'd.screen',
                'd.operation',
                'd.category',
                'd.severity',
                'd.message',
                'd.endpoint',
                'd.http_status',
                'd.app_version',
                'd.platform',
                'd.is_offline',
                'd.screenshot_path',
                'd.status',
                'd.occurrences',
                'd.first_seen_at',
                'd.last_seen_at',
                'd.created_at',
                'u.full_name as user_full_name',
                'u.phone as user_phone'
            );

        if (!empty($filters['status']) && $filters['status'] !== 'all') {
            $query->where('d.status', $filters['status']);
        }
        if (!empty($filters['module']) && $filters['module'] !== 'all') {
            $query->where('d.module', $filters['module']);
        }
        if (!empty($filters['severity']) && $filters['severity'] !== 'all') {
            $query->where('d.severity', $filters['severity']);
        }
        if (!empty($filters['category']) && $filters['category'] !== 'all') {
            $query->where('d.category', $filters['category']);
        }
        if (isset($filters['is_user_report']) && $filters['is_user_report'] !== '' && $filters['is_user_report'] !== 'all') {
            $query->where('d.is_user_report', filter_var($filters['is_user_report'], FILTER_VALIDATE_BOOLEAN));
        }
        if (!empty($filters['q'])) {
            $s = '%' . trim((string) $filters['q']) . '%';
            $query->where(function ($w) use ($s) {
                $w->where('d.report_id', 'like', $s)
                    ->orWhere('d.message', 'like', $s)
                    ->orWhere('d.user_description', 'like', $s)
                    ->orWhere('d.screen', 'like', $s)
                    ->orWhere('u.full_name', 'like', $s);
            });
        }

        $totalCount = (clone $query)->count();

        $page = max(1, (int) ($pageParams['page'] ?? 1));
        $limit = min(100, max(1, (int) ($pageParams['limit'] ?? 25)));
        $offset = ($page - 1) * $limit;

        $items = $query->orderByDesc('d.last_seen_at')
            ->offset($offset)
            ->limit($limit)
            ->get()
            ->map(function ($r) {
                return [
                    'id' => (int) $r->id,
                    'report_id' => $r->report_id,
                    'user_id' => $r->user_id ? (int) $r->user_id : null,
                    'user_name' => $r->user_full_name,
                    'is_user_report' => (bool) $r->is_user_report,
                    'module' => $r->module,
                    'screen' => $r->screen,
                    'operation' => $r->operation,
                    'category' => $r->category,
                    'severity' => $r->severity,
                    'message' => $r->message,
                    'endpoint' => $r->endpoint,
                    'http_status' => $r->http_status ? (int) $r->http_status : null,
                    'app_version' => $r->app_version,
                    'platform' => $r->platform,
                    'is_offline' => (bool) $r->is_offline,
                    'has_screenshot' => !empty($r->screenshot_path),
                    'screenshot_url' => Storage::url($r->screenshot_path),
                    'status' => $r->status,
                    'occurrences' => (int) $r->occurrences,
                    'first_seen_at' => $r->first_seen_at,
                    'last_seen_at' => $r->last_seen_at,
                    'created_at' => $r->created_at,
                ];
            })
            ->all();

        // Calculate summary counters
        $summary = [
            'total_reports' => DB::table('diagnostic_reports')->count(),
            'total_unresolved' => DB::table('diagnostic_reports')->whereIn('status', ['new', 'investigating'])->count(),
            'by_status' => [
                'new' => DB::table('diagnostic_reports')->where('status', 'new')->count(),
                'investigating' => DB::table('diagnostic_reports')->where('status', 'investigating')->count(),
                'resolved' => DB::table('diagnostic_reports')->where('status', 'resolved')->count(),
                'dismissed' => DB::table('diagnostic_reports')->where('status', 'dismissed')->count(),
            ],
            'by_severity' => [
                'critical' => DB::table('diagnostic_reports')->where('severity', 'critical')->count(),
                'error' => DB::table('diagnostic_reports')->where('severity', 'error')->count(),
                'warning' => DB::table('diagnostic_reports')->where('severity', 'warning')->count(),
                'info' => DB::table('diagnostic_reports')->where('severity', 'info')->count(),
            ],
            'user_reports_count' => DB::table('diagnostic_reports')->where('is_user_report', true)->count(),
        ];

        return [
            'data' => $items,
            'summary' => $summary,
            'meta' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $totalCount,
                'pages' => ceil($totalCount / $limit) ?: 1,
            ],
        ];
    }

    /**
     * Get single report details including technical diagnostics (Super Admin only for stack trace).
     */
    public static function getReport(AuthContext $auth, int $id): array
    {
        if (! $auth->isAdmin && ! $auth->isSuperAdmin()) {
            throw ApiError::forbidden('FORBIDDEN', 'Administrative privilege required');
        }

        $row = DB::table('diagnostic_reports as d')
            ->leftJoin('users as u', 'u.id', '=', 'd.user_id')
            ->leftJoin('users as rb', 'rb.id', '=', 'd.resolved_by')
            ->where('d.id', $id)
            ->first([
                'd.*',
                'u.full_name as user_full_name',
                'u.phone as user_phone',
                'u.email as user_email',
                'rb.full_name as resolved_by_name',
            ]);

        if (! $row) {
            throw ApiError::notFound('REPORT_NOT_FOUND', 'Diagnostic report not found');
        }

        // Restrict technical stack traces to Super Admin accounts
        $canViewTrace = $auth->isSuperAdmin();

        return [
            'id' => (int) $row->id,
            'report_id' => $row->report_id,
            'user_id' => $row->user_id ? (int) $row->user_id : null,
            'user' => $row->user_id ? [
                'id' => (int) $row->user_id,
                'name' => $row->user_full_name,
                'phone' => $row->user_phone,
                'email' => $row->user_email,
            ] : null,
            'is_user_report' => (bool) $row->is_user_report,
            'module' => $row->module,
            'screen' => $row->screen,
            'operation' => $row->operation,
            'category' => $row->category,
            'severity' => $row->severity,
            'message' => $row->message,
            'stack_trace' => $canViewTrace ? $row->stack_trace : '[Stack trace restricted to Super Administrator]',
            'endpoint' => $row->endpoint,
            'http_status' => $row->http_status ? (int) $row->http_status : null,
            'app_version' => $row->app_version,
            'platform' => $row->platform,
            'is_offline' => (bool) $row->is_offline,
            'has_screenshot' => !empty($row->screenshot_path),
            'screenshot_url' => Storage::url($row->screenshot_path),
            'user_description' => $row->user_description,
            'reproduce_steps' => $row->reproduce_steps,
            'status' => $row->status,
            'status_note' => $row->status_note,
            'resolved_by' => $row->resolved_by ? (int) $row->resolved_by : null,
            'resolved_by_name' => $row->resolved_by_name,
            'resolved_at' => $row->resolved_at,
            'occurrences' => (int) $row->occurrences,
            'first_seen_at' => $row->first_seen_at,
            'last_seen_at' => $row->last_seen_at,
            'created_at' => $row->created_at,
        ];
    }

    /**
     * Update report status with audit note.
     */
    public static function updateStatus(AuthContext $auth, int $id, string $status, ?string $note = null): array
    {
        if (! $auth->isAdmin && ! $auth->isSuperAdmin()) {
            throw ApiError::forbidden('FORBIDDEN', 'Administrative privilege required');
        }

        if (! in_array($status, ['new', 'investigating', 'resolved', 'dismissed'], true)) {
            throw ApiError::badRequest('INVALID_STATUS', 'Valid statuses: new, investigating, resolved, dismissed');
        }

        $row = DB::table('diagnostic_reports')->where('id', $id)->first();
        if (! $row) {
            throw ApiError::notFound('REPORT_NOT_FOUND', 'Diagnostic report not found');
        }

        $now = now();
        $updates = [
            'status' => $status,
            'updated_at' => $now,
        ];

        if ($note !== null && trim($note) !== '') {
            $existingNote = $row->status_note ? $row->status_note . "\n---\n" : '';
            $author = $auth->fullName ?? "Admin #{$auth->id}";
            $date = date('Y-m-d H:i');
            $updates['status_note'] = $existingNote . "[$date - $author ($status)] " . self::sanitize($note);
        }

        if ($status === 'resolved' || $status === 'dismissed') {
            $updates['resolved_by'] = $auth->id;
            $updates['resolved_at'] = $now;
        } else {
            $updates['resolved_by'] = null;
            $updates['resolved_at'] = null;
        }

        DB::table('diagnostic_reports')->where('id', $id)->update($updates);

        return self::getReport($auth, $id);
    }

    /**
     * Get authorized screenshot file path and MIME type for administrative inspection.
     */
    public static function getScreenshot(AuthContext $auth, int $id): array
    {
        if (! $auth->isAdmin && ! $auth->isSuperAdmin()) {
            throw ApiError::forbidden('FORBIDDEN', 'Administrative privilege required');
        }

        $row = DB::table('diagnostic_reports')->where('id', $id)->first(['screenshot_path']);
        if (! $row || empty($row->screenshot_path)) {
            throw ApiError::notFound('SCREENSHOT_NOT_FOUND', 'Screenshot not found');
        }

        $abs = Storage::privatePath($row->screenshot_path);
        if (! is_file($abs)) {
            throw ApiError::notFound('FILE_NOT_FOUND', 'Screenshot file missing on disk');
        }

        $ext = strtolower(pathinfo($abs, PATHINFO_EXTENSION));
        $mime = match ($ext) {
            'png' => 'image/png',
            'webp' => 'image/webp',
            default => 'image/jpeg',
        };

        return ['abs' => $abs, 'mime' => $mime, 'name' => "diagnostic_{$id}.{$ext}"];
    }

    /**
     * Sanitize strings to strip passwords, tokens, private authorization headers, and secrets.
     */
    public static function sanitize(string $text): string
    {
        // Redact JWT tokens
        $text = preg_replace('/(Bearer\s+)[A-Za-z0-9_\-=]+\.[A-Za-z0-9_\-=]+\.?[A-Za-z0-9_\-.\+\/=]*/i', '$1[REDACTED_JWT]', $text);
        // Redact passwords and pins in JSON or query params
        $text = preg_replace('/("(?:password|pin|access_token|refresh_token|secret)":\s*")[^"]+(")/i', '$1[REDACTED]$2', $text);
        $text = preg_replace('/((?:password|pin|token|secret)=)[^&\s]+/i', '$1[REDACTED]', $text);
        return $text;
    }

    /**
     * Sanitize API endpoint URLs to remove sensitive query parameters.
     */
    private static function sanitizeEndpoint(string $url): string
    {
        $parts = parse_url($url);
        $path = $parts['path'] ?? $url;
        return $path;
    }
}
