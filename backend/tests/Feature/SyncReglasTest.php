<?php

namespace Tests\Feature;

use App\Models\PomodoroSession;
use App\Models\Task;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

class SyncReglasTest extends TestCase
{
    use RefreshDatabase;

    /**
     * @return array<string, array{0: array<string, mixed>, 1: int}>
     */
    public static function proveedorValoresLimiteTarea(): array
    {
        return [
            'CP-VL-20 tarea con título de 120 caracteres' => [
                ['titulo' => str_repeat('a', 120)],
                200,
            ],
            'CP-VL-21 título de 121 caracteres' => [
                ['titulo' => str_repeat('a', 121)],
                422,
            ],
            'CP-VL-22 pomodoros_estimados 0' => [
                ['pomodoros_estimados' => 0],
                422,
            ],
            'CP-VL-23 pomodoros_estimados 1' => [
                ['pomodoros_estimados' => 1],
                200,
            ],
            'CP-VL-24 pomodoros_estimados 20' => [
                ['pomodoros_estimados' => 20],
                200,
            ],
            'CP-VL-25 pomodoros_estimados 21' => [
                ['pomodoros_estimados' => 21],
                422,
            ],
            'CP-VL-26 prioridad 0' => [
                ['prioridad' => 0],
                422,
            ],
            'CP-VL-27 prioridad 4' => [
                ['prioridad' => 4],
                422,
            ],
        ];
    }

