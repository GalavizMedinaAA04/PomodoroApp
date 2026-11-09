<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class () extends Migration {
    public function up(): void
    {
        Schema::create('tasks', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->string('titulo');
            $table->boolean('completada')->default(false);
            $table->unsignedSmallInteger('pomodoros_estimados')->default(1);
            $table->timestamp('created_at')->nullable();
            $table->timestamp('updated_at', 6)->index(); // precisión ms para LWW
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('tasks');
    }
};
