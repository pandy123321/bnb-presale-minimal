<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('contract_event_logs', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('contract_address', 42);
            $table->string('event_name', 100);
            $table->string('transaction_hash', 66);
            $table->integer('log_index');
            $table->bigInteger('block_number');
            $table->string('block_hash', 66);
            $table->timestamp('block_timestamp');
            $table->jsonb('decoded_data');
            $table->string('source', 32)->default('EXTERNAL_OPERATION');
            $table->bigInteger('contract_write_transaction_id')->nullable();
            $table->string('status', 32)->default('PENDING_CONFIRMATION');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('reorged_at')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'transaction_hash', 'log_index']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contract_event_logs');
    }
};
