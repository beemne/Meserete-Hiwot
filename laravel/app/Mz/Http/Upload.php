<?php

namespace App\Mz\Http;

use App\Mz\Services\Storage;
use App\Mz\Support\ApiError;
use Illuminate\Http\UploadedFile;

/**
 * One multipart file field (port of middleware/upload.js). A coarse check of the declared type and
 * the size here; the real type is verified from the bytes in Storage::save().
 */
final class Upload
{
    public static function single(string $kind, string $field = 'file', bool $required = true): ?UploadedFile
    {
        $r = request();
        $file = $r->file($field);
        if (is_array($file)) {
            throw ApiError::badRequest('INVALID_UPLOAD', 'Invalid upload');
        }
        if (! $file instanceof UploadedFile) {
            if ($r->hasFile($field) === false && isset($_FILES[$field]) && ($_FILES[$field]['error'] ?? 0) === UPLOAD_ERR_INI_SIZE) {
                throw new ApiError(413, 'FILE_TOO_LARGE', 'File is too large');
            }
            if ($required) {
                throw ApiError::badRequest('FILE_REQUIRED', 'File is required');
            }
            return null;
        }
        if (! $file->isValid()) {
            if (in_array($file->getError(), [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)) {
                throw new ApiError(413, 'FILE_TOO_LARGE', 'File is too large');
            }
            throw ApiError::badRequest('INVALID_UPLOAD', 'Invalid upload');
        }
        $max = Storage::kinds()[$kind]['max'];
        if ($file->getSize() > $max) {
            throw new ApiError(413, 'FILE_TOO_LARGE', 'File is too large');
        }
        $mime = (string) $file->getClientMimeType();
        $allowed = match ($kind) {
            'audio' => (bool) preg_match('#^(audio|video)/#', $mime),
            'apk' => (bool) preg_match('#^application/(vnd\.android\.package-archive|zip)$#', $mime),
            'chat' => (bool) preg_match('#^(image|audio|video)/|^application/(pdf|vnd\.openxmlformats-officedocument\.)#', $mime),
            'book' => (bool) preg_match('#^application/pdf$#', $mime),
            'lesson' => (bool) preg_match('#^(application/pdf|image/|audio/|application/vnd\.openxmlformats-officedocument\.)#', $mime),
            'project', 'document' =>(bool) preg_match('#^(application/pdf|image/|application/vnd\.openxmlformats-officedocument\.)#', $mime),
            default => str_starts_with($mime, 'image/'),
        };
        if (! $allowed && $mime !== 'application/octet-stream') {
            throw ApiError::badRequest('INVALID_FILE_TYPE', 'File type not allowed');
        }
        return $file;
    }

    /** The upload only when the request is multipart (optional attachments). */
    public static function optional(string $kind, string $field = 'file'): ?UploadedFile
    {
        return str_starts_with((string) request()->header('Content-Type'), 'multipart/form-data') ? self::single($kind, $field) : null;
    }
}
