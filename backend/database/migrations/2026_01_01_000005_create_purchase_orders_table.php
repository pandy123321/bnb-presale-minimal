<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('purchase_orders', function (Blueprint $table) {
            $table->id();
            $table->string('order_no', 40)->unique();
            $table->bigInteger('chain_id');
            $table->string('contract_address', 42);
            $table->string('buyer_address', 42);
            $table->decimal('bnb_amount_wei', 78, 0);
            $table->decimal('token_amount_raw', 78, 0);
            $table->decimal('token_per_bnb_raw', 78, 0);
            $table->decimal('wallet_purchase_count', 78, 0);
            $table->decimal('total_bnb_raised_wei', 78, 0);
            $table->decimal('total_tokens_sold_raw', 78, 0);
            $table->string('transaction_hash', 66);
            $table->integer('transaction_index')->nullable();
            $table->integer('log_index');
            $table->bigInteger('block_number');
            $table->string('block_hash', 66);
            $table->timestamp('block_timestamp');
            $table->integer('confirmations')->default(0);
            $table->string('status', 32)->default('PENDING_CONFIRMATION');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('reorged_at')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'transaction_hash', 'log_index']);
            $table->index(['buyer_address', 'block_timestamp']);
            $table->index(['status', 'block_number']);
            $table->index(['block_number', 'log_index']);
            $table->index('transaction_hash');
            $table->index('block_timestamp');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('purchase_orders');
    }
};
