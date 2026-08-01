<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('nonces', function (Blueprint $table) {
            $table->id();
            $table->string('wallet_address', 42);
            $table->string('nonce', 64);
            $table->text('message');
            $table->string('domain', 255);
            $table->bigInteger('chain_id');
            $table->timestamp('expires_at');
            $table->timestamp('used_at')->nullable();
            $table->timestamps();

            $table->unique('nonce');
            $table->index('wallet_address');
            $table->index('expires_at');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('nonces');
    }
};
