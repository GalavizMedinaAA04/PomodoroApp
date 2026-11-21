<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AutenticacionLimitesTest extends TestCase
{
    use RefreshDatabase;

    public function test_cp_vl_10_once_intentos_de_login_con_contrasena_incorrecta_en_un_minuto(): void
    {
        // Preparar
        User::factory()->create([
            'email' => 'lucia@itm.mx',
            'password' => Hash::make('secreto123'),
        ]);

        // Ejecutar
        $respuestas = [];
        for ($i = 1; $i <= 11; $i++) {
            $respuestas[$i] = $this->postJson('/api/login', [
                'email' => 'lucia@itm.mx',
                'password' => 'incorrecta',
            ]);
        }

        // Verificar
        for ($i = 1; $i <= 10; $i++) {
            $respuestas[$i]->assertStatus(401);
        }
        $respuestas[11]->assertStatus(429);
    }

    public function test_cp_vl_11_token_creado_hace_23_h_permite_sincronizar(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $token = $usuario->createToken('mobile')->plainTextToken;
        $this->travel(23)->hours();

        // Ejecutar
        $response = $this->withToken($token)->postJson('/api/sync', [
            'tasks' => [],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(200);
    }

    public function test_cp_vl_12_token_creado_hace_25_h_es_rechazado(): void
    {
        // Preparar
        $usuario = User::factory()->create();
        $token = $usuario->createToken('mobile')->plainTextToken;
        $this->travel(25)->hours();

        // Ejecutar
        $response = $this->withToken($token)->postJson('/api/sync', [
            'tasks' => [],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ]);

        // Verificar
        $response->assertStatus(401);
    }

    public function test_cp_ce_10_post_api_sync_sin_token_devuelve_401(): void
    {
        // Preparar
        $payload = [
            'tasks' => [],
            'sessions' => [],
            'tareas_eliminadas' => [],
        ];

        // Ejecutar
        $response = $this->postJson('/api/sync', $payload);

        // Verificar
        $response->assertStatus(401);
    }

    public function test_cp_ce_11_registro_con_correo_ya_existente_devuelve_422(): void
    {
        // Preparar
        User::factory()->create([
            'email' => 'existente@itm.mx',
        ]);

        // Ejecutar
        $response = $this->postJson('/api/register', [
            'name' => 'Usuario Duplicado',
            'email' => 'existente@itm.mx',
            'password' => 'secreto123',
            'password_confirmation' => 'secreto123',
        ]);

        // Verificar
        $response->assertStatus(422)
            ->assertJsonValidationErrors(['email']);
    }
}
