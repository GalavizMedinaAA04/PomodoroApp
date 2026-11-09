# ADR-008: Separar la lógica de dominio de los widgets

- **Estado:** Aceptada

## Contexto

Mezclar el cálculo de fases, ciclos y estadísticas dentro del `State` de los widgets dificulta las pruebas unitarias de caja blanca y eleva la complejidad ciclomática.

## Alternativas

- Mantener la lógica en `TimerScreen` y `StatsScreen`.
- Extraer servicios de dominio puros (`CicloPomodoro`, `EstadisticasService`, `SyncService`).

## Decisión

Toda la lógica de fases, descanso largo y conteo de ciclos reside en `CicloPomodoro` (recibiendo `DateTime` como parámetro), los cálculos y desgloses jerárquicos en `EstadisticasService`, y la comunicación HTTP en `SyncService` con inyección de dependencias.

## Consecuencias

- Cohesión funcional alta y acoplamiento de datos limpio.
- Permite ejecutar pruebas unitarias rápidas y deterministas con *mocking* sin levantar la interfaz gráfica.
