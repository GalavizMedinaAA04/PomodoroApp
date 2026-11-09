import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';
import '../services/ciclo_pomodoro.dart';
import '../services/notification_service.dart';
import 'graficas_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'sync_screen.dart';
import 'tasks_screen.dart';

class _AlternarRelojIntent extends Intent {
  const _AlternarRelojIntent();
}

class _CancelarFaseIntent extends Intent {
  const _CancelarFaseIntent();
}

/// Pantalla del temporizador. La lógica de fases vive en CicloPomodoro.
class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  final CicloPomodoro _ciclo = CicloPomodoro();

  /// Tareas pendientes disponibles en el Dropdown y la elegida.
  List<Map<String, dynamic>> _tareas = [];
  String? _tareaSeleccionadaId;

  /// Dispara la actualización de la pantalla cada segundo mientras corre el reloj.
  Timer? _timer;

  /// Reproductor del beep de fin de fase.
  final AudioPlayer _audioPlayer = AudioPlayer();

  bool get _corriendo => _ciclo.corriendo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.init();
    _cargarTiempos();
    _cargarTareas();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El Timer pudo congelarse en segundo plano: se recalcula con el reloj real.
    if (state == AppLifecycleState.resumed && _corriendo) _sincronizar();
  }

  /// Carga las tareas pendientes para el Dropdown.
  Future<void> _cargarTareas() async {
    final todas = await DatabaseHelper.instance.listarTareas();
    final pendientes = todas.where((t) => t['completada'] == 0).toList();
    if (!mounted) return;
    setState(() {
      _tareas = pendientes;
      if (!pendientes.any((t) => t['id'] == _tareaSeleccionadaId)) {
        _tareaSeleccionadaId = null;
      }
    });
  }

  Future<void> _abrirTareas() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const TasksScreen()),
    );
    await _cargarTareas();
  }

  /// Lee los minutos y ciclos guardados (o usa 25/5/15 y 4 por defecto).
  Future<void> _cargarTiempos() async {
    final prefs = await SharedPreferences.getInstance();
    final trabajo = prefs.getInt(SettingsScreen.claveTrabajo) ?? 25;
    final descanso = prefs.getInt(SettingsScreen.claveDescanso) ?? 5;
    final descansoLargo =
        prefs.getInt(SettingsScreen.claveDescansoLargo) ?? 15;
    final ciclos = prefs.getInt(SettingsScreen.claveCiclos) ?? 4;
    if (!mounted) return;
    setState(() {
      _ciclo.aplicarTiempos(trabajo, descanso, descansoLargo, ciclos);
    });
  }

  /// Si se guardaron cambios en Configuración, aplica los tiempos sin romper
  /// una fase en curso (CA-03.2).
  Future<void> _abrirConfiguracion() async {
    final guardado = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (guardado == true) {
      await _cargarTiempos();
    }
  }

  // ------------------------------------------------------------ Controles
  void _iniciar() {
    if (_corriendo) return;
    final iniciado = _ciclo.iniciar(
      tareaId: _tareaSeleccionadaId,
      ahora: DateTime.now(),
    );
    if (!iniciado) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona una tarea antes de iniciar')),
      );
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _sincronizar());
    _programarNotificacion();
    setState(() {});
  }

  /// Actualiza el tiempo restante con el reloj real y detecta el fin de fase.
  void _sincronizar() {
    if (_ciclo.sincronizar(DateTime.now())) {
      _finalizarFase();
    } else {
      setState(() {});
    }
  }

  /// Programa el aviso del sistema para cuando termine la fase actual.
  void _programarNotificacion() {
    final esTrabajo = _ciclo.fase == FasePomodoro.trabajo;
    NotificationService.instance.programarFinDeFase(
      segundos: _ciclo.segundosRestantes,
      titulo: 'Tiempo terminado',
      cuerpo: esTrabajo
          ? 'Completaste un Pomodoro. Descansa ${_ciclo.minutosDescanso} minutos.'
          : 'El descanso terminó. ¡A concentrarse!',
    );
  }

  void _pausar() {
    if (!_corriendo) return;
    _timer?.cancel();
    _ciclo.pausar(DateTime.now());
    NotificationService.instance.cancelar();
    setState(() {});
  }

  Future<void> _confirmarYCancelar() async {
    if (_ciclo.haySesionEnCurso) {
      final descartar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancelar pomodoro'),
          content: const Text(
            '¿Descartar este pomodoro? No se guardará en el historial.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Descartar'),
            ),
          ],
        ),
      );
      if (descartar != true) return;
    }
    _cancelar();
  }

  void _cancelar() {
    _timer?.cancel();
    NotificationService.instance.cancelar();
    _ciclo.cancelar();
    setState(() {});
  }

  /// Reproduce el beep de alerta; un fallo de audio nunca debe romper el flujo.
  Future<void> _reproducirBeep() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/beep.wav'));
    } catch (e) {
      debugPrint('No se pudo reproducir el beep: $e');
    }
  }

  void _finalizarFase() {
    _timer?.cancel();
    _reproducirBeep();

    final sesion = _ciclo.finalizarFase();
    if (sesion != null) _guardarSesion(sesion);
    setState(() {});

    if (!mounted) return;
    final descanso = _ciclo.fase == FasePomodoro.descanso;
    final textoDescanso = _ciclo.esDescansoLargo
        ? '¡Pomodoro completado! Toma un descanso largo de ${_ciclo.minutosDescansoLargo} minutos.'
        : '¡Pomodoro completado! Toma un descanso de ${_ciclo.minutosDescanso} minutos.';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          descanso ? textoDescanso : 'Descanso terminado. ¡A trabajar!',
        ),
      ),
    );
  }

  /// Guarda la sesión de trabajo completada en SQLite.
  Future<void> _guardarSesion(SesionCompletada sesion) async {
    try {
      await DatabaseHelper.instance.insertarSesion({
        'id': const Uuid().v4(),
        'tarea_id': sesion.tareaId,
        'fecha_inicio': sesion.inicio.toUtc().toIso8601String(),
        'duracion_minutos': sesion.minutos,
        'estado': 'completada',
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión guardada en el historial')),
        );
      }
    } catch (e) {
      debugPrint('No se pudo guardar la sesión: $e');
    }
  }

  // ------------------------------------------------------------------- UI
  String get _tiempoFormateado {
    final segundos = _ciclo.segundosRestantes;
    final m = (segundos ~/ 60).toString().padLeft(2, '0');
    final s = (segundos % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _abrir(Widget pantalla) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final esTrabajo = _ciclo.fase == FasePomodoro.trabajo;
    final colorFase = esTrabajo ? scheme.primary : scheme.tertiary;
    final etiquetaFase = esTrabajo
        ? 'Trabajo'
        : (_ciclo.esDescansoLargo ? 'Descanso largo' : 'Descanso');

    return Shortcuts(
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.space): _AlternarRelojIntent(),
        SingleActivator(LogicalKeyboardKey.escape): _CancelarFaseIntent(),
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          _AlternarRelojIntent: CallbackAction<_AlternarRelojIntent>(
            onInvoke: (_) {
              if (_corriendo) {
                _pausar();
              } else {
                _iniciar();
              }
              return null;
            },
          ),
          _CancelarFaseIntent: CallbackAction<_CancelarFaseIntent>(
            onInvoke: (_) {
              _confirmarYCancelar();
              return null;
            },
          ),
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Pomodoro'),
            centerTitle: true,
            actions: [
              IconButton(
                icon: const Icon(Icons.checklist),
                tooltip: 'Tareas',
                onPressed: _abrirTareas,
              ),
              IconButton(
                icon: const Icon(Icons.bar_chart),
                tooltip: 'Estadísticas',
                onPressed: () => _abrir(const StatsScreen()),
              ),
              IconButton(
                icon: const Icon(Icons.show_chart),
                tooltip: 'Gráficas',
                onPressed: () => _abrir(const GraficasScreen()),
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                tooltip: 'Configuración',
                onPressed: _abrirConfiguracion,
              ),
              IconButton(
                icon: const Icon(Icons.cloud_upload_outlined),
                tooltip: 'Sincronización',
                onPressed: () => _abrir(const SyncScreen()),
              ),
            ],
          ),
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'dd_${_tareaSeleccionadaId}_${_tareas.length}',
                    ),
                    initialValue: _tareaSeleccionadaId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Tarea en la que trabajarás',
                      border: OutlineInputBorder(),
                    ),
                    hint: Text(
                      _tareas.isEmpty
                          ? 'Crea una tarea en el menú Tareas'
                          : 'Selecciona una tarea',
                    ),
                    items: [
                      for (final t in _tareas)
                        DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(
                            t['titulo'] as String,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    // Bloqueado mientras el reloj corre o hay una sesión a medias.
                    onChanged: (_corriendo || _ciclo.haySesionEnCurso)
                        ? null
                        : (v) => setState(() => _tareaSeleccionadaId = v),
                  ),
                  const SizedBox(height: 24),
                  Chip(
                    label: Text(etiquetaFase),
                    avatar: Icon(
                      esTrabajo ? Icons.work : Icons.coffee,
                      color: colorFase,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      _tiempoFormateado,
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            fontSize: 96,
                            fontWeight: FontWeight.bold,
                            color: colorFase,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _ciclo.progreso,
                    minHeight: 8,
                    color: colorFase,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 48),
                  _BotonGrande(
                    key: const Key('btn_iniciar'),
                    label: 'Iniciar',
                    icon: Icons.play_arrow,
                    onPressed: _corriendo ? null : _iniciar,
                  ),
                  const SizedBox(height: 12),
                  _BotonGrande(
                    key: const Key('btn_pausar'),
                    label: 'Pausar',
                    icon: Icons.pause,
                    tonal: true,
                    onPressed: _corriendo ? _pausar : null,
                  ),
                  const SizedBox(height: 12),
                  _BotonGrande(
                    key: const Key('btn_cancelar'),
                    label: 'Cancelar',
                    icon: Icons.stop,
                    outlined: true,
                    onPressed: _confirmarYCancelar,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonGrande extends StatelessWidget {
  const _BotonGrande({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.tonal = false,
    this.outlined = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool tonal;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final style = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(64)),
      textStyle: WidgetStatePropertyAll(Theme.of(context).textTheme.titleLarge),
    );
    final child = Text(label);
    final iconW = Icon(icon, size: 28);

    if (outlined) {
      return OutlinedButton.icon(
        onPressed: onPressed,
        icon: iconW,
        label: child,
        style: style,
      );
    }
    if (tonal) {
      return FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: iconW,
        label: child,
        style: style,
      );
    }
    return FilledButton.icon(
      onPressed: onPressed,
      icon: iconW,
      label: child,
      style: style,
    );
  }
}
