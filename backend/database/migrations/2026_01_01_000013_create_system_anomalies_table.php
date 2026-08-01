<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('system_anomalies', function (Blueprint $table) {
            $table->id();
            $table->string('anomaly_type', 100);
            $table->string('severity', 16)->default('P2');
            $table->string('status', 32)->default('OPEN');
            $table->string('title', 255);
            $table->jsonb('details');
            $table->string('related_type', 64)->nullable();
            $table->bigInteger('related_id')->nullable();
            $table->timestamp('detected_at');
            $table->timestamp('resolved_at')->nullable();
            $table->foreignId('resolved_by')->nullable()->constrained('admins');
            $table->timestamps();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('system_anomalies');
    }
};
