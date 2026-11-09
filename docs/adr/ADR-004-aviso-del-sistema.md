# ADR-004: Aviso programado del sistema para el fin de fase

- **Estado:** Aceptada

## Contexto

El `Timer` de Dart se congela cuando la app pasa a segundo plano. El usuario necesita el aviso aunque no mire la pantalla. Este es el riesgo R-01 del proyecto.

## Decisión

Al iniciar una fase, `NotificationService` programa una notificación del sistema para la hora de fin. Al volver a primer plano, el temporizador recalcula con el reloj real.

## Consecuencias

- El aviso llega aunque la app esté cerrada.
- Con el modo Doze de Android, el aviso puede retrasarse unos segundos.
