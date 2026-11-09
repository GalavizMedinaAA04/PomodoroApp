# ADR-005: Autenticación con Laravel Sanctum

- **Estado:** Aceptada. Requiere instalar Sanctum con `composer require laravel/sanctum`.

## Contexto

La API debe identificar a cada usuario y a cada equipo sin enviar la contraseña en cada petición.

## Decisión

El login devuelve un token personal de Sanctum. La app guarda el token y lo envía en el encabezado `Authorization: Bearer`. Las rutas de sincronización usan el middleware `auth:sanctum`. El límite de intentos de login es de 10 por minuto.

## Consecuencias

- Cada equipo tiene su propio token y puede cerrar sesión por separado.
- El token se guarda en `SharedPreferences`, que no está cifrado. Para producción convendría `flutter_secure_storage`.
