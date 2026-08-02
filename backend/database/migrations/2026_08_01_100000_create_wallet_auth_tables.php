<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('wallet_nonces', function (Blueprint $table) {
            $table->id();
            $table->string('wallet_address', 42);
            $table->string('nonce', 128)->unique();
            $table->text('message');
            $table->string('domain', 255);
            $table->unsignedBigInteger('chain_id');
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->timestamps();

            $table->index(['wallet_address', 'expires_at']);
        });

        Schema::create('wallet_sessions', function (Blueprint $table) {
            $table->id();
            $table->string('wallet_address', 42);
            $table->string('token', 128)->unique();
            $table->timestamp('expires_at');
            $table->timestamp('last_activity_at')->nullable();
            $table->timestamps();

            $table->index(['wallet_address']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('wallet_sessions');
        Schema::dropIfExists('wallet_nonces');
    }
};
