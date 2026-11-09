<?php

namespace App\Http\Controllers;

use App\Models\PomodoroSession;
use App\Models\Task;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class SyncController extends Controller
{
    public function syncData(Request $request): JsonResponse
    {
        $data = $request->validate([
            'tasks' => ['array'],
            'tasks.*.id' => ['required', 'uuid'],
            'tasks.*.titulo' => ['required', 'string', 'min:1', 'max:120'],
            'tasks.*.prioridad' => ['nullable', 'integer', 'between:1,3'],
            'tasks.*.completada' => ['required', 'boolean'],
            'tasks.*.pomodoros_estimados' => ['required', 'integer', 'between:1,20'],
            'tasks.*.updated_at' => ['required', 'date'],

            'sessions' => ['array'],
            'sessions.*.id' => ['required', 'uuid'],
            'sessions.*.tarea_id' => ['required', 'uuid'],
            'sessions.*.fecha_inicio' => ['required', 'date'],
            'sessions.*.duracion_minutos' => ['required', 'integer', 'between:1,120'],
            'sessions.*.estado' => ['required', 'string', 'in:completada'],
            'sessions.*.updated_at' => ['required', 'date'],

            'tareas_eliminadas' => ['array'],
            'tareas_eliminadas.*' => ['uuid'],
        ]);

        $userId = $request->user()->id;

        $result = DB::transaction(function () use ($data, $userId) {
            $tasks = $this->syncTasks($data['tasks'] ?? [], $userId);
            $this->verificarTareasPropias($data['sessions'] ?? [], $userId);
            $sessions = $this->syncSessions($data['sessions'] ?? [], $userId);

            $eliminadas = $data['tareas_eliminadas'] ?? [];
            if (! empty($eliminadas)) {
                Task::where('user_id', $userId)->whereIn('id', $eliminadas)->delete();
            }

            return [
                'creados' => $tasks['created'] + $sessions['created'],
                'actualizados' => $tasks['updated'] + $sessions['updated'],
                'omitidos' => $tasks['skipped'] + $sessions['skipped'],
                'tasks' => $tasks,
                'sessions' => $sessions,
            ];
        });

        return response()->json([
            'status' => 'ok',
            'creados' => $result['creados'],
            'actualizados' => $result['actualizados'],
            'omitidos' => $result['omitidos'],
            'server_time' => now()->utc()->toIso8601ZuluString('millisecond'),
        ]);
    }

    private function syncTasks(array $records, int $userId): array
    {
        $created = $updated = $skipped = 0;

        foreach ($records as $record) {
            $incomingAt = Carbon::parse($record['updated_at'])->utc();
            $existing = Task::whereKey($record['id'])->lockForUpdate()->first();

            if ($existing) {
                if ($existing->user_id !== $userId) {
                    throw ValidationException::withMessages([
                        'tasks' => ['Una tarea enviada pertenece a otro usuario.'],
                    ]);
                }
                if (! $incomingAt->gt($existing->updated_at)) {
                    $skipped++;
                    continue;
                }
            }

            Task::withoutTimestamps(fn () => Task::updateOrCreate(
                ['id' => $record['id']],
                [
                    'user_id' => $userId,
                    'titulo' => $record['titulo'],
                    'prioridad' => $record['prioridad'] ?? 2,
                    'completada' => (bool) $record['completada'],
                    'pomodoros_estimados' => $record['pomodoros_estimados'],
                    'updated_at' => $incomingAt,
                ]
            ));

            $existing ? $updated++ : $created++;
        }

        return compact('created', 'updated', 'skipped');
    }

    private function verificarTareasPropias(array $sessions, int $userId): void
    {
        if (empty($sessions)) {
            return;
        }

        $tareaIds = collect($sessions)->pluck('tarea_id')->unique()->values();
        $propiasCount = Task::where('user_id', $userId)
            ->whereIn('id', $tareaIds)
            ->count();

        if ($propiasCount !== $tareaIds->count()) {
            throw ValidationException::withMessages([
                'sessions' => ['Una sesión apunta a una tarea inexistente o de otro usuario.'],
            ]);
        }
    }

    private function syncSessions(array $records, int $userId): array
    {
        $created = $updated = $skipped = 0;

        foreach ($records as $record) {
            $incomingAt = Carbon::parse($record['updated_at'])->utc();
            $existing = PomodoroSession::with('task')
                ->whereKey($record['id'])
                ->lockForUpdate()
                ->first();

            if ($existing) {
                if ($existing->task?->user_id !== $userId) {
                    throw ValidationException::withMessages([
                        'sessions' => ['Una sesión enviada pertenece a otro usuario.'],
                    ]);
                }
                if (! $incomingAt->gt($existing->updated_at)) {
                    $skipped++;
                    continue;
                }
            }

            PomodoroSession::withoutTimestamps(fn () => PomodoroSession::updateOrCreate(
                ['id' => $record['id']],
                [
                    'tarea_id' => $record['tarea_id'],
                    'fecha_inicio' => Carbon::parse($record['fecha_inicio'])->utc(),
                    'duracion_minutos' => $record['duracion_minutos'],
                    'estado' => $record['estado'],
                    'updated_at' => $incomingAt,
                ]
            ));

            $existing ? $updated++ : $created++;
        }

        return compact('created', 'updated', 'skipped');
    }
}
