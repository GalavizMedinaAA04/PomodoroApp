<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class PomodoroSession extends Model
{
    use HasUuids;

    protected $table = 'pomodoro_sessions';

    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'id', 'tarea_id', 'fecha_inicio', 'duracion_minutos', 'estado', 'updated_at',
    ];

    protected function casts(): array
    {
        return [
            'fecha_inicio' => 'datetime',
            'duracion_minutos' => 'integer',
            'updated_at' => 'datetime:Y-m-d\TH:i:s.v\Z',
        ];
    }

    public function task(): BelongsTo
    {
        return $this->belongsTo(Task::class, 'tarea_id');
    }
}
