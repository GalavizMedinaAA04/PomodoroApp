import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:pomodoroapp/data/database_helper.dart';
import 'package:pomodoroapp/main.dart' as app;
import 'package:uuid/uuid.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('CP-NF-01 fluidez de navegación', (tester) async {
    // Preparar
    DatabaseHelper.inicializarPlataforma();
    final existentes = await DatabaseHelper.instance.listarTareas();
    final pendientes =
        existentes.where((t) => (t['completada'] as int? ?? 0) == 0).toList();
    String tituloTarea;
    if (pendientes.isEmpty) {
      tituloTarea = 'Tarea fluidez CP-NF-01';
      await DatabaseHelper.instance.insertarTarea({
        'id': const Uuid().v4(),
        'titulo': tituloTarea,
        'prioridad': 2,
        'completada': 0,
        'pomodoros_estimados': 2,
      });
    } else {
      tituloTarea = pendientes.first['titulo'] as String;
    }

    await app.main();
    await tester.pumpAndSettle();

    // Seleccionar la tarea pendiente en el Dropdown para que Iniciar funcione
    final dropdown = find.byType(DropdownButtonFormField<String>);
    if (dropdown.evaluate().isNotEmpty) {
      await tester.tap(dropdown);
      await tester.pumpAndSettle();
      await tester.tap(find.text(tituloTarea).last);
      await tester.pumpAndSettle();
    }

    // Ejecutar
    await binding.traceAction(
      () async {
        for (var i = 0; i < 20; i++) {
          // 1. Tocar Tareas y volver
          await tester.tap(find.byTooltip('Tareas'));
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();

          // 2. Tocar Estadísticas y volver
          await tester.tap(find.byTooltip('Estadísticas'));
          await tester.pumpAndSettle();
          await tester.pageBack();
          await tester.pumpAndSettle();

          // 3. Iniciar y Pausar
          await tester.tap(find.byKey(const Key('btn_iniciar')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const Key('btn_pausar')));
          await tester.pumpAndSettle();
        }
      },
      reportKey: 'navegacion',
    );

    // Verificar
    expect(find.text('Pomodoro'), findsOneWidget);
    expect(find.byTooltip('Tareas'), findsOneWidget);
    expect(find.byTooltip('Estadísticas'), findsOneWidget);
  });
}
