import 'package:flutter_test/flutter_test.dart';
import 'package:sippt_movil/escucha_alertas.dart';
import 'package:sippt_movil/evaluacion.dart';
import 'package:sippt_movil/formato.dart';
import 'package:sippt_movil/modelos.dart';

void main() {
  const od = Umbral(min: 6.5, max: 12, margen: 1.5);

  group('evaluar (HU-04)', () {
    test('dentro del rango no alerta', () => expect(evaluar(8, od), isNull));
    test('en el borde no alerta', () => expect(evaluar(6.5, od), isNull));
    test('bajo el mínimo es advertencia', () => expect(evaluar(6, od), Severidad.advertencia));
    test('más allá del margen es crítica', () => expect(evaluar(4.9, od), Severidad.critica));
    test('también por arriba', () => expect(evaluar(13.6, od), Severidad.critica));
    test('sin umbral no evalúa', () => expect(evaluar(1, null), isNull));
    test('umbral violado es el borde más cercano', () {
      expect(umbralViolado(5, od), 6.5);
      expect(umbralViolado(13, od), 12);
    });
  });

  group('calidad de lectura (RF-04)', () {
    test('valor físico imposible se descarta', () => expect(lecturaValida('ph', 15), isFalse));
    test('valor posible se acepta', () => expect(lecturaValida('ph', 7.2), isTrue));
  });

  group('semáforo', () {
    test('el peor manda', () {
      expect(semaforoDe([null, Severidad.advertencia, Severidad.critica]), Semaforo.critico);
      expect(semaforoDe([null, Severidad.advertencia]), Semaforo.advertencia);
      expect(semaforoDe([null, null]), Semaforo.normal);
    });
    test('sin comunicación tras 15 min', () {
      final ahora = DateTime(2026, 11, 5, 12);
      expect(sinComunicacion(ahora.subtract(const Duration(minutes: 14)), ahora), isFalse);
      expect(sinComunicacion(ahora.subtract(const Duration(minutes: 15)), ahora), isTrue);
      expect(sinComunicacion(null, ahora), isTrue);
    });
  });

  group('antiguedadLegible', () {
    test('sin lecturas', () => expect(antiguedadLegible(null), 'sin lecturas'));
    test('segundos', () => expect(antiguedadLegible(30), 'hace instantes'));
    test('minutos', () => expect(antiguedadLegible(16 * 60), 'hace 16 min'));
    test('horas', () => expect(antiguedadLegible(3 * 3600), 'hace 3 h'));
    test('días', () => expect(antiguedadLegible(2 * 86400), 'hace 2 d'));
  });

  test('estado visual: sin comunicación desplaza al valor', () {
    const p = EstadoParametro(parametro: 'od_mgl', ultimoValor: 4, umbral: od, sinComunicacion: true, severidad: Severidad.critica);
    expect(estadoDelParametro(p), EstadoVisual.sinDatos);
  });

  test('detector: la primera lista no es «nueva», las siguientes sí', () {
    Alerta a(String id) => Alerta(
          id: id,
          estanqueId: 'EST-01',
          estanqueCodigo: 'EST-01',
          parametro: 'od_mgl',
          severidad: Severidad.critica,
          estado: 'abierta',
          valorDetectado: 4,
          umbralViolado: 6.5,
          ultimoValor: 4,
          generadaEn: DateTime(2026),
        );
    final d = DetectorAlertasNuevas();
    expect(d.nuevas([a('1')]), isEmpty);
    expect(d.nuevas([a('1'), a('2')]).map((x) => x.id), ['2']);
  });
}
