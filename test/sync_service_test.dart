import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pomodoroapp/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('iniciarSesion guarda el token de Sanctum cuando la API responde 200 (MockClient)', () async {
    final mockHttp = MockClient((request) async {
      expect(request.url.path, '/api/login');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['email'], 'lucia@itm.mx');
      return http.Response(
        jsonEncode({
          'token': 'token-sanctum-123',
          'token_type': 'Bearer',
          'user': {'id': 1, 'name': 'Lucía', 'email': 'lucia@itm.mx'},
        }),
        200,
      );
    });

    final service = SyncService(client: mockHttp);
    final resultado = await service.iniciarSesion(
      correo: 'lucia@itm.mx',
      clave: 'secreto123',
      baseUrl: 'https://api.pomodoro.test',
    );

    expect(resultado.exito, isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(SyncService.claveToken), 'token-sanctum-123');
  });

  test('iniciarSesion maneja el límite de 10 intentos por minuto (429)', () async {
    final mockHttp = MockClient((_) async => http.Response('{}', 429));
    final service = SyncService(client: mockHttp);

    final resultado = await service.iniciarSesion(
      correo: 'lucia@itm.mx',
      clave: 'mal',
    );

    expect(resultado.exito, isFalse);
    expect(resultado.mensaje, contains('429'));
  });

  test('sincronizar envía payload, recibe conteos y limpia tareas_eliminadas (Mock de API y BD)', () async {
    SharedPreferences.setMockInitialValues({
      SyncService.claveToken: 'token-activo',
      SyncService.claveUrlApi: 'https://api.pomodoro.test',
    });

    List<String>? eliminadasLimpiadas;
    Map<String, dynamic>? payloadRecibido;

    final mockHttp = MockClient((request) async {
      expect(request.url.path, '/api/sync');
      expect(request.headers['Authorization'], 'Bearer token-activo');
      payloadRecibido = jsonDecode(request.body) as Map<String, dynamic>;

      return http.Response(
        jsonEncode({
          'creados': 2,
          'actualizados': 1,
          'omitidos': 0,
          'server_time': '2026-10-20T15:04:06Z',
        }),
        200,
      );
    });

    final service = SyncService(
      client: mockHttp,
      exportarDatos: () async => {
        'tasks': [
          {
            'id': '6f1c0000-0000-4000-8000-000000000001',
            'titulo': 'Estudiar cálculo',
            'prioridad': 1,
            'completada': false,
            'pomodoros_estimados': 2,
            'updated_at': '2026-10-20T15:04:05.123Z',
          },
        ],
        'sessions': [],
        'tareas_eliminadas': ['c2d40000-0000-4000-8000-000000000009'],
      },
      limpiarEliminadas: (ids) async {
        eliminadasLimpiadas = ids;
      },
    );

    final resultado = await service.sincronizar();

    expect(resultado.exito, isTrue);
    expect(resultado.creados, 2);
    expect(resultado.actualizados, 1);
    expect(payloadRecibido!['tareas_eliminadas'], [
      'c2d40000-0000-4000-8000-000000000009',
    ]);
    expect(eliminadasLimpiadas, ['c2d40000-0000-4000-8000-000000000009']);
  });

  test('sincronizar conserva los borrados pendientes cuando la API responde 422 (tarea ajena)', () async {
    SharedPreferences.setMockInitialValues({
      SyncService.claveToken: 'token-activo',
    });

    var seLimpio = false;
    final mockHttp = MockClient(
      (_) async => http.Response(
        jsonEncode({'message': 'La tarea pertenece a otro usuario.'}),
        422,
      ),
    );

    final service = SyncService(
      client: mockHttp,
      exportarDatos: () async => {
        'tasks': [],
        'sessions': [],
        'tareas_eliminadas': ['id-pendiente'],
      },
      limpiarEliminadas: (_) async => seLimpio = true,
    );

    final resultado = await service.sincronizar();

    expect(resultado.exito, isFalse);
    expect(resultado.mensaje, contains('otro usuario'));
    expect(seLimpio, isFalse);
  });

  test('CP-CB-07 registrar guarda token con 201, maneja error 422 y cerrarSesion revoca y limpia', () async {
    // Preparar
    var codigoRegistro = 201;
    final mockHttp = MockClient((request) async {
      if (request.url.path == '/api/register') {
        if (codigoRegistro == 201) {
          return http.Response(jsonEncode({'token': 'tok-reg-1'}), 201);
        }
        return http.Response('no-json', 422);
      }
      if (request.url.path == '/api/logout') {
        return http.Response('', 204);
      }
      return http.Response('', 500);
    });
    final service = SyncService(client: mockHttp);

    // Ejecutar
    final regOk = await service.registrar(
      nombre: 'Ana',
      correo: 'ana@itm.mx',
      clave: 'secreto123',
      baseUrl: 'https://api.pomodoro.test/',
    );
    final prefs = await SharedPreferences.getInstance();
    final tokenGuardado = prefs.getString(SyncService.claveToken);

    codigoRegistro = 422;
    final regFallo = await service.registrar(
      nombre: 'Ana',
      correo: 'ana@itm.mx',
      clave: 'secreto123',
    );
    final cierre = await service.cerrarSesion();

    // Verificar
    expect(regOk.exito, isTrue);
    expect(tokenGuardado, 'tok-reg-1');
    expect(regFallo.exito, isFalse);
    expect(regFallo.mensaje, contains('422'));
    expect(cierre.exito, isTrue);
    expect(prefs.getString(SyncService.claveToken), isNull);
  });

  test('CP-CB-08 sincronizar sin token, respuesta 401 que limpia sesión y error 500 del servidor', () async {
    // Preparar
    var codigoSync = 401;
    final mockHttp = MockClient((_) async => http.Response('{}', codigoSync));
    final service = SyncService(
      client: mockHttp,
      exportarDatos: () async => {
        'tasks': [],
        'sessions': [],
        'tareas_eliminadas': [],
      },
      limpiarEliminadas: (_) async {},
    );

    // Ejecutar
    final sinToken = await service.sincronizar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(SyncService.claveToken, 'token-vencido');
    final resp401 = await service.sincronizar();
    final tokenTras401 = prefs.getString(SyncService.claveToken);

    await prefs.setString(SyncService.claveToken, 'token-activo');
    codigoSync = 500;
    final resp500 = await service.sincronizar();

    // Verificar
    expect(sinToken.exito, isFalse);
    expect(sinToken.mensaje, contains('Inicia sesión'));
    expect(resp401.exito, isFalse);
    expect(tokenTras401, isNull);
    expect(resp500.exito, isFalse);
    expect(resp500.mensaje, contains('500'));
  });
}
