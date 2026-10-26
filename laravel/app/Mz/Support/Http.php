<?php

namespace App\Mz\Support;

use Illuminate\Http\JsonResponse;

/** The API envelope: { success, code, message, data, errors, meta? }. */
final class Http
{
    public const JSON_FLAGS = JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES;

    public static function ok(mixed $data = null, ?array $meta = null, string $message = 'OK', int $status = 200): JsonResponse
    {
        $body = ['success' => true, 'code' => 'OK', 'message' => $message, 'data' => $data, 'errors' => []];
        if ($meta !== null) {
            $body['meta'] = $meta;
        }
        return new JsonResponse($body, $status, [], self::JSON_FLAGS);
    }

    public static function created(mixed $data = null, string $message = 'Created'): JsonResponse
    {
        return self::ok($data, null, $message, 201);
    }

    /** A paginated result { items, meta } → data = items, meta = meta. */
    public static function page(array $out): JsonResponse
    {
        return self::ok($out['items'], $out['meta']);
    }

    public static function error(ApiError $e): JsonResponse
    {
        return new JsonResponse([
            'success' => false,
            'code' => $e->errorCode,
            'message' => $e->getMessage(),
            'data' => null,
            'errors' => array_values($e->errors),
        ], $e->status, [], self::JSON_FLAGS);
    }
}