    /**
     * @param  array<string, mixed>  $sobreescrituras
     */
    #[DataProvider('proveedorValoresLimiteTarea')]
    public function test_cp_vl_20_a_27_valores_limite_de_tarea(array $sobreescrituras, int $estadoEsperado): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $tarea = array_merge([
            'id' => '6f1c0000-0000-4000-8000-000000000001',
            'titulo' => 'Tarea base',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 2,
            'updated_at' => '2026-10-20T15:00:00.000Z',
        ], $sobreescrituras);

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [$tarea],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus($estadoEsperado);
    }

    /**
     * @return array<string, array{0: int, 1: int}>
     */
    public static function proveedorValoresLimiteSesion(): array
    {
        return [
            'CP-VL-28 sesión de 0 minutos' => [0, 422],
            'CP-VL-29 sesión de 1 minuto' => [1, 200],
            'CP-VL-30 sesión de 120 minutos' => [120, 200],
            'CP-VL-31 sesión de 121 minutos' => [121, 422],
        ];
    }

    #[DataProvider('proveedorValoresLimiteSesion')]
    public function test_cp_vl_28_a_31_valores_limite_de_sesion(int $duracionMinutos, int $estadoEsperado): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000001';
        Task::withoutTimestamps(fn () => Task::create([
            'id' => $taskId,
            'user_id' => $usuario->id,
            'titulo' => 'Tarea para sesión',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 1,
            'updated_at' => Carbon::parse('2026-10-20T14:00:00.000Z'),
        ]));

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [],
            'sessions' => [[
                'id' => 'a93e0000-0000-4000-8000-000000000002',
                'tarea_id' => $taskId,
                'fecha_inicio' => '2026-10-20T14:30:00Z',
                'duracion_minutos' => $duracionMinutos,
                'estado' => 'completada',
                'updated_at' => '2026-10-20T15:00:00.000Z',
            ]],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus($estadoEsperado);
    }

    public function test_cp_td_20_version_con_updated_at_anterior_se_omite(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000020';
        Task::withoutTimestamps(fn () => Task::create([
            'id' => $taskId,
            'user_id' => $usuario->id,
            'titulo' => 'Título vigente',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 2,
            'updated_at' => Carbon::parse('2026-10-20T15:00:00.000Z'),
        ]));

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [[
                'id' => $taskId,
                'titulo' => 'Título antiguo',
                'prioridad' => 1,
                'completada' => true,
                'pomodoros_estimados' => 4,
                'updated_at' => '2026-10-20T14:00:00.000Z',
            ]],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(200)
            ->assertJsonPath('omitidos', 1);
        $this->assertDatabaseHas('tasks', [
            'id' => $taskId,
            'titulo' => 'Título vigente',
        ]);
    }

    public function test_cp_td_21_version_con_la_misma_updated_at_se_omite(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000021';
        Task::withoutTimestamps(fn () => Task::create([
            'id' => $taskId,
            'user_id' => $usuario->id,
            'titulo' => 'Título original',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 2,
            'updated_at' => Carbon::parse('2026-10-20T15:00:00.000Z'),
        ]));

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [[
                'id' => $taskId,
                'titulo' => 'Título con misma fecha',
                'prioridad' => 1,
                'completada' => true,
                'pomodoros_estimados' => 3,
                'updated_at' => '2026-10-20T15:00:00.000Z',
            ]],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(200)
            ->assertJsonPath('omitidos', 1);
        $this->assertDatabaseHas('tasks', [
            'id' => $taskId,
            'titulo' => 'Título original',
        ]);
    }

    public function test_cp_td_22_version_con_updated_at_posterior_actualiza_la_tarea(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000022';
        Task::withoutTimestamps(fn () => Task::create([
            'id' => $taskId,
            'user_id' => $usuario->id,
            'titulo' => 'Título anterior',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 2,
            'updated_at' => Carbon::parse('2026-10-20T15:00:00.000Z'),
        ]));

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [[
                'id' => $taskId,
                'titulo' => 'Título actualizado',
                'prioridad' => 1,
                'completada' => true,
                'pomodoros_estimados' => 5,
                'updated_at' => '2026-10-20T16:00:00.000Z',
            ]],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(200)
            ->assertJsonPath('actualizados', 1);
        $this->assertDatabaseHas('tasks', [
            'id' => $taskId,
            'titulo' => 'Título actualizado',
        ]);
    }

    public function test_cp_td_23_otro_usuario_envia_la_misma_tarea_con_fecha_posterior_y_recibe_422(): void
    {
        // Preparar
        $dueno = User::factory()->create();
        $otroUsuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000023';
        Task::withoutTimestamps(fn () => Task::create([
            'id' => $taskId,
            'user_id' => $dueno->id,
            'titulo' => 'Tarea del dueño',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 2,
            'updated_at' => Carbon::parse('2026-10-20T15:00:00.000Z'),
        ]));

        // Ejecutar
        $response = $this->actingAs($otroUsuario)->postJson('/api/sync', [
            'tasks' => [[
                'id' => $taskId,
                'titulo' => 'Intento de modificación ajena',
                'prioridad' => 1,
                'completada' => true,
                'pomodoros_estimados' => 5,
                'updated_at' => '2026-10-20T16:00:00.000Z',
            ]],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(422);
        $this->assertDatabaseHas('tasks', [
            'id' => $taskId,
            'user_id' => $dueno->id,
            'titulo' => 'Tarea del dueño',
        ]);
    }

    public function test_cp_cb_10_tarea_nueva_sin_prioridad_se_guarda_con_prioridad_2(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000010';

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [[
                'id' => $taskId,
                'titulo' => 'Tarea sin prioridad explícita',
                'completada' => false,
                'pomodoros_estimados' => 3,
                'updated_at' => '2026-10-20T15:00:00.000Z',
            ]],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(200)
            ->assertJsonPath('creados', 1);
        $this->assertDatabaseHas('tasks', [
            'id' => $taskId,
            'prioridad' => 2,
        ]);
    }

    public function test_cp_cu_07_eliminar_tarea_propia_borra_la_tarea_y_su_sesion(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $taskId = '6f1c0000-0000-4000-8000-000000000007';
        $sessionId = 'a93e0000-0000-4000-8000-000000000007';

        Task::withoutTimestamps(fn () => Task::create([
            'id' => $taskId,
            'user_id' => $usuario->id,
            'titulo' => 'Tarea a eliminar',
            'prioridad' => 2,
            'completada' => false,
            'pomodoros_estimados' => 1,
            'updated_at' => Carbon::parse('2026-10-20T14:00:00.000Z'),
        ]));

        PomodoroSession::withoutTimestamps(fn () => PomodoroSession::create([
            'id' => $sessionId,
            'tarea_id' => $taskId,
            'fecha_inicio' => Carbon::parse('2026-10-20T14:00:00.000Z'),
            'duracion_minutos' => 25,
            'estado' => 'completada',
            'updated_at' => Carbon::parse('2026-10-20T14:25:00.000Z'),
        ]));

        // Ejecutar
        $response = $this->actingAs($usuario)->postJson('/api/sync', [
            'tasks' => [],
            'sessions' => [],
            'tareas_eliminadas' => [$taskId],
        ]);

        // Verificar
        $response->assertStatus(200);
        $this->assertDatabaseMissing('tasks', ['id' => $taskId]);
        $this->assertDatabaseMissing('pomodoro_sessions', ['id' => $sessionId]);
    }
}
