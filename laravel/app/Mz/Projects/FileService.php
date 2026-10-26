<?php

namespace App\Mz\Projects;

use App\Mz\Auth\AuthContext;
use App\Mz\Services\Storage;
use App\Mz\Support\ApiError;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;

/** Project / task / issue files in the existing private storage (served only through access checks). */
final class FileService
{
    private static function serialize(object $f): array
    {
        $u = $f->uploaded_by ? (Pm::users([$f->uploaded_by])[(int) $f->uploaded_by] ?? null) : null;
        return ['id' => (int) $f->id, 'project_id' => (int) $f->project_id, 'task_id' => $f->task_id ? (int) $f->task_id : null, 'issue_id' => $f->issue_id ? (int) $f->issue_id : null,
            'name' => $f->name, 'mime' => $f->mime, 'size' => (int) $f->size, 'url' => "/projects/files/{$f->id}", 'uploaded_by' => $u, 'created_at' => $f->created_at];
    }

    public static function list(AuthContext $auth, int $projectId, array $f): array
    {
        Access::loadProject($auth, $projectId);
        $q = DB::table('project_files')->where('project_id', $projectId)->orderByDesc('id');
        if (! empty($f['task_id'])) $q->where('task_id', $f['task_id']);
        if (! empty($f['issue_id'])) $q->where('issue_id', $f['issue_id']);
        return $q->get()->map(fn ($r) => self::serialize($r))->all();
    }

    public static function upload(array $actx, int $projectId, UploadedFile $file, array $in): array
    {
        $auth = $actx['auth'];
        [$p, $a] = Access::loadProject($auth, $projectId);
        $taskId = $in['task_id'] ?? null;
        $issueId = $in['issue_id'] ?? null;
        $allowed = $a['project_manage'] || $a['team_member'];
        if ($taskId) {
            $t = DB::table('project_tasks')->where(['id' => $taskId, 'project_id' => $projectId])->whereNull('deleted_at')->first();
            if (! $t) throw ApiError::field('task_id', 'TASK_NOT_FOUND');
            $allowed = $allowed || in_array($auth->id, Access::assigneeIds((int) $taskId), true);
        }
        if ($issueId) {
            $i = DB::table('project_issues')->where(['id' => $issueId, 'project_id' => $projectId])->first();
            if (! $i) throw ApiError::field('issue_id', 'ISSUE_NOT_FOUND');
            $allowed = $allowed || (int) $i->reporter_id === $auth->id || (int) $i->assignee_id === $auth->id;
        }
        if (! $allowed) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'You cannot add files here');
        $saved = Storage::save('project', Storage::FOLDERS['PROJECTS'], $file);
        $name = mb_substr(preg_replace('/[^\p{L}\p{N}._ -]/u', '', (string) $file->getClientOriginalName()), 0, 150) ?: null;
        try {
            $id = DB::table('project_files')->insertGetId(['project_id' => $projectId, 'task_id' => $taskId, 'issue_id' => $issueId, 'path' => $saved['path'], 'mime' => $saved['mime'], 'size' => $saved['size'], 'name' => $name, 'uploaded_by' => $auth->id]);
        } catch (\Throwable $e) {
            Storage::remove($saved['path']);
            throw $e;
        }
        Pm::log($actx, 'project.file.add', $projectId, ['file_id' => $id, 'task_id' => $taskId, 'issue_id' => $issueId, 'name' => $name]);
        return self::serialize(DB::table('project_files')->where('id', $id)->first());
    }

    public static function download(AuthContext $auth, int $id): array
    {
        $f = DB::table('project_files')->where('id', $id)->first();
        if (! $f) throw ApiError::notFound();
        try {
            Access::loadProject($auth, (int) $f->project_id);
        } catch (ApiError) {
            throw ApiError::notFound();
        }
        $abs = Storage::privatePath($f->path);
        if (! is_file($abs)) throw ApiError::notFound();
        return ['abs' => $abs, 'mime' => $f->mime, 'name' => $f->name];
    }

    public static function remove(array $actx, int $id): void
    {
        $auth = $actx['auth'];
        $f = DB::table('project_files')->where('id', $id)->first();
        if (! $f) throw ApiError::notFound();
        [, $a] = Access::loadProject($auth, (int) $f->project_id);
        if ((int) $f->uploaded_by !== $auth->id && ! $a['project_manage']) throw ApiError::forbidden('PROJECT_FORBIDDEN', 'Only the uploader or a manager removes a file');
        DB::table('project_files')->where('id', $id)->delete();
        Storage::remove($f->path);
        Pm::log($actx, 'project.file.remove', (int) $f->project_id, ['file_id' => $id, 'name' => $f->name]);
    }
}
