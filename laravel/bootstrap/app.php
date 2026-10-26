<?php

use App\Mz\Http\Middleware as MzMiddleware;
use App\Mz\Http\Throttle;
use App\Mz\Support\ApiError;
use App\Mz\Support\Http;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Exceptions\PostTooLargeException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Log;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        apiPrefix: 'api/v1',
        commands: __DIR__.'/../routes/console.php',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias(['mz' => MzMiddleware::class, 'mz.throttle' => Throttle::class, 'mz.module' => \App\Mz\Http\ModuleGate::class]);
        // Same-origin web pages only render HTML; the API has no cookies or sessions.
        $middleware->api(prepend: [Throttle::class.':global']);
        $middleware->append(\App\Mz\Http\SecurityHeaders::class);
        $middleware->trustProxies(at: (int) env('TRUST_PROXY', 0) > 0 ? '*' : []);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        // Every error uses the API envelope; SQL errors, stack traces and paths never reach clients.
        $exceptions->render(function (Throwable $e, Request $request) {
            if ($e instanceof ApiError) {
                return Http::error($e);
            }
            if ($e instanceof NotFoundHttpException || $e instanceof MethodNotAllowedHttpException) {
                return Http::error(ApiError::notFound('ROUTE_NOT_FOUND', 'Route not found'));
            }
            if ($e instanceof PostTooLargeException) {
                return Http::error(new ApiError(413, 'PAYLOAD_TOO_LARGE', 'Request body too large'));
            }
            if ($e instanceof QueryException) {
                $code = $e->errorInfo[1] ?? null;
                if ($code === 1062) {
                    return Http::error(ApiError::conflict('DUPLICATE', 'Record already exists'));
                }
                if ($code === 1451 || $code === 1217) {
                    return Http::error(ApiError::conflict('IN_USE', 'Record is in use and cannot be deleted'));
                }
            }
            if ($e instanceof HttpExceptionInterface && $e->getStatusCode() < 500) {
                return Http::error(new ApiError($e->getStatusCode(), 'BAD_REQUEST', 'Bad request'));
            }
            Log::error('unhandled error', ['path' => $request->path(), 'method' => $request->method(), 'error' => $e->getMessage(), 'at' => $e->getFile().':'.$e->getLine()]);
            return Http::error(new ApiError(500, 'SERVER_ERROR', 'Something went wrong'));
        });
        $exceptions->dontReport([ApiError::class]);
    })->create();
