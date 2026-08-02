<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('dividend_epochs', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->integer('epoch_id');
            $table->bigInteger('snapshot_block');
            $table->decimal('total_dividend_raw', 78, 0);
            $table->string('merkle_root', 66);
            $table->string('artifact_checksum', 66)->nullable();
            $table->string('status', 32)->default('pending');
            $table->timestamp('published_at')->nullable();
            $table->timestamp('snapshot_at')->nullable();
            $table->timestamps();

            $table->unique(['chain_id', 'epoch_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('dividend_epochs');
    }
};
