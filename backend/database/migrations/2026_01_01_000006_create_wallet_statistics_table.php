<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('wallet_statistics', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('wallet_address', 42);
            $table->decimal('total_bnb_spent_wei', 78, 0)->default(0);
            $table->decimal('total_tokens_received_raw', 78, 0)->default(0);
            $table->bigInteger('purchase_count')->default(0);
            $table->timestamp('first_purchase_at')->nullable();
            $table->timestamp('last_purchase_at')->nullable();
            $table->bigInteger('first_purchase_block')->nullable();
            $table->bigInteger('last_purchase_block')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'wallet_address']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_statistics');
    }
};
