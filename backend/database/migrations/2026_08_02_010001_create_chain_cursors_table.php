<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('chain_cursors', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('stream', 64)->comment('PURCHASE_EVENTS, TRADE_EVENTS, DIVIDEND_EVENTS, etc.');
            $table->bigInteger('last_scanned_block');
            $table->string('last_scanned_block_hash', 66)->nullable();
            $table->string('status', 32)->default('HEALTHY');
            $table->text('last_error')->nullable();
            $table->timestamp('last_run_started_at')->nullable();
            $table->timestamp('last_run_completed_at')->nullable();
            $table->string('lease_holder', 128)->nullable();
            $table->timestamp('lease_expires_at')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'stream']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chain_cursors');
    }
};
