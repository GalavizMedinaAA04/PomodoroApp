import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:pomodoroapp/data/database_helper.dart';
import 'package:pomodoroapp/main.dart';
import 'package:pomodoroapp/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

const String _stagingUrl =
    'https://faster-endangered-cells-cubic.trycloudflare.com';
const String _e2eEmail = 'e2e@pomodoro.test';
const String _e2ePassword = String.fromEnvironment('E2E_PASSWORD');

Future<void> _limpiarEstadoLocal() async {
  DatabaseHelper.inicializarPlataforma();
  await DatabaseHelper.instance.close();
  final dbPath = p.join(await getDatabasesPath(), 'pomodoro.db');
  await deleteDatabase(dbPath);
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
}

Future<void> _ocultarTeclado(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    await tester.pump();
    if (tester.view.viewInsets.bottom == 0) break;
  }
  await tester.pumpAndSettle();
}

Future<void> _arrancarApp(WidgetTester tester) async {
  DatabaseHelper.inicializarPlataforma();
  await NotificationService.instance.init();
  await tester.pumpWidget(const PomodoroApp());
  await tester.pumpAndSettle();
}

Future<void> _crearTareaPorInterfaz(
  WidgetTester tester,
  String titulo,
) async {
  await tester.tap(find.byTooltip('Tareas'));
  await tester.pumpAndSettle();

  await tester.tap(find.byTooltip('Nueva tarea'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextField, 'Título'),
    titulo,
  );
  await _ocultarTeclado(tester);

  await tester.tap(find.text('Guardar'));
  await tester.pumpAndSettle();

  await tester.pageBack();
  await tester.pumpAndSettle();
}

Future<void> _configurarTrabajoEnUnMinuto(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Configuración'));
  await tester.pumpAndSettle();

  await tester.enterText(
    find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
    '1',
  );
  await _ocultarTeclado(tester);

  final btnGuardar = find.text('Guardar');
  await tester.ensureVisible(btnGuardar);
  await tester.pumpAndSettle();
  await tester.tap(btnGuardar);
  await tester.pumpAndSettle();

  await tester.tap(find.text('Continuar de todos modos'));
  await tester.pumpAndSettle();
}

Future<void> _seleccionarTareaEnTemporizador(
  WidgetTester tester,
  String titulo,
) async {
  await tester.tap(find.byType(DropdownButtonFormField<String>));
  await tester.pumpAndSettle();

  await tester.tap(find.text(titulo).last);
  await tester.pumpAndSettle();
}

