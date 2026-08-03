<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('dividend_epochs', function (Blueprint $table) {
            if (!Schema::hasColumn('dividend_epochs', 'reward_token_address')) {
                $table->string('reward_token_address', 42)->nullable()->after('artifact_checksum');
            }
            if (!Schema::hasColumn('dividend_epochs', 'distributor_address')) {
                $table->string('distributor_address', 42)->nullable()->after('reward_token_address');
            }
        });
    }

    public function down(): void
    {
        Schema::table('dividend_epochs', function (Blueprint $table) {
            $table->dropColumn(['reward_token_address', 'distributor_address']);
        });
    }
};
