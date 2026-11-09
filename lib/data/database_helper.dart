import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

// Import condicional: en web se usa el stub para que dart:ffi no se compile.
import 'sqlite_init_web.dart'
    if (dart.library.io) 'sqlite_init_io.dart';

/// Almacenamiento local (SQLite) – patrón Singleton.
class DatabaseHelper {
  static const String _dbName = 'pomodoro.db';
  static const int _dbVersion = 3;

  static const String tablaTareas = 'tareas';
  static const String tablaSesiones = 'sesiones';
  static const String tablaEliminadas = 'tareas_eliminadas';

  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();
  factory DatabaseHelper() => instance;

  static Database? _database;

  /// SQLite solo está disponible fuera de la web.
  static bool get soportado => !kIsWeb;

  /// Llamar una vez en `main()` antes de usar la base de datos.
  static void inicializarPlataforma() => inicializarSqlitePlataforma();

  Future<Database> get database async {
    if (!soportado) {
      throw UnsupportedError('SQLite no soportado en Web');
    }
    return _database ??= await _initDatabase();
  }

  /// Permite usar una base en memoria durante las pruebas unitarias.
  @visibleForTesting
  Future<void> usarBaseEnMemoria() async {
    await close();
    _database = await openDatabase(
      inMemoryDatabasePath,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<Database> _initDatabase() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onOpen: (db) async {
        // Mantiene el archivo compacto (objetivo < 50MB).
        await db.rawQuery('PRAGMA auto_vacuum = INCREMENTAL');
        await db.rawQuery('PRAGMA journal_mode = WAL');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _crearEsquemaV3(db);
  }

  Future<void> _crearEsquemaV3(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE $tablaEliminadas (
        id TEXT PRIMARY KEY NOT NULL,
        eliminada_en TEXT NOT NULL
      )
    ''');

    // WITHOUT ROWID: con PK TEXT evita el índice rowid duplicado -> menos peso.
    await db.execute('''
      CREATE TABLE $tablaTareas (
        id TEXT PRIMARY KEY NOT NULL,
        titulo TEXT NOT NULL CHECK (length(titulo) BETWEEN 1 AND 120),
        completada INTEGER NOT NULL DEFAULT 0 CHECK (completada IN (0, 1)),
        prioridad INTEGER NOT NULL DEFAULT 2 CHECK (prioridad BETWEEN 1 AND 3),
        pomodoros_estimados INTEGER NOT NULL DEFAULT 1
          CHECK (pomodoros_estimados BETWEEN 1 AND 20),
        updated_at TEXT NOT NULL
      ) WITHOUT ROWID
    ''');

    await db.execute('''
      CREATE TABLE $tablaSesiones (
        id TEXT PRIMARY KEY NOT NULL,
        tarea_id TEXT NOT NULL,
        fecha_inicio TEXT NOT NULL,
        duracion_minutos INTEGER NOT NULL CHECK (duracion_minutos BETWEEN 1 AND 120),
        estado TEXT NOT NULL CHECK (estado IN ('completada')),
        updated_at TEXT NOT NULL,
        FOREIGN KEY (tarea_id) REFERENCES $tablaTareas (id) ON DELETE CASCADE
      ) WITHOUT ROWID
    ''');

    await db.execute(
      'CREATE INDEX idx_sesiones_tarea ON $tablaSesiones (tarea_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 3) {
      await db.execute('PRAGMA foreign_keys = OFF');
      await db.transaction((txn) async {
        await txn.execute(
          'ALTER TABLE $tablaTareas RENAME TO ${tablaTareas}_old',
        );
        await txn.execute(
          'ALTER TABLE $tablaSesiones RENAME TO ${tablaSesiones}_old',
        );
        await txn.execute('DROP INDEX IF EXISTS idx_sesiones_tarea');

        await _crearEsquemaV3(txn);

        await txn.execute('''
          INSERT INTO $tablaTareas (
            id, titulo, completada, prioridad, pomodoros_estimados, updated_at
          )
          SELECT
            id,
            CASE
              WHEN length(trim(titulo)) = 0 THEN 'Tarea'
              ELSE substr(trim(titulo), 1, 120)
            END,
            CASE WHEN completada IN (0, 1) THEN completada ELSE 0 END,
            2,
            CASE
              WHEN pomodoros_estimados < 1 THEN 1
              WHEN pomodoros_estimados > 20 THEN 20
              ELSE pomodoros_estimados
            END,
            updated_at
          FROM ${tablaTareas}_old
        ''');

        await txn.execute('''
          INSERT INTO $tablaSesiones (
            id, tarea_id, fecha_inicio, duracion_minutos, estado, updated_at
          )
          SELECT
            id,
            tarea_id,
            fecha_inicio,
            CASE
              WHEN duracion_minutos < 1 THEN 1
              WHEN duracion_minutos > 120 THEN 120
              ELSE duracion_minutos
            END,
            'completada',
            updated_at
          FROM ${tablaSesiones}_old
          WHERE estado = 'completada'
            AND tarea_id IN (SELECT id FROM $tablaTareas)
        ''');

        await txn.execute('DROP TABLE ${tablaSesiones}_old');
        await txn.execute('DROP TABLE ${tablaTareas}_old');
      });
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  String _now() => DateTime.now().toUtc().toIso8601String();

  // ---------------------------------------------------------------- TAREAS
  Future<int> insertarTarea(Map<String, dynamic> tarea) async {
    if (!soportado) return 0;
    final db = await database;
    return db.insert(
      tablaTareas,
      {
        'prioridad': 2,
        'completada': 0,
        'pomodoros_estimados': 1,
        ...tarea,
        'updated_at': tarea['updated_at'] ?? _now(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> listarTareas() async {
    if (!soportado) return [];
    final db = await database;
    return db.query(tablaTareas, orderBy: 'updated_at DESC');
  }

  Future<int> actualizarTarea(Map<String, dynamic> tarea) async {
    if (!soportado) return 0;
    final db = await database;
    return db.update(
      tablaTareas,
      {...tarea, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [tarea['id']],
    );
  }

  /// Elimina la tarea (y sus sesiones en cascada) y registra su id en
  /// `tareas_eliminadas` dentro de la misma transacción (ADR-006).
  Future<int> eliminarTarea(String id) async {
    if (!soportado) return 0;
    final db = await database;
    return db.transaction((txn) async {
      final borradas = await txn.delete(
        tablaTareas,
        where: 'id = ?',
        whereArgs: [id],
      );
      await txn.insert(
        tablaEliminadas,
        {'id': id, 'eliminada_en': _now()},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      return borradas;
    });
  }

  // -------------------------------------------------------------- SESIONES
  Future<int> insertarSesion(Map<String, dynamic> sesion) async {
    if (!soportado) return 0;
    final db = await database;
    return db.insert(
      tablaSesiones,
      {...sesion, 'updated_at': sesion['updated_at'] ?? _now()},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> listarSesiones() async {
    if (!soportado) return [];
    final db = await database;
    return db.query(tablaSesiones, orderBy: 'fecha_inicio DESC');
  }

  Future<int> actualizarSesion(Map<String, dynamic> sesion) async {
    if (!soportado) return 0;
    final db = await database;
    return db.update(
      tablaSesiones,
      {...sesion, 'updated_at': _now()},
      where: 'id = ?',
      whereArgs: [sesion['id']],
    );
  }

  /// Sesiones completadas con el título de su tarea, para estadísticas.
  Future<List<Map<String, dynamic>>> listarSesionesCompletadasConTitulo() async {
    if (!soportado) return [];
    final db = await database;
    return db.rawQuery('''
      SELECT s.*, t.titulo AS tarea_titulo
      FROM $tablaSesiones s
      LEFT JOIN $tablaTareas t ON s.tarea_id = t.id
      WHERE s.estado = 'completada'
      ORDER BY s.fecha_inicio DESC
    ''');
  }

  // -------------------------------------------------------- SINCRONIZACIÓN
  /// Exporta las tareas, sesiones y los ids de tareas eliminadas pendientes.
  Future<Map<String, dynamic>> exportarParaSync() async {
    if (!soportado) {
      return {
        'tasks': <Map<String, dynamic>>[],
        'sessions': <Map<String, dynamic>>[],
        'tareas_eliminadas': <String>[],
      };
    }
    final db = await database;
    final tareas = await db.query(tablaTareas);
    final sesiones = await db.query(tablaSesiones);
    final eliminadas = await db.query(tablaEliminadas);

    return {
      'tasks': [
        for (final t in tareas)
          {
            'id': t['id'],
            'titulo': t['titulo'],
            'prioridad': t['prioridad'] ?? 2,
            'completada': (t['completada'] as int? ?? 0) == 1,
            'pomodoros_estimados': t['pomodoros_estimados'] ?? 1,
            'updated_at': t['updated_at'],
          },
      ],
      'sessions': [
        for (final s in sesiones)
          {
            'id': s['id'],
            'tarea_id': s['tarea_id'],
            'fecha_inicio': s['fecha_inicio'],
            'duracion_minutos': s['duracion_minutos'],
            'estado': s['estado'],
            'updated_at': s['updated_at'],
          },
      ],
      'tareas_eliminadas': [
        for (final e in eliminadas) e['id'] as String,
      ],
    };
  }

  /// Limpia de `tareas_eliminadas` los identificadores ya sincronizados.
  Future<void> limpiarEliminadas(List<String> ids) async {
    if (!soportado || ids.isEmpty) return;
    final db = await database;
    final placeholders = List.filled(ids.length, '?').join(', ');
    await db.delete(
      tablaEliminadas,
      where: 'id IN ($placeholders)',
      whereArgs: ids,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
