import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../services/estadisticas_service.dart';

/// Totales, Top de tareas y bitácora diaria. Los cálculos viven en EstadisticasService.
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  bool _cargando = true;
  ResumenEstadisticas? _resumen;

  DateTime _fechaSeleccionada = DateTime.now().toUtc();

  /// Si es false, solo se muestra el Top 5 de tareas.
  bool _verTodasTareas = false;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    try {
      final sesiones =
          await DatabaseHelper.instance.listarSesionesCompletadasConTitulo();
      if (!mounted) return;
      setState(() {
        _resumen = EstadisticasService.resumir(sesiones);
        _cargando = false;
      });
    } catch (e) {
      debugPrint('Error cargando estadísticas: $e');
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarDetalleTarea(String nombreTarea) {
    final scheme = Theme.of(context).colorScheme;
    final datosAgrupados =
        EstadisticasService.desglosePorAnioMesDia(_resumen!, nombreTarea);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          nombreTarea,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: datosAgrupados.isEmpty
            ? const Text('No hay datos.')
            : SizedBox(
                width: double.maxFinite,
                child: ListView(
                  shrinkWrap: true,
                  children: datosAgrupados.entries.map((entryAnio) {
                    return ExpansionTile(
                      initiallyExpanded: true,
                      title: Text(
                        'Año ${entryAnio.key}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                      children: entryAnio.value.entries.map((entryMes) {
                        return ExpansionTile(
                          initiallyExpanded: true,
                          title: Text(
                            entryMes.key,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          children: entryMes.value.map((datoDia) {
                            return ListTile(
                              contentPadding: const EdgeInsets.only(
                                left: 32,
                                right: 16,
                              ),
                              leading: Icon(
                                Icons.calendar_today,
                                size: 18,
                                color: scheme.outline,
                              ),
                              title: Text('Día ${datoDia['dia']}'),
                              trailing: Text(
                                '${datoDia['minutos']} min',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          }).toList(),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha() async {
    final seleccion = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada.toLocal(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Selecciona una fecha',
    );
    if (seleccion != null) {
      setState(() {
        _fechaSeleccionada =
            DateTime.utc(seleccion.year, seleccion.month, seleccion.day);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resumen = _resumen;
    final fechaStr = _fechaSeleccionada.toIso8601String().substring(0, 10);
    final sesionesDelDia = resumen?.historialPorDia[fechaStr] ?? [];
    final minsDelDia = sesionesDelDia.fold<int>(
      0,
      (suma, sesion) => suma + (sesion['duracion_minutos'] as int? ?? 0),
    );

    final tareasOrdenadas = (resumen?.minutosPorTarea.entries.toList() ?? [])
      ..sort((a, b) => b.value.compareTo(a.value));
    final tareasAMostrar =
        _verTodasTareas ? tareasOrdenadas : tareasOrdenadas.take(5).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Estadísticas Detalladas'),
        centerTitle: true,
      ),
      body: _cargando || resumen == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MiniCard(
                        titulo: 'Hoy',
                        valor: '${resumen.sesionesHoy}',
                        icono: Icons.today,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniCard(
                        titulo: 'Minutos',
                        valor: '${resumen.minutosTotales}',
                        icono: Icons.timer,
                        color: scheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniCard(
                        titulo: 'Racha',
                        valor: '${resumen.rachaDias}',
                        icono: Icons.local_fire_department,
                        color: scheme.tertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Text(
                  _verTodasTareas
                      ? 'Todas las tareas (Ordenadas)'
                      : 'Top 5 Tareas más productivas',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (tareasOrdenadas.isEmpty)
                  Text(
                    'Aún no hay tareas completadas.',
                    style: TextStyle(color: scheme.outline),
                  ),
                ...tareasAMostrar.map(
                  (entry) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.check_circle_outline,
                      color: scheme.secondary,
                    ),
                    title: Text(entry.key),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${entry.value} min',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(Icons.chevron_right, color: scheme.outline),
                      ],
                    ),
                    onTap: () => _mostrarDetalleTarea(entry.key),
                  ),
                ),
                if (tareasOrdenadas.length > 5) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _verTodasTareas = !_verTodasTareas),
                      icon: Icon(
                        _verTodasTareas
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      label: Text(
                        _verTodasTareas
                            ? 'Mostrar solo el Top 5'
                            : 'Ver todas las tareas (${tareasOrdenadas.length})',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Bitácora diaria',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: _seleccionarFecha,
                      icon: const Icon(Icons.calendar_month),
                      label: Text(fechaStr),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (sesionesDelDia.isEmpty)
                  Text(
                    'No registraste actividad en esta fecha.',
                    style: TextStyle(color: scheme.outline),
                  )
                else
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(
                              'Total del día: $minsDelDia min',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          const Divider(),
                          ...sesionesDelDia.map(
                            (sesion) => ListTile(
                              leading: const Icon(Icons.history),
                              title: Text(
                                sesion['tarea_titulo'] as String? ??
                                    'Tarea eliminada',
                              ),
                              trailing: Text(
                                '${sesion['duracion_minutos']} min',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({
    required this.titulo,
    required this.valor,
    required this.icono,
    required this.color,
  });

  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Column(
          children: [
            Icon(icono, color: color, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                valor,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
              ),
            ),
            Text(
              titulo,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
