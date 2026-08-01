<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\TooManyRequestsHttpException;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;
use Symfony\Component\HttpKernel\Exception\MethodNotAllowedHttpException;
use App\Http\ApiEnvelope;
use App\Modules\Core\RBAC\Middleware\AdminRbacMiddleware;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__ . '/../routes/web.php',
        api: __DIR__ . '/../routes/api.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        $middleware->api(prepend: [
            \Illuminate\Cookie\Middleware\EncryptCookies::class,
            \Illuminate\Cookie\Middleware\AddQueuedCookiesToResponse::class,
            \Illuminate\Session\Middleware\StartSession::class,
            \Illuminate\Foundation\Http\Middleware\VerifyCsrfToken::class,
        ]);

        $middleware->alias([
            'rbac' => AdminRbacMiddleware::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions) {
        $exceptions->render(function (ValidationException $e, Request $request) {
            if ($request->expectsJson() || $request->is('api/*') || $request->is('admin-api/*')) {
                return ApiEnvelope::error(
                    'VALIDATION_FAILED',
                    'The given data was invalid.',
                    false,
                    $e->errors(),
                    422,
                );
            }
        });

        $exceptions->render(function (TooManyRequestsHttpException $e, Request $request) {
            if ($request->expectsJson() || $request->is('api/*') || $request->is('admin-api/*')) {
                return ApiEnvelope::error(
                    'RATE_LIMITED',
                    $e->getMessage() ?: 'Too many requests.',
                    true,
                    ['retry_after_seconds' => $e->getHeaders()['Retry-After'] ?? 60],
                    429,
                );
            }
        });

        $exceptions->render(function (NotFoundHttpException $e, Request $request) {
            if ($request->expectsJson() || $request->is('api/*') || $request->is('admin-api/*')) {
                return ApiEnvelope::error(
                    'NOT_FOUND',
                    'The requested resource was not found.',
                    false,
                    [],
                    404,
                );
            }
        });

        $exceptions->render(function (MethodNotAllowedHttpException $e, Request $request) {
            if ($request->expectsJson() || $request->is('api/*') || $request->is('admin-api/*')) {
                return ApiEnvelope::error(
                    'METHOD_NOT_ALLOWED',
                    'The HTTP method is not supported for this route.',
                    false,
                    [],
                    405,
                );
            }
        });

        $exceptions->render(function (\Throwable $e, Request $request) {
            if ($request->expectsJson() || $request->is('api/*') || $request->is('admin-api/*')) {
                $httpStatus = method_exists($e, 'getStatusCode') ? $e->getStatusCode() : 500;
                if ($httpStatus < 400) {
                    $httpStatus = 500;
                }

                return ApiEnvelope::error(
                    'INTERNAL_ERROR',
                    config('app.debug') ? $e->getMessage() : 'An internal error occurred.',
                    $httpStatus >= 500,
                    config('app.debug') ? [
                        'exception' => get_class($e),
                        'file' => $e->getFile(),
                        'line' => $e->getLine(),
                    ] : [],
                    $httpStatus,
                );
            }
        });
    })
    ->create();
