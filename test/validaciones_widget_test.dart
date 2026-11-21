import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoroapp/data/database_helper.dart';
import 'package:pomodoroapp/screens/settings_screen.dart';
import 'package:pomodoroapp/screens/tasks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await DatabaseHelper.instance.usarBaseEnMemoria();
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
  });

  Future<void> abrirNuevaTarea(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: TasksScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Nueva tarea'));
    await tester.pumpAndSettle();
  }

  Future<void> abrirConfiguracion(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SettingsScreen(),
                  ),
                );
              },
              child: const Text('Abrir configuración'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir configuración'));
    await tester.pumpAndSettle();
  }

  testWidgets('CP-VL-01a título vacío', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), '');

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('El título no puede quedar vacío'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });

  testWidgets('CP-VL-01b título de tres espacios', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), '   ');

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('El título no puede quedar vacío'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
    expect(await DatabaseHelper.instance.listarTareas(), isEmpty);
  });

  testWidgets('CP-VL-01c título "a" (1 carácter)', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Título'), 'a');

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Nueva tarea'), findsNothing);
    expect(find.text('a'), findsOneWidget);
  });

  testWidgets('CP-VL-01d título de 120 caracteres', (tester) async {
    // Preparar
    final titulo120 = 'a' * 120;
    await abrirNuevaTarea(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      titulo120,
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Nueva tarea'), findsNothing);
    expect(find.text(titulo120), findsOneWidget);
  });

  testWidgets('CP-VL-01e escribir 121 caracteres', (tester) async {
    // Preparar
    final titulo121 = 'a' * 121;
    await abrirNuevaTarea(tester);
    final campoTitulo = find.widgetWithText(TextField, 'Título');

    // Ejecutar
    await tester.enterText(campoTitulo, titulo121);
    await tester.pumpAndSettle();

    // Verificar
    final textField = tester.widget<TextField>(campoTitulo);
    expect(textField.controller!.text.length, 120);
  });

  testWidgets('CP-VL-02a pomodoros 0', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Tarea de prueba',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Pomodoros estimados'),
      '0',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 1 y 20'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });

  testWidgets('CP-VL-02b pomodoros 1', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Tarea 1 pomo',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Pomodoros estimados'),
      '1',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Nueva tarea'), findsNothing);
    expect(find.text('Tarea 1 pomo'), findsOneWidget);
    final tareas = await DatabaseHelper.instance.listarTareas();
    expect(tareas.single['pomodoros_estimados'], 1);
  });

  testWidgets('CP-VL-02c pomodoros 20', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Tarea 20 pomos',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Pomodoros estimados'),
      '20',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Nueva tarea'), findsNothing);
    expect(find.text('Tarea 20 pomos'), findsOneWidget);
    final tareas = await DatabaseHelper.instance.listarTareas();
    expect(tareas.single['pomodoros_estimados'], 20);
  });

  testWidgets('CP-VL-02d pomodoros 21', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Título'),
      'Tarea 21 pomos',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Pomodoros estimados'),
      '21',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 1 y 20'), findsOneWidget);
    expect(find.text('Nueva tarea'), findsOneWidget);
  });

  testWidgets('CP-VL-02e pulsar "Disminuir" con valor 1', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    final campoEstimados = find.widgetWithText(
      TextField,
      'Pomodoros estimados',
    );
    await tester.enterText(campoEstimados, '1');

    // Ejecutar
    await tester.tap(find.byTooltip('Disminuir'));
    await tester.pumpAndSettle();

    // Verificar
    final textField = tester.widget<TextField>(campoEstimados);
    expect(textField.controller!.text, '1');
  });

  testWidgets('CP-VL-02f pulsar "Aumentar" con valor 20', (tester) async {
    // Preparar
    await abrirNuevaTarea(tester);
    final campoEstimados = find.widgetWithText(
      TextField,
      'Pomodoros estimados',
    );
    await tester.enterText(campoEstimados, '20');

    // Ejecutar
    await tester.tap(find.byTooltip('Aumentar'));
    await tester.pumpAndSettle();

    // Verificar
    final textField = tester.widget<TextField>(campoEstimados);
    expect(textField.controller!.text, '20');
  });

  testWidgets('CP-VL-03a minutos de trabajo vacío', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Requerido'), findsOneWidget);
  });

  testWidgets('CP-VL-03b minutos de trabajo 0', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '0',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 1 y 120 min'), findsOneWidget);
  });

  testWidgets('CP-VL-03c minutos de trabajo 121', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '121',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 1 y 120 min'), findsOneWidget);
  });

  testWidgets('CP-VL-03d minutos de trabajo 1', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '1',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 1 y 120 min'), findsNothing);
    expect(find.text('Fuera del rango recomendado'), findsOneWidget);
  });

  testWidgets('CP-VL-03e minutos de trabajo 120', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '120',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 1 y 120 min'), findsNothing);
    expect(find.text('Fuera del rango recomendado'), findsOneWidget);
  });

  testWidgets('CP-VL-04a ciclos 1', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciclos antes del descanso largo'),
      '1',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 2 y 8'), findsOneWidget);
  });

  testWidgets('CP-VL-04b ciclos 2', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciclos antes del descanso largo'),
      '2',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SettingsScreen.claveCiclos), 2);
    expect(find.text('Configuración de Tiempos'), findsNothing);
  });

  testWidgets('CP-VL-04c ciclos 8', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciclos antes del descanso largo'),
      '8',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SettingsScreen.claveCiclos), 8);
    expect(find.text('Configuración de Tiempos'), findsNothing);
  });

  testWidgets('CP-VL-04d ciclos 9', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Ciclos antes del descanso largo'),
      '9',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Debe ser entre 2 y 8'), findsOneWidget);
  });

  testWidgets('CP-VL-05a trabajo 14', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '14',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Fuera del rango recomendado'), findsOneWidget);
  });

  testWidgets('CP-VL-05b trabajo 15', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '15',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Fuera del rango recomendado'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SettingsScreen.claveTrabajo), 15);
    expect(find.text('Configuración de Tiempos'), findsNothing);
  });

  testWidgets('CP-VL-05c trabajo 60', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '60',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Fuera del rango recomendado'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt(SettingsScreen.claveTrabajo), 60);
    expect(find.text('Configuración de Tiempos'), findsNothing);
  });

  testWidgets('CP-VL-05d trabajo 61', (tester) async {
    // Preparar
    await abrirConfiguracion(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
      '61',
    );

    // Ejecutar
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    // Verificar
    expect(find.text('Fuera del rango recomendado'), findsOneWidget);
  });
}
