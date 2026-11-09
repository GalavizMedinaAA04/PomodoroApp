# ADR-009: SQLite en el servidor para la versión 1, con ruta a PostgreSQL

- **Estado:** Aceptada

## Contexto

El proyecto requiere un DBMS relacional ACID en el servidor con cero costo de licencias y despliegue sencillo para el entorno académico, pero capaz de migrar a PostgreSQL si la concurrencia de escritura crece.

## Alternativas

- PostgreSQL desde el inicio.
- MySQL / MariaDB.
- SQLite con `journal_mode = WAL` y migraciones de Laravel portables.

## Decisión

Usar SQLite en la versión 1 del servidor y validar la latencia con `k6` (RNF-02: p95 ≤ 500 ms con 100 usuarios). Las migraciones usan tipos estándar de Eloquent para que el paso a PostgreSQL solo requiera cambiar `DB_CONNECTION=pgsql`.

## Consecuencias

- Despliegue inmediato sin servicios adicionales y soporte transaccional ACID completo.
