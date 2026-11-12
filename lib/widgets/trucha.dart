import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Trucha arcoíris dibujada con vectores (sin imágenes).
///
/// Se dibuja en coordenadas locales: el hocico apunta a +x y el cuerpo mide
/// unas 210 unidades, de -108 (cola) a +100 (hocico), centrado en el origen.
/// Quien la usa traslada, rota y escala el canvas antes de llamar.
void dibujarTrucha(Canvas canvas, {double opacidad = 1, bool silueta = false}) {
  if (opacidad <= 0) return;

  Color c(int argb) => Color(argb).withValues(alpha: opacidad * Color(argb).a);

  final cuerpo = Path()
    ..moveTo(100, 0)
    ..cubicTo(88, -21, 34, -30, -18, -25)
    ..cubicTo(-50, -21, -68, -11, -78, -4.5)
    ..lineTo(-78, 4.5)
    ..cubicTo(-68, 12, -44, 22, -8, 24)
    ..cubicTo(36, 26, 86, 18, 100, 0)
    ..close();

  final cola = Path()
    ..moveTo(-74, -4)
    ..lineTo(-108, -27)
    ..quadraticBezierTo(-96, 0, -108, 27)
    ..lineTo(-74, 4)
    ..close();

  final dorsal = Path()
    ..moveTo(-2, -27)
    ..quadraticBezierTo(-14, -45, -26, -44)
    ..quadraticBezierTo(-31, -34, -36, -24)
    ..close();

  final adiposa = Path()
    ..moveTo(-52, -19)
    ..quadraticBezierTo(-58, -27, -64, -15)
    ..close();

  final pectoral = Path()
    ..moveTo(58, 9)
    ..quadraticBezierTo(44, 18, 40, 27)
    ..quadraticBezierTo(54, 22, 64, 14)
    ..close();

  final ventral = Path()
    ..moveTo(4, 23)
    ..lineTo(-6, 34)
    ..lineTo(-14, 23)
    ..close();

  final anal = Path()
    ..moveTo(-38, 19)
    ..lineTo(-50, 31)
    ..lineTo(-58, 15)
    ..close();

  if (silueta) {
    final p = Paint()..color = c(0xFF0B2A3A);
    for (final parte in [cola, dorsal, adiposa, pectoral, ventral, anal, cuerpo]) {
      canvas.drawPath(parte, p);
    }
    return;
  }

  // Aletas: tono oliva translúcido con radios.
  final aleta = Paint()..color = c(0xCC6E7F4A);
  final radios = Paint()
    ..color = c(0x553A4A26)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.8;
  for (final parte in [cola, dorsal, adiposa, pectoral, ventral, anal]) {
    canvas.drawPath(parte, aleta);
  }
  for (var i = -3; i <= 3; i++) {
    canvas.drawLine(const Offset(-78, 0), Offset(-104, i * 7.5), radios);
  }

  // Cuerpo: lomo oliva → flanco plateado → vientre claro.
  final degradado = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(0, -28),
      const Offset(0, 26),
      [c(0xFF4F6B2E), c(0xFF8FA163), c(0xFFDDE5E2), c(0xFFF4F1EA)],
      const [0.0, 0.35, 0.65, 1.0],
    );
  canvas.drawPath(cuerpo, degradado);

  // Banda rosada iridiscente, sello de la trucha arcoíris.
  canvas.save();
  canvas.clipPath(cuerpo);
  final banda = Paint()
    ..shader = ui.Gradient.linear(
      const Offset(90, 0),
      const Offset(-80, 0),
      [c(0x00E86F86), c(0xCCE86F86), c(0xB3D9637E), c(0x66C85A78)],
      const [0.0, 0.18, 0.6, 1.0],
    )
    ..style = PaintingStyle.stroke
    ..strokeWidth = 9
    ..strokeCap = StrokeCap.round;
  canvas.drawPath(
    Path()
      ..moveTo(88, -1)
      ..cubicTo(40, -5, -20, -3, -80, 0),
    banda,
  );

  // Pintas negras en lomo, aleta y cola.
  final pinta = Paint()..color = c(0xD9231F1A);
  const pintas = [
    Offset(40, -16), Offset(28, -20), Offset(14, -14), Offset(4, -21), Offset(-10, -17),
    Offset(-22, -21), Offset(-30, -12), Offset(-42, -16), Offset(-54, -9), Offset(52, -11),
    Offset(20, -7), Offset(-4, -9), Offset(-62, -3), Offset(-16, 6), Offset(-38, 4),
  ];
  for (final o in pintas) {
    canvas.drawCircle(o, 1.35, pinta);
  }
  canvas.restore();

  for (final o in const [Offset(-88, -9), Offset(-94, 4), Offset(-99, -15), Offset(-97, 14), Offset(-18, -35)]) {
    canvas.drawCircle(o, 1.2, pinta);
  }

  // Opérculo y brillo dorsal.
  canvas.drawPath(
    Path()
      ..moveTo(66, -15)
      ..quadraticBezierTo(56, 0, 64, 14),
    Paint()
      ..color = c(0x66403A30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4,
  );
  canvas.drawPath(
    Path()
      ..moveTo(70, -12)
      ..cubicTo(40, -22, 0, -24, -40, -16),
    Paint()
      ..color = c(0x40FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round,
  );

  // Ojo.
  canvas.drawCircle(const Offset(80, -6), 4.6, Paint()..color = c(0xFFE8D7A0));
  canvas.drawCircle(const Offset(81, -6), 2.7, Paint()..color = c(0xFF111111));
  canvas.drawCircle(const Offset(82, -7.2), 0.9, Paint()..color = c(0xFFFFFFFF));

  // Boca.
  canvas.drawLine(
    const Offset(99, 1.5),
    const Offset(90, 4),
    Paint()
      ..color = c(0x99403A30)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round,
  );
}

/// Widget estático con la trucha, útil para logos e íconos.
class Trucha extends StatelessWidget {
  final double ancho;
  final double angulo;
  const Trucha({super.key, this.ancho = 120, this.angulo = 0});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: ancho,
        height: ancho * 0.45,
        child: CustomPaint(painter: _PintorTruchaFija(angulo)),
      );
}

class _PintorTruchaFija extends CustomPainter {
  final double angulo;
  _PintorTruchaFija(this.angulo);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.rotate(angulo);
    final s = size.width / 220;
    canvas.scale(s);
    canvas.translate(4, 0);
    dibujarTrucha(canvas);
  }

  @override
  bool shouldRepaint(_PintorTruchaFija old) => old.angulo != angulo;
}
