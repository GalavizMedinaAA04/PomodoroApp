import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoroapp/services/estadisticas_service.dart';

void main() {
  // 2026-10-20 (martes) y el día anterior, 2026-10-19 (lunes), en hora local.
  final hoy = DateTime(2026, 10, 20, 12);
  final sesiones = <Map<String, dynamic>>[
    {
      'fecha_inicio': DateTime(2026, 10, 20, 9).toUtc().toIso8601String(),
      'duracion_minutos': 25,
      'tarea_titulo': 'Cálculo',
    },
    {
      'fecha_inicio': DateTime(2026, 10, 19, 9).toUtc().toIso8601String(),
      'duracion_minutos': 25,
      'tarea_titulo': 'Cálculo',
    },
    {
      'fecha_inicio': DateTime(2026, 10, 19, 15).toUtc().toIso8601String(),
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

  test('CP-CB-06 desglosePorAnioMesDia organiza año, nombre de mes y días de una tarea', () {
    // Preparar
    final resumen = EstadisticasService.resumir(sesiones, hoy: hoy);

    // Ejecutar
    final desglose = EstadisticasService.desglosePorAnioMesDia(
      resumen,
      'Cálculo',
    );

    // Verificar
    expect(desglose.keys, ['2026']);
    expect(desglose['2026']!.keys, ['Octubre']);
    expect(desglose['2026']!['Octubre'], [
      {'dia': '20', 'minutos': 25},
      {'dia': '19', 'minutos': 25},
    ]);
  });

  test(
    'CP-TD-30 sesión a las 20:14 hora local del 21/11 cuenta como de hoy, aparece en la bitácora del 21 y en la barra 21/11',
    () {
      // Preparar
      final hoyLocal = DateTime(2026, 11, 21, 23, 0);
      final sesionNocturna = <Map<String, dynamic>>[
        {
          'fecha_inicio':
              DateTime(2026, 11, 21, 20, 14).toUtc().toIso8601String(),
          'duracion_minutos': 25,
          'tarea_titulo': 'Piloto',
        },
      ];

      // Ejecutar
      final resumen = EstadisticasService.resumir(
        sesionNocturna,
        hoy: hoyLocal,
      );
      final barras = EstadisticasService.agrupar(
        sesionNocturna,
        PeriodoGrafica.dia,
        hoy: hoyLocal,
      );

      // Verificar
      expect(resumen.sesionesHoy, 1);
      expect(resumen.historialPorDia['2026-11-21']?.length, 1);
      expect(resumen.historialPorDia['2026-11-22'], isNull);
      expect(barras.last.etiqueta, '21/11');
      expect(barras.last.minutos, 25);
    },
  );

  test(
    'CP-TD-31 sesión a las 00:30 local del 22/11 cuenta para el 22 y no para el 21',
    () {
      // Preparar
      final hoyLocal = DateTime(2026, 11, 22, 10, 0);
      final sesionMadrugada = <Map<String, dynamic>>[
        {
          'fecha_inicio':
              DateTime(2026, 11, 22, 0, 30).toUtc().toIso8601String(),
          'duracion_minutos': 25,
          'tarea_titulo': 'Piloto',
        },
      ];

      // Ejecutar
      final resumen = EstadisticasService.resumir(
        sesionMadrugada,
        hoy: hoyLocal,
      );

      // Verificar
      expect(resumen.sesionesHoy, 1);
      expect(resumen.historialPorDia['2026-11-22']?.length, 1);
      expect(resumen.historialPorDia['2026-11-21'], isNull);
    },
  );

  test(
    'CP-TD-32 la racha cuenta dos días seguidos aunque las sesiones crucen la medianoche UTC',
    () {
      // Preparar
      final hoyLocal = DateTime(2026, 11, 22, 21, 0);
      final sesionesDosNoches = <Map<String, dynamic>>[
        {
          'fecha_inicio':
              DateTime(2026, 11, 22, 20, 30).toUtc().toIso8601String(),
          'duracion_minutos': 25,
          'tarea_titulo': 'Piloto',
        },
        {
          'fecha_inicio':
              DateTime(2026, 11, 21, 20, 14).toUtc().toIso8601String(),
          'duracion_minutos': 25,
          'tarea_titulo': 'Piloto',
        },
      ];

      // Ejecutar
      final resumen = EstadisticasService.resumir(
        sesionesDosNoches,
        hoy: hoyLocal,
      );

      // Verificar
      expect(resumen.rachaDias, 2);
      expect(
        resumen.historialPorDia.keys,
        containsAll(['2026-11-21', '2026-11-22']),
      );
    },
  );
}
