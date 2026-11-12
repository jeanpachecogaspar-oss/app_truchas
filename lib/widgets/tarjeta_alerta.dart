import 'package:flutter/material.dart';

import '../api.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import 'distintivo.dart';

/// Una alerta (HU-04). Si está abierta y el rol puede, permite registrar la
/// atención (HU-05); si ya fue atendida, muestra quién hizo qué.
class TarjetaAlerta extends StatelessWidget {
  final Alerta alerta;

  /// null = solo lectura (historial).
  final Usuario? usuario;

  const TarjetaAlerta({super.key, required this.alerta, required this.usuario});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final estado = alerta.abierta ? estadoDeSeveridad(alerta.severidad) : EstadoVisual.normal;
    final color = Paleta.deEstado(estadoDeSeveridad(alerta.severidad));
    final u = usuario;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 5))),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      '${alerta.estanqueCodigo} · ${alerta.nombreParametro}',
                      style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Generada ${horaDeFecha(alerta.generadaEn)}',
                      style: tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada),
                    ),
                  ]),
                ),
                Distintivo(
                  estado: estado,
                  etiqueta: alerta.abierta
                      ? (alerta.severidad == Severidad.critica ? 'Crítica' : 'Advertencia')
                      : 'Atendida',
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(children: [
              _Dato(etiqueta: 'Detectado', valor: valorLegible(alerta.valorDetectado, alerta.unidad), color: color),
              _Dato(etiqueta: 'Umbral', valor: valorLegible(alerta.umbralViolado, alerta.unidad)),
              if (alerta.ultimoValor != alerta.valorDetectado)
                _Dato(etiqueta: 'Último', valor: valorLegible(alerta.ultimoValor, alerta.unidad)),
            ]),
            const SizedBox(height: 12),
            if (alerta.atencion != null)
              _ResumenAtencion(atencion: alerta.atencion!)
            else if (u != null && u.puedeAtender)
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () => mostrarFormularioAtencion(context, alerta, u),
                  icon: const Icon(Icons.task_alt),
                  label: const Text('Registrar atención'),
                ),
              )
            else if (u != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tema.colorScheme.primary.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Tu rol puede consultar la alerta; la intervención la registra el operador o el técnico.',
                  style: tema.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dato extends StatelessWidget {
  final String etiqueta;
  final String valor;
  final Color? color;
  const _Dato({required this.etiqueta, required this.valor, this.color});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Expanded(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(etiqueta, style: tema.textTheme.labelSmall?.copyWith(color: Paleta.tintaApagada)),
        Text(
          valor,
          style: tema.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ]),
    );
  }
}

class _ResumenAtencion extends StatelessWidget {
  final Atencion atencion;
  const _ResumenAtencion({required this.atencion});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Paleta.normal.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.task_alt, size: 18, color: Paleta.normal),
          const SizedBox(width: 6),
          Expanded(child: Text(atencion.accion, style: const TextStyle(fontWeight: FontWeight.w700))),
        ]),
        if (atencion.observacion != null && atencion.observacion!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(atencion.observacion!),
        ],
        const SizedBox(height: 4),
        Text(
          '${atencion.usuarioNombre} · ${horaDeFecha(atencion.registradaEn)}',
          style: tema.textTheme.bodySmall?.copyWith(color: Paleta.tintaApagada),
        ),
      ]),
    );
  }
}

/// Hoja inferior con el formulario de atención.
Future<void> mostrarFormularioAtencion(BuildContext context, Alerta alerta, Usuario usuario) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (hoja) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(hoja).viewInsets.bottom),
      child: _FormularioAtencion(alerta: alerta, usuario: usuario),
    ),
  );
}

class _FormularioAtencion extends StatefulWidget {
  final Alerta alerta;
  final Usuario usuario;
  const _FormularioAtencion({required this.alerta, required this.usuario});

  @override
  State<_FormularioAtencion> createState() => _FormularioAtencionState();
}

class _FormularioAtencionState extends State<_FormularioAtencion> {
  final _accion = TextEditingController();
  final _observacion = TextEditingController();
  bool _enviando = false;
  String? _error;
  ResultadoAtencion? _resultado;

  static const _sugerencias = {
    'od_mgl': ['Aireación manual activada', 'Aireador reparado', 'Reducción de alimento'],
    'temp_c': ['Recambio de agua', 'Sombra instalada', 'Reducción de alimento'],
    'ph': ['Recambio parcial de agua', 'Encalado', 'Revisión del sensor'],
  };

  @override
  void dispose() {
    _accion.dispose();
    _observacion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final accion = _accion.text.trim();
    if (accion.isEmpty) {
      setState(() => _error = 'Indica la acción tomada.');
      return;
    }
    setState(() {
      _enviando = true;
      _error = null;
    });
    final obs = _observacion.text.trim();
    final r = await Api.instancia.atenderAlerta(
      alerta: widget.alerta,
      accion: accion,
      observacion: obs.isEmpty ? null : obs,
      usuario: widget.usuario,
    );
    if (!mounted) return;
    setState(() {
      _enviando = false;
      if (r is AtencionFallida) {
        _error = r.mensaje;
      } else {
        _resultado = r;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final r = _resultado;

    if (r != null) {
      final atencion = switch (r) {
        AtencionRegistrada(:final atencion) => atencion,
        AtencionYaExistente(:final atencion) => atencion,
        AtencionFallida() => null,
      };
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const IconoEstado(estado: EstadoVisual.normal, tamano: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  r is AtencionRegistrada ? 'Intervención registrada' : 'Otra persona ya atendió esta alerta',
                  style: tema.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ]),
            if (atencion != null) ...[
              const SizedBox(height: 14),
              _ResumenAtencion(atencion: atencion),
            ],
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Listo')),
            ),
          ],
        ),
      );
    }

    final sugerencias = _sugerencias[widget.alerta.parametro] ?? const <String>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Registrar atención', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          Text(
            '${widget.alerta.estanqueCodigo} · ${widget.alerta.nombreParametro} · '
            '${valorLegible(widget.alerta.ultimoValor, widget.alerta.unidad)}',
            style: tema.textTheme.bodyMedium?.copyWith(color: Paleta.tintaApagada),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _accion,
            maxLength: 80,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Acción tomada', hintText: 'Aireación manual activada'),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: sugerencias
                .map((s) => ActionChip(label: Text(s), onPressed: () => setState(() => _accion.text = s)))
                .toList(),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _observacion,
            minLines: 2,
            maxLines: 4,
            maxLength: 500,
            decoration: const InputDecoration(
              labelText: 'Observación (opcional)',
              hintText: 'Detalle de lo encontrado y lo hecho',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(color: Paleta.critico)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _enviando ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _enviando ? null : _enviar,
                child: Text(_enviando ? 'Guardando…' : 'Guardar y cerrar alerta'),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
