import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'modelos.dart';

/// Notificaciones del sistema para alertas nuevas (plan gratuito de Firebase).
///
/// Llegan mientras la app está abierta o en segundo plano reciente; con la app
/// cerrada del todo no, porque eso exige Cloud Functions + FCM (plan Blaze).
/// El código nativo está en android/.../MainActivity.kt.
class Notificaciones {
  static const _canal = MethodChannel('sippt/notificaciones');

  static bool get _disponible => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> pedirPermiso() async {
    if (!_disponible) return;
    try {
      await _canal.invokeMethod('pedirPermiso');
    } catch (_) {
      // Sin canal nativo (pruebas, otra plataforma): no hay notificación.
    }
  }

  static Future<void> alerta(Alerta a) async {
    if (!_disponible) return;
    final critica = a.severidad == Severidad.critica;
    final valor = a.unidad.isEmpty
        ? a.valorDetectado.toStringAsFixed(2)
        : '${a.valorDetectado.toStringAsFixed(2)} ${a.unidad}';
    try {
      await _canal.invokeMethod('mostrar', {
        // Un id estable por alerta: si se repite, Android la reemplaza.
        'id': a.id.hashCode & 0x7fffffff,
        'titulo': '${critica ? '⚠ Alerta crítica' : 'Alerta'} · ${a.estanqueCodigo}',
        'texto': '${a.nombreParametro} en $valor (umbral ${a.umbralViolado.toStringAsFixed(2)}). '
            'Toca para registrar la atención.',
        'critica': critica,
      });
    } catch (_) {}
  }
}
