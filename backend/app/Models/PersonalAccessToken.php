<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\MorphTo;

class PersonalAccessToken extends Model
{
    protected $fillable = [
        'tokenable_type',
        'tokenable_id',
        'name',
        'token',
        'abilities',
        'last_used_at',
        'expires_at',
    ];

    protected function casts(): array
    {
        return [
            'abilities' => 'json',
            'last_used_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    public function tokenable(): MorphTo
    {
        return $this->morphTo('tokenable');
    }

    public static function findToken(string $token): ?self
    {
        if (! str_contains($token, '|')) {
            return self::where('token', hash('sha256', $token))->first();
        }

        [$id, $plain] = explode('|', $token, 2);
        $instance = self::find($id);

        if ($instance && hash_equals($instance->token, hash('sha256', $plain))) {
            return $instance;
        }

        return null;
    }
}
