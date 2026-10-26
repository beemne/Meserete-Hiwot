<?php

namespace App\Mz\Auth;

use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Throwable;

/** Administrative audit log (port of audit/auditService.js). */
final class Audit
{
    public const ADMIN_LOGIN = 'admin.login';
    public const AUTH_LOGIN = 'auth.login';
    public const REPORT_EXPORT = 'report.export';
    public const AUTH_LOGOUT = 'auth.logout';
    public const AUTH_PASSWORD_CHANGE = 'auth.password_change';
    public const AUTH_PASSWORD_RESET = 'auth.password_reset';
    public const SESSION_REVOKE = 'auth.session_revoke';
    public const SESSION_REVOKE_OTHERS = 'auth.session_revoke_others';
    public const SESSION_REVOKE_ALL = 'auth.session_revoke_all';
    public const ADMIN_LOGIN_FAILED = 'admin.login_failed';
    public const SYSTEM_LOGIN = 'system.login';
    public const SYSTEM_LOGIN_FAILED = 'system.login_failed';
    public const AUTHZ_DENIED = 'authorization.denied';
    public const USER_CREATE = 'user.create';
    public const USER_UPDATE = 'user.update';
    public const USER_DISABLE = 'user.disable';
    public const USER_ENABLE = 'user.enable';
    public const USER_DELETE = 'user.delete';
    public const USER_PASSWORD_RESET = 'user.password_reset';
    public const PROFILE_CHANGE_APPROVE = 'user.profile_change_approved';
    public const PROFILE_CHANGE_REJECT = 'user.profile_change_rejected';
    public const RELEASE_PUBLISH = 'release.publish';
    public const RELEASE_UPDATE = 'release.update';
    public const RELEASE_DELETE = 'release.delete';
    public const DEVICE_RESET = 'user.device_reset';
    public const FORCE_LOGOUT = 'user.force_logout';
    public const MEZMUR_CREATE = 'mezmur.create';
    public const MEZMUR_UPDATE = 'mezmur.update';
    public const MEZMUR_DELETE = 'mezmur.delete';
    public const MEZMUR_MEDIA = 'mezmur.media';
    public const CATEGORY_CREATE = 'category.create';
    public const CATEGORY_UPDATE = 'category.update';
    public const CATEGORY_MOVE = 'category.move';
    public const CATEGORY_REORDER = 'category.reorder';
    public const CATEGORY_DELETE = 'category.delete';
    public const AD_CREATE = 'advertisement.create';
    public const AD_UPDATE = 'advertisement.update';
    public const AD_DELETE = 'advertisement.delete';
    public const PAGE_CREATE = 'page.create';
    public const PAGE_UPDATE = 'page.update';
    public const PAGE_DELETE = 'page.delete';
    public const PROGRAM_CREATE = 'program.create';
    public const PROGRAM_UPDATE = 'program.update';
    public const PROGRAM_CANCEL = 'program.cancel';
    public const PROGRAM_DELETE = 'program.delete';
    public const PROGRAM_PARTICIPANTS = 'program.participants';
    public const ATTENDANCE_SET = 'attendance.set';
    public const ATTENDANCE_BULK = 'attendance.bulk';
    public const PERMISSION_REVIEW = 'permission.review';
    public const PERMISSION_CANCEL = 'permission.cancel';
    public const BULK_IMPORT = 'bulk.import';
    public const DEPARTMENT_UPDATE = 'department.update';
    public const DEPARTMENT_ASSIGN = 'department.assign';
    public const PAYMENT_RECORD = 'payment.record';
    public const PAYMENT_VERIFY = 'payment.verify';
    public const PAYMENT_RATE = 'payment.rate_update';
    public const PROGRAM_CATEGORY = 'program.category';
    public const CHOIR_POLICY = 'choir.policy_update';
    public const CHOIR_SELECT = 'choir.select';
    public const CHOIR_REMOVE = 'choir.remove';
    public const PARTICIPATION = 'participation.record';
    public const EDU_UPDATE = 'education.update';
    public const NOTIFICATION_BROADCAST = 'notification.broadcast';
    public const NOTIFICATION_RESEND = 'notification.resend';
    public const ITEM_CREATE = 'item.create';
    public const ITEM_UPDATE = 'item.update';
    public const ITEM_DELETE = 'item.delete';
    public const BORROW_CREATE = 'borrowing.create';
    public const BORROW_BULK = 'borrowing.bulk_create';
    public const BORROW_SIGNATURE = 'borrowing.signature';
    public const BORROW_RETURN = 'borrowing.return';
    public const FINE_OVERRIDE = 'fine.override';
    public const FINE_STATUS = 'fine.status';
    public const FINE_POLICY = 'fine.policy_update';
    public const RETURN_CONDITIONS = 'return_conditions.update';
    public const ADMIN_CREATE = 'admin.create';
    public const ADMIN_UPDATE = 'admin.update';
    public const ADMIN_ROLE_CHANGE = 'admin.role_change';
    public const ADMIN_PROMOTE = 'admin.promote';
    public const ADMIN_DEMOTE = 'admin.demote';
    public const ADMIN_PERMISSIONS_CHANGE = 'admin.permissions_change';
    public const ROLE_CREATE = 'role.create';
    public const ROLE_UPDATE = 'role.update';
    public const ROLE_DELETE = 'role.delete';
    public const SETTINGS_UPDATE = 'settings.update';
    public const DEPARTMENT_ADMIN = 'department.admin_roles';
    public const ATTENDANCE_CLOSE = 'attendance.close';
    public const ATTENDANCE_CORRECTION_REQUEST = 'attendance.correction_request';
    public const ATTENDANCE_CORRECTION_REVIEW = 'attendance.correction_review';
    public const ATTENDANCE_OVERRIDE = 'attendance.override';
    public const PROGRAM_OCCURRENCE = 'program.occurrence_change';
    public const PROPERTY_REQUEST = 'property.request';
    public const PROPERTY_REVIEW = 'property.review';
    public const PROPERTY_ISSUE = 'property.issue';
    public const PROPERTY_RETURN = 'property.return';
    public const BORROW_APPROVE = 'borrowing.approve';
    public const BORROW_REJECT = 'borrowing.reject';
    public const BORROW_RENEW = 'borrowing.renew';
    public const SELECTION_CREATE = 'selection.create';
    public const SELECTION_UPDATE = 'selection.update';
    public const SELECTION_STATUS = 'selection.status';
    public const SELECTION_OVERRIDE = 'selection.override';
    public const SELECTION_FINALIZE = 'selection.finalize';
    public const WEDDING_UPDATE = 'wedding.update';
    public const WEDDING_MEMBERS = 'wedding.members';
    public const EXAM_SCORE_UPDATE = 'education.score_update';
    public const PROJECT_UPDATE = 'project.update';
    public const PROJECT_TASK_UPDATE = 'project.task_update';
    public const SELECTION_REVIEW = 'selection.review';
    public const CONTRIBUTION_RECEIPT_SUBMIT = 'payment.receipt_submit';
    public const CONTRIBUTION_RECEIPT_VERIFY = 'payment.receipt_verify';
    public const CONTRIBUTION_RECEIPT_REJECT = 'payment.receipt_reject';
    public const EDU_LESSON_CREATE = 'education.lesson_create';
    public const EDU_LESSON_UPDATE = 'education.lesson_update';
    public const EDU_LESSON_DELETE = 'education.lesson_delete';
    public const EDU_QUIZ_CREATE = 'education.quiz_create';
    public const EDU_QUIZ_SUBMIT = 'education.quiz_submit';
    public const EDU_QUIZ_GRADE = 'education.quiz_grade';
    public const EDU_ENROLL = 'education.enroll';
    public const EDU_PROMOTION = 'education.promotion';
    public const EDU_BANK_CREATE = 'education.bank_create';
    public const EDU_BANK_DELETE = 'education.bank_delete';
    public const SELECTION_RANK = 'selection.rank';

