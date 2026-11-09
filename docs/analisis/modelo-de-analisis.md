# Modelo de análisis: requisitos, usuarios y trazabilidad

Este documento es el punto de partida de la trazabilidad. Cada requisito se traza al diseño (`docs/diseno/`), al código y a una prueba.

## Análisis de usuario y contexto

**Usuaria o usuario principal:** estudiante universitario que organiza su estudio con la técnica Pomodoro.

**Contexto de uso:**

- Estudia en casa, en la biblioteca o en el transporte, con conexión intermitente.
- Usa principalmente un teléfono Android. Ocasionalmente usa un escritorio.
- Necesita avisos aunque la app esté en segundo plano.

**Tareas principales:**

1. Elegir la tarea en la que va a trabajar y empezar un pomodoro.
2. Pausar o cancelar cuando una interrupción lo obliga.
3. Revisar cuánto trabajó por día, por semana y por mes.
4. Ajustar la duración de los pomodoros sin salirse de lo recomendado.
5. Guardar su progreso en el servidor cuando tiene conexión.

**Necesidades que se desprenden:** respuesta inmediata, avisos confiables, datos que no se pierdan sin conexión, y control sobre sus propios tiempos.

## Requisitos funcionales

| ID | Requisito | Fuente | Diseño | Código | Prueba |
| --- | --- | --- | --- | --- | --- |
| RF-01 | El usuario inicia, pausa y cancela el temporizador | Tarea 1 | `diseno/procesos.md`, pseudocódigo del ciclo | `services/ciclo_pomodoro.dart`, `screens/timer_screen.dart` | `test/ciclo_pomodoro_test.dart` |
| RF-02 | No se inicia una fase de trabajo sin tarea seleccionada | Tarea 1 | `diseno/interfaz.md`, prevención de errores | `CicloPomodoro.iniciar` | `ciclo_pomodoro_test`: "no inicia una fase de trabajo sin tarea" |
| RF-03 | Cada pomodoro de trabajo completo se guarda como sesión | ADR-003 | `diseno/datos.md`, tabla `sesiones` | `CicloPomodoro.finalizarFase`, `DatabaseHelper.insertarSesion` | `ciclo_pomodoro_test`: "al terminar el trabajo devuelve la sesión" |
| RF-04 | El sistema avisa cuando termina la fase, aunque la app esté en segundo plano | ADR-004 | `diseno/arquitectura.md` | `services/notification_service.dart` | Manual: bloquear el teléfono y esperar el aviso |
| RF-05 | El usuario crea, edita, completa y borra tareas | Tarea 1 | `diseno/interfaz.md`, pantalla Tareas | `screens/tasks_screen.dart`, `DatabaseHelper` | Manual |
| RF-06 | Los minutos de trabajo y descanso tienen un rango recomendado y piden confirmación fuera de él | Acuerdo del equipo | `diseno/interfaz.md`, pantalla Configuración | `screens/settings_screen.dart` | Manual: escribir 90 min y elegir cada opción |
| RF-07 | Estadísticas: totales, racha, Top 5 y bitácora diaria | Tarea 1 | `diseno/interfaz.md`, pantalla Estadísticas | `EstadisticasService.resumir`, `screens/stats_screen.dart` | `test/resumen_estadisticas_test.dart` |
| RF-08 | Gráficas de minutos por día, semana y mes | Requisito del proyecto | `diseno/interfaz.md`, pantalla Gráficas | `EstadisticasService.agrupar`, `screens/graficas_screen.dart` | `test/estadisticas_service_test.dart` |
| RF-09 | El usuario inicia sesión en la API con correo y contraseña | ADR-005 | `diseno/arquitectura.md`, vista de procesos | `SyncService.iniciarSesion`, `AuthController` | `AuthTest` |
| RF-10 | La app envía tareas, sesiones y borrados al servidor | ADR-001, ADR-002 | Pseudocódigo de la sincronización | `SyncService.sincronizar`, `SyncController::syncData` | `SyncTest::test_sincroniza_tareas_y_sesiones_del_usuario` |
| RF-11 | El servidor borra solo las tareas del propio usuario | Seguridad | `diseno/datos.md` | `SyncController` (`tareas_eliminadas`) | `SyncTest::test_solo_borra_tareas_propias` |
| RF-12 | Una sesión no puede apuntar a una tarea ajena | 3FN y seguridad | `sql/esquema.sql`, migración `000001` | `SyncController::verificarTareasPropias` | `SyncTest::test_rechaza_sesion_que_apunta_a_tarea_ajena` |

## Requisitos no funcionales

| ID | Requisito | Atributo | Diseño | Código | Prueba |
| --- | --- | --- | --- | --- | --- |
| RNF-01 | El temporizador y las tareas funcionan sin red | Disponibilidad | ADR-001 | SQLite local | Manual en modo avión |
| RNF-02 | Los conflictos entre equipos se resuelven por la marca más reciente | Consistencia | ADR-002 | `SyncController::applyLastWriteWins` | `SyncTest::test_no_sobreescribe_tareas_de_otro_usuario` |
| RNF-03 | El login tiene límite de 10 intentos por minuto y no expone contraseñas | Seguridad | ADR-005 | `routes/api.php`, `AuthController` | `AuthTest` |
| RNF-04 | El temporizador se corrige al volver a primer plano | Confiabilidad | ADR-004 | `TimerScreen.didChangeAppLifecycleState` | Manual |
| RNF-05 | Las pantallas validan entradas y piden confirmación ante acciones destructivas | Usabilidad | `diseno/interfaz.md` | `SettingsScreen`, `TasksScreen` | Manual |

## Matriz de trazabilidad resumida

| Requisito | Sección de diseño | Archivo de código | Prueba automatizada |
| --- | --- | --- | --- |
| RF-01, RF-02, RF-03 | 1. Procesos | `ciclo_pomodoro.dart` | Sí |
| RF-04 | 2. Arquitectura (ADR-004) | `notification_service.dart` | No, manual |
| RF-05, RF-06 | 4. Interfaz | `tasks_screen.dart`, `settings_screen.dart` | No, manual |
| RF-07, RF-08 | 4. Interfaz | `estadisticas_service.dart`, `stats_screen.dart`, `graficas_screen.dart` | Sí |
| RF-09, RF-10, RF-11, RF-12 | 2. Arquitectura, 3. Datos | `SyncController.php`, `sync_service.dart` | Sí |
| RNF-01 a RNF-05 | 2. Arquitectura, ADR | Ver tabla de requisitos | Parcial |
