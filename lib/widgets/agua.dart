import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'trucha.dart';

/// Piezas de la escena acuática: cielo andino, montañas, superficie con olas,
/// rayos de luz bajo el agua y burbujas. Las comparten la bienvenida animada
/// y el fondo de la pantalla de acceso.
class Escena {
  static const cieloAlto = Color(0xFF071F33);
  static const cieloMedio = Color(0xFF16587A);
  static const cieloBajo = Color(0xFF7CC6D3);
  static const aguaSuperficie = Color(0xFF1C8BA3);
  static const aguaMedia = Color(0xFF0C4F6C);
  static const aguaFondo = Color(0xFF041C2B);

  static final _azar = Random(7);
  static final List<_Burbuja> _burbujas = List.generate(
    22,
    (i) => _Burbuja(
      x: _azar.nextDouble(),
      velocidad: 0.05 + _azar.nextDouble() * 0.09,
      radio: 1.2 + _azar.nextDouble() * 3.4,
      fase: _azar.nextDouble(),
    ),
  );

  static double alturaOla(double x, double ancho, double fase, {double amplitud = 3.5}) =>
      amplitud * sin(x / ancho * 2 * pi * 2.2 + fase) + amplitud * 0.5 * sin(x / ancho * 2 * pi * 5.3 - fase * 1.7);

  static void cielo(Canvas canvas, Size size, double horizonte) {
    final r = Rect.fromLTWH(0, 0, size.width, horizonte + 4);
    canvas.drawRect(
      r,
      Paint()
        ..shader = ui.Gradient.linear(
          r.topCenter,
          r.bottomCenter,
          const [cieloAlto, cieloMedio, cieloBajo],
          const [0.0, 0.55, 1.0],
        ),
    );
    // Resplandor del amanecer detrás de las montañas.
    final sol = Offset(size.width * 0.72, horizonte - size.height * 0.09);
    canvas.drawCircle(
      sol,
      size.width * 0.5,
      Paint()
        ..shader = ui.Gradient.radial(
          sol,
          size.width * 0.5,
          [const Color(0x66FFE2A8), const Color(0x00FFE2A8)],
        ),
    );
    canvas.drawCircle(sol, size.width * 0.045, Paint()..color = const Color(0xCCFFF1CF));
  }

  /// Dos capas de cordillera: la sierra central del Perú.
  static void montanas(Canvas canvas, Size size, double horizonte) {
    final w = size.width;
    final lejana = Path()..moveTo(0, horizonte);
    const picosLejanos = [0.10, 0.62, 0.24, 0.44, 0.38, 0.78, 0.55, 0.50, 0.70, 0.86, 0.85, 0.58, 1.0, 0.70];
    for (var i = 0; i < picosLejanos.length; i += 2) {
      lejana.lineTo(w * picosLejanos[i], horizonte - size.height * 0.16 * picosLejanos[i + 1]);
    }
    lejana
      ..lineTo(w, horizonte)
      ..close();
    canvas.drawPath(lejana, Paint()..color = const Color(0xFF2F6F8C).withValues(alpha: 0.75));

    // Nieve en la cumbre más alta.
    final alto = Offset(w * 0.38, horizonte - size.height * 0.16 * 0.78);
    canvas.drawPath(
      Path()
        ..moveTo(alto.dx, alto.dy)
        ..lineTo(alto.dx + w * 0.035, alto.dy + size.height * 0.022)
        ..lineTo(alto.dx + w * 0.012, alto.dy + size.height * 0.018)
        ..lineTo(alto.dx - w * 0.01, alto.dy + size.height * 0.026)
        ..lineTo(alto.dx - w * 0.04, alto.dy + size.height * 0.02)
        ..close(),
      Paint()..color = const Color(0xCCEAF4F7),
    );

    final cercana = Path()..moveTo(0, horizonte);
    const picosCercanos = [0.0, 0.30, 0.16, 0.52, 0.30, 0.34, 0.47, 0.46, 0.64, 0.28, 0.82, 0.40, 1.0, 0.22];
    for (var i = 0; i < picosCercanos.length; i += 2) {
      cercana.lineTo(w * picosCercanos[i], horizonte - size.height * 0.11 * picosCercanos[i + 1]);
    }
    cercana
      ..lineTo(w, horizonte)
      ..close();
    canvas.drawPath(cercana, Paint()..color = const Color(0xFF184A62));
  }

  static Path superficie(Size size, double horizonte, double fase, {double amplitud = 3.5}) {
    final p = Path()..moveTo(0, size.height);
    for (double x = 0; x <= size.width + 6; x += 6) {
      p.lineTo(x, horizonte + alturaOla(x, size.width, fase, amplitud: amplitud));
    }
    p
      ..lineTo(size.width, size.height)
      ..close();
    return p;
  }

