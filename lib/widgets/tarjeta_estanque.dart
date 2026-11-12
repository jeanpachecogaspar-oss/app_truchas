import 'package:flutter/material.dart';

import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import 'distintivo.dart';

/// Tarjeta de un estanque con su semáforo y cada parámetro (HU-03).
class TarjetaEstanque extends StatelessWidget {
  final Estanque estanque;
  final DateTime ahora;
  final VoidCallback? alTocar;

  const TarjetaEstanque({super.key, required this.estanque, required this.ahora, this.alTocar});

  @override
  Widget build(BuildContext context) {
    // Sin comunicación desplaza al semáforo: un estanque que no reporta podría
    // estar en riesgo sin que el sistema lo sepa.
    final incomunicado = estanque.incomunicado(ahora);
    final estado = incomunicado ? EstadoVisual.sinDatos : estadoDeSemaforo(estanque.semaforo(ahora));
    final color = Paleta.deEstado(estado);
    final tema = Theme.of(context);
    final parametrosEstado = estanque.estadoParametros(ahora);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: alTocar,
        child: Container(
          decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 5))),
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.water, color: color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(estanque.codigo,
                          style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      Text(
                        '${capitalizar(estanque.etapa)} · ${estanque.volumenM3.toStringAsFixed(0)} m³ · '
                        '${estanque.biomasaKg.toStringAsFixed(0)} kg',
                        style: tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada),
                      ),
                    ]),
                  ),
                  Distintivo(estado: estado),
                ],
              ),
              const SizedBox(height: 14),
              ...parametrosEstado.map((p) => _FilaParametro(parametro: p, ahora: ahora)),
              if (alTocar != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('Ver tendencia',
                        style: tema.textTheme.labelMedium
                            ?.copyWith(color: tema.colorScheme.primary, fontWeight: FontWeight.w700)),
                    Icon(Icons.chevron_right, size: 18, color: tema.colorScheme.primary),
                  ]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilaParametro extends StatelessWidget {
  final EstadoParametro parametro;
  final DateTime ahora;
  const _FilaParametro({required this.parametro, required this.ahora});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estado = estadoDelParametro(parametro);
    final posicion = posicionEnRango(parametro);
    final fuera = posicion == Posicion.bajo || posicion == Posicion.sobre;

    final rango = (parametro.minAceptable != null && parametro.maxAceptable != null)
        ? 'rango ${numeroCorto(parametro.minAceptable)}–${numeroCorto(parametro.maxAceptable)}'
        : 'sin umbral configurado';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoEstado(estado: estado, tamano: 12),
              const SizedBox(width: 6),
              Expanded(child: Text(parametro.nombre, style: tema.textTheme.bodyMedium)),
              Text(
                valorLegible(parametro.ultimoValor, parametro.unidad),
                style: tema.textTheme.titleSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          MedidorRango(parametro: parametro, estado: estado),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(children: [
              if (fuera)
                TextSpan(
                  text: posicion == Posicion.bajo ? '↓ bajo el mínimo · ' : '↑ sobre el máximo · ',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              TextSpan(text: '$rango · ${antiguedadLegible(parametro.antiguedadSegundos(ahora))}'),
            ]),
            style: tema.textTheme.bodySmall?.copyWith(color: fuera ? null : Paleta.tintaApagada),
          ),
        ],
      ),
    );
  }
}

/// Barra con la banda aceptable y un punto en el valor actual.
class MedidorRango extends StatelessWidget {
  final EstadoParametro parametro;
  final EstadoVisual estado;
  const MedidorRango({super.key, required this.parametro, required this.estado});

  @override
  Widget build(BuildContext context) {
    final v = parametro.ultimoValor, min = parametro.minAceptable, max = parametro.maxAceptable;
    if (v == null || min == null || max == null || max <= min) return const SizedBox.shrink();

    // Un tercio del rango de aire a cada lado; se estira si el valor cae lejos.
    final aire = (max - min) * 0.35;
    final desde = (min - aire) < v ? (min - aire) : v;
    final hasta = (max + aire) > v ? (max + aire) : v;
    double pct(double x) => ((x - desde) / (hasta - desde)).clamp(0.0, 1.0);

    final oscuro = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      height: 12,
      child: LayoutBuilder(builder: (context, c) {
        final ancho = c.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 4,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: oscuro ? const Color(0xFF2C2C2A) : const Color(0xFFE4E7E5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Positioned(
              left: ancho * pct(min),
              width: ancho * (pct(max) - pct(min)),
              top: 4,
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: Paleta.normal.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              left: ancho * pct(v) - 6,
              top: 0,
              child: Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: Paleta.deEstado(estado),
                  shape: BoxShape.circle,
                  border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                  boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 3)],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
