# ADR-006: Registrar borrados en `tareas_eliminadas` (tombstones)

- **Estado:** Aceptada

## Contexto

Un borrado local realizado sin conexión debe propagarse al servidor en la siguiente sincronización sin alterar las consultas habituales de lectura local.

## Alternativas

- Borrado lógico con columna `deleted_at` en `tareas`.
- Tabla separada `tareas_eliminadas` (tombstones).

## Decisión

Al eliminar una tarea en `DatabaseHelper.eliminarTarea`, dentro de una misma transacción se elimina la fila de `tareas` (borrando sus sesiones en cascada) y se inserta su UUID en `tareas_eliminadas`. Al recibir `200 OK` de `POST /api/sync`, se limpia `tareas_eliminadas`.

## Consecuencias

- Las consultas locales (`listarTareas`, `listarSesionesCompletadasConTitulo`) no necesitan filtrar registros borrados.
- La tabla `tareas_eliminadas` se vacía tras cada sincronización exitosa.
