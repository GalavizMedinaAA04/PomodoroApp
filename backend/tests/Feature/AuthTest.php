<?php

namespace Tests\Feature;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Tests\TestCase;

class AuthTest extends TestCase
{
    use RefreshDatabase;

    public function test_usuario_puede_registrarse_y_recibir_token(): void
    {
        $response = $this->postJson('/api/register', [
            'name' => 'Lucía Estudiante',
            'email' => 'lucia@itm.mx',
            'password' => 'secreto123',
            'password_confirmation' => 'secreto123',
        ]);

        $response->assertCreated()
            ->assertJsonStructure(['token', 'token_type', 'user' => ['id', 'name', 'email']]);

        $this->assertDatabaseHas('users', ['email' => 'lucia@itm.mx']);
        $this->assertDatabaseHas('personal_access_tokens', ['name' => 'mobile']);
    }

    public function test_login_rechaza_credenciales_invalidas(): void
    {
        User::factory()->create([
            'email' => 'lucia@itm.mx',
            'password' => Hash::make('secreto123'),
        ]);

        $response = $this->postJson('/api/login', [
            'email' => 'lucia@itm.mx',
            'password' => 'incorrecta',
        ]);

        $response->assertStatus(401);
    }

    public function test_logout_revoca_el_token_personal(): void
    {
        $user = User::factory()->create();
        $plainToken = $user->createToken('test-device')->plainTextToken;

        $this->withHeader('Authorization', 'Bearer '.$plainToken)
            ->postJson('/api/logout')
            ->assertNoContent();

        $this->assertDatabaseCount('personal_access_tokens', 0);
    }
}
