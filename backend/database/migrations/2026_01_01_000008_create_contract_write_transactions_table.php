<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('contract_write_transactions', function (Blueprint $table) {
            $table->id();
            $table->string('operation', 64);
            $table->string('idempotency_key', 128);
            $table->bigInteger('chain_id');
            $table->string('from_address', 42);
            $table->string('to_address', 42);
            $table->decimal('nonce', 78, 0)->nullable();
            $table->decimal('value_wei', 78, 0)->default(0);
            $table->decimal('gas_limit', 78, 0)->nullable();
            $table->decimal('max_fee_per_gas_wei', 78, 0)->nullable();
            $table->decimal('max_priority_fee_per_gas_wei', 78, 0)->nullable();
            $table->decimal('gas_price_wei', 78, 0)->nullable();
            $table->text('calldata_hex');
            $table->string('transaction_hash', 66)->nullable();
            $table->string('status', 32)->default('CREATED');
            $table->bigInteger('receipt_block_number')->nullable();
            $table->string('receipt_block_hash', 66)->nullable();
            $table->integer('receipt_status')->nullable();
            $table->string('error_code', 100)->nullable();
            $table->text('error_message')->nullable();
            $table->foreignId('initiated_by')->nullable()->constrained('admins');
            $table->string('related_type', 64)->nullable();
            $table->bigInteger('related_id')->nullable();
            $table->foreignId('replacement_of_id')->nullable()->constrained('contract_write_transactions');
            $table->foreignId('replaced_by_id')->nullable()->constrained('contract_write_transactions');
            $table->timestamp('last_checked_at')->nullable();
            $table->timestamp('signed_at')->nullable();
            $table->timestamp('broadcast_at')->nullable();
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->timestamps();

            $table->unique(['operation', 'idempotency_key']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contract_write_transactions');
    }
};
