<?php

declare(strict_types=1);

namespace App\Modules\Core\RBAC;

/**
 * PANGU2 RBAC Permission Matrix.
 *
 * Roles: SUPER_ADMIN, OPERATOR, AUDITOR, VIEWER
 *
 * Permissions follow the principle of least privilege.
 * No role can modify user assets, costs, or allocations.
 */
final class RbacMatrix
{
    public const ROLE_SUPER_ADMIN = 'SUPER_ADMIN';
    public const ROLE_OPERATOR    = 'OPERATOR';
    public const ROLE_AUDITOR     = 'AUDITOR';
    public const ROLE_VIEWER      = 'VIEWER';

    /**
     * All valid roles.
     */
    public const ROLES = [
        self::ROLE_SUPER_ADMIN,
        self::ROLE_OPERATOR,
        self::ROLE_AUDITOR,
        self::ROLE_VIEWER,
    ];

    /**
     * Permission → allowed roles.
     */
    private const PERMISSIONS = [
        // Dashboard — all roles can view
        'dashboard.read' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_OPERATOR,
            self::ROLE_AUDITOR,
            self::ROLE_VIEWER,
        ],
        // Contracts — read-only
        'contracts.read' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_OPERATOR,
            self::ROLE_AUDITOR,
            self::ROLE_VIEWER,
        ],
        // Jobs — view
        'jobs.read' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_OPERATOR,
            self::ROLE_AUDITOR,
            self::ROLE_VIEWER,
        ],
        // Jobs — retry (dangerous, needs idempotency)
        'jobs.retry' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_OPERATOR,
        ],
        // Audit logs — view
        'audit.read' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_AUDITOR,
        ],
        // Chain write operations — SUPER_ADMIN only
        'chain.write' => [
            self::ROLE_SUPER_ADMIN,
        ],
        // Staking — read (all roles)
        'staking.read' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_OPERATOR,
            self::ROLE_AUDITOR,
            self::ROLE_VIEWER,
        ],
        // Staking — manage rewards (SUPER_ADMIN + OPERATOR)
        'staking.manage' => [
            self::ROLE_SUPER_ADMIN,
            self::ROLE_OPERATOR,
        ],
    ];

    /**
     * Check if a role has a specific permission.
     */
    public static function can(string $role, string $permission): bool
    {
        if (!in_array($role, self::ROLES, true)) {
            return false;
        }
        return in_array($role, self::PERMISSIONS[$permission] ?? [], true);
    }

    /**
     * Get all permissions for a role.
     */
    public static function permissionsFor(string $role): array
    {
        $perms = [];
        foreach (self::PERMISSIONS as $perm => $roles) {
            if (in_array($role, $roles, true)) {
                $perms[] = $perm;
            }
        }
        return $perms;
    }
}
