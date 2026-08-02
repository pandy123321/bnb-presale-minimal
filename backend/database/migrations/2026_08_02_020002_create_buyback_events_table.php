<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('buyback_events', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->integer('buyback_id');
            $table->string('trigger_address', 42);
            $table->decimal('bnb_amount_wei', 78, 0);
            $table->decimal('token_amount_raw', 78, 0);
            $table->string('locker_address', 42);
            $table->string('pool_address', 42);
            $table->bigInteger('block_number');
            $table->timestamp('event_timestamp');
            $table->timestamps();

            $table->unique(['chain_id', 'buyback_id']);
            $table->index(['chain_id', 'event_timestamp']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('buyback_events');
    }
};
