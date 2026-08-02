<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('chain_raw_events', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('contract_address', 42);
            $table->string('event_name', 100);
            $table->string('transaction_hash', 66);
            $table->integer('log_index');
            $table->bigInteger('block_number');
            $table->string('block_hash', 66);
            $table->integer('transaction_index')->nullable();
            $table->timestamp('block_timestamp');
            $table->jsonb('decoded_data');
            $table->jsonb('topics');
            $table->jsonb('raw_data')->nullable();
            $table->string('status', 32)->default('PENDING_CONFIRMATION');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('reorged_at')->nullable();
            $table->bigInteger('replaced_by_block')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'transaction_hash', 'log_index', 'block_hash'], 'raw_events_unique');
            $table->index(['chain_id', 'block_number', 'log_index']);
            $table->index(['chain_id', 'contract_address', 'event_name']);
            $table->index(['status', 'block_number']);
            $table->index('block_hash');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('chain_raw_events');
    }
};
