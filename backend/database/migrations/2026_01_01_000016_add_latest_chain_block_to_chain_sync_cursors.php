<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        if (!Schema::hasColumn('chain_sync_cursors', 'latest_chain_block')) {
            Schema::table('chain_sync_cursors', function (Blueprint $table) {
                $table->bigInteger('latest_chain_block')->nullable()->after('last_finalized_block');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('chain_sync_cursors', 'latest_chain_block')) {
            Schema::table('chain_sync_cursors', function (Blueprint $table) {
                $table->dropColumn('latest_chain_block');
            });
        }
    }
};
