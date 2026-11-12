import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../widgets/agua.dart';
import '../widgets/trucha.dart';

/// Entrada animada: una trucha salta desde lo alto, cae al agua, salpica y
/// se pierde en el fondo mientras aparece la marca. Tocar la salta.
class PantallaBienvenida extends StatefulWidget {
  final VoidCallback alTerminar;
  const PantallaBienvenida({super.key, required this.alTerminar});

  @override
  State<PantallaBienvenida> createState() => _PantallaBienvenidaState();
}

class _PantallaBienvenidaState extends State<PantallaBienvenida> with SingleTickerProviderStateMixin {
  static const duracion = 4.2; // segundos

  final _tiempo = ValueNotifier<double>(0);
  late final Ticker _ticker;
  bool _terminado = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final t = d.inMicroseconds / 1e6;
      _tiempo.value = t;
      if (t >= duracion) _terminar();
    })
      ..start();
  }

  void _terminar() {
    if (_terminado) return;
    _terminado = true;
    _ticker.stop();
    widget.alTerminar();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _tiempo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Escena.aguaFondo,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _terminar,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _PintorBienvenida(_tiempo)),
            ValueListenableBuilder<double>(
              valueListenable: _tiempo,
              builder: (context, t, _) => _Marca(t: t),
            ),
          ],
        ),
      ),
    );
  }
}

/// Curvas de suavizado.
double _clamp01(double v) => v.clamp(0.0, 1.0);
double _entre(double t, double a, double b) => _clamp01((t - a) / (b - a));
double _salidaCubica(double x) => 1 - pow(1 - x, 3).toDouble();

class _PintorBienvenida extends CustomPainter {
  final ValueNotifier<double> reloj;
  _PintorBienvenida(this.reloj) : super(repaint: reloj);

  // Momentos clave (segundos).
  static const tImpacto = 1.25;
  static const tHundida = 2.6;

  static final List<_Gota> _gotas = () {
    final r = Random(3);
    return List.generate(30, (i) {
      // Abanico hacia arriba, más cargado a los lados (corona de salpicadura).
      final lado = r.nextBool() ? 1 : -1;
      final angulo = -pi / 2 + lado * (0.15 + r.nextDouble() * 1.05);
      final rapidez = 260 + r.nextDouble() * 360;
      return _Gota(cos(angulo) * rapidez, sin(angulo) * rapidez, 1.6 + r.nextDouble() * 3.4);
    });
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = reloj.value;
    final w = size.width, h = size.height;
    final horizonte = h * 0.6;
    final fase = t * 1.6;

    // Al chocar, la superficie se agita más y luego se calma.
    final agitacion = t < tImpacto ? 0.0 : exp(-(t - tImpacto) * 1.6);
    final amplitud = 3.5 + 4 * agitacion;

    Escena.cielo(canvas, size, horizonte);
    Escena.montanas(canvas, size, horizonte);
    Escena.agua(canvas, size, horizonte, fase, amplitud: amplitud);

    final aguaClip = Escena.superficie(size, horizonte, fase, amplitud: amplitud);
    canvas.save();
    canvas.clipPath(aguaClip);
    Escena.rayos(canvas, size, horizonte, t);
    Escena.burbujas(canvas, size, horizonte, t, opacidad: _entre(t, 0.2, 1.0));
    canvas.restore();

    final escala = w / 430;
    final impacto = Offset(w * 0.5, horizonte);

    if (t < tImpacto) {
      // ── Caída: parábola desde arriba a la derecha, acelerando ──
      final s = t / tImpacto;
      final inicio = Offset(w * 1.15, h * 0.04);
      final x = inicio.dx + (impacto.dx - inicio.dx) * s;
      final y = inicio.dy + (impacto.dy - inicio.dy) * s * s;
      final dx = (impacto.dx - inicio.dx).abs();
      final dy = 2 * (impacto.dy - inicio.dy) * s;
      final aleteo = sin(t * 22) * 0.07 * (1 - s);
      _pintarTrucha(canvas, Offset(x, y), atan2(dy, dx) + aleteo, escala, 1);
      // Sombra que crece sobre el agua al acercarse.
      canvas.drawOval(
        Rect.fromCenter(center: impacto, width: 60 * escala * (0.3 + s), height: 10 * escala * (0.3 + s)),
        Paint()..color = Colors.black.withValues(alpha: 0.18 * s),
      );
    } else {
      // ── Bajo el agua: sigue hundiéndose, frena y se desvanece ──
      final s = _salidaCubica(_entre(t, tImpacto, tHundida));
      final x = impacto.dx - w * 0.18 * s;
      final y = impacto.dy + h * 0.24 * s;
      final anguloImpacto = atan2(2 * (impacto.dy - h * 0.04), (impacto.dx - w * 1.15).abs());
      final angulo = anguloImpacto + (0.15 - anguloImpacto) * s + sin(t * 9) * 0.05;
      final opacidad = 0.85 * (1 - _entre(t, tImpacto + 0.4, tHundida));
      final centro = Offset(x, y);
      final escalaT = escala * (1 - 0.25 * s);

      // Lo que todavía no entró al agua se sigue viendo seco, sobre ella.
      if (t < tImpacto + 0.6) {
        canvas.save();
        canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(Offset.zero & size), aguaClip));
        _pintarTrucha(canvas, centro, angulo, escalaT, 1);
        canvas.restore();
      }

