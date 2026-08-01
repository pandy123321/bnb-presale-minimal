<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('asset_ledger_entries', function (Blueprint $table) {
            $table->id();
            $table->string('ledger_no', 40)->unique();
            $table->bigInteger('chain_id');
            $table->string('asset_type', 16);
            $table->string('entry_type', 40);
            $table->string('direction', 8);
            $table->decimal('amount_raw', 78, 0);
            $table->string('wallet_address', 42)->nullable();
            $table->string('contract_address', 42);
            $table->string('reference_type', 40);
            $table->bigInteger('reference_id')->nullable();
            $table->string('transaction_hash', 66)->nullable();
            $table->integer('log_index')->nullable();
            $table->bigInteger('block_number')->nullable();
            $table->string('block_hash', 66)->nullable();
            $table->timestamp('effective_at');
            $table->boolean('is_final')->default(false);
            $table->boolean('is_reversal')->default(false);
            $table->foreignId('reversal_of_id')->nullable()->constrained('asset_ledger_entries');
            $table->string('reversal_reason', 120)->nullable();
            $table->jsonb('metadata')->default('{}');
            $table->timestamps();

            $table->unique(['entry_type', 'chain_id', 'transaction_hash', 'log_index'], 'ledger_purchase_unique');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('asset_ledger_entries');
    }
};
