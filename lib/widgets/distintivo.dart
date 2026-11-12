import 'package:flutter/material.dart';

import '../formato.dart';
import '../tema.dart';

/// Distintivo de estado: forma + color + palabra.
///
/// Círculo = normal, triángulo = advertencia, octógono (pare) = crítico,
/// círculo tachado = sin comunicación. Con daltonismo o a pleno sol el ámbar y
/// el rojo se confunden; un triángulo y un octógono no.
class IconoEstado extends StatelessWidget {
  final EstadoVisual estado;
  final double tamano;

  const IconoEstado({super.key, required this.estado, this.tamano = 14});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(tamano),
      painter: _PintorEstado(estado),
    );
  }
}

class _PintorEstado extends CustomPainter {
  final EstadoVisual estado;
  _PintorEstado(this.estado);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 16; // el diseño original es de 16×16
    canvas.scale(s);
    final color = Paleta.deEstado(estado);
    final relleno = Paint()..color = color;
    final glifo = Paint()
      ..color = estado == EstadoVisual.advertencia ? const Color(0xFF0B0B0B) : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final punto = Paint()..color = glifo.color;

    switch (estado) {
      case EstadoVisual.normal:
        canvas.drawCircle(const Offset(8, 8), 7.5, relleno);
        canvas.drawPath(
          Path()
            ..moveTo(4.6, 8.3)
            ..lineTo(7, 10.6)
            ..lineTo(11.4, 5.7),
          glifo,
        );
      case EstadoVisual.advertencia:
        canvas.drawPath(
          Path()
            ..moveTo(8, 0.9)
            ..lineTo(15.4, 14.6)
            ..lineTo(0.6, 14.6)
            ..close(),
          relleno,
        );
        canvas.drawLine(const Offset(8, 5.6), const Offset(8, 9.9), glifo);
        canvas.drawCircle(const Offset(8, 12.2), 1, punto);
      case EstadoVisual.critico:
        canvas.drawPath(
          Path()
            ..moveTo(5.1, 0.5)
            ..lineTo(10.9, 0.5)
            ..lineTo(15.5, 5.1)
            ..lineTo(15.5, 10.9)
            ..lineTo(10.9, 15.5)
            ..lineTo(5.1, 15.5)
            ..lineTo(0.5, 10.9)
            ..lineTo(0.5, 5.1)
            ..close(),
          relleno,
        );
        canvas.drawLine(const Offset(8, 4.2), const Offset(8, 8.8), glifo);
        canvas.drawCircle(const Offset(8, 11.4), 1, punto);
      case EstadoVisual.sinDatos:
        final trazo = Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8
          ..strokeCap = StrokeCap.round;
        canvas.drawCircle(const Offset(8, 8), 6.6, trazo);
        canvas.drawLine(const Offset(3.4, 12.6), const Offset(12.6, 3.4), trazo);
    }
  }

  @override
  bool shouldRepaint(_PintorEstado old) => old.estado != estado;
}

class Distintivo extends StatelessWidget {
  final EstadoVisual estado;
  final String? etiqueta;

  const Distintivo({super.key, required this.estado, this.etiqueta});

  @override
  Widget build(BuildContext context) {
    final color = Paleta.deEstado(estado);
    return Semantics(
      label: etiqueta ?? etiquetaEstado[estado],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconoEstado(estado: estado),
            const SizedBox(width: 6),
            Text(
              etiqueta ?? etiquetaEstado[estado]!,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
