import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database_helper.dart';

/// Resultado de una operación de sincronización con el servidor.
class ResultadoSync {
  const ResultadoSync({
    required this.exito,
    required this.mensaje,
    this.creados = 0,
    this.actualizados = 0,
    this.omitidos = 0,
    this.serverTime,
  });

  final bool exito;
  final String mensaje;
  final int creados;
  final int actualizados;
  final int omitidos;
  final String? serverTime;
}

/// Servicio de autenticación (Sanctum) y sincronización con la API Laravel.
///
/// Permite inyectar [http.Client] y funciones de acceso a datos para aislar
/// dependencias externas mediante mocking en pruebas unitarias.
class SyncService {
  SyncService({
    http.Client? client,
    Future<Map<String, dynamic>> Function()? exportarDatos,
    Future<void> Function(List<String> ids)? limpiarEliminadas,
  })  : _client = client ?? http.Client(),
        _exportarDatos =
            exportarDatos ?? DatabaseHelper.instance.exportarParaSync,
        _limpiarEliminadas =
            limpiarEliminadas ?? DatabaseHelper.instance.limpiarEliminadas;

  static const String claveToken = 'api_auth_token';
  static const String claveUrlApi = 'api_base_url';
  static const String claveCorreo = 'api_user_email';
  static const String urlPorDefecto = 'https://127.0.0.1:8000';

  final http.Client _client;
  final Future<Map<String, dynamic>> Function() _exportarDatos;
  final Future<void> Function(List<String> ids) _limpiarEliminadas;

  Map<String, String> _headers([String? token]) => {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  String _normalizarUrl(String baseUrl) {
    final limpia = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    return limpia.isEmpty ? urlPorDefecto : limpia;
  }

  /// Registra una cuenta nueva en `POST /api/register` y guarda el token.
  Future<ResultadoSync> registrar({
    required String nombre,
    required String correo,
    required String clave,
    String? confirmacion,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final url = _normalizarUrl(
      baseUrl ?? prefs.getString(claveUrlApi) ?? urlPorDefecto,
    );
    try {
      final respuesta = await _client.post(
        Uri.parse('$url/api/register'),
        headers: _headers(),
        body: jsonEncode({
          'name': nombre.trim(),
          'email': correo.trim(),
          'password': clave,
          'password_confirmation': confirmacion ?? clave,
          'device_name': 'flutter_app',
        }),
      );

      if (respuesta.statusCode == 201 || respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
        final token = datos['token'] as String? ?? '';
        await prefs.setString(claveToken, token);
        await prefs.setString(claveUrlApi, url);
        await prefs.setString(claveCorreo, correo.trim());
        return const ResultadoSync(
          exito: true,
          mensaje: 'Cuenta creada y sesión iniciada.',
        );
      }
      return ResultadoSync(
        exito: false,
        mensaje: _mensajeDeError(respuesta),
      );
    } catch (_) {
      return const ResultadoSync(
        exito: false,
        mensaje: 'Sin conexión con el servidor.',
      );
    }
  }

  /// Inicia sesión en `POST /api/login` y guarda el token de Sanctum.
  Future<ResultadoSync> iniciarSesion({
    required String correo,
    required String clave,
    String? baseUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final url = _normalizarUrl(
      baseUrl ?? prefs.getString(claveUrlApi) ?? urlPorDefecto,
    );
    try {
      final respuesta = await _client.post(
        Uri.parse('$url/api/login'),
        headers: _headers(),
        body: jsonEncode({
          'email': correo.trim(),
          'password': clave,
          'device_name': 'flutter_app',
        }),
      );

      if (respuesta.statusCode == 200) {
        final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
        final token = datos['token'] as String? ?? '';
        await prefs.setString(claveToken, token);
        await prefs.setString(claveUrlApi, url);
        await prefs.setString(claveCorreo, correo.trim());
        return const ResultadoSync(
          exito: true,
          mensaje: 'Sesión iniciada correctamente.',
        );
      }
      return ResultadoSync(
        exito: false,
        mensaje: _mensajeDeError(respuesta),
      );
    } catch (_) {
      return const ResultadoSync(
        exito: false,
        mensaje: 'Sin conexión con el servidor.',
      );
    }
  }

  /// Revoca el token actual en `POST /api/logout` y limpia la sesión local.
  Future<ResultadoSync> cerrarSesion({String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(claveToken);
    final url = _normalizarUrl(
      baseUrl ?? prefs.getString(claveUrlApi) ?? urlPorDefecto,
    );
    try {
      if (token != null && token.isNotEmpty) {
        await _client.post(
          Uri.parse('$url/api/logout'),
          headers: _headers(token),
        );
      }
    } catch (_) {
      // Aunque no haya red, se limpia el token local.
    } finally {
      await prefs.remove(claveToken);
      await prefs.remove(claveCorreo);
    }
    return const ResultadoSync(
      exito: true,
      mensaje: 'Sesión cerrada.',
    );
  }

  /// Exporta tareas, sesiones y borrados pendientes y los envía a `POST /api/sync`.
  Future<ResultadoSync> sincronizar({String? baseUrl}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(claveToken);
    if (token == null || token.isEmpty) {
      return const ResultadoSync(
        exito: false,
        mensaje: 'Inicia sesión antes de sincronizar.',
      );
    }

    final url = _normalizarUrl(
      baseUrl ?? prefs.getString(claveUrlApi) ?? urlPorDefecto,
    );
    final payload = await _exportarDatos();
    final eliminadas = List<String>.from(
      payload['tareas_eliminadas'] as List? ?? const <String>[],
    );

    try {
      final respuesta = await _client.post(
        Uri.parse('$url/api/sync'),
        headers: _headers(token),
        body: jsonEncode(payload),
      );

      if (respuesta.statusCode == 200) {
        await _limpiarEliminadas(eliminadas);
        final datos = jsonDecode(respuesta.body) as Map<String, dynamic>;
        final creados = datos['creados'] as int? ?? 0;
        final actualizados = datos['actualizados'] as int? ?? 0;
        final omitidos = datos['omitidos'] as int? ?? 0;
        final serverTime = datos['server_time'] as String?;

        return ResultadoSync(
          exito: true,
          creados: creados,
          actualizados: actualizados,
          omitidos: omitidos,
          serverTime: serverTime,
          mensaje:
              'Sincronizado: $creados creados, $actualizados actualizados y $omitidos omitidos.',
        );
      }

      if (respuesta.statusCode == 401) {
        await prefs.remove(claveToken);
      }

      return ResultadoSync(
        exito: false,
        mensaje: _mensajeDeError(respuesta),
      );
    } catch (_) {
      return const ResultadoSync(
        exito: false,
        mensaje: 'Sin conexión con el servidor. Tus datos siguen guardados localmente.',
      );
    }
  }

  String _mensajeDeError(http.Response respuesta) {
    if (respuesta.statusCode == 401) {
      return 'Credenciales inválidas o sesión vencida.';
    }
    if (respuesta.statusCode == 429) {
      return 'Demasiados intentos (429). Espera un minuto.';
    }
    if (respuesta.statusCode == 422) {
      try {
        final body = jsonDecode(respuesta.body) as Map<String, dynamic>;
        if (body['message'] is String) return body['message'] as String;
      } catch (_) {}
      return 'Datos rechazados por validación o tarea ajena (422).';
    }
    return 'Error del servidor (${respuesta.statusCode}).';
  }
}
