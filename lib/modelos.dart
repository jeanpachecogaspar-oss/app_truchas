/// Modelo de datos sobre Cloud Firestore.
///
/// Colecciones:
///   usuarios/{uid}                              nombre, email, rol
///   estanques/{id}                              codigo, volumen_m3, biomasa_kg, etapa,
///                                               umbrales{param:{min,max,margen}},
///                                               ultimas{param:{valor,medido_en}},
///                                               alertas_abiertas{param: alertaId}
///   estanques/{id}/series/{param}/lecturas/{id} valor, medido_en
///   alertas/{id}                                estanque_id, estanque_codigo, parametro,
///                                               severidad, estado, valor_detectado,
///                                               umbral_violado, ultimo_valor,
///                                               generada_en, actualizada_en, atencion{...}
library;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'evaluacion.dart';

enum Rol { operador, tecnico, veterinario }

enum Semaforo { normal, advertencia, critico }

enum Severidad { advertencia, critica }

const etapas = ['alevino', 'juvenil', 'engorde', 'cosecha'];

/// Parámetros vigilados en el PMV (el amonio queda para el Incremento 2).
const parametros = ['od_mgl', 'temp_c', 'ph'];

const etiquetasParametro = {
  'od_mgl': 'Oxígeno disuelto',
  'temp_c': 'Temperatura',
  'ph': 'pH',
};

const etiquetasCortas = {'od_mgl': 'OD', 'temp_c': 'Temp.', 'ph': 'pH'};

const unidadesParametro = {'od_mgl': 'mg/L', 'temp_c': '°C', 'ph': ''};

double? _numONulo(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

double _num(Object? v) => _numONulo(v) ?? 0;

DateTime? _fecha(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is String) return DateTime.tryParse(v)?.toLocal();
  return null;
}

Map<String, dynamic> _mapa(Object? v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

Rol rolDesde(Object? v) => Rol.values.firstWhere((r) => r.name == v, orElse: () => Rol.operador);

Severidad? severidadDesde(Object? v) {
  for (final s in Severidad.values) {
    if (s.name == v) return s;
  }
  return null;
}

class Usuario {
  final String id;
  final String nombre;
  final String email;
  final Rol rol;

  const Usuario({required this.id, required this.nombre, required this.email, required this.rol});

  factory Usuario.desdeMapa(String id, Map<String, dynamic> j) => Usuario(
        id: id,
        nombre: (j['nombre'] ?? '').toString(),
        email: (j['email'] ?? '').toString(),
        rol: rolDesde(j['rol']),
      );

  bool get puedeAtender => rol == Rol.operador || rol == Rol.tecnico;
  bool get esTecnico => rol == Rol.tecnico;

  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first[0].toUpperCase();
    return (partes[0][0] + partes[1][0]).toUpperCase();
  }
}

class Umbral {
  final double min;
  final double max;
  final double margen;

  const Umbral({required this.min, required this.max, required this.margen});

  static Umbral? desdeMapa(Object? v) {
    final m = _mapa(v);
    final min = _numONulo(m['min']), max = _numONulo(m['max']);
    if (min == null || max == null) return null;
    return Umbral(min: min, max: max, margen: _num(m['margen']));
  }

  Map<String, dynamic> aMapa() => {'min': min, 'max': max, 'margen': margen};
}

/// Estado de un parámetro en un estanque, calculado en el cliente a partir de
/// la última lectura y el umbral (equivale a EstadoParametro de la API).
class EstadoParametro {
  final String parametro;
  final double? ultimoValor;
  final DateTime? medidoEn;
  final Umbral? umbral;
  final bool sinComunicacion;
  final Severidad? severidad;

  const EstadoParametro({
    required this.parametro,
    this.ultimoValor,
    this.medidoEn,
    this.umbral,
    this.sinComunicacion = false,
    this.severidad,
  });

  String get nombre => etiquetasParametro[parametro] ?? parametro;
  String get unidad => unidadesParametro[parametro] ?? '';
  double? get minAceptable => umbral?.min;
  double? get maxAceptable => umbral?.max;
  int? antiguedadSegundos(DateTime ahora) => medidoEn == null ? null : ahora.difference(medidoEn!).inSeconds;
}

class Estanque {
  final String id;
  final String codigo;
  final double volumenM3;
  final double biomasaKg;
  final String etapa;
  final Map<String, Umbral> umbrales;
  final Map<String, (double, DateTime)> ultimas;
  final Map<String, String> alertasAbiertas;

  const Estanque({
    required this.id,
    required this.codigo,
    required this.volumenM3,
    required this.biomasaKg,
    required this.etapa,
    required this.umbrales,
    required this.ultimas,
    required this.alertasAbiertas,
  });

