<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('system_task_runs', function (Blueprint $table) {
            $table->id();
            $table->string('task_name', 100);
            $table->string('run_id', 64)->unique();
            $table->string('status', 32)->default('UNKNOWN');
            $table->timestamp('started_at');
            $table->timestamp('completed_at')->nullable();
            $table->bigInteger('last_processed_block')->nullable();
            $table->bigInteger('processed_count')->default(0);
            $table->bigInteger('error_count')->default(0);
            $table->text('error_message')->nullable();
            $table->jsonb('metadata')->default('{}');
            $table->timestamp('created_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_task_runs');
    }
};
