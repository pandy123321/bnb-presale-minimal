<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('transaction_projections', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('tx_hash', 66);
            $table->string('block_hash', 66);
            $table->bigInteger('block_number');
            $table->string('from_address', 42);
            $table->string('contract_address', 42);
            $table->string('type', 32)->comment('buy, sell, claim, buyback, other');
            $table->decimal('amount_in_raw', 78, 0)->default('0');
            $table->decimal('amount_out_raw', 78, 0)->default('0');
            $table->decimal('tax_amount_raw', 78, 0)->nullable();
            $table->string('tax_rate_bps')->nullable()->comment('Tax rate in basis points');
            $table->string('status', 32)->default('pending');
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->timestamp('replaced_at')->nullable();
            $table->timestamp('dropped_at')->nullable();
            $table->timestamp('reorged_at')->nullable();
            $table->bigInteger('replaced_by_tx_id')->nullable();
            $table->jsonb('metadata')->default('{}');
            $table->timestamp('event_timestamp');
            $table->timestamps();

            $table->unique(['chain_id', 'tx_hash'], 'tx_projection_unique');
            $table->index(['chain_id', 'from_address', 'event_timestamp']);
            $table->index(['chain_id', 'type', 'status']);
            $table->index('block_number');
            $table->index('status');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transaction_projections');
    }
};
