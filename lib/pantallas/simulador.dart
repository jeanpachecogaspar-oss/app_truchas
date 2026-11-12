import 'dart:async';

import 'package:flutter/material.dart';

import '../api.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';

/// Simulador de los nodos IoT (HU-02) mientras no haya sensores instalados.
///
/// Cada ronda envía una lectura por parámetro a cada estanque, igual que el
/// gateway cada 5 minutos. Las lecturas pasan por la misma evaluación de
/// umbrales, así que las alertas se generan de verdad.
class PantallaSimulador extends StatefulWidget {
  final Usuario usuario;
  const PantallaSimulador({super.key, required this.usuario});

  @override
  State<PantallaSimulador> createState() => _PantallaSimuladorState();
}

class _PantallaSimuladorState extends State<PantallaSimulador> {
  bool _enviando = false;
  bool _automatico = false;
  double _anomalias = 0.12;
  Timer? _temporizador;
  final List<(DateTime, String, bool)> _registro = [];

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  Future<void> _ronda() async {
    if (_enviando) return;
    setState(() => _enviando = true);
    try {
      final alertas = await Api.instancia.simularRonda(widget.usuario, probabilidadAnomalia: _anomalias);
      _anotar(alertas == 0 ? 'Ronda enviada: todo en rango.' : 'Ronda enviada: $alertas valor(es) fuera de rango.',
          alertas > 0);
    } catch (e) {
      _anotar('Error: ${Api.instancia.mensajeDeError(e)}', true);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  void _anotar(String texto, bool destacado) {
    if (!mounted) return;
    setState(() {
      _registro.insert(0, (DateTime.now(), texto, destacado));
      if (_registro.length > 30) _registro.removeLast();
    });
  }

  void _cambiarAutomatico(bool v) {
    setState(() => _automatico = v);
    _temporizador?.cancel();
    if (v) {
      _ronda();
      _temporizador = Timer.periodic(const Duration(seconds: 30), (_) => _ronda());
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulador de sensores')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.sensors, color: tema.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text('Nodos IoT simulados',
                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 6),
                Text(
                  'Envía lecturas de oxígeno, temperatura y pH a todos los estanques. '
                  'Si un valor sale del rango, se genera la alerta como en producción.',
                  style: tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada),
                ),
                const SizedBox(height: 16),
                Text('Probabilidad de anomalía: ${(_anomalias * 100).round()} %', style: tema.textTheme.labelLarge),
                Slider(
                  value: _anomalias,
                  min: 0,
                  max: 0.6,
                  divisions: 12,
                  label: '${(_anomalias * 100).round()} %',
                  onChanged: (v) => setState(() => _anomalias = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Envío automático cada 30 s'),
                  subtitle: const Text('Mientras esta pantalla esté abierta'),
                  value: _automatico,
                  onChanged: _cambiarAutomatico,
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _enviando ? null : _ronda,
                    icon: _enviando
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send),
                    label: Text(_enviando ? 'Enviando…' : 'Enviar una ronda ahora'),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 18),
          Text('Registro', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          if (_registro.isEmpty)
            Text('Todavía no se envió ninguna ronda.', style: tema.textTheme.bodySmall)
          else
            Card(
              child: Column(
                children: _registro
                    .map((r) => ListTile(
                          dense: true,
                          leading: Icon(
                            r.$3 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                            color: r.$3 ? Paleta.advertencia : Paleta.normal,
                          ),
                          title: Text(r.$2),
                          trailing: Text(soloHora(r.$1), style: const TextStyle(color: Paleta.tintaApagada)),
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