  factory Estanque.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    final umbrales = <String, Umbral>{};
    _mapa(j['umbrales']).forEach((k, v) {
      final u = Umbral.desdeMapa(v);
      if (u != null) umbrales[k] = u;
    });
    final ultimas = <String, (double, DateTime)>{};
    _mapa(j['ultimas']).forEach((k, v) {
      final m = _mapa(v);
      final valor = _numONulo(m['valor']);
      final fecha = _fecha(m['medido_en']);
      if (valor != null && fecha != null) ultimas[k] = (valor, fecha);
    });
    return Estanque(
      id: doc.id,
      codigo: (j['codigo'] ?? '').toString(),
      volumenM3: _num(j['volumen_m3']),
      biomasaKg: _num(j['biomasa_kg']),
      etapa: (j['etapa'] ?? '').toString(),
      umbrales: umbrales,
      ultimas: ultimas,
      alertasAbiertas: _mapa(j['alertas_abiertas']).map((k, v) => MapEntry(k, v.toString())),
    );
  }

  /// Estado de cada parámetro vigilado en este momento.
  List<EstadoParametro> estadoParametros(DateTime ahora) => parametros.map((p) {
        final u = ultimas[p];
        final umbral = umbrales[p];
        return EstadoParametro(
          parametro: p,
          ultimoValor: u?.$1,
          medidoEn: u?.$2,
          umbral: umbral,
          sinComunicacion: sinComunicacion(u?.$2, ahora),
          severidad: u == null ? null : evaluar(u.$1, umbral),
        );
      }).toList();

  /// Sin comunicación si ningún parámetro reporta en el plazo.
  bool incomunicado(DateTime ahora) =>
      parametros.every((p) => sinComunicacion(ultimas[p]?.$2, ahora));

  Semaforo semaforo(DateTime ahora) => semaforoDe(estadoParametros(ahora).map((e) => e.severidad));
}

class Atencion {
  final String accion;
  final String? observacion;
  final String usuarioNombre;
  final DateTime? registradaEn;

  const Atencion({required this.accion, this.observacion, required this.usuarioNombre, this.registradaEn});

  static Atencion? desdeMapa(Object? v) {
    final m = _mapa(v);
    if (m['accion'] == null) return null;
    return Atencion(
      accion: m['accion'].toString(),
      observacion: m['observacion']?.toString(),
      usuarioNombre: (m['usuario_nombre'] ?? '').toString(),
      registradaEn: _fecha(m['registrada_en']),
    );
  }
}

class Alerta {
  final String id;
  final String estanqueId;
  final String estanqueCodigo;
  final String parametro;
  final Severidad severidad;
  final String estado;
  final double valorDetectado;
  final double umbralViolado;
  final double ultimoValor;
  final DateTime generadaEn;
  final Atencion? atencion;

  const Alerta({
    required this.id,
    required this.estanqueId,
    required this.estanqueCodigo,
    required this.parametro,
    required this.severidad,
    required this.estado,
    required this.valorDetectado,
    required this.umbralViolado,
    required this.ultimoValor,
    required this.generadaEn,
    this.atencion,
  });

  factory Alerta.desdeDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final j = doc.data() ?? const {};
    return Alerta(
      id: doc.id,
      estanqueId: (j['estanque_id'] ?? '').toString(),
      estanqueCodigo: (j['estanque_codigo'] ?? '').toString(),
      parametro: (j['parametro'] ?? '').toString(),
      severidad: severidadDesde(j['severidad']) ?? Severidad.advertencia,
      estado: (j['estado'] ?? 'abierta').toString(),
      valorDetectado: _num(j['valor_detectado']),
      umbralViolado: _num(j['umbral_violado']),
      ultimoValor: _num(j['ultimo_valor'] ?? j['valor_detectado']),
      generadaEn: _fecha(j['generada_en']) ?? DateTime.now(),
      atencion: Atencion.desdeMapa(j['atencion']),
    );
  }

  bool get abierta => estado == 'abierta';
  String get nombreParametro => etiquetasParametro[parametro] ?? parametro;
  String get unidad => unidadesParametro[parametro] ?? '';
}

class PuntoDeSerie {
  final double valor;
  final DateTime medidoEn;
  const PuntoDeSerie({required this.valor, required this.medidoEn});
}

class EstanqueNuevo {
  final String codigo;
  final double volumenM3;
  final double biomasaKg;
  final String etapa;
  final Map<String, Umbral> umbrales;

  const EstanqueNuevo({
    required this.codigo,
    required this.volumenM3,
    required this.biomasaKg,
    required this.etapa,
    required this.umbrales,
  });
}

/// Resultado de registrar una atención: «ya atendida» no es un error del app,
/// es información que el operador debe ver (CP-10).
sealed class ResultadoAtencion {
  const ResultadoAtencion();
}

class AtencionRegistrada extends ResultadoAtencion {
  final Atencion atencion;
  const AtencionRegistrada(this.atencion);
}

class AtencionYaExistente extends ResultadoAtencion {
  final Atencion? atencion;
  const AtencionYaExistente(this.atencion);
}

class AtencionFallida extends ResultadoAtencion {
  final String mensaje;
  const AtencionFallida(this.mensaje);
}
