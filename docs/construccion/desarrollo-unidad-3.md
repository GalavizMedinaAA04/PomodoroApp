# Documento de Construcción y Desarrollo de Software — Unidad 3

Este documento respalda los 5 criterios de evaluación de la **Unidad 3 (Desarrollo de Software)** conforme al SWEBOK (IEEE, 2014), ISO/IEC/IEEE 12207, Pressman, Sommerville y Kendall & Kendall, alineado con los documentos de Análisis (Unidad 1 v1.1) y Diseño (Unidad 2 v1.1).

---

## 3.1 Selección e Implementación del Lenguaje de Programación

### Justificación técnica según SWEBOK
| Criterio SWEBOK | Cliente: Dart 3 / Flutter | Servidor: PHP 8.3 / Laravel 13 |
| :--- | :--- | :--- |
| **Adecuación al dominio** | Compilación nativa multiplataforma (Android, iOS, escritorio) desde una sola base de código (RNF-09) con acceso directo a notificaciones locales y SQLite. | Desarrollo ágil de APIs RESTful JSON con autenticación por tokens, limitación de tasa (`throttle:10,1`) y transacciones de base de datos. |
| **Rendimiento** | Compilación AOT (*Ahead-of-Time*) a código máquina nativo que garantiza respuesta de UI ≤ 200 ms (RNF-01) y cálculo exacto contra el reloj real (RNF-03). | Motor Zend de PHP 8.3 con tipado estricto en firmas y operaciones por lotes dentro de una sola transacción para cumplir p95 ≤ 500 ms (RNF-02). |
| **Sistema de tipos** | Tipado estático fuerte con *sound null safety* (`String?`, `DateTime?`), evitando errores de referencias nulas en tiempo de ejecución. | Declaraciones de tipos en argumentos y retornos (`JsonResponse`, `Response`, `array`, `int`, `?PersonalAccessToken`) y *casts* en modelos Eloquent. |
| **Ecosistema de bibliotecas** | `sqflite`, `flutter_local_notifications`, `shared_preferences`, `audioplayers`, `http` y `flutter_test`. | Eloquent ORM, sistema de migraciones, `Hash` (bcrypt), `RateLimiter` y `PHPUnit` / `Laravel Pint`. |

### Aplicación del paradigma (POO y programación funcional)
1. **Encapsulamiento y ocultamiento de estado:** En `CicloPomodoro` (`lib/services/ciclo_pomodoro.dart`), las marcas internas (`_inicioReloj`, `_segundosAlIniciar`, `_inicioSesion`, `_tareaSesion`, `_pendienteTrabajo`) son privadas; las pantallas solo interactúan mediante métodos de negocio (`iniciar`, `sincronizar`, `pausar`, `cancelar`, `finalizarFase`).
2. **Inmutabilidad y funciones puras:** `SesionCompletada`, `BarraGrafica`, `ResumenEstadisticas` y `ResultadoSync` usan constructores `const` y campos `final`. `EstadisticasService` (`lib/services/estadisticas_service.dart`) implementa métodos estáticos puros y deterministas que transforman colecciones mediante programación declarativa (`fold`, `where`, *collection-for*).
3. **Inyección de dependencias e inversión de control:** `SyncService` (`lib/services/sync_service.dart`) recibe por constructor el cliente HTTP (`http.Client`) y las funciones de persistencia (`exportarDatos`, `limpiarEliminadas`), permitiendo sustituir la red y la base de datos por objetos simulados (*mocks*) en las pruebas unitarias.

---

## 3.2 Manejador de Bases de Datos (DBMS) y Persistencia

### Justificación de volumen, concurrencia y consistencia
* **Cliente (`pomodoro.db` en SQLite v3):**
  - **Volumen:** Tablas declaradas con `WITHOUT ROWID` (evita duplicar el índice primario sobre llaves UUID `TEXT`) y `PRAGMA auto_vacuum = INCREMENTAL` para mantener el archivo muy por debajo del límite de 50 MB.
  - **Concurrencia y rendimiento:** `PRAGMA journal_mode = WAL` (*Write-Ahead Logging*) e índice `idx_sesiones_tarea` para que la consulta `LEFT JOIN` de estadísticas responda en milisegundos.
  - **Integridad y transacciones ACID:** `PRAGMA foreign_keys = ON`, borrado en cascada (`ON DELETE CASCADE`), restricciones `CHECK` en el DDL (`prioridad BETWEEN 1 AND 3`, `length(titulo) BETWEEN 1 AND 120`, `estado IN ('completada')`) y uso de `db.transaction` tanto en la migración `onUpgrade` (v2 → v3) como en `eliminarTarea` (borrado + registro atómico en `tareas_eliminadas`).
