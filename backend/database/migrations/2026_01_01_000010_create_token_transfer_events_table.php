<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('token_transfer_events', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('token_address', 42);
            $table->string('presale_address', 42);
            $table->string('from_address', 42);
            $table->string('to_address', 42);
            $table->decimal('amount_raw', 78, 0);
            $table->string('transfer_class', 40);
            $table->string('transaction_hash', 66);
            $table->integer('log_index');
            $table->bigInteger('block_number');
            $table->string('block_hash', 66);
            $table->timestamp('block_timestamp');
            $table->foreignId('related_purchase_order_id')->nullable();
            $table->foreignId('related_contract_event_log_id')->nullable();
            $table->string('status', 32)->default('PENDING_CONFIRMATION');
            $table->timestamps();

            $table->unique(['chain_id', 'transaction_hash', 'log_index']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('token_transfer_events');
    }
};
