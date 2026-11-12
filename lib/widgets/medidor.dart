import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';

/// Medidor semicircular de un parámetro, con zonas de color (crítico,
/// advertencia, aceptable) y una aguja animada.
///
/// El pH lleva además, por fuera, la escala universal de color del pH (rojo
/// ácido → verde neutro → morado alcalino): es el parámetro central del
/// proyecto y así se lee de un vistazo.
class MedidorParametro extends StatelessWidget {
  final EstadoParametro parametro;
  final bool seleccionado;
  final VoidCallback? alTocar;

  const MedidorParametro({super.key, required this.parametro, this.seleccionado = false, this.alTocar});

  /// Escala visible de cada sensor.
  static const escalas = {
    'od_mgl': (0.0, 16.0),
    'temp_c': (0.0, 26.0),
    'ph': (0.0, 14.0),
  };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estado = estadoDelParametro(parametro);
    final color = Paleta.deEstado(estado);
    final escala = escalas[parametro.parametro] ?? (0.0, 100.0);
    final v = parametro.ultimoValor;

    return Semantics(
      label: '${parametro.nombre}: ${valorLegible(v, parametro.unidad)}, ${etiquetaEstado[estado]}',
      button: alTocar != null,
      child: InkWell(
        onTap: alTocar,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: tema.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: seleccionado ? color : tema.dividerColor.withValues(alpha: 0.25),
              width: seleccionado ? 2 : 1,
            ),
            boxShadow: seleccionado
                ? [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))]
                : null,
          ),
          child: Column(
            children: [
              AspectRatio(
                aspectRatio: 1.6,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: escala.$1, end: (v ?? escala.$1).clamp(escala.$1, escala.$2)),
                  duration: const Duration(milliseconds: 1100),
                  curve: Curves.easeOutBack,
                  builder: (context, valorAnimado, _) => CustomPaint(
                    painter: _PintorMedidor(
                      desde: escala.$1,
                      hasta: escala.$2,
                      valor: v == null ? null : valorAnimado,
                      umbral: parametro.umbral,
                      escalaPh: parametro.parametro == 'ph',
                      colorAguja: color,
                      oscuro: tema.brightness == Brightness.dark,
                    ),
                  ),
                ),
              ),
              Text(
                v == null ? '—' : v.toStringAsFixed(parametro.parametro == 'ph' ? 2 : 1),
                style: tema.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  color: Color.lerp(color, tema.colorScheme.onSurface, 0.35),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                parametro.unidad.isEmpty ? parametro.nombre : '${parametro.nombre} (${parametro.unidad})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tema.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  etiquetaEstado[estado]!,
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color.lerp(color, Colors.black, 0.25)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PintorMedidor extends CustomPainter {
  final double desde, hasta;
  final double? valor;
  final Umbral? umbral;
  final bool escalaPh;
  final Color colorAguja;
  final bool oscuro;

  _PintorMedidor({
    required this.desde,
    required this.hasta,
    required this.valor,
    required this.umbral,
    required this.escalaPh,
    required this.colorAguja,
    required this.oscuro,
  });

  /// Ángulo (radianes) de un valor: de 180° (izquierda) a 360° (derecha).
  double _angulo(double x) => pi + pi * ((x - desde) / (hasta - desde)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final grosor = size.width * 0.085;
    final centro = Offset(size.width / 2, size.height * 0.86);
    final radio = min(size.width / 2, size.height * 0.86) - grosor * (escalaPh ? 1.35 : 0.7);
    final arco = Rect.fromCircle(center: centro, radius: radio);

    // Pista de fondo.
    canvas.drawArc(
      arco,
      pi,
      pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round
        ..color = oscuro ? const Color(0xFF2B3134) : const Color(0xFFE7EBEA),
    );

    // Zonas del semáforo según el umbral.
    final u = umbral;
    if (u != null) {
      void zona(double a, double b, Color c) {
        final ia = _angulo(max(a, desde)), ib = _angulo(min(b, hasta));
        if (ib <= ia) return;
        canvas.drawArc(
          arco,
          ia,
          ib - ia,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = grosor
            ..color = c,
        );
      }

      zona(desde, u.min - u.margen, Paleta.critico.withValues(alpha: 0.85));
      zona(u.min - u.margen, u.min, Paleta.advertencia);
      zona(u.min, u.max, Paleta.normal);
      zona(u.max, u.max + u.margen, Paleta.advertencia);
      zona(u.max + u.margen, hasta, Paleta.critico.withValues(alpha: 0.85));
    }

    // Escala universal del pH, por fuera del arco.
    if (escalaPh) {
      final exterior = Rect.fromCircle(center: centro, radius: radio + grosor * 1.05);
      canvas.drawArc(
        exterior,
        pi,
        pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = grosor * 0.38
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.sweep(
            centro,
            const [
              Color(0xFFE53935), // 0  ácido fuerte
              Color(0xFFFB8C00), // 3
              Color(0xFFFDD835), // 5
              Color(0xFF43A047), // 7  neutro
              Color(0xFF1E88E5), // 9
              Color(0xFF3949AB), // 11
              Color(0xFF8E24AA), // 14 alcalino fuerte
            ],
            const [0.5, 0.6, 0.67, 0.75, 0.83, 0.91, 1.0],
          ),
      );
    }

    // Marcas cada cierto paso.
    final marca = Paint()
      ..color = (oscuro ? Colors.white : Colors.black).withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    const divisiones = 7;
    for (var i = 0; i <= divisiones; i++) {
      final a = pi + pi * i / divisiones;
      final r1 = radio - grosor * 0.75, r2 = radio - grosor * 1.05;
      canvas.drawLine(
        centro + Offset(cos(a) * r1, sin(a) * r1),
        centro + Offset(cos(a) * r2, sin(a) * r2),
        marca,
      );
    }

    // Aguja.
    final x = valor;
    if (x != null) {
      final a = _angulo(x);
      final punta = centro + Offset(cos(a), sin(a)) * (radio + grosor * 0.15);
      final ancho = grosor * 0.32;
      final perp = Offset(-sin(a), cos(a)) * ancho;
      final aguja = Path()
        ..moveTo(punta.dx, punta.dy)
        ..lineTo(centro.dx + perp.dx, centro.dy + perp.dy)
        ..lineTo(centro.dx - perp.dx, centro.dy - perp.dy)
        ..close();
      canvas.drawShadow(aguja, Colors.black, 2, false);
      canvas.drawPath(aguja, Paint()..color = colorAguja);
      canvas.drawCircle(centro, grosor * 0.55, Paint()..color = colorAguja);
      canvas.drawCircle(centro, grosor * 0.25, Paint()..color = oscuro ? const Color(0xFF15191B) : Colors.white);
    }
  }

  @override
  bool shouldRepaint(_PintorMedidor old) =>
      old.valor != valor || old.colorAguja != colorAguja || old.oscuro != oscuro || old.umbral != umbral;
}
