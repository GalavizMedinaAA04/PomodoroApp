# ADR-003: Guardar la sesión solo al completar la fase de trabajo

- **Estado:** Aceptada

## Contexto

Una pausa o una cancelación no debe contar como trabajo realizado.

## Decisión

La sesión se guarda en SQLite solo cuando la fase de trabajo llega a cero. Pausar no guarda nada, y cancelar descarta la sesión en curso.

## Consecuencias

- Las estadísticas solo cuentan pomodoros completos.
- Si la app se cierra durante una fase, esa sesión se pierde.
