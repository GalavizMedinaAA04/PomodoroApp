# Pomodoro API — Backend Laravel

API REST para respaldo y sincronización *offline-first* de la aplicación Pomodoro.

## Requisitos

- PHP 8.3 o superior
- Composer
- Extensión `pdo_sqlite` habilitada

## Instalación y ejecución local

```bash
composer install
cp .env.example .env
php artisan key:generate
touch database/database.sqlite
php artisan migrate
php artisan serve
```

## Endpoints principales

- `POST /api/register` — Registro de usuario y emisión de token personal (Sanctum, vigencia de 24 h).
- `POST /api/login` — Inicio de sesión con límite de 10 intentos por minuto (`throttle:10,1`).
- `POST /api/logout` — Revocación del token actual (`auth:sanctum`).
- `POST /api/sync` — Sincronización transaccional por lotes (`tasks`, `sessions`, `tareas_eliminadas`) bajo regla *last-write-wins*.

## Verificación y pruebas

```bash
./vendor/bin/pint --test
php artisan test
```