* **Servidor (`database.sqlite` / ruta a PostgreSQL):**
  - **Esquema en 3FN / FNBC:** Migraciones versionadas en `backend/database/migrations/` que eliminan la dependencia transitiva `user_id` de `pomodoro_sessions`, agregan `prioridad` e índice `tasks_user_id_index`, y crean `personal_access_tokens`.
  - **Control de concurrencia y seguridad:** `SyncController::syncData` ejecuta toda la sincronización dentro de `DB::transaction`, bloquea filas con `lockForUpdate()`, verifica la propiedad de las tareas (`verificarTareasPropias`, respondiendo `422` si una sesión apunta a una tarea ajena) y aplica la regla *last-write-wins* comparando `updated_at` en UTC. Todas las consultas usan parámetros enlazados (Eloquent/Query Builder), impidiendo inyecciones SQL (RNF-07).

---

## 3.3 Estándares de Codificación, Pruebas de Caja Blanca y Gestión de Configuración

### 3.3.1 y 3.3.5 Estándares de codificación y análisis estático
* **Dart / Flutter (*Effective Dart*):** Reglas activas en `analysis_options.yaml` (`flutter_lints`, `prefer_single_quotes`, `prefer_final_locals`, `avoid_empty_else`, `cancel_subscriptions`). Verificado con `flutter analyze` (`No issues found!`).
* **PHP / Laravel (*PSR-12*):** Configurado en `backend/pint.json` (`{"preset": "psr12"}`) y verificado con `./vendor/bin/pint --test`.

### 3.3.2 Pruebas unitarias, verificación de caja blanca y *mocking*
* **Suite en Flutter (`test/` — 23 pruebas automatizadas):**
  - `test/ciclo_pomodoro_test.dart`: Verifica caminos lógicos del temporizador, bloqueo sin tarea, pausa, cancelación, aplicación diferida de tiempos (CA-03.2) y activación del descanso largo tras completar los ciclos configurados (E6).
  - `test/sync_service_test.dart`: Emplea **`MockClient` (`package:http/testing.dart`)** y *mocks* de persistencia para aislar completamente la red y SQLite, probando respuestas `200`, `422` (tarea ajena) y `429` (límite de intentos).
  - `test/database_helper_test.dart`: Verifica en una base SQLite en memoria (`sqflite_common_ffi`) el CRUD con prioridad, el borrado en cascada con registro en `tareas_eliminadas` y el rechazo por restricciones `CHECK`.
  - `test/estadisticas_service_test.dart` y `test/resumen_estadisticas_test.dart`: Verifican agrupación por día/semana/mes y cálculo de racha en UTC.
* **Suite en Laravel (`backend/tests/Feature/` — 7 pruebas en PHPUnit):**
  - `AuthTest.php`: Registro con emisión de token personal, rechazo `401` ante credenciales inválidas y revocación de token en `/api/logout`.
  - `SyncTest.php`: Sincronización de tareas y sesiones con *last-write-wins* y rechazo `422` con reversión transaccional cuando una sesión apunta a una tarea de otro usuario.

### 3.3.3 y 3.3.4 Control de versiones e Integración Continua (ISO/IEC/IEEE 12207)
* **Flujo de ramas y commits semánticos:** Uso de ramas de funcionalidad (`feat/unidad-3-construccion`) y commits atómicos bajo la convención *Conventional Commits* (`feat(db):`, `feat(dominio):`, `feat(sync):`, `feat(ui):`, `feat(api):`, `ci:`).
* **Pipeline de Integración Continua (`.github/workflows/ci.yml`):** Ejecuta automáticamente en cada `push` y `pull_request` dos *jobs* paralelos:
  1. `flutter-ci`: Instala Flutter, ejecuta `flutter analyze` y corre `flutter test --coverage`.
  2. `laravel-ci`: Configura PHP 8.3, instala dependencias con Composer, verifica el estándar PSR-12 con `./vendor/bin/pint --test`, ejecuta las migraciones sobre SQLite y corre `php artisan test`.
