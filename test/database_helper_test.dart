import 'package:flutter_test/flutter_test.dart';
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
}