Future<void> _esperarSegundosReales(
  WidgetTester tester,
  int segundos,
) async {
  for (var i = 0; i < segundos; i++) {
    await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _esperarHastaQueAparezca(
  WidgetTester tester,
  Finder finder, {
  int maxIntentos = 60,
}) async {
  for (var i = 0; i < maxIntentos; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump();
    if (finder.evaluate().isNotEmpty) {
      break;
    }
  }
  await tester.pumpAndSettle();
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await _limpiarEstadoLocal();
  });

  tearDown(() async {
    await NotificationService.instance.cancelar();
    await DatabaseHelper.instance.close();
  });

  testWidgets(
    'CP-CU-01a sin tareas pulsar Iniciar muestra Selecciona una tarea antes de iniciar y el reloj no arranca',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      expect(find.text('25:00'), findsOneWidget);

      // Ejecutar
      await tester.tap(find.text('Iniciar'));
      await tester.pump();

      // Verificar
      expect(
        find.text('Selecciona una tarea antes de iniciar'),
        findsOneWidget,
      );
      await _esperarSegundosReales(tester, 2);
      expect(find.text('25:00'), findsOneWidget);
      final botonPausar = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Pausar'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(botonPausar.onPressed, isNull);
    },
  );

  testWidgets(
    'CP-CU-01b completar pomodoro de 1 min guarda la sesión en el historial e inicia el descanso',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      await _crearTareaPorInterfaz(tester, 'Tarea E2E 01b');
      await _configurarTrabajoEnUnMinuto(tester);
      expect(find.text('01:00'), findsOneWidget);
      await _seleccionarTareaEnTemporizador(tester, 'Tarea E2E 01b');

      // Ejecutar
      await tester.tap(find.text('Iniciar'));
      await tester.pump();

      bool vioAvisoHistorial = false;
      for (var i = 0; i < 65; i++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        await tester.pump();
        if (find.text('Sesión guardada en el historial').evaluate().isNotEmpty) {
          vioAvisoHistorial = true;
        }
      }
      await tester.pumpAndSettle();

      // Verificar
      expect(vioAvisoHistorial, isTrue);
      expect(find.text('Descanso'), findsOneWidget);
      expect(find.text('05:00'), findsOneWidget);
      final sesiones = await DatabaseHelper.instance.listarSesiones();
      expect(sesiones.length, 1);
      expect(sesiones.first['duracion_minutos'], 1);
      expect(sesiones.first['estado'], 'completada');
    },
  );

  testWidgets(
    'CP-CU-02 iniciar pausar cancelar y descartar reinicia el reloj y deja 0 sesiones hoy en Estadísticas',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      await _crearTareaPorInterfaz(tester, 'Tarea E2E 02');
      await _seleccionarTareaEnTemporizador(tester, 'Tarea E2E 02');

      // Ejecutar
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      await _esperarSegundosReales(tester, 2);

      await tester.tap(find.text('Pausar'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // Verificar diálogo Cancelar pomodoro
      expect(find.text('Cancelar pomodoro'), findsOneWidget);
      expect(
        find.text('¿Descartar este pomodoro? No se guardará en el historial.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.text('25:00'), findsOneWidget);

      await tester.tap(find.byTooltip('Estadísticas'));
      await tester.pumpAndSettle();

      expect(find.text('Estadísticas Detalladas'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('0'), findsNWidgets(3));
      expect(
        find.text('No registraste actividad en esta fecha.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'CP-CU-03 crear editar completar y borrar una tarea con confirmación actualiza la lista',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      await tester.tap(find.byTooltip('Tareas'));
      await tester.pumpAndSettle();
      expect(find.text('No hay tareas. Agrega una con +'), findsOneWidget);

      // Ejecutar y Verificar 1: Crear tarea
      await tester.tap(find.byTooltip('Nueva tarea'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Tarea Inicial CU03',
      );
      await _ocultarTeclado(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Tarea Inicial CU03'), findsOneWidget);

      // Ejecutar y Verificar 2: Editar tarea
      await tester.tap(find.text('Tarea Inicial CU03'));
      await tester.pumpAndSettle();
      expect(find.text('Editar tarea'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Título'),
        'Tarea Editada CU03',
      );
      await _ocultarTeclado(tester);
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
      expect(find.text('Tarea Editada CU03'), findsOneWidget);
      expect(find.text('Tarea Inicial CU03'), findsNothing);

      // Ejecutar y Verificar 3: Completar tarea
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);

      // Ejecutar y Verificar 4: Borrar tarea con confirmación
      await tester.tap(find.byTooltip('Eliminar'));
      await tester.pumpAndSettle();
      expect(find.text('Eliminar tarea'), findsOneWidget);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      expect(find.text('Tarea Editada CU03'), findsNothing);
      expect(find.text('No hay tareas. Agrega una con +'), findsOneWidget);
    },
  );

  testWidgets(
    'CP-CU-04 completar un pomodoro de 1 min y abrir Estadísticas muestra Hoy 1 sesión y 1 min',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      await _crearTareaPorInterfaz(tester, 'Tarea E2E 04');
      await _configurarTrabajoEnUnMinuto(tester);
      await _seleccionarTareaEnTemporizador(tester, 'Tarea E2E 04');

      // Ejecutar
      await tester.tap(find.text('Iniciar'));
      await tester.pump();
      await _esperarSegundosReales(tester, 65);

      await tester.tap(find.byTooltip('Estadísticas'));
      await tester.pumpAndSettle();

      // Verificar
      expect(find.text('Estadísticas Detalladas'), findsOneWidget);
      expect(find.text('Hoy'), findsOneWidget);
      expect(find.text('Minutos'), findsOneWidget);
      expect(find.text('Total del día: 1 min'), findsOneWidget);
      expect(find.text('1 min'), findsWidgets);
      expect(find.text('Tarea E2E 04'), findsWidgets);
    },
  );

  testWidgets(
    'CP-CU-05 escribir 70 en trabajo y Guardar muestra diálogo Fuera del rango recomendado con tres opciones',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      await tester.tap(find.byTooltip('Configuración'));
      await tester.pumpAndSettle();

      // Ejecutar
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Minutos de Trabajo'),
        '70',
      );
      await _ocultarTeclado(tester);
      final btnGuardar = find.text('Guardar');
      await tester.ensureVisible(btnGuardar);
      await tester.pumpAndSettle();
      await tester.tap(btnGuardar);
      await tester.pumpAndSettle();

      // Verificar
      expect(find.text('Fuera del rango recomendado'), findsOneWidget);
      expect(
        find.textContaining('Trabajo: 70 min (recomendado de 15 a 60)'),
        findsOneWidget,
      );
      expect(find.text('Cancelar'), findsOneWidget);
      expect(find.text('Usar rango recomendado'), findsOneWidget);
      expect(find.text('Continuar de todos modos'), findsOneWidget);
    },
  );

  testWidgets(
    'CP-CU-06 con una tarea local iniciar sesión en staging y Sincronizar ahora reporta al menos 1 creado',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      final sufijo = DateTime.now().millisecondsSinceEpoch;
      await _crearTareaPorInterfaz(tester, 'Tarea Sync E2E $sufijo');

      await tester.tap(find.byTooltip('Sincronización'));
      await tester.pumpAndSettle();

      // Ejecutar
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Dirección de la API (HTTPS)'),
        _stagingUrl,
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Correo electrónico'),
        _e2eEmail,
      );
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Contraseña (mínimo 8 caracteres)',
        ),
        _e2ePassword,
      );
      await _ocultarTeclado(tester);

      final btnLogin = find.widgetWithText(FilledButton, 'Iniciar sesión');
      await tester.ensureVisible(btnLogin);
      await tester.pumpAndSettle();
      await tester.tap(btnLogin);
      await tester.pump();

      await _esperarHastaQueAparezca(tester, find.text('Sincronizar ahora'));
      expect(find.text('Sincronizar ahora'), findsOneWidget);

      final btnSync = find.text('Sincronizar ahora');
      await tester.ensureVisible(btnSync);
      await tester.pumpAndSettle();
      await tester.tap(btnSync);
      await tester.pump();

      await _esperarHastaQueAparezca(
        tester,
        find.textContaining('Sincronizado:'),
      );

      // Verificar
      final patron = RegExp(
        r'^Sincronizado: (\d+) creados, (\d+) actualizados y (\d+) omitidos\.$',
      );
      String? mensajeEncontrado;
      for (final elemento in find.byType(Text).evaluate()) {
        final widgetTexto = elemento.widget as Text;
        final data = widgetTexto.data;
        if (data != null && patron.hasMatch(data)) {
          mensajeEncontrado = data;
          break;
        }
      }
      expect(
        mensajeEncontrado,
        isNotNull,
        reason: 'Se esperaba mensaje de sincronización exitosa.',
      );
      final match = patron.firstMatch(mensajeEncontrado!)!;
      final creados = int.parse(match.group(1)!);
      expect(creados, greaterThanOrEqualTo(1));
    },
  );

  testWidgets(
    'CP-CU-08 con una tarea elegida Espacio inicia Espacio pausa y Esc abre el diálogo de cancelación',
    (tester) async {
      // Preparar
      await _arrancarApp(tester);
      await _crearTareaPorInterfaz(tester, 'Tarea E2E 08');
      await _seleccionarTareaEnTemporizador(tester, 'Tarea E2E 08');

      // Asegurar que un FocusNode enfocable descendiente de Shortcuts en TimerScreen tenga el foco primario
      final Element elementoBoton = tester.element(find.text('Cancelar'));
      Focus.of(elementoBoton).requestFocus();
      await tester.pumpAndSettle();

      // Ejecutar 1: Espacio para iniciar
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();

      final pausarActivo = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Pausar'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(pausarActivo.onPressed, isNotNull);

      // Ejecutar 2: Espacio para pausar
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      final iniciarActivo = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Iniciar'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(iniciarActivo.onPressed, isNotNull);

      // Ejecutar 3: Esc para abrir el diálogo de cancelación
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      // Verificar
      expect(find.text('Cancelar pomodoro'), findsOneWidget);
      expect(
        find.text('¿Descartar este pomodoro? No se guardará en el historial.'),
        findsOneWidget,
      );
    },
  );
}
