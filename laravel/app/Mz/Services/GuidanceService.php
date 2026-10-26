<?php

namespace App\Mz\Services;

use App\Mz\Auth\AuthContext;
use App\Mz\Support\ApiError;
use App\Mz\Support\T;
use Illuminate\Support\Facades\DB;

final class GuidanceService
{
    /** List guidance articles accessible to the user based on role and effective permissions. */
    public static function listForUser(?AuthContext $auth, array $filters = []): array
    {
        $q = DB::table('guidance_articles')
            ->where('status', 'published')
            ->orderBy('sort_order')
            ->orderBy('id');

        if (! empty($filters['category'])) {
            $q->where('category', $filters['category']);
        }

        if (! empty($filters['screen'])) {
            $q->where('target_screen', $filters['screen']);
        }

        if (! empty($filters['tour_id'])) {
            $q->where('tour_id', $filters['tour_id']);
        }

        if (! empty($filters['search'])) {
            $term = '%' . trim($filters['search']) . '%';
            $q->where(function ($sub) use ($term) {
                $sub->where('title', 'like', $term)
                    ->orWhere('summary', 'like', $term)
                    ->orWhere('content', 'like', $term)
                    ->orWhere('category', 'like', $term);
            });
        }

        $rows = $q->get();
        $out = [];

        foreach ($rows as $r) {
            if (! self::isAccessibleToUser($r, $auth)) {
                continue;
            }
            $out[] = self::formatArticle($r);
        }

        return $out;
    }

    /** Contextual guidance article for a specific screen, gated by caller's role/permissions. */
    public static function getForScreen(?AuthContext $auth, string $screen): ?array
    {
        $articles = self::listForUser($auth, ['screen' => $screen]);
        if (! empty($articles)) {
            return $articles[0];
        }

        // Check if there is an article matching the prefix or category
        $normalized = explode('?', $screen)[0];
        $rows = DB::table('guidance_articles')
            ->where('status', 'published')
            ->where('target_screen', $normalized)
            ->get();

        foreach ($rows as $r) {
            if (self::isAccessibleToUser($r, $auth)) {
                return self::formatArticle($r);
            }
        }

        // Hierarchical fallback: e.g. /programs/12 -> /programs, /admin/users/5 -> /admin/users
        $parts = explode('/', trim($normalized, '/'));
        while (count($parts) > 1) {
            array_pop($parts);
            $parentScreen = '/' . implode('/', $parts);
            $parentRows = DB::table('guidance_articles')
                ->where('status', 'published')
                ->where('target_screen', $parentScreen)
                ->get();

            foreach ($parentRows as $r) {
                if (self::isAccessibleToUser($r, $auth)) {
                    return self::formatArticle($r);
                }
            }
        }

        return null;
    }

    /** Get article by slug or ID with authorization check. */
    public static function getBySlugOrId(?AuthContext $auth, string|int $slugOrId): array
    {
        $q = DB::table('guidance_articles');
        if (is_numeric($slugOrId)) {
            $q->where('id', (int) $slugOrId);
        } else {
            $q->where('slug', $slugOrId);
        }

        $row = $q->first();
        if (! $row) {
            throw ApiError::notFound('ARTICLE_NOT_FOUND', 'Guidance article not found');
        }

        $canManage = $auth && ($auth->isAdmin || $auth->can('guidance.manage'));
        if ($row->status !== 'published' && ! $canManage) {
            throw ApiError::notFound('ARTICLE_NOT_FOUND', 'Guidance article not found');
        }

        if (! self::isAccessibleToUser($row, $auth)) {
            throw ApiError::forbidden('FORBIDDEN', 'You do not have permission to view this guidance');
        }

        return self::formatArticle($row);
    }

    /** Check if article is accessible to the user based on target role and permission. */
    private static function isAccessibleToUser(object $article, ?AuthContext $auth): bool
    {
        $role = $article->target_role ?? 'all';

        // 1. Target role check
        if ($role === 'admin') {
            if (! $auth || ! $auth->isAdmin) {
                return false;
            }
        } elseif ($role === 'leader') {
            if (! $auth) {
                return false;
            }
            if (! $auth->isAdmin && empty($auth->departments)) {
                return false;
            }
        } elseif ($role === 'teacher') {
            if (! $auth) {
                return false;
            }
            if (! $auth->isAdmin && ! self::isTeacherOrAttendanceTaker($auth->id)) {
                return false;
            }
        }

        // 2. Specific permission requirement check
        if (! empty($article->required_permission)) {
            if (! $auth || ! $auth->can($article->required_permission)) {
                return false;
            }
        }

        return true;
    }

