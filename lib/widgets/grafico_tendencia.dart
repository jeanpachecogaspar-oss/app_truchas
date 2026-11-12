import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';

/// Tendencia de un parámetro: línea curva con degradado, área sombreada,
/// zonas de color (aceptable / advertencia), líneas de umbral rotuladas,
/// puntos rojos fuera de rango y un punto final que «late». Se dibuja de
/// izquierda a derecha al aparecer.
class GraficoTendencia extends StatefulWidget {
  final List<PuntoDeSerie> puntos;
  final String? unidad;
  final Umbral? umbral;
  final String parametro;

  const GraficoTendencia({
    super.key,
    required this.puntos,
    required this.parametro,
    this.unidad,
    this.umbral,
  });

  /// Colores de la línea según el parámetro, para que cada uno tenga su identidad.
  static const _degradados = {
    'od_mgl': [Color(0xFF00B4D8), Color(0xFF0077B6)],
    'temp_c': [Color(0xFFFFB703), Color(0xFFFB5607)],
    'ph': [Color(0xFF8E24AA), Color(0xFF43A047)],
  };

  @override
  State<GraficoTendencia> createState() => _GraficoTendenciaState();
}

class _GraficoTendenciaState extends State<GraficoTendencia> with TickerProviderStateMixin {
  late final AnimationController _dibujo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();
  late final AnimationController _latido =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat(reverse: true);

  @override
  void didUpdateWidget(GraficoTendencia old) {
    super.didUpdateWidget(old);
    // Al cambiar de parámetro se vuelve a dibujar desde la izquierda.
    if (old.parametro != widget.parametro) _dibujo.forward(from: 0);
  }

  @override
  void dispose() {
    _dibujo.dispose();
    _latido.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final puntos = widget.puntos;
    if (puntos.isEmpty) {
      return const SizedBox(height: 240, child: Center(child: Text('Sin lecturas en las últimas 24 h')));
    }

    final tema = Theme.of(context);
    final oscuro = tema.brightness == Brightness.dark;
    final u = widget.umbral;
    final colores = GraficoTendencia._degradados[widget.parametro] ?? const [Paleta.serie, Paleta.aguaMedia];

    final inicio = puntos.first.medidoEn.millisecondsSinceEpoch.toDouble();
    double x(DateTime t) => (t.millisecondsSinceEpoch - inicio) / 60000; // minutos

    final valores = puntos.map((p) => p.valor).toList();
    var minY = valores.reduce((a, b) => a < b ? a : b);
    var maxY = valores.reduce((a, b) => a > b ? a : b);
    if (u != null) {
      if (u.min - u.margen * 0.5 < minY) minY = u.min - u.margen * 0.5;
      if (u.max + u.margen * 0.5 > maxY) maxY = u.max + u.margen * 0.5;
    }
    final aire = (maxY - minY) == 0 ? 1.0 : (maxY - minY) * 0.1;
    minY -= aire;
    maxY += aire;

    final maxX = x(puntos.last.medidoEn) <= 0 ? 1.0 : x(puntos.last.medidoEn);
    final horas = DateFormat('HH:mm');
    final estiloEje = tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada, fontSize: 10);

    bool fuera(double v) => u != null && (v < u.min || v > u.max);
    final ultimo = puntos.length - 1;

