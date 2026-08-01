<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('contract_registry', function (Blueprint $table) {
            $table->id();
            $table->string('environment', 32);
            $table->bigInteger('chain_id');
            $table->string('name', 100);
            $table->string('address', 42);
            $table->string('abi_version', 32)->default('0.0.0');
            $table->string('deployment_block', 32)->default('0');
            $table->string('status', 32)->default('UNKNOWN');
            $table->string('version', 32)->default('1.0.0');
            $table->jsonb('metadata')->nullable();
            $table->timestamps();

            $table->unique(['environment', 'chain_id', 'name']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('contract_registry');
    }
};
