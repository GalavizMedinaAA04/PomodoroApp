# ADR-007: Sincronización solo de subida en la versión 1

- **Estado:** Aceptada

## Contexto

El objetivo prioritario de la versión 1 es respaldar el progreso del estudiante en el servidor sin complejizar el cliente con reconciliación bidireccional en segundo plano.

## Alternativas

- Sincronización bidireccional automática en segundo plano.
- Subida por lotes iniciada por el usuario (`POST /api/sync`).

## Decisión

En la versión 1 la sincronización es de subida a petición del usuario («Sincronizar ahora»). La configuración de tiempos permanece en `SharedPreferences` de cada dispositivo.

## Consecuencias

- Menor consumo de batería y datos móviles; control explícito del usuario.
- La descarga incremental hacia otros equipos queda preparada para la versión 2 mediante `server_time`.
