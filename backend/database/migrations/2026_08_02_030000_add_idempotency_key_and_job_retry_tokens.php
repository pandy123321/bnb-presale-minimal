<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('admin_audit_logs', function (Blueprint $table) {
            if (!Schema::hasColumn('admin_audit_logs', 'idempotency_key')) {
                $table->string('idempotency_key', 128)->nullable()->after('request_id');
            }
        });

        Schema::create('job_retry_tokens', function (Blueprint $table) {
            $table->id();
            $table->string('task_name', 100);
            $table->string('idempotency_key', 128);
            $table->bigInteger('admin_id')->nullable();
            $table->string('status', 32)->default('pending');
            $table->timestamp('executed_at')->nullable();
            $table->text('result')->nullable();
            $table->text('error_message')->nullable();
            $table->timestamps();

            $table->unique(['task_name', 'idempotency_key']);
            $table->index(['task_name', 'status']);
            $table->timestamp('expires_at')->nullable();
        });
    }

    public function down(): void
    {
        Schema::table('admin_audit_logs', function (Blueprint $table) {
            $table->dropColumn('idempotency_key');
        });

        Schema::dropIfExists('job_retry_tokens');
    }
};
