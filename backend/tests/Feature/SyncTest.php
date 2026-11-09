<?php

namespace Tests\Feature;

use App\Models\Task;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SyncTest extends TestCase
{
    use RefreshDatabase;

    public function test_sincroniza_tareas_sesiones_y_borrados_con_last_write_wins(): void
    {
        $user = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000001';
        $sessionId = 'a93e0000-0000-4000-8000-000000000002';

        $response = $this->actingAs($user)->postJson('/api/sync', [
            'tasks' => [[
                'id' => $taskId,
                'titulo' => 'Estudiar cálculo',
                'prioridad' => 1,
                'completada' => false,
                'pomodoros_estimados' => 2,
                'updated_at' => '2026-10-20T15:04:05.123Z',
            ]],
            'sessions' => [[
                'id' => $sessionId,
                'tarea_id' => $taskId,
                'fecha_inicio' => '2026-10-20T14:39:00Z',
                'duracion_minutos' => 25,
                'estado' => 'completada',
                'updated_at' => '2026-10-20T15:04:05.123Z',
            ]],
            'tareas_eliminadas' => [],
        ]);

        $response->assertOk()
            ->assertJsonPath('creados', 2);

        $this->assertDatabaseHas('tasks', [
            'id' => $taskId,
            'prioridad' => 1,
        ]);
        $this->assertDatabaseHas('pomodoro_sessions', [
            'id' => $sessionId,
            'tarea_id' => $taskId,
        ]);
    }

    public function test_rechaza_con_422_sesion_que_apunta_a_tarea_ajena(): void
    {
        $dueno = User::factory()->create();
        $intruso = User::factory()->create();
        $tareaAjenaId = '6f1c0000-0000-4000-8000-000000000099';

        Task::create([
            'id' => $tareaAjenaId,
            'user_id' => $dueno->id,
            'titulo' => 'Tarea privada',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 1,
            'updated_at' => now(),
        ]);

        $response = $this->actingAs($intruso)->postJson('/api/sync', [
            'tasks' => [],
            'sessions' => [[
                'id' => 'a93e0000-0000-4000-8000-000000000088',
                'tarea_id' => $tareaAjenaId,
                'fecha_inicio' => '2026-10-20T14:39:00Z',
                'duracion_minutos' => 25,
                'estado' => 'completada',
                'updated_at' => '2026-10-20T15:04:05.123Z',
            ]],
            'tareas_eliminadas' => [],
        ]);

        $response->assertStatus(422);
    }
}
