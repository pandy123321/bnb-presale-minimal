<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('chain_sync_cursors', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('stream', 64);
            $table->bigInteger('last_scanned_block');
            $table->bigInteger('last_finalized_block')->nullable();
            $table->string('last_scanned_block_hash', 66)->nullable();
            $table->string('status', 32)->default('UNKNOWN');
            $table->text('last_error')->nullable();
            $table->timestamp('last_run_started_at')->nullable();
            $table->timestamp('last_run_completed_at')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'stream']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chain_sync_cursors');
    }
};
