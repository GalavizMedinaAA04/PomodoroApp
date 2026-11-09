-- DDL del servidor (SQLite, equivalente a las migraciones de Laravel).
-- Incluye la corrección de 3FN: pomodoro_sessions ya no tiene user_id.

CREATE TABLE users (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  name VARCHAR NOT NULL,
  email VARCHAR NOT NULL UNIQUE,
  email_verified_at DATETIME,
  password VARCHAR NOT NULL,
  remember_token VARCHAR,
  created_at DATETIME,
  updated_at DATETIME
);

CREATE TABLE tasks (
  id TEXT PRIMARY KEY NOT NULL,
  user_id INTEGER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  titulo VARCHAR(255) NOT NULL,
  completada BOOLEAN NOT NULL DEFAULT 0,
  pomodoros_estimados SMALLINT NOT NULL DEFAULT 1,
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NOT NULL
);
CREATE INDEX tasks_updated_at_index ON tasks (updated_at);

CREATE TABLE pomodoro_sessions (
  id TEXT PRIMARY KEY NOT NULL,
  tarea_id TEXT NOT NULL REFERENCES tasks (id) ON DELETE CASCADE,
  fecha_inicio TIMESTAMP NOT NULL,
  duracion_minutos SMALLINT NOT NULL,
  estado VARCHAR(20) NOT NULL CHECK (estado IN ('completada')),
  created_at TIMESTAMP NULL,
  updated_at TIMESTAMP NOT NULL
);
CREATE INDEX pomodoro_sessions_updated_at_index ON pomodoro_sessions (updated_at);

CREATE TABLE personal_access_tokens (
  id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
  tokenable_type VARCHAR NOT NULL,
  tokenable_id INTEGER NOT NULL,
  name TEXT NOT NULL,
  token VARCHAR(64) NOT NULL UNIQUE,
  abilities TEXT,
  last_used_at TIMESTAMP,
  expires_at TIMESTAMP,
  created_at TIMESTAMP,
  updated_at TIMESTAMP
);

-- DDL del teléfono (SQLite local, database_helper.dart, versión 2).

CREATE TABLE tareas (
  id TEXT PRIMARY KEY NOT NULL,
  titulo TEXT NOT NULL,
  completada INTEGER NOT NULL DEFAULT 0,
  pomodoros_estimados INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
) WITHOUT ROWID;

CREATE TABLE sesiones (
  id TEXT PRIMARY KEY NOT NULL,
  tarea_id TEXT NOT NULL,
  fecha_inicio TEXT NOT NULL,
  duracion_minutos INTEGER NOT NULL,
  estado TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (tarea_id) REFERENCES tareas (id) ON DELETE CASCADE
) WITHOUT ROWID;
CREATE INDEX idx_sesiones_tarea ON sesiones (tarea_id);

CREATE TABLE tareas_eliminadas (
  id TEXT PRIMARY KEY NOT NULL,
  eliminada_en TEXT NOT NULL
);
