# Documentación de diseño: Pomodoro

Esta carpeta contiene el diseño del sistema, según la rúbrica de la Unidad 2 (50 pts).

| Carpeta o archivo | Contenido | Criterio de la rúbrica |
| --- | --- | --- |
| `diseno/procesos.md` | Pseudocódigo del ciclo de fase y de la sincronización; carta de estructura | 1. Procesos y CASE |
| `diseno/arquitectura.md` | Vistas 4+1, diagrama de componentes y atributos de calidad | 2. Arquitectura |
| `adr/` | Registros de decisiones de arquitectura (ADR-001 a ADR-005) | 2. Arquitectura |
| `diseno/datos.md` | Modelo entidad-relación, normalización a 3FN y diccionario de datos | 3. Datos |
| `sql/esquema.sql` | DDL físico del servidor (con la corrección) y del teléfono | 3. Datos |
| `diseno/interfaz.md` | Prototipos de baja fidelidad, mapa de navegación y reglas de Shneiderman | 4. Interfaz |
| `analisis/modelo-de-analisis.md` | Usuario, requisitos RF y RNF, y matriz de trazabilidad | 1 y 2 (modelo de análisis) |
| `case/modelos.puml` | Casos de uso, modelo de dominio, clases del ciclo y secuencia de sincronización (PlantUML) | 1. CASE, pendiente de exportar desde una herramienta CASE |
| `prototipos/mockup-interactivo.html` | Prototipo de alta fidelidad e interactivo de las cinco pantallas | 4. Prototipado |
| `referencias.md` | Fuentes bibliográficas citadas | Fundamentación |

## Pendiente de hacer a mano

- Exportar los diagramas de `case/modelos.puml` desde Enterprise Architect, StarUML o Visual Paradigm, y guardar las imágenes en `docs/case/exportados/`. Ese paso no lo puede hacer el código.
- Ejecutar `composer require laravel/sanctum`, `php artisan migrate` y `php artisan test` en `PomodoroAPI`.
- Ejecutar `flutter pub get` y `flutter test` en `PomodoroApp`.

## Cómo correr el proyecto

Backend (carpeta `PomodoroAPI`):

```sh
composer require laravel/sanctum
php artisan migrate
php artisan test
php artisan serve
```

Si `composer require` pregunta por publicar la migración de Sanctum, responde que no: la migración `2026_10_21_000002` ya está en el proyecto.

App (carpeta `PomodoroApp`):

```sh
flutter pub get
flutter test
flutter run
```

En el emulador de Android, la API se alcanza en `http://10.0.2.2:8000/api`, que es la dirección por defecto de la pantalla de sincronización.

## Estado de verificación

El código de esta versión se escribió sin poder compilarlo ni ejecutarlo en el equipo donde se preparó. Antes de entregar, corre las pruebas listadas arriba.
