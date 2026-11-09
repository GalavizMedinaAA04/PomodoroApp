<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

/**
 * Nota: Laravel ya crea una tabla `sessions` (driver de sesión HTTP) en
 * 0001_01_01_000000_create_users_table.php, por eso se usa `pomodoro_sessions`.
 */
return new class () extends Migration {
    public function up(): void
    {
        Schema::create('pomodoro_sessions', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignUuid('tarea_id')->constrained('tasks')->cascadeOnDelete();
            $table->timestamp('fecha_inicio');
            $table->unsignedSmallInteger('duracion_minutos');
            $table->string('estado', 20);
            $table->timestamp('created_at')->nullable();
            $table->timestamp('updated_at', 6)->index();
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('pomodoro_sessions');
    }
};
