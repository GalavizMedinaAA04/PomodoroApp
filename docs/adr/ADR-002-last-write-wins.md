# ADR-002: Last-write-wins por `updated_at`

- **Estado:** Aceptada

## Contexto

Dos equipos pueden editar la misma tarea sin conexión.

## Decisión

Cada registro lleva su marca `updated_at` del dispositivo. Al sincronizar, el servidor reemplaza un registro solo si el cambio entrante es más reciente. El servidor nunca sobreescribe registros de otro usuario.

## Consecuencias

- La resolución es automática y predecible.
- Un cambio más antiguo se pierde sin aviso. Es aceptable para tareas y sesiones de estudio.
- Depende de que los relojes de los equipos estén razonablemente sincronizados.
