<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dividend_allocations', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->integer('epoch_id');
            $table->string('wallet_address', 42);
            $table->decimal('balance_raw', 78, 0);
            $table->integer('rank');
            $table->string('tier', 20);
            $table->decimal('share_percent', 5, 2);
            $table->decimal('allocated_raw', 78, 0);
            $table->string('proof_hash', 66)->comment('keccak256 leaf hash');
            $table->boolean('claimed')->default(false);
            $table->timestamp('claimed_at')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'epoch_id', 'wallet_address']);
            $table->index(['chain_id', 'epoch_id', 'rank']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dividend_allocations');
    }
};
