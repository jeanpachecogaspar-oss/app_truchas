import 'package:flutter/material.dart';

import '../api.dart';
import '../evaluacion.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';

/// Alta de estanque con sus umbrales (HU-01). Solo rol técnico.
///
/// Un parámetro con sus tres casillas vacías se omite (se configura después);
/// uno a medio llenar es un error, porque dejaría al estanque sin vigilancia
/// por un lado.
class PantallaAltaEstanque extends StatefulWidget {
  final Usuario usuario;
  final VoidCallback alCrear;
  const PantallaAltaEstanque({super.key, required this.usuario, required this.alCrear});

  @override
  State<PantallaAltaEstanque> createState() => _PantallaAltaEstanqueState();
}

class _PantallaAltaEstanqueState extends State<PantallaAltaEstanque> {
  final _codigo = TextEditingController();
  final _volumen = TextEditingController();
  final _biomasa = TextEditingController();
  String? _etapa;

  late final Map<String, List<TextEditingController>> _umbrales = {
    for (final p in parametros) p: [TextEditingController(), TextEditingController(), TextEditingController()],
  };

  bool _enviando = false;
  String? _campoError;
  String? _mensajeError;

  @override
  void dispose() {
    for (final c in [_codigo, _volumen, _biomasa, ..._umbrales.values.expand((l) => l)]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _n(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.'));

  void _fallo(String campo, String mensaje) => setState(() {
        _campoError = campo;
        _mensajeError = mensaje;
      });

  Future<void> _enviar() async {
    setState(() {
      _campoError = null;
      _mensajeError = null;
    });

    final codigo = _codigo.text.trim().toUpperCase();
    if (codigo.isEmpty) {
      _fallo('codigo', 'Indica el código del estanque.');
      return;
    }
    if (!RegExp(r'^[A-Z0-9][A-Z0-9_-]{0,19}$').hasMatch(codigo)) {
      _fallo('codigo', 'Usa solo letras, números y guiones (ej.: EST-05).');
      return;
    }

    final volumen = _n(_volumen);
    if (volumen == null || volumen <= 0) {
      _fallo('volumen_m3', 'El volumen debe ser mayor que cero.');
      return;
    }

    final biomasa = _n(_biomasa);
    if (biomasa == null || biomasa < 0) {
      _fallo('biomasa_kg', 'La biomasa no puede ser negativa.');
      return;
    }

    if (_etapa == null) {
      _fallo('etapa', 'Elige la etapa productiva.');
      return;
    }

    final umbrales = <String, Umbral>{};
    for (final p in parametros) {
      final cs = _umbrales[p]!;
      if (cs.every((c) => c.text.trim().isEmpty)) continue;
      final valores = cs.map(_n).toList();
      if (valores.any((v) => v == null)) {
        _fallo('${p}_min', 'Completa mínimo, máximo y margen crítico, o deja las tres casillas vacías.');
        return;
      }
      if (valores[0]! >= valores[1]!) {
        _fallo('${p}_min', 'El mínimo aceptable debe ser menor que el máximo aceptable.');
        return;
      }
      if (valores[2]! < 0) {
        _fallo('${p}_min', 'El margen crítico no puede ser negativo.');
        return;
      }
      umbrales[p] = Umbral(min: valores[0]!, max: valores[1]!, margen: valores[2]!);
    }

    setState(() => _enviando = true);
    final error = await Api.instancia.crearEstanque(
      EstanqueNuevo(codigo: codigo, volumenM3: volumen, biomasaKg: biomasa, etapa: _etapa!, umbrales: umbrales),
      widget.usuario,
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    if (error != null) {
      _fallo(error.contains('código') ? 'codigo' : 'general', error);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Estanque $codigo registrado'), backgroundColor: Paleta.normal),
    );
    _limpiar();
    widget.alCrear();
  }

  void _limpiar() {
    for (final c in [_codigo, _volumen, _biomasa, ..._umbrales.values.expand((l) => l)]) {
      c.clear();
    }
    setState(() => _etapa = null);
  }

  void _usarSugeridos() {
    umbralesSugeridos.forEach((p, u) {
      final cs = _umbrales[p]!;
      cs[0].text = numeroCorto(u.min);
      cs[1].text = numeroCorto(u.max);
      cs[2].text = numeroCorto(u.margen);
    });
    setState(() {});
  }

  String? _err(String campo) => _campoError == campo ? _mensajeError : null;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    const teclado = TextInputType.numberWithOptions(decimal: true);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Text('Registrar estanque', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 14),
        TextField(
          controller: _codigo,
          textCapitalization: TextCapitalization.characters,
          maxLength: 20,
          decoration: InputDecoration(labelText: 'Código', hintText: 'EST-05', errorText: _err('codigo')),
        ),
        const SizedBox(height: 4),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _volumen,
              keyboardType: teclado,
              decoration:
                  InputDecoration(labelText: 'Volumen', suffixText: 'm³', errorText: _err('volumen_m3')),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _biomasa,
              keyboardType: teclado,
              decoration:
                  InputDecoration(labelText: 'Biomasa', suffixText: 'kg', errorText: _err('biomasa_kg')),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          value: _etapa,
          decoration: InputDecoration(labelText: 'Etapa productiva', errorText: _err('etapa')),
          items: etapas
              .map((e) => DropdownMenuItem(value: e, child: Text(e[0].toUpperCase() + e.substring(1))))
              .toList(),
          onChanged: (v) => setState(() => _etapa = v),
        ),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(
            child: Text('Umbrales', style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
          TextButton.icon(
            onPressed: _usarSugeridos,
            icon: const Icon(Icons.auto_fix_high, size: 18),
            label: const Text('Valores sugeridos'),
          ),
        ]),
        Text(
          'El margen crítico se suma por fuera del rango: la alerta es crítica bajo '
          '«mín − margen» o sobre «máx + margen».',
          style: tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada),
        ),
        const SizedBox(height: 12),
        ...parametros.map((p) {
          final cs = _umbrales[p]!;
          final unidad = unidadesParametro[p]!;
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${etiquetasParametro[p]}${unidad.isEmpty ? '' : ' ($unidad)'}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Row(children: [
                    for (final (i, etiqueta) in const [(0, 'Mínimo'), (1, 'Máximo'), (2, 'Margen')]) ...[
                      if (i > 0) const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: cs[i],
                          keyboardType: teclado,
                          decoration: InputDecoration(labelText: etiqueta),
                        ),
                      ),
                    ],
                  ]),
                  if (_err('${p}_min') != null) ...[
                    const SizedBox(height: 6),
                    Text(_err('${p}_min')!, style: const TextStyle(color: Paleta.critico, fontSize: 12)),
                  ],
                ],
              ),
            ),
          );
        }),
        if (_campoError != null &&
            !['codigo', 'volumen_m3', 'biomasa_kg', 'etapa', ...parametros.map((p) => '${p}_min')]
                .contains(_campoError)) ...[
          Text(_mensajeError ?? '', style: const TextStyle(color: Paleta.critico)),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _enviando ? null : _enviar,
          icon: const Icon(Icons.save),
          label: Text(_enviando ? 'Guardando…' : 'Registrar estanque'),
        ),
      ],
    );
  }
}
