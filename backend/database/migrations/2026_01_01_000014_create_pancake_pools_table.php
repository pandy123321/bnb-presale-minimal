<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('pancake_pools', function (Blueprint $table) {
            $table->id();
            $table->bigInteger('chain_id');
            $table->string('version', 8)->default('V2');
            $table->string('pair_address', 42);
            $table->string('token0_address', 42);
            $table->string('token1_address', 42);
            $table->integer('token0_decimals');
            $table->integer('token1_decimals');
            $table->boolean('sale_token_is_token0');
            $table->string('wbnb_address', 42);
            $table->boolean('is_active')->default(true);
            $table->timestamp('validated_at')->nullable();
            $table->text('validation_error')->nullable();
            $table->foreignId('created_by')->nullable()->constrained('admins');
            $table->foreignId('updated_by')->nullable()->constrained('admins');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pancake_pools');
    }
};
