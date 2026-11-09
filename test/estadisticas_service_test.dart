import 'package:flutter_test/flutter_test.dart';
import 'package:pomodoroapp/services/estadisticas_service.dart';

void main() {
  // 2026-10-20 es martes; su semana empieza el lunes 2026-10-19.
  final hoy = DateTime.utc(2026, 10, 20, 12);
  final sesiones = <Map<String, dynamic>>[
    {'fecha_inicio': '2026-10-20T09:00:00.000Z', 'duracion_minutos': 25},
    {'fecha_inicio': '2026-10-20T15:00:00.000Z', 'duracion_minutos': 25},
    {'fecha_inicio': '2026-10-13T10:00:00.000Z', 'duracion_minutos': 25},
  ];

  test('por día: 14 barras y la última es hoy con 50 min', () {
    final barras = EstadisticasService.agrupar(
      sesiones,
      PeriodoGrafica.dia,
      hoy: hoy,
    );

    expect(barras.length, 14);
    expect(barras.last.etiqueta, '20/10');
    expect(barras.last.minutos, 50);
    expect(barras[6].etiqueta, '13/10');
    expect(barras[6].minutos, 25);
  });

  test('por semana: agrupa desde el lunes', () {
    final barras = EstadisticasService.agrupar(
      sesiones,
      PeriodoGrafica.semana,
      hoy: hoy,
    );

    expect(barras.length, 8);
    expect(barras.last.etiqueta, '19/10');
    expect(barras.last.minutos, 50);
    expect(barras[barras.length - 2].etiqueta, '12/10');
    expect(barras[barras.length - 2].minutos, 25);
  });

  test('por mes: 12 barras y el mes actual suma 75 min', () {
    final barras = EstadisticasService.agrupar(
      sesiones,
      PeriodoGrafica.mes,
      hoy: hoy,
    );

    expect(barras.length, 12);
    expect(barras.last.etiqueta, 'oct 26');
    expect(EstadisticasService.total(barras), 75);
  });

  test('sin sesiones todas las barras quedan en cero', () {
    final barras = EstadisticasService.agrupar(
      const [],
      PeriodoGrafica.dia,
      hoy: hoy,
    );

    expect(EstadisticasService.total(barras), 0);
  });
}
