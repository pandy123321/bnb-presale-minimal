<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('reconciliation_runs', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('asset_type', 16);
            $table->decimal('expected_balance_raw', 78, 0);
            $table->decimal('onchain_balance_raw', 78, 0);
            $table->decimal('difference_raw', 78, 0);
            $table->string('status', 32)->default('MATCHED');
            $table->bigInteger('block_number');
            $table->timestamp('checked_at');
            $table->text('error_message')->nullable();
            $table->timestamp('created_at');

            $table->index(['asset_type', 'checked_at']);
            $table->index(['status', 'checked_at']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('reconciliation_runs');
    }
};
