import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';

import '../data/database_helper.dart';

/// CRUD de tareas con título (1-120 caracteres), prioridad y estimación (RF-04).
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final _db = DatabaseHelper.instance;
  List<Map<String, dynamic>> _tareas = [];
  bool _cargando = true;

  static const Map<int, String> _etiquetasPrioridad = {
    1: 'Alta',
    2: 'Media',
    3: 'Baja',
  };

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final tareas = await _db.listarTareas();
    if (!mounted) return;
    setState(() {
      _tareas = tareas;
      _cargando = false;
    });
  }

  Future<void> _editar([Map<String, dynamic>? tarea]) async {
    final tituloCtrl = TextEditingController(
      text: tarea?['titulo'] as String? ?? '',
    );
    final estimadosCtrl = TextEditingController(
      text: (tarea?['pomodoros_estimados'] as int? ?? 1).toString(),
    );
    var prioridad = tarea?['prioridad'] as int? ?? 2;
    String? errorTitulo;
    String? errorEstimados;

    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          void ajustarEstimados(int delta) {
            final actual = int.tryParse(estimadosCtrl.text.trim()) ?? 1;
            final nuevo = (actual + delta).clamp(1, 20);
            setModalState(() {
              estimadosCtrl.text = nuevo.toString();
              errorEstimados = null;
            });
          }

          void intentarGuardar() {
            final titulo = tituloCtrl.text.trim();
            final estimados = int.tryParse(estimadosCtrl.text.trim());
            setModalState(() {
              errorTitulo = titulo.isEmpty
                  ? 'El título no puede quedar vacío'
                  : (titulo.length > 120
                      ? 'Máximo 120 caracteres'
                      : null);
              errorEstimados = (estimados == null ||
                      estimados < 1 ||
                      estimados > 20)
                  ? 'Debe ser entre 1 y 20'
                  : null;
            });
            if (errorTitulo != null || errorEstimados != null) return;

            Navigator.pop(ctx, {
              'titulo': titulo,
              'prioridad': prioridad,
              'pomodoros_estimados': estimados!,
            });
          }

          return AlertDialog(
            title: Text(tarea == null ? 'Nueva tarea' : 'Editar tarea'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: tituloCtrl,
                    autofocus: true,
                    maxLength: 120,
                    decoration: InputDecoration(
                      labelText: 'Título',
                      errorText: errorTitulo,
                    ),
                    onChanged: (_) {
                      if (errorTitulo != null) {
                        setModalState(() => errorTitulo = null);
                      }
                    },
                    onSubmitted: (_) => intentarGuardar(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    initialValue: prioridad,
                    decoration: const InputDecoration(
                      labelText: 'Prioridad',
                      border: OutlineInputBorder(),
                    ),
                    items: _etiquetasPrioridad.entries
                        .map(
                          (e) => DropdownMenuItem<int>(
                            value: e.key,
                            child: Text(e.value),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setModalState(() => prioridad = v);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        tooltip: 'Disminuir',
                        onPressed: () => ajustarEstimados(-1),
                      ),
                      Expanded(
                        child: TextField(
                          controller: estimadosCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: InputDecoration(
                            labelText: 'Pomodoros estimados',
                            errorText: errorEstimados,
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        tooltip: 'Aumentar',
                        onPressed: () => ajustarEstimados(1),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: intentarGuardar,
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );

    if (resultado == null) return;

    if (tarea == null) {
      await _db.insertarTarea({
        'id': const Uuid().v4(),
        'titulo': resultado['titulo'],
        'prioridad': resultado['prioridad'],
        'completada': 0,
        'pomodoros_estimados': resultado['pomodoros_estimados'],
      });
    } else {
      await _db.actualizarTarea({
        'id': tarea['id'],
        'titulo': resultado['titulo'],
        'prioridad': resultado['prioridad'],
        'pomodoros_estimados': resultado['pomodoros_estimados'],
      });
    }
    await _cargar();
  }

  Future<void> _alternar(Map<String, dynamic> tarea, bool? valor) async {
    await _db.actualizarTarea({
      'id': tarea['id'],
      'completada': (valor ?? false) ? 1 : 0,
    });
    await _cargar();
  }

  Future<void> _eliminar(Map<String, dynamic> tarea) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar tarea'),
        content: Text(
          '¿Eliminar "${tarea['titulo']}"? También se borrarán sus sesiones.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _db.eliminarTarea(tarea['id'] as String);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tareas'), centerTitle: true),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _editar(),
        tooltip: 'Nueva tarea',
        child: const Icon(Icons.add),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _tareas.isEmpty
              ? const Center(child: Text('No hay tareas. Agrega una con +'))
              : ListView.builder(
                  itemCount: _tareas.length,
                  itemBuilder: (_, i) {
                    final t = _tareas[i];
                    final hecha = (t['completada'] as int? ?? 0) == 1;
                    final prio = t['prioridad'] as int? ?? 2;
                    final estimados = t['pomodoros_estimados'] as int? ?? 1;
                    final etiquetaPrio = _etiquetasPrioridad[prio] ?? 'Media';

                    return ListTile(
                      leading: Checkbox(
                        value: hecha,
                        onChanged: (v) => _alternar(t, v),
                      ),
                      title: Text(
                        t['titulo'] as String,
                        style: hecha
                            ? const TextStyle(
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                      subtitle: Text(
                        'Prioridad: $etiquetaPrio · Estimación: $estimados pomodoro${estimados == 1 ? '' : 's'}',
                      ),
                      onTap: () => _editar(t),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: 'Eliminar',
                        onPressed: () => _eliminar(t),
                      ),
                    );
                  },
                ),
    );
  }
}