    HorizontalLine lineaUmbral(double y, String texto) => HorizontalLine(
          y: y,
          color: Paleta.normal.withValues(alpha: 0.8),
          strokeWidth: 1.2,
          dashArray: [6, 4],
          label: HorizontalLineLabel(
            show: true,
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 4, bottom: 2),
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Paleta.normal.withValues(alpha: 0.9)),
            labelResolver: (_) => texto,
          ),
        );

    final grafico = AnimatedBuilder(
      animation: _latido,
      builder: (context, _) => LineChart(
        LineChartData(
          minX: 0,
          maxX: maxX,
          minY: minY,
          maxY: maxY,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            drawVerticalLine: true,
            verticalInterval: maxX / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: tema.dividerColor.withValues(alpha: 0.18), strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: tema.dividerColor.withValues(alpha: 0.12), strokeWidth: 1, dashArray: [3, 5]),
          ),
          borderData: FlBorderData(show: false),
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: [
              if (u != null) ...[
                HorizontalRangeAnnotation(y1: u.min, y2: u.max, color: Paleta.normal.withValues(alpha: oscuro ? 0.12 : 0.09)),
                HorizontalRangeAnnotation(
                    y1: u.min - u.margen, y2: u.min, color: Paleta.advertencia.withValues(alpha: oscuro ? 0.12 : 0.10)),
                HorizontalRangeAnnotation(
                    y1: u.max, y2: u.max + u.margen, color: Paleta.advertencia.withValues(alpha: oscuro ? 0.12 : 0.10)),
              ],
            ],
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              if (u != null) lineaUmbral(u.max, 'máx ${numeroCorto(u.max)}'),
              if (u != null) lineaUmbral(u.min, 'mín ${numeroCorto(u.min)}'),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (v, meta) => SideTitleWidget(
                  meta: meta,
                  child: Text(v.toStringAsFixed(1), style: estiloEje),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: (maxX / 4).ceilToDouble(),
                getTitlesWidget: (v, meta) {
                  final t = DateTime.fromMillisecondsSinceEpoch((inicio + v * 60000).round());
                  return SideTitleWidget(meta: meta, child: Text(horas.format(t), style: estiloEje));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            getTouchedSpotIndicator: (barra, indices) => indices
                .map((_) => TouchedSpotIndicatorData(
                      FlLine(color: colores.last.withValues(alpha: 0.5), strokeWidth: 1.5, dashArray: [4, 3]),
                      FlDotData(
                        getDotPainter: (s, a, b, c) => FlDotCirclePainter(
                          radius: 6,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: colores.last,
                        ),
                      ),
                    ))
                .toList(),
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => const Color(0xEE0B2A3A),
              getTooltipItems: (spots) => spots.map((s) {
                final t = DateTime.fromMillisecondsSinceEpoch((inicio + s.x * 60000).round());
                return LineTooltipItem(
                  valorLegible(s.y, widget.unidad),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                  children: [
                    TextSpan(
                      text: '\n${horaDeFecha(t)}',
                      style: const TextStyle(color: Color(0xCCFFFFFF), fontWeight: FontWeight.w400, fontSize: 11),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: puntos.map((p) => FlSpot(x(p.medidoEn), p.valor)).toList(),
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              gradient: LinearGradient(colors: colores),
              barWidth: 3.2,
              isStrokeCapRound: true,
              shadow: Shadow(color: colores.last.withValues(alpha: 0.35), blurRadius: 8, offset: const Offset(0, 4)),
              dotData: FlDotData(
                checkToShowDot: (spot, barra) => fuera(spot.y) || barra.spots.indexOf(spot) == ultimo,
                getDotPainter: (spot, _, barra, indice) {
                  if (indice == ultimo) {
                    // Punto final que late, en el color de su estado.
                    final c = fuera(spot.y) ? Paleta.critico : colores.last;
                    return FlDotCirclePainter(
                      radius: 5 + _latido.value * 2.5,
                      color: c,
                      strokeWidth: 3 + _latido.value * 4,
                      strokeColor: c.withValues(alpha: 0.25),
                    );
                  }
                  return FlDotCirclePainter(radius: 3.2, color: Paleta.critico, strokeWidth: 1.5, strokeColor: Colors.white);
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colores.first.withValues(alpha: 0.35), colores.last.withValues(alpha: 0.0)],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    // Revelado de izquierda a derecha.
    return SizedBox(
      height: 250,
      child: AnimatedBuilder(
        animation: _dibujo,
        builder: (context, hijo) => ClipRect(
          clipper: _RecorteHorizontal(Curves.easeOutCubic.transform(_dibujo.value)),
          child: hijo,
        ),
        child: grafico,
      ),
    );
  }
}

class _RecorteHorizontal extends CustomClipper<Rect> {
  final double fraccion;
  _RecorteHorizontal(this.fraccion);

  @override
  Rect getClip(Size size) => Rect.fromLTWH(0, -20, size.width * fraccion, size.height + 40);

  @override
  bool shouldReclip(_RecorteHorizontal old) => old.fraccion != fraccion;
}
