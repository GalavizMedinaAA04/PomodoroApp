import 'package:flutter/material.dart';

import '../data/database_helper.dart';
import '../services/estadisticas_service.dart';

/// Gráficas de minutos trabajados por día, por semana y por mes.
class GraficasScreen extends StatefulWidget {
  const GraficasScreen({super.key});

  @override
  State<GraficasScreen> createState() => _GraficasScreenState();
}

class _GraficasScreenState extends State<GraficasScreen> {
  static const double _altoGrafica = 260;
  static const double _anchoPorBarra = 48;

  List<Map<String, dynamic>> _sesiones = [];
  PeriodoGrafica _periodo = PeriodoGrafica.dia;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final sesiones = await DatabaseHelper.instance.listarSesiones();
    if (!mounted) return;
    setState(() {
      _sesiones = sesiones;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final barras = EstadisticasService.agrupar(_sesiones, _periodo);
    final total = EstadisticasService.total(barras);
    final descripcion = switch (_periodo) {
      PeriodoGrafica.dia => 'Últimos 14 días',
      PeriodoGrafica.semana => 'Últimas 8 semanas, desde el lunes',
      PeriodoGrafica.mes => 'Últimos 12 meses',
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Gráficas'), centerTitle: true),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SegmentedButton<PeriodoGrafica>(
                    segments: const [
                      ButtonSegment(
                        value: PeriodoGrafica.dia,
                        label: Text('Día'),
                      ),
                      ButtonSegment(
                        value: PeriodoGrafica.semana,
                        label: Text('Semana'),
                      ),
                      ButtonSegment(
                        value: PeriodoGrafica.mes,
                        label: Text('Mes'),
                      ),
                    ],
                    selected: {_periodo},
                    onSelectionChanged: (seleccion) =>
                        setState(() => _periodo = seleccion.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Total: $total min',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(descripcion, style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  // Desplazable en horizontal: con 14 o 12 barras no caben en pantalla.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final ancho = barras.length * _anchoPorBarra;
                      return SizedBox(
                        height: _altoGrafica,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: SizedBox(
                            width: ancho > constraints.maxWidth
                                ? ancho
                                : constraints.maxWidth,
                            height: _altoGrafica,
                            child: CustomPaint(
                              painter: _PintorBarras(
                                barras: barras,
                                colorBarra: scheme.primary,
                                colorTexto: scheme.onSurface,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }
}

/// Dibuja las barras con su valor encima y su etiqueta debajo.
class _PintorBarras extends CustomPainter {
  _PintorBarras({
    required this.barras,
    required this.colorBarra,
    required this.colorTexto,
  });

  final List<BarraGrafica> barras;
  final Color colorBarra;
  final Color colorTexto;

  static const double _alturaEtiqueta = 28;
  static const double _margenSuperior = 24;

  @override
  void paint(Canvas canvas, Size size) {
    final alturaBarras = size.height - _alturaEtiqueta - _margenSuperior;
    final maximo = barras.fold<int>(
      0,
      (mayor, barra) => barra.minutos > mayor ? barra.minutos : mayor,
    );
    final anchoSlot = size.width / barras.length;
    final anchoBarra = anchoSlot * 0.6;
    final pincelFondo = Paint()..color = colorBarra.withValues(alpha: 0.08);
    final pincel = Paint()..color = colorBarra;
    const radio = Radius.circular(6);

    for (var i = 0; i < barras.length; i++) {
      final barra = barras[i];
      final x = i * anchoSlot + (anchoSlot - anchoBarra) / 2;
      final alto = maximo == 0 ? 0.0 : alturaBarras * barra.minutos / maximo;
      final y = _margenSuperior + alturaBarras - alto;

      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, _margenSuperior, anchoBarra, alturaBarras),
          radio,
        ),
        pincelFondo,
      );

      if (barra.minutos > 0) {
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromLTWH(x, y, anchoBarra, alto), radio),
          pincel,
        );
        _texto(
          canvas,
          '${barra.minutos}',
          Offset(i * anchoSlot, y - 16),
          anchoSlot,
        );
      }

      _texto(
        canvas,
        barra.etiqueta,
        Offset(i * anchoSlot, size.height - _alturaEtiqueta + 6),
        anchoSlot,
      );
    }
  }

  void _texto(Canvas canvas, String texto, Offset origen, double ancho) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(color: colorTexto, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: ancho);
    tp.paint(canvas, Offset(origen.dx + (ancho - tp.width) / 2, origen.dy));
  }

  @override
  bool shouldRepaint(covariant _PintorBarras antiguo) =>
      antiguo.barras != barras ||
      antiguo.colorBarra != colorBarra ||
      antiguo.colorTexto != colorTexto;
}
