<?php

declare(strict_types=1);

namespace App\Modules\Pangu2\Admin\Controllers;

use App\Http\ApiEnvelope;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Illuminate\Support\Facades\DB;

/**
 * Admin Audit Logs Controller — read-only access to all audit entries.
 */
class AdminAuditController extends Controller
{
    /**
     * GET /admin-api/v1/projects/pangu2/audit-logs
     *
     * Query filters:
     *   - administrator: filter by admin email
     *   - action: filter by action type (e.g., JOB_RETRY, WALLET_AUTHENTICATED)
     *   - page / per_page: pagination
     */
    public function index(Request $request): JsonResponse
    {
        $page          = max(1, (int) $request->query('page', 1));
        $perPage       = min(100, max(1, (int) $request->query('per_page', 20)));
        $administrator = $request->query('administrator');
        $action        = $request->query('action');

        $query = DB::table('admin_audit_logs')
            ->leftJoin('admins', 'admin_audit_logs.admin_id', '=', 'admins.id')
            ->select(
                'admin_audit_logs.id',
                'admin_audit_logs.action',
                'admin_audit_logs.target_type',
                'admin_audit_logs.target_id',
                'admin_audit_logs.ip_address',
                'admin_audit_logs.result',
                'admin_audit_logs.created_at',
                'admins.email as admin_email',
                'admins.role as admin_role',
            )
            ->orderBy('admin_audit_logs.created_at', 'desc');

        if ($administrator) {
            $query->where('admins.email', $administrator);
        }
        if ($action) {
            $query->where('admin_audit_logs.action', $action);
        }

        $paginator = $query->paginate($perPage);

        $data = array_map(function ($row) {
            return [
                'id'           => $row->id,
                'action'       => $row->action,
                'target_type'  => $row->target_type,
                'target_id'    => $row->target_id,
                'admin_email'  => $row->admin_email ?? 'SYSTEM',
                'admin_role'   => $row->admin_role ?? 'N/A',
                'ip_address'   => $row->ip_address,
                'result'       => $row->result,
                'created_at'   => $row->created_at,
            ];
        }, $paginator->items());

        return ApiEnvelope::paginated(
            $data,
            $paginator->currentPage(),
            $paginator->perPage(),
            $paginator->total(),
            'LIVE',
        );
    }

    /**
     * GET /admin-api/v1/projects/pangu2/audit-logs/{id}
     *
     * Full detail of a single audit entry (including before_data/after_data).
     */
    public function show(int $id): JsonResponse
    {
        $row = DB::table('admin_audit_logs')
            ->leftJoin('admins', 'admin_audit_logs.admin_id', '=', 'admins.id')
            ->select('admin_audit_logs.*', 'admins.email as admin_email', 'admins.role as admin_role')
            ->where('admin_audit_logs.id', $id)
            ->first();

        if (!$row) {
            return ApiEnvelope::error('NOT_FOUND', 'Audit log entry not found.', false, [], 404);
        }

        return ApiEnvelope::success([
            'id'             => $row->id,
            'action'         => $row->action,
            'target_type'    => $row->target_type,
            'target_id'      => $row->target_id,
            'admin_email'    => $row->admin_email ?? 'SYSTEM',
            'admin_role'     => $row->admin_role ?? 'N/A',
            'ip_address'     => $row->ip_address,
            'user_agent'     => $row->user_agent,
            'result'         => $row->result,
            'before_data'    => json_decode($row->before_data ?? 'null', true),
            'after_data'     => json_decode($row->after_data ?? 'null', true),
            'error_message'  => $row->error_message,
            'created_at'     => $row->created_at,
        ], 'LIVE');
    }
}
