<?php

declare(strict_types=1);

namespace App\Http\Controllers;

use App\Http\ApiEnvelope;
use App\Modules\Core\Auth\WalletAuthService;
use Illuminate\Http\Request;

final class WalletAuthController extends Controller
{
    public function __construct(
        private readonly WalletAuthService $authService,
    ) {}

    /**
     * POST /api/v1/projects/pangu2/auth/nonce
     */
    public function nonce(Request $request)
    {
        $validated = $request->validate([
            'wallet_address' => ['required', 'string', 'regex:/^0x[0-9a-f]{40}$/i'],
        ]);

        $result = $this->authService->issueNonce($validated['wallet_address']);

        return ApiEnvelope::success($result, 'MOCK_DATA');
    }

    /**
     * POST /api/v1/projects/pangu2/auth/verify
     */
    public function verify(Request $request)
    {
        $validated = $request->validate([
            'wallet_address' => ['required', 'string', 'regex:/^0x[0-9a-f]{40}$/i'],
            'signature' => ['required', 'string'],
        ]);

        $session = $this->authService->verifySignature(
            $validated['wallet_address'],
            $validated['signature'],
        );

        if (! $session) {
            return ApiEnvelope::error(
                'AUTH_INVALID_SIGNATURE',
                'Signature verification failed or nonce expired.',
                true,
                [],
                401,
            );
        }

        return ApiEnvelope::success($session, 'MOCK_DATA');
    }

    /**
     * POST /api/v1/projects/pangu2/auth/logout
     */
    public function logout(Request $request)
    {
        $token = $request->bearerToken();

        if ($token) {
            $this->authService->revokeSession($token);
        }

        return ApiEnvelope::success(['ok' => true], 'MOCK_DATA');
    }
}
