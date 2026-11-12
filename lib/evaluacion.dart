/// Reglas de negocio puras (sin Firebase), igual que el dominio del backend
/// Laravel: ReglaUmbral + EvaluarUmbrales. Se prueban en test/.
library;

import 'modelos.dart';

/// Minutos sin reportar tras los que un parámetro se marca sin comunicación.
const minutosSinComunicacion = 15;

/// Evalúa un valor contra el umbral (HU-04).
///
/// `margen` es un margen MÁS ALLÁ del rango aceptable: la alerta es crítica
/// bajo `min − margen` o sobre `max + margen`, porque el pH y la temperatura
/// son peligrosos en ambas direcciones. Devuelve null si está en rango.
Severidad? evaluar(double valor, Umbral? u) {
  if (u == null) return null;
  if (valor < u.min - u.margen || valor > u.max + u.margen) return Severidad.critica;
  if (valor < u.min || valor > u.max) return Severidad.advertencia;
  return null;
}

/// Valor del umbral que se violó (el borde más cercano).
double umbralViolado(double valor, Umbral u) => valor < u.min ? u.min : u.max;

/// Rango físico de cada sensor (RF-04). Fuera de él la lectura delata un
/// instrumento averiado, no una condición del agua, y se descarta.
const rangosFisicos = {
  'od_mgl': (0.0, 20.0),
  'temp_c': (-5.0, 40.0),
  'ph': (0.0, 14.0),
};

bool lecturaValida(String parametro, double valor) {
  final r = rangosFisicos[parametro];
  if (r == null) return false;
  return valor >= r.$1 && valor <= r.$2 && !valor.isNaN;
}

/// Semáforo del estanque = el peor de sus parámetros.
Semaforo semaforoDe(Iterable<Severidad?> severidades) {
  var resultado = Semaforo.normal;
  for (final s in severidades) {
    if (s == Severidad.critica) return Semaforo.critico;
    if (s == Severidad.advertencia) resultado = Semaforo.advertencia;
  }
  return resultado;
}

bool sinComunicacion(DateTime? medidoEn, DateTime ahora) =>
    medidoEn == null || ahora.difference(medidoEn).inMinutes >= minutosSinComunicacion;

/// Umbrales de referencia para trucha arcoíris (Oncorhynchus mykiss).
const umbralesSugeridos = {
  'od_mgl': Umbral(min: 6.5, max: 12, margen: 1.5),
  'temp_c': Umbral(min: 10, max: 16, margen: 2),
  'ph': Umbral(min: 6.5, max: 8.5, margen: 0.5),
};
