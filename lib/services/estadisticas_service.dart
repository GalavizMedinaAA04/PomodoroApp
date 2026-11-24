/// Periodo de agrupación de la gráfica de minutos trabajados.
enum PeriodoGrafica { dia, semana, mes }

/// Una barra de la gráfica: etiqueta del eje X y minutos trabajados.
class BarraGrafica {
  const BarraGrafica(this.etiqueta, this.minutos);

  final String etiqueta;
  final int minutos;
}

/// Agrupa las sesiones completadas por día, semana o mes, en hora local.
class EstadisticasService {
  EstadisticasService._();

  static const int diasMostrados = 14;
  static const int semanasMostradas = 8;
  static const int mesesMostrados = 12;

  static const List<String> _meses = [
    'ene', 'feb', 'mar', 'abr', 'may', 'jun',
    'jul', 'ago', 'sep', 'oct', 'nov', 'dic',
  ];

  static const List<String> nombresMesesCompletos = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre',
  ];

  /// Devuelve una barra por cada periodo, del más antiguo al más reciente.
  static List<BarraGrafica> agrupar(
    List<Map<String, dynamic>> sesiones,
    PeriodoGrafica periodo, {
    DateTime? hoy,
  }) {
    final inicios = _inicios(periodo, (hoy ?? DateTime.now()).toLocal());
    final minutos = {for (final inicio in inicios) inicio: 0};

    for (final sesion in sesiones) {
      final fecha = DateTime.parse(sesion['fecha_inicio'] as String).toLocal();
      final clave = _inicioDe(fecha, periodo);
      if (minutos.containsKey(clave)) {
        minutos[clave] =
            minutos[clave]! + (sesion['duracion_minutos'] as int? ?? 0);
      }
    }

    return [
      for (final inicio in inicios)
        BarraGrafica(_etiqueta(inicio, periodo), minutos[inicio]!),
    ];
  }

  static int total(List<BarraGrafica> barras) =>
      barras.fold(0, (suma, barra) => suma + barra.minutos);

  /// Primer instante (00:00 local) de cada periodo mostrado.
  static List<DateTime> _inicios(PeriodoGrafica periodo, DateTime ahora) {
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final lunes = _inicioDe(hoy, PeriodoGrafica.semana);
    return switch (periodo) {
      PeriodoGrafica.dia => [
          for (var i = diasMostrados - 1; i >= 0; i--)
            DateTime(hoy.year, hoy.month, hoy.day - i),
        ],
      PeriodoGrafica.semana => [
          for (var i = semanasMostradas - 1; i >= 0; i--)
            DateTime(lunes.year, lunes.month, lunes.day - 7 * i),
        ],
      PeriodoGrafica.mes => [
          for (var i = mesesMostrados - 1; i >= 0; i--)
            DateTime(ahora.year, ahora.month - i, 1),
        ],
    };
  }

  /// Inicio del periodo al que pertenece una fecha local: día, lunes de la semana o día 1.
  static DateTime _inicioDe(DateTime fecha, PeriodoGrafica periodo) {
    final local = fecha.toLocal();
    final dia = DateTime(local.year, local.month, local.day);
    return switch (periodo) {
      PeriodoGrafica.dia => dia,
      PeriodoGrafica.semana =>
        DateTime(dia.year, dia.month, dia.day - (dia.weekday - 1)),
      PeriodoGrafica.mes => DateTime(local.year, local.month, 1),
    };
  }

  static String _etiqueta(DateTime inicio, PeriodoGrafica periodo) {
    if (periodo == PeriodoGrafica.mes) {
      return '${_meses[inicio.month - 1]} ${inicio.year % 100}';
    }
    return '${_dosDigitos(inicio.day)}/${_dosDigitos(inicio.month)}';
  }

  static String _dosDigitos(int numero) => numero.toString().padLeft(2, '0');

  /// Calcula totales, racha, Top de tareas y bitácora a partir de las sesiones
  /// completadas (con `tarea_titulo`), agrupando por fecha local.
  static ResumenEstadisticas resumir(
    List<Map<String, dynamic>> sesiones, {
    DateTime? hoy,
  }) {
    final ahora = (hoy ?? DateTime.now()).toLocal();
    final fechaHoy = _claveDia(ahora);

    var minutos = 0;
    var sesionesHoy = 0;
    final minutosPorTarea = <String, int>{};
    final historialPorDia = <String, List<Map<String, dynamic>>>{};

    for (final sesion in sesiones) {
      final duracion = sesion['duracion_minutos'] as int? ?? 0;
      final fechaLocal =
          DateTime.parse(sesion['fecha_inicio'] as String).toLocal();
      final dia = _claveDia(fechaLocal);
      final titulo = _tituloDe(sesion);

      minutos += duracion;
      if (dia == fechaHoy) sesionesHoy++;
      minutosPorTarea[titulo] = (minutosPorTarea[titulo] ?? 0) + duracion;
      historialPorDia.putIfAbsent(dia, () => []).add(sesion);
    }

    return ResumenEstadisticas(
      minutosTotales: minutos,
      rachaDias: _racha(historialPorDia.keys.toSet(), ahora),
      sesionesHoy: sesionesHoy,
      minutosPorTarea: minutosPorTarea,
      historialPorDia: historialPorDia,
    );
  }

  /// Minutos por día que se trabajaron en una tarea, para su detalle.
  static Map<String, int> minutosPorDiaDe(
    ResumenEstadisticas resumen,
    String tarea,
  ) {
    final minutosPorDia = <String, int>{};
    resumen.historialPorDia.forEach((dia, sesiones) {
      for (final sesion in sesiones) {
        if (_tituloDe(sesion) == tarea) {
          minutosPorDia[dia] = (minutosPorDia[dia] ?? 0) +
              (sesion['duracion_minutos'] as int? ?? 0);
        }
      }
    });
    return minutosPorDia;
  }

  /// Arma la jerarquía Año -> Mes -> Lista de días con minutos para una tarea.
  static Map<String, Map<String, List<Map<String, dynamic>>>>
      desglosePorAnioMesDia(ResumenEstadisticas resumen, String tarea) {
    final minutosPorDia = minutosPorDiaDe(resumen, tarea);
    final datosAgrupados = <String, Map<String, List<Map<String, dynamic>>>>{};

    minutosPorDia.forEach((fecha, minutos) {
      final anio = fecha.substring(0, 4);
      final nombreMes =
          nombresMesesCompletos[int.parse(fecha.substring(5, 7)) - 1];
      final dia = fecha.substring(8, 10);

      datosAgrupados.putIfAbsent(anio, () => {});
      datosAgrupados[anio]!.putIfAbsent(nombreMes, () => []);
      datosAgrupados[anio]![nombreMes]!.add({'dia': dia, 'minutos': minutos});
    });

    return datosAgrupados;
  }

  /// Días consecutivos con sesiones, contando hacia atrás desde hoy local.
  /// Si hoy no hay sesiones, la racha empieza ayer.
  static int _racha(Set<String> diasTrabajados, DateTime ahora) {
    final local = ahora.toLocal();
    var fecha = DateTime(local.year, local.month, local.day);
    if (!diasTrabajados.contains(_claveDia(fecha))) {
      fecha = DateTime(fecha.year, fecha.month, fecha.day - 1);
    }

    var racha = 0;
    while (diasTrabajados.contains(_claveDia(fecha))) {
      racha++;
      fecha = DateTime(fecha.year, fecha.month, fecha.day - 1);
    }
    return racha;
  }

  static String _claveDia(DateTime fecha) {
    final local = fecha.toLocal();
    return '${local.year.toString().padLeft(4, '0')}-${_dosDigitos(local.month)}-${_dosDigitos(local.day)}';
  }

  static String _tituloDe(Map<String, dynamic> sesion) =>
      sesion['tarea_titulo'] as String? ?? 'Tarea eliminada';
}

/// Resultado de [EstadisticasService.resumir]: lo que muestra la pantalla de estadísticas.
class ResumenEstadisticas {
  const ResumenEstadisticas({
    required this.minutosTotales,
    required this.rachaDias,
    required this.sesionesHoy,
    required this.minutosPorTarea,
    required this.historialPorDia,
  });

  final int minutosTotales;
  final int rachaDias;
  final int sesionesHoy;

  /// Título de la tarea → minutos totales.
  final Map<String, int> minutosPorTarea;

  /// Fecha `aaaa-mm-dd` → sesiones de ese día.
  final Map<String, List<Map<String, dynamic>>> historialPorDia;
}
