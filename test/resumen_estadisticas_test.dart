import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoroapp/services/estadisticas_service.dart';

void main() {
  // 2026-10-20 (martes) y el día anterior, 2026-10-19 (lunes).
  final hoy = DateTime.utc(2026, 10, 20, 12);
  final sesiones = <Map<String, dynamic>>[
    {
      'fecha_inicio': '2026-10-20T09:00:00.000Z',
      'duracion_minutos': 25,
      'tarea_titulo': 'Cálculo',
    },
    {
      'fecha_inicio': '2026-10-19T09:00:00.000Z',
      'duracion_minutos': 25,
      'tarea_titulo': 'Cálculo',
    },
    {
      'fecha_inicio': '2026-10-19T15:00:00.000Z',
      'duracion_minutos': 50,
      'tarea_titulo': null,
    },
  ];

  test('suma minutos, cuenta sesiones de hoy y calcula la racha', () {
    final resumen = EstadisticasService.resumir(sesiones, hoy: hoy);

    expect(resumen.minutosTotales, 100);
    expect(resumen.sesionesHoy, 1);
    expect(resumen.rachaDias, 2);
  });

  test('agrupa por tarea y marca las tareas borradas', () {
    final resumen = EstadisticasService.resumir(sesiones, hoy: hoy);

    expect(resumen.minutosPorTarea['Cálculo'], 50);
    expect(resumen.minutosPorTarea['Tarea eliminada'], 50);
  });

  test('el desglose por día de una tarea suma solo esa tarea', () {
    final resumen = EstadisticasService.resumir(sesiones, hoy: hoy);
    final porDia = EstadisticasService.minutosPorDiaDe(resumen, 'Cálculo');

    expect(porDia, {'2026-10-20': 25, '2026-10-19': 25});
  });

  test('sin sesiones la racha es cero', () {
    final resumen = EstadisticasService.resumir(const [], hoy: hoy);

    expect(resumen.rachaDias, 0);
    expect(resumen.minutosTotales, 0);
  });
}
