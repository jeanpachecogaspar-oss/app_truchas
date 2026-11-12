import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets/distintivo.dart';
import '../widgets/grafico_tendencia.dart';
import '../widgets/medidor.dart';
import '../widgets/tarjeta_estanque.dart';

/// Estado en vivo, tendencia de 24 h y últimas lecturas de un estanque.
class PantallaDetalleEstanque extends StatefulWidget {
  final String estanqueId;
  final String codigo;
  const PantallaDetalleEstanque({super.key, required this.estanqueId, required this.codigo});

  @override
  State<PantallaDetalleEstanque> createState() => _PantallaDetalleEstanqueState();
}

class _PantallaDetalleEstanqueState extends State<PantallaDetalleEstanque> {
  late final Stream<Estanque?> _estanque = Api.instancia.estanque(widget.estanqueId);
  String? _parametro;
  Stream<List<PuntoDeSerie>>? _serie;
  DateTime _ahora = DateTime.now();
  Timer? _reloj;

  @override
  void initState() {
    super.initState();
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _ahora = DateTime.now()));
  }

  @override
  void dispose() {
    _reloj?.cancel();
    super.dispose();
  }

  void _elegir(String parametro) {
    if (parametro == _parametro) return;
    setState(() {
      _parametro = parametro;
      _serie = Api.instancia.serie(widget.estanqueId, parametro);
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text('Estanque ${widget.codigo}')),
      body: StreamBuilder<Estanque?>(
        stream: _estanque,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: Text(Api.instancia.mensajeDeError(snap.error!)));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final e = snap.data;
          if (e == null) return const Center(child: Text('Este estanque ya no existe.'));

          // Se abre en el parámetro más comprometido.
          if (_parametro == null) {
            final estados = e.estadoParametros(_ahora);
            final peor = estados.where((p) => p.severidad == Severidad.critica).firstOrNull ??
                estados.where((p) => p.severidad != null).firstOrNull ??
                estados.first;
            _parametro = peor.parametro;
            _serie = Api.instancia.serie(widget.estanqueId, peor.parametro);
          }
          final p = e.estadoParametros(_ahora).firstWhere((x) => x.parametro == _parametro);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TarjetaEstanque(estanque: e, ahora: _ahora),
              const SizedBox(height: 22),
              Text('Calidad del agua ahora',
                  style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('Toca un medidor para ver su tendencia',
                  style: tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada)),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // El pH primero: es el parámetro central del proyecto.
                  for (final (i, clave) in const ['ph', 'od_mgl', 'temp_c'].indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: MedidorParametro(
                        parametro: e.estadoParametros(_ahora).firstWhere((x) => x.parametro == clave),
                        seleccionado: _parametro == clave,
                        alTocar: () => _elegir(clave),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              Text('Tendencia · últimas 24 h',
                  style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const ['ph', 'od_mgl', 'temp_c']
                    .map((x) => ButtonSegment(value: x, label: Text(etiquetasCortas[x]!)))
                    .toList(),
                selected: {_parametro!},
                onSelectionChanged: (s) => _elegir(s.first),
              ),
              const SizedBox(height: 14),
              StreamBuilder<List<PuntoDeSerie>>(
                stream: _serie,
                builder: (context, serie) {
                  final puntos = serie.data;
                  return Column(children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 18, 16, 8),
                        child: serie.hasError
                            ? SizedBox(
                                height: 220,
                                child: Center(child: Text(Api.instancia.mensajeDeError(serie.error!))))
                            : puntos == null
                                ? const SizedBox(height: 220, child: Center(child: CircularProgressIndicator()))
                                : GraficoTendencia(
                                    puntos: puntos,
                                    parametro: p.parametro,
                                    unidad: p.unidad,
                                    umbral: p.umbral,
                                  ),
                      ),
                    ),
                    if (puntos != null && puntos.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _Estadisticas(puntos: puntos, unidad: p.unidad),
                      const SizedBox(height: 18),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Últimas lecturas',
                            style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(height: 8),
                      Card(
                        child: Column(
                          children: puntos.reversed.take(20).map((punto) {
                            final fuera = (p.minAceptable != null && punto.valor < p.minAceptable!) ||
                                (p.maxAceptable != null && punto.valor > p.maxAceptable!);
                            return ListTile(
                              dense: true,
                              leading: IconoEstado(
                                estado: fuera ? EstadoVisual.advertencia : EstadoVisual.normal,
                                tamano: 16,
                              ),
                              title: Text(
                                valorLegible(punto.valor, p.unidad),
                                style: TextStyle(fontWeight: fuera ? FontWeight.w800 : FontWeight.w500),
                              ),
                              trailing: Text(horaDeFecha(punto.medidoEn),
                                  style: const TextStyle(color: Paleta.tintaApagada)),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ]);
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Estadisticas extends StatelessWidget {
  final List<PuntoDeSerie> puntos;
  final String unidad;
  const _Estadisticas({required this.puntos, required this.unidad});

  @override
  Widget build(BuildContext context) {
    final valores = puntos.map((p) => p.valor).toList();
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    final promedio = valores.reduce((a, b) => a + b) / valores.length;
    Widget celda(String t, double v) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t, style: const TextStyle(fontSize: 11, color: Paleta.tintaApagada)),
                Text(valorLegible(v, unidad), style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        );
    return Row(children: [
      celda('Mínimo', minimo),
      const SizedBox(width: 8),
      celda('Promedio', promedio),
      const SizedBox(width: 8),
      celda('Máximo', maximo),
    ]);
  }
}
