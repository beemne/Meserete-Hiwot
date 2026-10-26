<?php

namespace App\Mz\Support;

use RuntimeException;

/**
 * An error with a stable machine-readable code; the mobile app maps the code to a localized message.
 * Rendered as { success:false, code, message, data:null, errors:[{field, code, message}] }.
 */
class ApiError extends RuntimeException
{
    public function __construct(public int $status, public string $errorCode, string $message, public array $errors = [])
    {
        parent::__construct($message);
    }

    public static function badRequest(string $code = 'BAD_REQUEST', string $message = 'Bad request', array $errors = []): self
    {
        return new self(400, $code, $message, $errors);
    }

    public static function unauthorized(string $code = 'UNAUTHORIZED', string $message = 'Authentication required'): self
    {
        return new self(401, $code, $message);
    }

    public static function forbidden(string $code = 'FORBIDDEN', string $message = 'You do not have permission to perform this action'): self
    {
        return new self(403, $code, $message);
    }

    public static function notFound(string $code = 'NOT_FOUND', string $message = 'Resource not found'): self
    {
        return new self(404, $code, $message);
    }

    public static function conflict(string $code = 'CONFLICT', string $message = 'Conflict', array $errors = []): self
    {
        return new self(409, $code, $message, $errors);
    }

    public static function gone(string $code = 'GONE', string $message = 'Resource is no longer available'): self
    {
        return new self(410, $code, $message);
    }

    /** @param array<array{field:?string,code:string,message:string}> $errors */
    public static function validation(array $errors, string $message = 'Validation failed'): self
    {
        return new self(422, 'VALIDATION_ERROR', $message, $errors);
    }

    /** One field error (the common case in services). */
    public static function field(string $field, string $code): self
    {
        return self::validation([['field' => $field, 'code' => $code, 'message' => $code]]);
    }

    public static function tooMany(string $code = 'TOO_MANY_REQUESTS', string $message = 'Too many requests'): self
    {
        return new self(429, $code, $message);
    }
}
