<?php

namespace App\Models;

use Database\Factories\UserFactory;
use Illuminate\Database\Eloquent\Attributes\Fillable;
use Illuminate\Database\Eloquent\Attributes\Hidden;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Relations\MorphMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Illuminate\Support\Str;

#[Fillable(['name', 'email', 'password'])]
#[Hidden(['password', 'remember_token'])]
class User extends Authenticatable
{
    /** @use HasFactory<UserFactory> */
    use HasFactory;
    use Notifiable;

    protected ?PersonalAccessToken $accessToken = null;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'email_verified_at' => 'datetime',
            'password' => 'hashed',
        ];
    }

    public function tokens(): MorphMany
    {
        return $this->morphMany(PersonalAccessToken::class, 'tokenable');
    }

    /**
     * Emite un token personal con expiración de 24 horas (RNF-06).
     */
    public function createToken(string $name, array $abilities = ['*']): object
    {
        $plainTextToken = Str::random(40);

        $token = $this->tokens()->create([
            'name' => $name,
            'token' => hash('sha256', $plainTextToken),
            'abilities' => $abilities,
            'expires_at' => now()->addHours(24),
        ]);

        return (object) [
            'accessToken' => $token,
            'plainTextToken' => $token->getKey().'|'.$plainTextToken,
        ];
    }

    public function currentAccessToken(): ?PersonalAccessToken
    {
        return $this->accessToken;
    }

    public function withAccessToken(?PersonalAccessToken $accessToken): static
    {
        $this->accessToken = $accessToken;

        return $this;
    }
}