      canvas.save();
      canvas.clipPath(aguaClip);
      _pintarTrucha(canvas, centro, angulo, escalaT, opacidad);
      // Velo de agua encima para que se vea sumergida.
      canvas.drawPath(aguaClip, Paint()..color = Escena.aguaMedia.withValues(alpha: 0.38 * _entre(t, tImpacto, tImpacto + 0.25)));
      canvas.restore();

      _pintarSalpicadura(canvas, impacto, t - tImpacto, escala, horizonte);
    }
  }

  /// La trucha mira hacia la izquierda mientras viaja; se espeja en x.
  void _pintarTrucha(Canvas canvas, Offset centro, double angulo, double escala, double opacidad) {
    canvas.save();
    canvas.translate(centro.dx, centro.dy);
    canvas.scale(-escala, escala);
    canvas.rotate(angulo);
    // El centro de rotación es el hocico, que es lo que «entra» al agua.
    canvas.translate(-100, 0);
    dibujarTrucha(canvas, opacidad: opacidad);
    canvas.restore();
  }

  void _pintarSalpicadura(Canvas canvas, Offset impacto, double tau, double escala, double horizonte) {
    if (tau < 0) return;

    // Ondas concéntricas (elipses en perspectiva).
    for (var k = 0; k < 5; k++) {
      final e = _clamp01((tau - k * 0.18) / 2.2);
      if (e <= 0 || e >= 1) continue;
      final rx = (16 + 260 * _salidaCubica(e)) * escala * 1.4;
      canvas.drawOval(
        Rect.fromCenter(center: impacto, width: rx * 2, height: rx * 0.36),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2.6 - 1.8 * e) * escala * 1.4
          ..color = Colors.white.withValues(alpha: (1 - e) * 0.75),
      );
    }

    // Espuma en el punto de entrada.
    final espuma = _clamp01(1 - tau / 1.4);
    if (espuma > 0) {
      canvas.drawOval(
        Rect.fromCenter(center: impacto, width: 90 * escala * (1 + tau), height: 18 * escala * (1 + tau * 0.6)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.7 * espuma)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }

    // Columna de agua que sube y cae (el «rebote» de la salpicadura).
    final columna = sin(_clamp01(tau / 0.7) * pi);
    if (columna > 0) {
      final alto = 70 * escala * columna;
      final base = 18 * escala;
      canvas.drawPath(
        Path()
          ..moveTo(impacto.dx - base, impacto.dy)
          ..quadraticBezierTo(impacto.dx - base * 0.2, impacto.dy - alto * 0.6, impacto.dx, impacto.dy - alto)
          ..quadraticBezierTo(impacto.dx + base * 0.2, impacto.dy - alto * 0.6, impacto.dx + base, impacto.dy)
          ..close(),
        Paint()..color = const Color(0xFFDDF3F8).withValues(alpha: 0.8 * columna),
      );
    }

    // Gotas balísticas.
    const gravedad = 1300.0;
    final escalaGota = escala * 1.2;
    for (final g in _gotas) {
      final x = impacto.dx + g.vx * tau * escalaGota;
      final y = impacto.dy + (g.vy * tau + 0.5 * gravedad * tau * tau) * escalaGota;
      if (y > horizonte + 4) continue;
      final vida = _clamp01(1 - tau / 1.3);
      canvas.drawCircle(
        Offset(x, y),
        g.radio * escala * 1.4,
        Paint()..color = const Color(0xFFF2FBFD).withValues(alpha: 0.95 * vida),
      );
    }
  }

  @override
  bool shouldRepaint(_PintorBienvenida old) => old.reloj != reloj;
}

class _Gota {
  final double vx, vy, radio;
  const _Gota(this.vx, this.vy, this.radio);
}

/// Nombre y lema, que aparecen cuando la trucha ya está en el agua.
class _Marca extends StatelessWidget {
  final double t;
  const _Marca({required this.t});

  @override
  Widget build(BuildContext context) {
    final aparicion = _salidaCubica(_entre(t, 1.9, 2.8));
    final lema = _salidaCubica(_entre(t, 2.4, 3.2));
    final pie = _entre(t, 2.9, 3.5);
    final salida = 1 - _entre(t, 3.8, 4.2);

    return Opacity(
      opacity: salida,
      child: Column(
        children: [
          const Spacer(flex: 2),
          Opacity(
            opacity: aparicion,
            child: Transform.translate(
              offset: Offset(0, 24 * (1 - aparicion)),
              child: Column(children: [
                Transform.scale(scale: 0.8 + 0.2 * aparicion, child: const Trucha(ancho: 92, angulo: -0.18)),
                const SizedBox(height: 10),
                const Text(
                  'SIPPT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 10,
                    shadows: [Shadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 4))],
                  ),
                ),
              ]),
            ),
          ),
          Opacity(
            opacity: lema,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Monitoreo inteligente de trucha',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 16, letterSpacing: 1.2),
              ),
            ),
          ),
          const Spacer(flex: 5),
          Opacity(
            opacity: pie,
            child: const Padding(
              padding: EdgeInsets.only(bottom: 36),
              child: Text(
                'Universidad Continental · Huancayo',
                style: TextStyle(color: Color(0x99FFFFFF), fontSize: 12, letterSpacing: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
