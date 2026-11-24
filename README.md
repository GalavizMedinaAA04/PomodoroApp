# PomodoroApp

Aplicación Pomodoro multiplataforma con enfoque *offline-first* desarrollada en Flutter y acompañada de una API REST opcional en Laravel 13 para respaldo y sincronización en la nube. Permite gestionar tareas con prioridad y estimación de pomodoros, ejecutar ciclos configurables de trabajo, descanso corto y descanso largo con avisos del sistema (alarmas exactas en Android, sonido y vibración), consultar estadísticas e historial diario en hora local, visualizar gráficas por día, semana o mes y sincronizar los datos con resolución de conflictos *Last-Write-Wins* (LWW) y registro de tareas eliminadas (*tombstones*).

- **Versión actual:** `1.0.1` (`1.0.1+3` — release candidata [`v1.0.1-rc.2`](https://github.com/GalavizMedinaAA04/PomodoroApp/releases/tag/v1.0.1-rc.2) · [todas las releases](https://github.com/GalavizMedinaAA04/PomodoroApp/releases))
- **Documento del proyecto:** [Documento de Desarrollo — Unidad 3 (`docs/construccion/Documento_Desarrollo_Unidad_3_Pomodoro.pdf`)](docs/construccion/Documento_Desarrollo_Unidad_3_Pomodoro.pdf) ([versión en Markdown](docs/construccion/desarrollo-unidad-3.md)) y [índice general de documentación (`docs/README.md`)](docs/README.md).

---

## Tabla de contenidos

1. [Qué es la aplicación](#1-qué-es-la-aplicación)
2. [Arquitectura](#2-arquitectura)
3. [Requisitos](#3-requisitos)
4. [Cómo correr la app y la API en local](#4-cómo-correr-la-app-y-la-api-en-local)
5. [Variables del `.env` que importan](#5-variables-del-env-que-importan)
6. [Cómo correr las pruebas y la cobertura](#6-cómo-correr-las-pruebas-y-la-cobertura)
7. [Resumen de endpoints de la API](#7-resumen-de-endpoints-de-la-api)
8. [Despliegue](#8-despliegue)
9. [Estructura de carpetas](#9-estructura-de-carpetas)
10. [Versión actual y enlaces del proyecto](#10-versión-actual-y-enlaces-del-proyecto)

---

## 1. Qué es la aplicación

**PomodoroApp** es un sistema de productividad personal basado en la técnica Pomodoro, diseñado para funcionar al 100 % sin conexión a internet y ofrecer sincronización opcional hacia un servidor propio:

- **Temporizador Pomodoro (`TimerScreen`):** máquina de estados determinista (`CicloPomodoro`) que alterna fases de trabajo (`25 min` por defecto, configurable de `1` a `120 min`), descanso corto (`5 min`, configurable de `1` a `60 min`) y descanso largo (`15 min`, configurable de `1` a `60 min`) cada `N` pomodoros (`4` por defecto, configurable de `1` a `12`). Solo registra sesiones completadas con su `fecha_inicio` en UTC y duración en minutos.
- **Gestión de tareas (`TasksScreen`):** creación, edición, marcado de completadas y eliminación de tareas con UUID v4, título (`1` a `120` caracteres), prioridad (`1` alta, `2` media, `3` baja) y pomodoros estimados (`1` a `20`). Al borrar una tarea, se eliminan en cascada sus sesiones locales y se guarda un *tombstone* en `tareas_eliminadas` para propagar la baja al servidor.
- **Estadísticas y bitácora (`StatsScreen` y `EstadisticasService`):** cálculo en hora local de minutos acumulados, sesiones del día actual, racha de días consecutivos trabajados, desglose por tarea (incluyendo sesiones de tareas eliminadas) y bitácora diaria consultable por fecha.
- **Gráficas (`GraficasScreen`):** barras de minutos enfocados agrupadas en hora local por día (últimos 14 días), semana (últimas 8 semanas, iniciando en lunes) y mes (últimos 12 meses).
- **Configuración (`SettingsScreen`):** personalización de duraciones del ciclo y activación/desactivación de sonido con persistencia local en `SharedPreferences`.
- **Sincronización en la nube (`SyncScreen` y `SyncService`):** registro, inicio/cierre de sesión y envío por lotes (`POST /api/sync`) de tareas, sesiones completadas y UUID de tareas eliminadas.

---

## 2. Arquitectura

El sistema sigue una arquitectura cliente-servidor con cliente **offline-first** ([ADR-001](docs/adr/ADR-001-offline-first.md)) y sincronización de subida con **Last-Write-Wins** ([ADR-002](docs/adr/ADR-002-last-write-wins.md), [ADR-007](docs/adr/ADR-007-sincronizacion-subida.md)):

- **Cliente móvil y de escritorio (`lib/` — Flutter):**
  - Persistencia local en SQLite mediante `sqflite` (Android/iOS) y `sqflite_common_ffi` (Windows, Linux, macOS y pruebas automatizadas) centralizada en `DatabaseHelper` (`lib/data/database_helper.dart`), con `PRAGMA foreign_keys = ON` y tres tablas: `tareas`, `sesiones_pomodoro` y `tareas_eliminadas`.
  - Lógica de dominio desacoplada de los widgets ([ADR-008](docs/adr/ADR-008-separar-dominio-de-widgets.md)) en `lib/services/`: `CicloPomodoro`, `EstadisticasService`, `SyncService` y `NotificationService`.
  - Barra de navegación inferior fija en la pantalla principal con cinco accesos con icono y etiqueta visible (`Tareas`, `Estadísticas`, `Gráficas`, `Configuración` y `Sincronizar`).
- **API REST opcional (`backend/` — Laravel 13):**
  - Almacenamiento en SQLite con modo `WAL`, `busy_timeout = 5000`, `synchronous = normal` y transacciones `IMMEDIATE` para serializar escrituras concurrentes sin bloqueos ([ADR-009](docs/adr/ADR-009-sqlite-servidor-ruta-postgresql.md)).
  - Autenticación mediante un guard propio llamado `sanctum` registrado con `Auth::viaRequest` en `AppServiceProvider`, respaldado por el modelo `App\Models\PersonalAccessToken` (tokens opacos con hash SHA-256 en la tabla `personal_access_tokens` y expiración de 24 horas). No requiere ni instala el paquete externo `laravel/sanctum` ([ADR-005](docs/adr/ADR-005-autenticacion-sanctum.md)).
  - En `SyncController`, las marcas `updated_at` recibidas con milisegundos se normalizan a UTC y se truncan al segundo (`Carbon::parse(...)->utc()->startOfSecond()`) antes de compararlas con los registros existentes. En `AuthController`, el correo se normaliza a minúsculas y sin espacios (`Str::lower(trim(...))`) tanto en `/api/register` como en `/api/login`.

---

## 3. Requisitos

| Componente | Versión requerida |
| --- | --- |
| **Flutter SDK** | `3.38.8` (canal `stable`) |
| **Dart SDK** | `3.10.7` o superior (`^3.10.7` en `pubspec.yaml`) |
| **PHP** | `8.4` o superior (con extensiones `pdo_sqlite`, `sqlite3`, `mbstring`, `openssl`, `xml`, `curl`) |
| **Composer** | `2.x` |
| **SQLite** | `3.x` |

---

## 4. Cómo correr la app y la API en local

### 4.1. Iniciar la API Laravel en local (`backend/`)

```bash
cd backend
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan serve --host=127.0.0.1 --port=8000
```

La API quedará disponible en `http://127.0.0.1:8000/api` y el endpoint de salud en `http://127.0.0.1:8000/up`.

### 4.2. Iniciar la aplicación Flutter (raíz del repositorio)

```bash
flutter pub get
flutter run
```

- La aplicación funciona de inmediato en modo local sin necesidad de levantar la API.
- Para sincronizar contra una instancia local de la API desde la pantalla **Sincronizar**, introduce la URL del servidor en el campo **URL del servidor**:
  - En escritorio (Windows/Linux/macOS): `http://127.0.0.1:8000`
  - En emulador de Android: `http://10.0.2.2:8000`
  - En dispositivo físico o prueba piloto: se utiliza por defecto el túnel HTTPS configurado en `SyncService.urlPorDefecto`.

---

## 5. Variables del `.env` que importan

En `backend/.env` (basado en [`backend/.env.example`](backend/.env.example) para desarrollo local y en [`deploy/env.staging.example`](deploy/env.staging.example) para staging/producción), las variables críticas son:

| Variable | Valor en local | Valor en staging / producción | Propósito |
| --- | --- | --- | --- |
| `APP_NAME` | `Pomodoro` | `Pomodoro` | Nombre de la aplicación Laravel. |
| `APP_ENV` | `local` | `production` | Entorno de ejecución (`production` desactiva herramientas de desarrollo). |
| `APP_KEY` | Generada con `php artisan key:generate` | Generada con `php artisan key:generate` | Clave de cifrado y firma de la aplicación. |
| `APP_DEBUG` | `true` | `false` | **Crítico en despliegue:** en `false` evita exponer trazas internas en respuestas HTTP. |
| `APP_URL` | `http://localhost:8000` | `https://<tunel>.trycloudflare.com` | URL base pública de la API. |
| `APP_LOCALE` | `es` | `es` | Idioma de mensajes de validación. |
| `DB_CONNECTION` | `sqlite` | `sqlite` | Motor de base de datos utilizado por la API. |
| `DB_DATABASE` | *(por defecto `database/database.sqlite`)* | `/var/www/pomodoro/backend/database/database.sqlite` | Ruta absoluta al archivo SQLite del servidor. |
| `BCRYPT_ROUNDS` | `12` | `12` | Factor de costo del hash `bcrypt` para contraseñas de usuarios. |
| `LOG_LEVEL` | `debug` | `warning` | Nivel mínimo de bitácora en `storage/logs/laravel.log`. |

---

## 6. Cómo correr las pruebas y la cobertura

### 6.1. Pruebas y análisis estático en Flutter (raíz del repositorio)

```bash
# Análisis estático (0 warnings)
flutter analyze

# Suite completa de pruebas unitarias, de servicios y de widgets (64 pruebas)
flutter test

# Generar reporte de cobertura en coverage/lcov.info
flutter test --coverage
```

### 6.2. Pruebas, estilo PSR-12 y cobertura en Laravel (`backend/`)

```bash
cd backend

# Suite completa de pruebas de integración y reglas con PHPUnit 12 (31 pruebas, 80 aserciones)
php artisan test

# Verificación de formato y estándar de código PSR-12 con Laravel Pint
./vendor/bin/pint --test

# Cobertura de código con Xdebug / PCOV
php -d xdebug.mode=coverage ./vendor/bin/phpunit --coverage-text
```

Las evidencias de ejecución, cobertura, pruebas de carga con k6 (`evidencias/k6-*`), escaneo OWASP ZAP (`evidencias/reporte-zap.json`) y verificación TLS con Nmap (`evidencias/nmap-tls.txt`) se encuentran en la carpeta [`evidencias/`](evidencias/).

---

## 7. Resumen de endpoints de la API

La especificación completa en formato **OpenAPI 3.0.3** (con esquemas, límites de validación, seguridad Bearer y ejemplos para cada código de respuesta) se encuentra en [`docs/api/openapi.yaml`](docs/api/openapi.yaml).

| Método y ruta | Autenticación / Límite | Descripción | Códigos de respuesta |
| --- | --- | --- | --- |
| `GET /up` | Público | Verificación de salud (*healthcheck*) de Laravel. | `200 OK` |
| `POST /api/register` | Público · `throttle:10,1` | Registra un usuario nuevo (normalizando `email` a minúsculas), crea y devuelve un token personal Bearer válido por 24 h. | `201 Created`, `422 Unprocessable Content`, `429 Too Many Requests` |
| `POST /api/login` | Público · `throttle:10,1` | Autentica con `email` (normalizado a minúsculas) y `password`; emite un token Bearer válido por 24 h. | `200 OK`, `401 Unauthorized`, `422 Unprocessable Content`, `429 Too Many Requests` |
| `POST /api/logout` | `Bearer <token>` (`auth:sanctum`) | Revoca el token personal utilizado en la petición actual. | `204 No Content`, `401 Unauthorized` |
| `POST /api/sync` | `Bearer <token>` (`auth:sanctum`) | Sincroniza en una transacción atómica lotes de `tasks`, `sessions` (comparando `updated_at` al segundo con *Last-Write-Wins*) y `tareas_eliminadas`. | `200 OK`, `401 Unauthorized`, `422 Unprocessable Content` |

Para validar la especificación OpenAPI con Redocly CLI:

```bash
npx @redocly/cli lint docs/api/openapi.yaml
```

---

## 8. Despliegue

Los archivos de configuración y aprovisionamiento del servidor de staging/producción (Ubuntu 24.04 LTS con Nginx, PHP 8.4-FPM, SQLite en modo WAL y Cloudflare Tunnel) se encuentran en la carpeta [`deploy/`](deploy/):

- [`deploy/nginx-pomodoro.conf`](deploy/nginx-pomodoro.conf): virtual host de Nginx apuntando a `/var/www/pomodoro/backend/public`, con cabeceras de seguridad (`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`), límite de cuerpo (`client_max_body_size 2M`) y paso a `unix:/run/php/php8.4-fpm.sock`.
- [`deploy/php-fpm-pool.conf`](deploy/php-fpm-pool.conf): configuración del pool `www` de PHP 8.4-FPM (`pm = dynamic`, `pm.max_children = 20`, `pm.start_servers = 6`, `pm.min_spare_servers = 4`, `pm.max_spare_servers = 12`) dimensionada para soportar picos de sincronización concurrente.
- [`deploy/env.staging.example`](deploy/env.staging.example): plantilla de `.env` para el entorno de staging (`APP_ENV=production`, `APP_DEBUG=false`, `DB_CONNECTION=sqlite`).
- [`deploy/crontab-www-data.txt`](deploy/crontab-www-data.txt): tarea programada diaria del usuario `www-data` para respaldar en caliente la base SQLite con `sqlite3 ... ".backup ..."` y conservar 7 días de rotación en `/var/backups/pomodoro`.

---

## 9. Estructura de carpetas

```text
PomodoroApp/
├── .github/workflows/
│   └── ci.yml                  # Pipeline de CI en GitHub Actions (Flutter + Laravel/Pint)
├── android/                    # Proyecto nativo Android (permisos de alarma exacta y notificaciones)
├── assets/sounds/              # Audio de alerta al finalizar una fase (alarm.mp3)
├── backend/                    # API REST en Laravel 13 (PHP 8.4+, SQLite)
│   ├── app/
│   │   ├── Http/Controllers/   # AuthController y SyncController
│   │   ├── Models/             # User, Task, PomodoroSession y PersonalAccessToken
│   │   └── Providers/          # AppServiceProvider (guard "sanctum" con expiración de 24 h)
│   ├── config/                 # Configuración de Laravel (database.php con WAL, busy_timeout e IMMEDIATE)
│   ├── database/migrations/    # Migraciones de users, tasks, pomodoro_sessions y personal_access_tokens
│   ├── routes/api.php          # Definición de rutas /api/register, /api/login, /api/logout y /api/sync
│   └── tests/Feature/          # Pruebas funcionales y de reglas con PHPUnit 12
├── deploy/                     # Archivos de configuración de Nginx, PHP-FPM, .env de staging y respaldos
├── docs/                       # Documentación de análisis, diseño, ADR, OpenAPI, SQL y construcción
│   ├── adr/                    # Registros de decisiones de arquitectura (ADR-001 a ADR-010)
│   ├── analisis/               # Modelo de análisis, requisitos RF/RNF y trazabilidad
│   ├── api/openapi.yaml        # Especificación OpenAPI 3.0.3 de la API REST
│   ├── case/                   # Modelos en PlantUML (casos de uso, dominio, clases y secuencia)
│   ├── construccion/           # Documento de desarrollo del proyecto (Markdown y PDF)
│   ├── diseno/                 # Arquitectura 4+1, diseño de datos, interfaz y procesos
│   ├── prototipos/             # Mockup interactivo HTML de las pantallas
│   └── sql/esquema.sql         # DDL físico de SQLite (cliente y servidor)
├── evidencias/                 # Reportes y salidas de pruebas, cobertura, k6, OWASP ZAP y Nmap
├── lib/                        # Código fuente de la aplicación Flutter
│   ├── data/                   # DatabaseHelper (SQLite local con sqflite / sqflite_common_ffi)
│   ├── screens/                # Pantallas: timer, tasks, stats, graficas, settings y sync
│   ├── services/               # Servicios: ciclo_pomodoro, estadisticas, sync y notification
│   └── main.dart               # Punto de entrada y configuración de tema Material 3
├── test/                       # Pruebas unitarias y de widgets de Flutter (64 pruebas)
│   └── k6/sync-carga.js        # Script de prueba de carga sobre POST /api/sync con k6
└── pubspec.yaml                # Dependencias y versión de la aplicación Flutter (1.0.1+3)
```

---

## 10. Versión actual y enlaces del proyecto

- **Versión actual de la aplicación:** `1.0.1` (`version: 1.0.1+3` en [`pubspec.yaml`](pubspec.yaml))
- **Release actual en GitHub:** [`v1.0.1-rc.2` — Versión candidata corregida tras prueba piloto](https://github.com/GalavizMedinaAA04/PomodoroApp/releases/tag/v1.0.1-rc.2) ([todas las releases](https://github.com/GalavizMedinaAA04/PomodoroApp/releases))
- **Especificación OpenAPI 3.0.3:** [`docs/api/openapi.yaml`](docs/api/openapi.yaml)
- **Configuración de despliegue:** [`deploy/`](deploy/)
- **Documento del proyecto:** [`docs/construccion/Documento_Desarrollo_Unidad_3_Pomodoro.pdf`](docs/construccion/Documento_Desarrollo_Unidad_3_Pomodoro.pdf) y [`docs/construccion/desarrollo-unidad-3.md`](docs/construccion/desarrollo-unidad-3.md)
