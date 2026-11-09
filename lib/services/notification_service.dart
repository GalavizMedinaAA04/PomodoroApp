import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Servicio de notificaciones locales (mitigación del riesgo R-01):
/// el sistema operativo dispara el aviso aunque la app esté en segundo
/// plano o el Timer de Dart esté congelado.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const int _idFinFase = 1;
  static const String _canalId = 'pomodoro_fin_fase';

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Android, iOS y Windows están configurados. En otras plataformas el
  /// servicio no hace nada, para poder probar la app sin que crashee.
  bool get _soportado =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.windows);

  bool _inicializado = false;

  Future<void> init() async {
    if (!_soportado) {
      debugPrint('NotificationService: plataforma no soportada, se omite.');
      return;
    }
    if (_inicializado) return;
    _inicializado = true;

    // Se programa en UTC, por lo que no se requiere la zona horaria local.
    tz.initializeTimeZones();

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      windows: WindowsInitializationSettings(
        appName: 'Pomodoro',
        appUserModelId: 'ITM.Pomodoro.App',
        guid: '8f2c1e54-6b7a-4d3e-9a10-5c4b2d7e9f31',
      ),
    );
    await _plugin.initialize(settings: settings);

    // Android 13+ requiere pedir permiso en tiempo de ejecución.
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Programa la notificación de fin de fase dentro de [segundos].
  Future<void> programarFinDeFase({
    required int segundos,
    required String titulo,
    required String cuerpo,
  }) async {
    if (!_soportado) return;
    await cancelar();
    if (segundos <= 0) return;

    await _plugin.zonedSchedule(
      id: _idFinFase,
      title: titulo,
      body: cuerpo,
      scheduledDate:
          tz.TZDateTime.now(tz.UTC).add(Duration(seconds: segundos)),
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          _canalId,
          'Fin de fase Pomodoro',
          channelDescription: 'Avisa cuando termina el trabajo o descanso',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
        windows: WindowsNotificationDetails(
          audio: WindowsNotificationAudio.preset(
            sound: WindowsNotificationSound.reminder,
          ),
        ),
      ),
      // Inexacta pero sin permiso SCHEDULE_EXACT_ALARM; en modo Doze puede
      // retrasarse algunos segundos. Cambiar a exactAllowWhileIdle si se
      // agrega dicho permiso.
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelar() async {
    if (!_soportado) return;
    await _plugin.cancel(id: _idFinFase);
  }
}
