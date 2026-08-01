<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('price_snapshots', function (Blueprint $table) {
            $table->id();
            $table->foreignId('pancake_pool_id')->constrained('pancake_pools');
            $table->bigInteger('chain_id');
            $table->bigInteger('block_number');
            $table->decimal('reserve_sale_token_raw', 78, 0);
            $table->decimal('reserve_wbnb_wei', 78, 0);
            $table->decimal('market_token_per_bnb_raw', 78, 0);
            $table->decimal('coefficient_numerator', 78, 0);
            $table->decimal('coefficient_denominator', 78, 0);
            $table->decimal('suggested_token_per_bnb_raw', 78, 0);
            $table->timestamp('observed_at');
            $table->timestamp('created_at');

            $table->index(['pancake_pool_id', 'observed_at']);
            $table->index(['chain_id', 'block_number']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('price_snapshots');
    }
};