    /**
     * Recursively redact sensitive keys (passwords, PINs, tokens, secrets) before logging.
     */
    public static function redactSensitive(mixed $data): mixed
    {
        if (! is_array($data) && ! is_object($data)) return $data;
        $sensitiveKeys = ['password', 'new_password', 'current_password', 'pin', 'token', 'access_token', 'refresh_token', 'secret', 'totp_secret', 'secret_hash', 'hash', 'authorization', 'bearer'];
        $clean = [];
        foreach ((array) $data as $k => $v) {
            $lower = strtolower((string) $k);
            $isSensitive = false;
            foreach ($sensitiveKeys as $sk) {
                if (str_contains($lower, $sk)) {
                    $isSensitive = true;
                    break;
                }
            }
            if ($isSensitive) {
                $clean[$k] = '[REDACTED]';
            } elseif (is_array($v) || is_object($v)) {
                $clean[$k] = self::redactSensitive($v);
            } else {
                $clean[$k] = $v;
            }
        }
        return is_object($data) ? (object) $clean : $clean;
    }

    /**
     * Record an administrative action. $ctx = ['auth' => ?AuthContext, 'ip' => ?string, 'userAgent' => ?string, 'actorId' => ?int].
     * Inside a transaction ($inTrx) a failure propagates so the operation rolls back.
     */
    public static function log(?array $ctx, string $action, ?string $entityType = null, int|string|null $entityId = null, mixed $metadata = null, bool $hidden = false, bool $inTrx = false): void
    {
        $auth = $ctx['auth'] ?? null;
        $cleanMeta = $metadata !== null ? self::redactSensitive($metadata) : null;
        $row = [
            'actor_id' => $auth?->id ?? ($ctx['actorId'] ?? null),
            'is_hidden' => (bool) ($hidden || ($auth?->isSystem ?? false)),
            'action' => $action,
            'entity_type' => $entityType,
            'entity_id' => $entityId,
            'metadata' => $cleanMeta !== null ? json_encode($cleanMeta, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES) : null,
            'ip' => isset($ctx['ip']) ? substr((string) $ctx['ip'], 0, 45) : null,
            'user_agent' => isset($ctx['userAgent']) ? substr((string) $ctx['userAgent'], 0, 255) : null,
        ];
        try {
            DB::table('audit_logs')->insert($row);
        } catch (Throwable $e) {
            if ($inTrx || DB::transactionLevel() > 0) {
                throw $e;
            }
            Log::error('failed to write audit log', ['action' => $action, 'error' => $e->getMessage()]);
        }
    }
}
