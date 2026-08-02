<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('locker_batches', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->integer('batch_id');
            $table->decimal('tokens_raw', 78, 0);
            $table->bigInteger('source_block_number');
            $table->bigInteger('lock_until_block')->nullable();
            $table->timestamp('locked_until')->nullable();
            $table->integer('duration_days')->default(365);
            $table->string('status', 32)->default('locked');
            $table->timestamps();

            $table->unique(['chain_id', 'batch_id']);
            $table->index(['chain_id', 'status']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('locker_batches');
    }
};
