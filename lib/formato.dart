import 'package:intl/intl.dart';

import 'modelos.dart';

/// Presentación: cómo se leen los datos en pantalla.

String antiguedadLegible(int? segundos) {
  if (segundos == null) return 'sin lecturas';
  if (segundos < 60) return 'hace instantes';
  final minutos = segundos ~/ 60;
  if (minutos < 60) return 'hace $minutos min';
  final horas = minutos ~/ 60;
  if (horas < 24) return 'hace $horas h';
  return 'hace ${horas ~/ 24} d';
}

final _formatoHora = DateFormat('dd/MM HH:mm', 'es');
final _formatoSoloHora = DateFormat('HH:mm', 'es');

String horaDeFecha(DateTime? fecha) => fecha == null ? '—' : _formatoHora.format(fecha);
String soloHora(DateTime fecha) => _formatoSoloHora.format(fecha);

String valorLegible(double? valor, String? unidad) {
  if (valor == null) return '—';
  final texto = valor.toStringAsFixed(2);
  return (unidad == null || unidad.isEmpty) ? texto : '$texto $unidad';
}

String numeroCorto(double? v) {
  if (v == null) return '—';
  return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

String capitalizar(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Estado visual: forma + color + palabra (nunca solo color).
enum EstadoVisual { normal, advertencia, critico, sinDatos }

const etiquetaEstado = {
  EstadoVisual.normal: 'Normal',
  EstadoVisual.advertencia: 'Advertencia',
  EstadoVisual.critico: 'Crítico',
  EstadoVisual.sinDatos: 'Sin comunicación',
};

EstadoVisual estadoDeSemaforo(Semaforo s) => switch (s) {
      Semaforo.normal => EstadoVisual.normal,
      Semaforo.advertencia => EstadoVisual.advertencia,
      Semaforo.critico => EstadoVisual.critico,
    };

EstadoVisual estadoDeSeveridad(Severidad? s) => switch (s) {
      Severidad.critica => EstadoVisual.critico,
      Severidad.advertencia => EstadoVisual.advertencia,
      null => EstadoVisual.normal,
    };

enum Posicion { bajo, dentro, sobre, desconocida }

Posicion posicionEnRango(EstadoParametro p) {
  final v = p.ultimoValor, min = p.minAceptable, max = p.maxAceptable;
  if (v == null || min == null || max == null) return Posicion.desconocida;
  if (v < min) return Posicion.bajo;
  return v > max ? Posicion.sobre : Posicion.dentro;
}

EstadoVisual estadoDelParametro(EstadoParametro p) {
  if (p.sinComunicacion || p.ultimoValor == null) return EstadoVisual.sinDatos;
  return estadoDeSeveridad(p.severidad);
}

class InfoRol {
  final String nombre;
  final String vista;
  final String enfoque;
  const InfoRol(this.nombre, this.vista, this.enfoque);
}

const roles = {
  Rol.operador: InfoRol('Operador', 'Vista de campo', 'Alertas primero: lo que exige ir al estanque ahora.'),
  Rol.tecnico: InfoRol(
      'Técnico acuícola', 'Vista técnica', 'Estado, tendencias y configuración de estanques y umbrales.'),
  Rol.veterinario: InfoRol('Veterinario', 'Vista sanitaria',
      'Consulta del estado y de las alertas; la intervención la registra el operador.'),
};
