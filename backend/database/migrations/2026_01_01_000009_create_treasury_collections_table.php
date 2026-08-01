<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('treasury_collections', function (Blueprint $table) {
            $table->id();
            $table->string('collection_no', 40)->unique();
            $table->bigInteger('chain_id');
            $table->string('contract_address', 42);
            $table->string('treasury_address', 42);
            $table->decimal('observed_contract_balance_wei', 78, 0);
            $table->decimal('threshold_wei', 78, 0);
            $table->decimal('retained_balance_wei', 78, 0);
            $table->decimal('proposed_amount_wei', 78, 0);
            $table->decimal('actual_amount_wei', 78, 0)->nullable();
            $table->string('status', 32)->default('READY');
            $table->foreignId('contract_write_transaction_id')->nullable();
            $table->boolean('created_by_system')->default(true);
            $table->foreignId('executed_by')->nullable()->constrained('admins');
            $table->foreignId('cancelled_by')->nullable()->constrained('admins');
            $table->text('failure_reason')->nullable();
            $table->timestamp('ready_at');
            $table->timestamp('submitted_at')->nullable();
            $table->timestamp('confirmed_at')->nullable();
            $table->timestamp('failed_at')->nullable();
            $table->timestamp('cancelled_at')->nullable();
            $table->timestamp('reorged_at')->nullable();
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('treasury_collections');
    }
};
