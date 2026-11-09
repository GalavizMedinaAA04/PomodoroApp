<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Task extends Model
{
    use HasUuids;

    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id',
        'user_id',
        'titulo',
        'prioridad',
        'completada',
        'pomodoros_estimados',
        'updated_at',
    ];

    protected function casts(): array
    {
        return [
            'prioridad' => 'integer',
            'completada' => 'boolean',
            'pomodoros_estimados' => 'integer',
            'updated_at' => 'datetime:Y-m-d\TH:i:s.v\Z',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function sessions(): HasMany
    {
        return $this->hasMany(PomodoroSession::class, 'tarea_id');
    }
}
