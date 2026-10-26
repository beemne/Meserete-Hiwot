<?php

namespace App\Mz\Crypto;

/**
 * The columns kept encrypted at rest (MZ-Seal). Values are sealed by the query builder on insert /
 * update / upsert (App\Mz\Db\MzBuilder) and opened on every read (App\Mz\Db\MzConnection::select).
 *
 * Chosen: personal data (membership form, IP addresses, user agents), private communication
 * (chat, notification texts), and free-text notes / reasons / descriptions.
 * Not encrypted on purpose — the database must compare, search, sort or join on them: ids and
 * foreign keys, statuses, dates and amounts, names and titles (search / ordering), phone and email
 * (sign-in lookup), codes, tokens (already stored as hashes), file paths, JSON columns, settings.
 * An encrypted column can never be used in WHERE / LIKE / ORDER BY / GROUP BY / JOIN.
 */
final class EncryptedColumns
{
    public const MAP = [
        'member_profiles' => [
            'mother_name', 'birth_diocese', 'birth_city', 'birth_woreda', 'birth_kebele', 'birth_place_name', 'christian_name',
            'baptism_church', 'address_woreda', 'house_number', 'phone_home', 'emergency_name', 'emergency_phone_home',
            'emergency_phone_mobile', 'abinet_other', 'institution_name', 'field_of_study', 'profession', 'experience_profession',
            'church_service', 'school_name', 'confession_father_name', 'confession_father_phone', 'marriage_other',
        ],
        'users' => ['membership_status_detail'],
        'chat_messages' => ['body', 'meeting_url', 'attachment_name'],
        'notifications' => ['body'],
        'scheduled_notifications' => ['body'],
        'attendance' => ['notes'],
        'attendance_corrections' => ['reason', 'review_note'],
        'borrowing_batches' => ['notes'],
        'borrowings' => ['notes', 'return_notes', 'fine_override_reason', 'rejection_reason'],
        'department_participation' => ['note'],
        'department_participation_history' => ['note'],
        'edu_scores' => ['remark', 'review_note'],
        'edu_score_history' => ['reason'],
        'edu_requests' => ['reason', 'review_note'],
        'edu_complaints' => ['description'],
        'edu_complaint_messages' => ['body'],
        'edu_journey' => ['reason'],
        'edu_submissions' => ['text', 'feedback'],
        'payments' => ['reference', 'note'],
        'permission_requests' => ['reason', 'review_note', 'cancel_reason'],
        'profile_change_requests' => ['reason', 'changes', 'note'],
        'profile_change_history' => ['old_value', 'new_value'],
        'property_requests' => ['review_note'],
        'property_request_events' => ['note'],
        'wedding_services' => ['notes'],
        'wedding_service_members' => ['note'],
        'choir_selections' => ['notes'],
        'selection_results' => ['override_reason'],
        'selection_scores' => ['note'],
        'selection_config_versions' => ['comment'],
        'library_requests' => ['note', 'review_note'],
        'projects' => ['description', 'notes'],
        'project_tasks' => ['description', 'status_reason', 'notes', 'completion_note'],
        'project_issues' => ['description', 'resolution'],
        'project_suggestions' => ['body', 'review_note'],
        'project_comments' => ['body'],
        'project_expenses' => ['description', 'paid_by', 'review_note', 'notes'],
        'project_budget_adjustments' => ['reason', 'review_note'],
        'audit_logs' => ['ip', 'user_agent'],
        'device_history' => ['ip'],
        'refresh_tokens' => ['ip', 'user_agent'],
    ];

    /** Primary keys of the tables whose key is not `id` (used by mz:encrypt-data). */
    public const KEYS = ['member_profiles' => ['user_id'], 'edu_scores' => ['assessment_id', 'user_id']];

    /** @return string[] */
    public static function for(string $table): array
    {
        return self::MAP[$table] ?? [];
    }

    /** Seal the encrypted columns of one row (strings / numbers; null, '' and raw expressions are kept). */
    public static function sealRow(string $table, array $row): array
    {
        if (! Seal::enabled()) return $row;
        foreach (self::for($table) as $c) {
            if (! array_key_exists($c, $row)) continue;
            $v = $row[$c];
            if ($v === null || $v === '' || ! (is_string($v) || is_int($v) || is_float($v))) continue;
            // Already sealed (e.g. re-saved by mz:encrypt-data). Text that only looks sealed is sealed too,
            // so a member can never store a value that breaks reading.
            if (Seal::canOpen($v)) continue;
            $row[$c] = Seal::seal((string) $v);
        }
        return $row;
    }
}
