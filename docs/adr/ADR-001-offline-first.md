# ADR-001: App offline-first con SQLite local

- **Estado:** Aceptada

## Contexto

El temporizador debe funcionar sin red, porque el usuario estudia en cualquier lugar.

## Decisión

Cada dato se guarda primero en SQLite local (`pomodoro.db`). La sincronización con la API es opcional y ocurre cuando el usuario la pide.

## Consecuencias

- La app funciona sin conexión.
- Los datos pueden diferir entre equipos hasta que se sincronizan. ADR-002 define cómo se resuelven esas diferencias.
