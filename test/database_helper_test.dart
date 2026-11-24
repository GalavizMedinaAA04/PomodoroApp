import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart';
import 'package:pomodoroapp/data/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    await DatabaseHelper.instance.usarBaseEnMemoria();
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  test('inserta tarea con prioridad y pomodoros estimados y la exporta para sync', () async {
    final db = DatabaseHelper.instance;
    await db.insertarTarea({
      'id': 'tarea-1',
      'titulo': 'Preparar entrega Unidad 3',
      'prioridad': 1,
      'completada': 0,
      'pomodoros_estimados': 4,
    });

    final tareas = await db.listarTareas();
    expect(tareas.length, 1);
    expect(tareas.first['prioridad'], 1);
    expect(tareas.first['pomodoros_estimados'], 4);

    final exportado = await db.exportarParaSync();
    expect((exportado['tasks'] as List).length, 1);
  });

  test('eliminarTarea borra sus sesiones en cascada y registra el tombstone en tareas_eliminadas', () async {
    final db = DatabaseHelper.instance;
    await db.insertarTarea({
      'id': 'tarea-borrar',
      'titulo': 'Tarea temporal',
      'prioridad': 2,
      'completada': 0,
      'pomodoros_estimados': 1,
    });
    await db.insertarSesion({
      'id': 'sesion-1',
      'tarea_id': 'tarea-borrar',
      'fecha_inicio': '2026-10-20T10:00:00Z',
      'duracion_minutos': 25,
      'estado': 'completada',
    });

    await db.eliminarTarea('tarea-borrar');

    expect(await db.listarTareas(), isEmpty);
    expect(await db.listarSesiones(), isEmpty);

    final exportado = await db.exportarParaSync();
    expect(exportado['tareas_eliminadas'], ['tarea-borrar']);

    await db.limpiarEliminadas(['tarea-borrar']);
    final exportadoLimpio = await db.exportarParaSync();
    expect(exportadoLimpio['tareas_eliminadas'], isEmpty);
  });

  test('las restricciones CHECK rechazan prioridad fuera de 1..3 o estado inválido', () async {
    final db = DatabaseHelper.instance;

    expect(
      () => db.insertarTarea({
        'id': 'invalida',
        'titulo': 'Prioridad fuera de rango',
        'prioridad': 9,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test(
    'CP-CB-03 actualizarTarea, actualizarSesion, listarSesionesCompletadasConTitulo y exportarParaSync con sesiones',
    () async {
      // Preparar
      final db = DatabaseHelper();
      await db.insertarTarea({
        'id': 'tarea-cb3',
        'titulo': 'Tarea inicial',
        'prioridad': 2,
        'completada': 0,
        'pomodoros_estimados': 2,
      });
      await db.insertarSesion({
        'id': 'sesion-cb3',
        'tarea_id': 'tarea-cb3',
        'fecha_inicio': '2026-10-20T09:00:00Z',
        'duracion_minutos': 25,
        'estado': 'completada',
      });

      // Ejecutar
      final filasTarea = await db.actualizarTarea({
        'id': 'tarea-cb3',
        'titulo': 'Tarea actualizada',
        'completada': 1,
      });
      final filasSesion = await db.actualizarSesion({
        'id': 'sesion-cb3',
        'duracion_minutos': 30,
      });
      final conTitulo = await db.listarSesionesCompletadasConTitulo();
      final exportado = await db.exportarParaSync();

      // Verificar
      expect(filasTarea, 1);
      expect(filasSesion, 1);
      expect(conTitulo.single['tarea_titulo'], 'Tarea actualizada');
      expect(conTitulo.single['duracion_minutos'], 30);
      expect((exportado['sessions'] as List).single['duracion_minutos'], 30);
    },
  );

  test(
    'CP-CB-04 inicializarPlataforma, _initDatabase y migración _onUpgrade de v2 a v3',
    () async {
      // Preparar
      DatabaseHelper.inicializarPlataforma();
      await DatabaseHelper.instance.close();
      final ruta = join(await getDatabasesPath(), 'pomodoro.db');
      await deleteDatabase(ruta);
      final dbV2 = await openDatabase(
        ruta,
        version: 2,
        onCreate: (db, _) async {
          await db.execute('''
            CREATE TABLE tareas (
              id TEXT PRIMARY KEY,
              titulo TEXT,
              completada INTEGER,
              pomodoros_estimados INTEGER,
              updated_at TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE sesiones (
              id TEXT PRIMARY KEY,
              tarea_id TEXT,
              fecha_inicio TEXT,
              duracion_minutos INTEGER,
              estado TEXT,
              updated_at TEXT
            )
          ''');
          await db.insert('tareas', {
            'id': 't-legacy',
            'titulo': '   ',
            'completada': 9,
            'pomodoros_estimados': 99,
            'updated_at': '2026-10-19T10:00:00Z',
          });
          await db.insert('sesiones', {
            'id': 's-legacy',
            'tarea_id': 't-legacy',
            'fecha_inicio': '2026-10-19T10:00:00Z',
            'duracion_minutos': 200,
            'estado': 'completada',
            'updated_at': '2026-10-19T10:25:00Z',
          });
        },
      );
      await dbV2.close();

      // Ejecutar
      final tareasMigradas = await DatabaseHelper.instance.listarTareas();
      final sesionesMigradas = await DatabaseHelper.instance.listarSesiones();

      // Verificar
      expect(tareasMigradas.single['titulo'], 'Tarea');
      expect(tareasMigradas.single['completada'], 0);
      expect(tareasMigradas.single['prioridad'], 2);
      expect(tareasMigradas.single['pomodoros_estimados'], 20);
      expect(sesionesMigradas.single['duracion_minutos'], 120);

      await DatabaseHelper.instance.close();
      await deleteDatabase(ruta);
    },
  );
}
