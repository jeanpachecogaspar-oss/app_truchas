import 'modelos.dart';

/// Detecta alertas que aparecen mientras la app está abierta (RF-07).
///
/// Firestore ya entrega los cambios en tiempo real (reemplaza al MQTT de la
/// web); esto solo distingue cuáles son nuevas para avisar al usuario. La
/// primera lista que llega no se considera «nueva»: es el estado inicial.
class DetectorAlertasNuevas {
  Set<String>? _conocidas;

  List<Alerta> nuevas(List<Alerta> abiertas) {
    final ids = abiertas.map((a) => a.id).toSet();
    final previas = _conocidas;
    _conocidas = ids;
    if (previas == null) return const [];
    return abiertas.where((a) => !previas.contains(a.id)).toList();
  }
}