    private static function isTeacherOrAttendanceTaker(int $userId): bool
    {
        return DB::table('edu_courses')->where('teacher_user_id', $userId)->exists()
            || DB::table('edu_class_staff')->where('user_id', $userId)->exists()
            || DB::table('program_attendance_takers')->where('user_id', $userId)->exists();
    }

    /** Tour progress persistence for signed-in user. */
    public static function getTourProgress(AuthContext $auth): array
    {
        return DB::table('user_guidance_progress')
            ->where('user_id', $auth->id)
            ->get(['tour_id', 'completed', 'dismissed', 'completed_at', 'updated_at'])
            ->map(function ($r) {
                return [
                    'tour_id' => $r->tour_id,
                    'completed' => (bool) $r->completed,
                    'dismissed' => (bool) $r->dismissed,
                    'completed_at' => $r->completed_at,
                ];
            })
            ->all();
    }

    public static function saveTourProgress(AuthContext $auth, string $tourId, bool $completed, bool $dismissed = false): array
    {
        $now = date('Y-m-d H:i:s');
        $existing = DB::table('user_guidance_progress')
            ->where(['user_id' => $auth->id, 'tour_id' => $tourId])
            ->first();

        if ($existing) {
            DB::table('user_guidance_progress')
                ->where(['user_id' => $auth->id, 'tour_id' => $tourId])
                ->update([
                    'completed' => $completed,
                    'dismissed' => $dismissed,
                    'completed_at' => $completed ? ($existing->completed_at ?? $now) : null,
                    'updated_at' => $now,
                ]);
        } else {
            DB::table('user_guidance_progress')->insert([
                'user_id' => $auth->id,
                'tour_id' => $tourId,
                'completed' => $completed,
                'dismissed' => $dismissed,
                'completed_at' => $completed ? $now : null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        return [
            'tour_id' => $tourId,
            'completed' => $completed,
            'dismissed' => $dismissed,
            'completed_at' => $completed ? $now : null,
        ];
    }

    public static function resetTourProgress(AuthContext $auth, ?string $tourId = null): void
    {
        $q = DB::table('user_guidance_progress')->where('user_id', $auth->id);
        if ($tourId) {
            $q->where('tour_id', $tourId);
        }
        $q->delete();
    }

    // --- Admin Management Methods ---

    public static function adminList(AuthContext $auth, array $filters = []): array
    {
        self::assertCanManage($auth);

        $q = DB::table('guidance_articles')->orderBy('sort_order')->orderBy('id');

        if (! empty($filters['status'])) {
            $q->where('status', $filters['status']);
        }
        if (! empty($filters['category'])) {
            $q->where('category', $filters['category']);
        }
        if (! empty($filters['search'])) {
            $term = '%' . trim($filters['search']) . '%';
            $q->where(function ($sub) use ($term) {
                $sub->where('title', 'like', $term)
                    ->orWhere('summary', 'like', $term)
                    ->orWhere('slug', 'like', $term);
            });
        }

        return $q->get()->map(fn ($r) => self::formatArticle($r))->all();
    }

    public static function create(AuthContext $auth, array $data): array
    {
        self::assertCanManage($auth);

        $now = date('Y-m-d H:i:s');
        $slug = trim($data['slug'] ?? '');
        if (empty($slug)) {
            $slug = 'guide-' . time() . '-' . rand(100, 999);
        }

        $summary = $data['summary'] ?? $data['overview'] ?? null;
        $content = $data['content'] ?? $summary ?? '';
        $targetRole = $data['target_role'] ?? 'all';
        if ($targetRole === 'department_leader') {
            $targetRole = 'leader';
        }
        $steps = $data['steps'] ?? null;
        $tips = $data['tips'] ?? $data['quick_tips'] ?? null;
        $faqItems = $data['faq_items'] ?? $data['faqs'] ?? null;

        $id = DB::table('guidance_articles')->insertGetId([
            'slug' => $slug,
            'category' => $data['category'] ?? 'general',
            'title' => $data['title'],
            'summary' => $summary,
            'content' => $content,
            'target_role' => $targetRole,
            'target_screen' => $data['target_screen'] ?? null,
            'required_permission' => $data['required_permission'] ?? null,
            'steps' => isset($steps) ? (is_string($steps) ? $steps : json_encode($steps, JSON_UNESCAPED_UNICODE)) : null,
            'tips' => isset($tips) ? (is_string($tips) ? $tips : json_encode($tips, JSON_UNESCAPED_UNICODE)) : null,
            'faq_items' => isset($faqItems) ? (is_string($faqItems) ? $faqItems : json_encode($faqItems, JSON_UNESCAPED_UNICODE)) : null,
            'tour_id' => $data['tour_id'] ?? null,
            'icon' => $data['icon'] ?? null,
            'sort_order' => (int) ($data['sort_order'] ?? 0),
            'status' => $data['status'] ?? 'draft',
            'created_by' => $auth->id,
            'updated_by' => $auth->id,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return self::getBySlugOrId($auth, $id);
    }

    public static function update(AuthContext $auth, int $id, array $data): array
    {
        self::assertCanManage($auth);

        $existing = DB::table('guidance_articles')->where('id', $id)->first();
        if (! $existing) {
            throw ApiError::notFound('ARTICLE_NOT_FOUND', 'Guidance article not found');
        }

        if (array_key_exists('overview', $data) && ! array_key_exists('summary', $data)) {
            $data['summary'] = $data['overview'];
        }
        if (array_key_exists('summary', $data) && ! array_key_exists('content', $data) && empty($existing->content)) {
            $data['content'] = $data['summary'];
        }
        if (array_key_exists('quick_tips', $data) && ! array_key_exists('tips', $data)) {
            $data['tips'] = $data['quick_tips'];
        }
        if (array_key_exists('faqs', $data) && ! array_key_exists('faq_items', $data)) {
            $data['faq_items'] = $data['faqs'];
        }
        if (($data['target_role'] ?? null) === 'department_leader') {
            $data['target_role'] = 'leader';
        }

        $updates = ['updated_by' => $auth->id, 'updated_at' => date('Y-m-d H:i:s')];

        foreach (['title', 'category', 'slug', 'summary', 'content', 'target_role', 'target_screen', 'required_permission', 'tour_id', 'icon', 'sort_order', 'status'] as $f) {
            if (array_key_exists($f, $data)) {
                $updates[$f] = $data[$f];
            }
        }

        if (array_key_exists('steps', $data)) {
            $updates['steps'] = is_string($data['steps']) ? $data['steps'] : json_encode($data['steps'], JSON_UNESCAPED_UNICODE);
        }
        if (array_key_exists('tips', $data)) {
            $updates['tips'] = is_string($data['tips']) ? $data['tips'] : json_encode($data['tips'], JSON_UNESCAPED_UNICODE);
        }
        if (array_key_exists('faq_items', $data)) {
            $updates['faq_items'] = is_string($data['faq_items']) ? $data['faq_items'] : json_encode($data['faq_items'], JSON_UNESCAPED_UNICODE);
        }

        DB::table('guidance_articles')->where('id', $id)->update($updates);

        return self::getBySlugOrId($auth, $id);
    }

    public static function publish(AuthContext $auth, int $id): array
    {
        return self::update($auth, $id, ['status' => 'published']);
    }

    public static function retire(AuthContext $auth, int $id): array
    {
        return self::update($auth, $id, ['status' => 'retired']);
    }

    public static function delete(AuthContext $auth, int $id): void
    {
        self::assertCanManage($auth);
        $deleted = DB::table('guidance_articles')->where('id', $id)->delete();
        if (! $deleted) {
            throw ApiError::notFound('ARTICLE_NOT_FOUND', 'Guidance article not found');
        }
    }

    public static function assertCanManage(AuthContext $auth): void
    {
        if (! $auth->isAdmin && ! $auth->can('guidance.manage')) {
            throw ApiError::forbidden('FORBIDDEN', 'Guidance management permission required');
        }
    }

    private static function formatArticle(object $r): array
    {
        return [
            'id' => (int) $r->id,
            'slug' => $r->slug,
            'category' => $r->category,
            'title' => $r->title,
            'summary' => $r->summary,
            'content' => $r->content,
            'target_role' => $r->target_role,
            'target_screen' => $r->target_screen,
            'required_permission' => $r->required_permission,
            'steps' => self::decodeJsonList($r->steps),
            'tips' => self::decodeJsonList($r->tips),
            'faq_items' => self::decodeJsonList($r->faq_items),
            'tour_id' => $r->tour_id,
            'icon' => $r->icon,
            'sort_order' => (int) $r->sort_order,
            'status' => $r->status,
            'created_at' => $r->created_at,
            'updated_at' => $r->updated_at,
        ];
    }

    private static function decodeJsonList(?string $raw): array
    {
        if (empty($raw)) {
            return [];
        }
        $val = json_decode($raw, true);
        return is_array($val) ? $val : [];
    }
}