  static void agua(Canvas canvas, Size size, double horizonte, double fase, {double amplitud = 3.5}) {
    final cuerpo = superficie(size, horizonte, fase, amplitud: amplitud);
    canvas.drawPath(
      cuerpo,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonte),
          Offset(0, size.height),
          const [aguaSuperficie, aguaMedia, aguaFondo],
          const [0.0, 0.4, 1.0],
        ),
    );

    // Reflejo del cielo en la superficie.
    canvas.save();
    canvas.clipPath(cuerpo);
    canvas.drawRect(
      Rect.fromLTWH(0, horizonte - 6, size.width, 26),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(0, horizonte - 6),
          Offset(0, horizonte + 20),
          [const Color(0x557CC6D3), const Color(0x007CC6D3)],
        ),
    );
    canvas.restore();

    // Línea de espuma de la superficie.
    final linea = Path();
    for (double x = 0; x <= size.width + 6; x += 6) {
      final y = horizonte + alturaOla(x, size.width, fase, amplitud: amplitud);
      if (x == 0) {
        linea.moveTo(x, y);
      } else {
        linea.lineTo(x, y);
      }
    }
    canvas.drawPath(
      linea,
      Paint()
        ..color = const Color(0x99E6F7FA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  /// Haces de luz que entran por la superficie y se mueven despacio.
  static void rayos(Canvas canvas, Size size, double horizonte, double tiempo) {
    final alto = size.height - horizonte;
    for (var i = 0; i < 5; i++) {
      final base = size.width * (0.12 + i * 0.2) + sin(tiempo * 0.6 + i * 1.3) * 18;
      final ancho = 18.0 + (i % 2) * 14;
      final r = Path()
        ..moveTo(base - ancho / 2, horizonte)
        ..lineTo(base + ancho / 2, horizonte)
        ..lineTo(base + ancho * 2.2 + 40, horizonte + alto * 0.85)
        ..lineTo(base + ancho * 0.6 + 40, horizonte + alto * 0.85)
        ..close();
      canvas.drawPath(
        r,
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(0, horizonte),
            Offset(0, horizonte + alto * 0.85),
            [const Color(0x24FFFFFF), const Color(0x00FFFFFF)],
          ),
      );
    }
  }

  static void burbujas(Canvas canvas, Size size, double horizonte, double tiempo, {double opacidad = 1}) {
    final borde = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.45 * opacidad);
    final relleno = Paint()..color = Colors.white.withValues(alpha: 0.08 * opacidad);
    final brillo = Paint()..color = Colors.white.withValues(alpha: 0.6 * opacidad);
    final recorrido = size.height - horizonte;
    for (var i = 0; i < _burbujas.length; i++) {
      final b = _burbujas[i];
      final avance = (tiempo * b.velocidad + b.fase) % 1.0;
      final y = size.height - avance * recorrido;
      if (y < horizonte + 6) continue;
      final x = b.x * size.width + sin(tiempo * 2 + i) * 5;
      final o = Offset(x, y);
      canvas.drawCircle(o, b.radio, relleno);
      canvas.drawCircle(o, b.radio, borde);
      canvas.drawCircle(o.translate(-b.radio * 0.35, -b.radio * 0.35), b.radio * 0.25, brillo);
    }
  }
}

class _Burbuja {
  final double x, velocidad, radio, fase;
  const _Burbuja({required this.x, required this.velocidad, required this.radio, required this.fase});
}

/// Fondo animado de la pantalla de acceso: bajo el agua, con una trucha que
/// cruza nadando de vez en cuando.
class FondoAgua extends StatefulWidget {
  final Widget child;
  const FondoAgua({super.key, required this.child});

  @override
  State<FondoAgua> createState() => _FondoAguaState();
}

class _FondoAguaState extends State<FondoAgua> with SingleTickerProviderStateMixin {
  final _tiempo = ValueNotifier<double>(0);
  late final Ticker _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((transcurrido) => _tiempo.value = transcurrido.inMicroseconds / 1e6)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: _PintorFondo(_tiempo))),
        widget.child,
      ],
    );
  }
}

class _PintorFondo extends CustomPainter {
  final ValueNotifier<double> reloj; // segundos desde que apareció
  _PintorFondo(this.reloj) : super(repaint: reloj);

  @override
  void paint(Canvas canvas, Size size) {
    final tiempo = reloj.value;
    final horizonte = size.height * 0.2;
    Escena.cielo(canvas, size, horizonte);
    Escena.montanas(canvas, size, horizonte);
    Escena.agua(canvas, size, horizonte, tiempo * 1.2);
    canvas.save();
    canvas.clipPath(Escena.superficie(size, horizonte, tiempo * 1.2));
    Escena.rayos(canvas, size, horizonte, tiempo);

    // Trucha que cruza cada 15 s, ondulando un poco al nadar.
    final ciclo = (tiempo % 15) / 15;
    final escala = size.width / 520;
    final x = -120 * escala + ciclo * (size.width + 240 * escala);
    final y = size.height * 0.78 + sin(ciclo * 2 * pi * 2) * 14;
    canvas.save();
    canvas.translate(x, y);
    canvas.rotate(cos(ciclo * 2 * pi * 2) * 0.06);
    canvas.scale(escala);
    dibujarTrucha(canvas, opacidad: 0.55);
    canvas.restore();

    // Otra más pequeña y lejana, en sentido contrario.
    final ciclo2 = ((tiempo + 6) % 21) / 21;
    final escala2 = size.width / 1100;
    final x2 = size.width + 120 * escala2 - ciclo2 * (size.width + 240 * escala2);
    canvas.save();
    canvas.translate(x2, size.height * 0.42 + sin(ciclo2 * 2 * pi * 3) * 8);
    canvas.scale(-escala2, escala2);
    dibujarTrucha(canvas, opacidad: 0.3);
    canvas.restore();

    Escena.burbujas(canvas, size, horizonte, tiempo);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PintorFondo old) => old.reloj != reloj;
}
