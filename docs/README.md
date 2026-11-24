# Índice de documentación (`docs/`)

Esta carpeta concentra los artefactos de análisis, diseño, arquitectura, especificación de API y construcción del proyecto **PomodoroApp**. Para las instrucciones de instalación, configuración de `.env`, ejecución local, pruebas y despliegue, consulta el [`README.md` principal del repositorio](../README.md).

## Contenido actual de `docs/`

| Carpeta o archivo | Contenido |
| --- | --- |
| [`analisis/modelo-de-analisis.md`](analisis/modelo-de-analisis.md) | Perfil de usuario, requisitos funcionales (`RF-01` a `RF-06`), requisitos no funcionales (`RNF-01` a `RNF-06`) y matriz de trazabilidad. |
| [`diseno/arquitectura.md`](diseno/arquitectura.md) | Arquitectura del sistema con vistas 4+1, diagrama de componentes y atributos de calidad. |
| [`diseno/datos.md`](diseno/datos.md) | Modelo entidad-relación, normalización a 3FN y diccionario de datos del cliente y del servidor. |
| [`diseno/interfaz.md`](diseno/interfaz.md) | Prototipos de baja fidelidad, mapa de navegación y aplicación de las reglas de oro de Shneiderman. |
| [`diseno/procesos.md`](diseno/procesos.md) | Pseudocódigo del ciclo Pomodoro y del algoritmo de sincronización *Last-Write-Wins*, más carta de estructura. |
| [`adr/`](adr/) | Registros de decisiones de arquitectura ([`ADR-001`](adr/ADR-001-offline-first.md) a [`ADR-010`](adr/ADR-010-backend-laravel.md)). |
| [`api/openapi.yaml`](api/openapi.yaml) | Especificación **OpenAPI 3.0.3** de la API REST (`/register`, `/login`, `/logout` y `/sync`) validada con Redocly CLI. |
| [`sql/esquema.sql`](sql/esquema.sql) | DDL físico de las tablas en SQLite tanto para el cliente móvil/escritorio como para el servidor Laravel. |
| [`case/modelos.puml`](case/modelos.puml) | Diagramas en PlantUML: casos de uso, modelo de dominio, diagrama de clases del ciclo y secuencia de sincronización. |
| [`prototipos/mockup-interactivo.html`](prototipos/mockup-interactivo.html) | Prototipo interactivo de alta fidelidad de las pantallas de la aplicación. |
| [`construccion/desarrollo-unidad-3.md`](construccion/desarrollo-unidad-3.md) | Documento de desarrollo y construcción del sistema en formato Markdown. |
| [`construccion/Documento_Desarrollo_Unidad_3_Pomodoro.pdf`](construccion/Documento_Desarrollo_Unidad_3_Pomodoro.pdf) | Documento formal del proyecto en formato PDF. |
| [`referencias.md`](referencias.md) | Fuentes bibliográficas y técnicas citadas en la documentación. |

## Registros de decisiones de arquitectura (`docs/adr/`)

- [`ADR-001-offline-first.md`](adr/ADR-001-offline-first.md): operación local prioritaria (*offline-first*) con SQLite en el dispositivo.
- [`ADR-002-last-write-wins.md`](adr/ADR-002-last-write-wins.md): resolución de conflictos mediante marca de tiempo `updated_at` (*Last-Write-Wins*).
- [`ADR-003-sesion-al-completar.md`](adr/ADR-003-sesion-al-completar.md): registro exclusivo de sesiones de trabajo completadas.
- [`ADR-004-aviso-del-sistema.md`](adr/ADR-004-aviso-del-sistema.md): notificaciones locales del sistema operativo al concluir cada fase.
- [`ADR-005-autenticacion-sanctum.md`](adr/ADR-005-autenticacion-sanctum.md): autenticación por tokens personales Bearer con guard propio `sanctum` y expiración de 24 horas (sin instalar el paquete externo `laravel/sanctum`).
- [`ADR-006-tombstones-tareas-eliminadas.md`](adr/ADR-006-tombstones-tareas-eliminadas.md): tabla local `tareas_eliminadas` (*tombstones*) para propagar borrados al servidor durante la sincronización.
- [`ADR-007-sincronizacion-subida.md`](adr/ADR-007-sincronizacion-subida.md): sincronización por lotes en una sola petición transaccional `POST /api/sync`.
- [`ADR-008-separar-dominio-de-widgets.md`](adr/ADR-008-separar-dominio-de-widgets.md): separación de la lógica de dominio (`CicloPomodoro`, `EstadisticasService`, `SyncService`) respecto de la capa de presentación.
- [`ADR-009-sqlite-servidor-ruta-postgresql.md`](adr/ADR-009-sqlite-servidor-ruta-postgresql.md): uso de SQLite con modo WAL en el servidor y ruta de migración futura a PostgreSQL.
- [`ADR-010-backend-laravel.md`](adr/ADR-010-backend-laravel.md): implementación del backend en Laravel 13 dentro de la carpeta `backend/`.
