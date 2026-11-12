import 'package:flutter/material.dart';

import '../formato.dart';
import '../tema.dart';
import 'distintivo.dart';

/// Las cuatro cifras del resumen, pensadas para ir sobre la cabecera oscura.
class ResumenTablero extends StatelessWidget {
  final int estanques;
  final int alertas;
  final int criticos;
  final int incomunicados;

  /// Mientras llegan los datos se muestra «–»: un «0» diría que no hay
  /// alertas cuando todavía no se sabe.
  final bool cargando;

  const ResumenTablero({
    super.key,
    this.cargando = false,
    required this.estanques,
    required this.alertas,
    required this.criticos,
    required this.incomunicados,
  });

  @override
  Widget build(BuildContext context) {
    final cifras = <(String, int, EstadoVisual?)>[
      ('Alertas', alertas, EstadoVisual.advertencia),
      ('Críticos', criticos, EstadoVisual.critico),
      ('Sin señal', incomunicados, EstadoVisual.sinDatos),
      ('Estanques', estanques, null),
    ];

    return Row(
      children: [
        for (var i = 0; i < cifras.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: _Cifra(etiqueta: cifras[i].$1, valor: cifras[i].$2, estado: cifras[i].$3, cargando: cargando)),
        ],
      ],
    );
  }
}

class _Cifra extends StatelessWidget {
  final String etiqueta;
  final int valor;
  final EstadoVisual? estado;
  final bool cargando;
  const _Cifra({required this.etiqueta, required this.valor, this.estado, this.cargando = false});

  @override
  Widget build(BuildContext context) {
    final e = estado;
    final activa = !cargando && e != null && valor > 0;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: activa ? Paleta.deEstado(e).withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: activa ? Paleta.deEstado(e).withValues(alpha: 0.7) : Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cargando ? '–' : '$valor',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: 2),
          Row(children: [
            if (activa) ...[IconoEstado(estado: e, tamano: 10), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                etiqueta,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xD9FFFFFF), fontSize: 11),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
