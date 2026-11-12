import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'evaluacion.dart';
import 'modelos.dart';

/// Acceso a Firebase: sesión (Firebase Auth) y datos (Cloud Firestore).
///
/// Reemplaza a la API Laravel. Las reglas que allá vivían en el servidor
/// (umbrales, alertas sin duplicar, cierre con atención) se aplican aquí en
/// transacciones, y los permisos por rol en firestore.rules.
class Api {
  Api._();
  static final Api instancia = Api._();

  FirebaseAuth get _auth => FirebaseAuth.instance;
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usuarios => _db.collection('usuarios');
  CollectionReference<Map<String, dynamic>> get _estanques => _db.collection('estanques');
  CollectionReference<Map<String, dynamic>> get _alertas => _db.collection('alertas');

  CollectionReference<Map<String, dynamic>> _lecturas(String estanqueId, String parametro) =>
      _estanques.doc(estanqueId).collection('series').doc(parametro).collection('lecturas');

  // ── Sesión ───────────────────────────────────────────────────────────────

  /// Perfil del usuario con sesión (null = sin sesión). Se actualiza solo.
  Stream<Usuario?> perfil() {
    late final StreamController<Usuario?> salida;
    StreamSubscription<User?>? subSesion;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? subPerfil;

    salida = StreamController<Usuario?>(
      onListen: () {
        subSesion = _auth.authStateChanges().listen((u) {
          // Al cambiar de sesión se suelta la suscripción al perfil anterior.
          subPerfil?.cancel();
          subPerfil = null;
          if (u == null) {
            salida.add(null);
            return;
          }
          subPerfil = _usuarios.doc(u.uid).snapshots().listen((doc) {
            final datos = doc.data();
            if (datos == null) {
              // Cuenta creada desde la consola sin perfil: entra como operador.
              salida.add(Usuario(
                id: u.uid,
                nombre: u.displayName ?? (u.email ?? '').split('@').first,
                email: u.email ?? '',
                rol: Rol.operador,
              ));
            } else {
              salida.add(Usuario.desdeMapa(u.uid, datos));
            }
          }, onError: salida.addError);
        }, onError: salida.addError);
      },
      onCancel: () async {
        await subPerfil?.cancel();
        await subSesion?.cancel();
      },
    );
    return salida.stream;
  }

  /// Devuelve null si entró, o el mensaje para mostrar.
  Future<String?> iniciarSesion(String email, String clave) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email.trim().toLowerCase(), password: clave);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeAuth(e);
    } catch (_) {
      return 'No se pudo conectar. Revisa tu internet.';
    }
  }

  Future<String?> registrar({
    required String nombre,
    required String email,
    required String clave,
    required Rol rol,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(email: email.trim().toLowerCase(), password: clave);
      await cred.user?.updateDisplayName(nombre);
      await _usuarios.doc(cred.user!.uid).set({
        'nombre': nombre,
        // Debe coincidir con el correo del token (lo exige firestore.rules).
        'email': cred.user!.email ?? email.trim().toLowerCase(),
        'rol': rol.name,
        'creado_en': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeAuth(e);
    } on FirebaseException catch (e) {
      return _mensajeFirestore(e);
    } catch (_) {
      return 'No se pudo crear la cuenta.';
    }
  }

  Future<String?> restablecerClave(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mensajeAuth(e);
    }
  }

  Future<void> cerrarSesion() => _auth.signOut();

  String _mensajeAuth(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => 'El correo no es válido.',
        'user-disabled' => 'Esta cuenta está deshabilitada.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Correo o contraseña incorrectos.',
        'email-already-in-use' => 'Ya existe una cuenta con ese correo.',
        'weak-password' => 'La contraseña debe tener al menos 6 caracteres.',
        'too-many-requests' => 'Demasiados intentos. Espera un momento.',
        'network-request-failed' => 'Sin conexión a internet.',
        'operation-not-allowed' =>
          'El acceso con correo no está activado en Firebase (Authentication → Método de acceso).',
        _ => e.message ?? 'Error de autenticación (${e.code}).',
      };

  String _mensajeFirestore(FirebaseException e) => switch (e.code) {
        'permission-denied' => 'Tu rol no tiene permiso para esta acción.',
        'unavailable' => 'Sin conexión con la base de datos. Se reintentará.',
        'not-found' => 'La base de datos Firestore no existe todavía. Créala en la consola de Firebase.',
        _ => e.message ?? 'Error de base de datos (${e.code}).',
      };

  String mensajeDeError(Object e) =>
      e is FirebaseException ? _mensajeFirestore(e) : e.toString().replaceFirst('Exception: ', '');

  // ── Lectura en tiempo real (HU-03, HU-04) ────────────────────────────────

  Stream<List<Estanque>> estanques() => _estanques
      .orderBy('codigo')
      .snapshots()
      .map((s) => s.docs.map(Estanque.desdeDoc).toList());

  Stream<Estanque?> estanque(String id) =>
      _estanques.doc(id).snapshots().map((d) => d.exists ? Estanque.desdeDoc(d) : null);

  Stream<List<Alerta>> alertasAbiertas() => _alertas
      .where('estado', isEqualTo: 'abierta')
      .snapshots()
      .map((s) => s.docs.map(Alerta.desdeDoc).toList()
        ..sort((a, b) {
          // Críticas primero, y dentro de cada severidad la más reciente.
          final sev = b.severidad.index.compareTo(a.severidad.index);
          return sev != 0 ? sev : b.generadaEn.compareTo(a.generadaEn);
        }));

  Stream<List<Alerta>> alertasAtendidas({int limite = 50}) => _alertas
      .where('estado', isEqualTo: 'atendida')
      .limit(limite)
      .snapshots()
      .map((s) => s.docs.map(Alerta.desdeDoc).toList()
        ..sort((a, b) => (b.atencion?.registradaEn ?? b.generadaEn)
            .compareTo(a.atencion?.registradaEn ?? a.generadaEn)));

  /// Serie de las últimas [horas] horas para el gráfico de tendencia.
  Stream<List<PuntoDeSerie>> serie(String estanqueId, String parametro, {int horas = 24}) {
    final desde = Timestamp.fromDate(DateTime.now().subtract(Duration(hours: horas)));
    return _lecturas(estanqueId, parametro)
        .where('medido_en', isGreaterThanOrEqualTo: desde)
        .orderBy('medido_en')
        .snapshots()
        .map((s) => s.docs
            .map((d) {
              final j = d.data();
              final v = j['valor'], t = j['medido_en'];
              if (v is! num || t is! Timestamp) return null;
              return PuntoDeSerie(valor: v.toDouble(), medidoEn: t.toDate());
            })
            .whereType<PuntoDeSerie>()
            .toList());
  }

  // ── Escrituras (HU-01, HU-02, HU-05) ─────────────────────────────────────

  /// Alta de estanque (HU-01). El código es el id del documento, así no
  /// puede repetirse.
  Future<String?> crearEstanque(EstanqueNuevo e, Usuario usuario) async {
    final ref = _estanques.doc(e.codigo);
    try {
      return await _db.runTransaction<String?>((tx) async {
        final actual = await tx.get(ref);
        if (actual.exists) return 'Ya existe un estanque con el código ${e.codigo}.';
        tx.set(ref, {
          'codigo': e.codigo,
          'volumen_m3': e.volumenM3,
          'biomasa_kg': e.biomasaKg,
          'etapa': e.etapa,
          'umbrales': e.umbrales.map((k, v) => MapEntry(k, v.aMapa())),
          'ultimas': <String, dynamic>{},
          'alertas_abiertas': <String, dynamic>{},
          'creado_por': usuario.id, // RNF-04: escritura auditada
          'creado_en': FieldValue.serverTimestamp(),
        });
        return null;
      });
    } on FirebaseException catch (ex) {
      return _mensajeFirestore(ex);
    }
  }

  /// Registra una lectura y evalúa umbrales (HU-02 + HU-04).
  ///
  /// Si el valor está fuera de rango y ya hay una alerta abierta de ese
  /// parámetro, se actualiza (y se agrava si pasa a crítica) en lugar de
  /// duplicarla. Una alerta NO se cierra sola al volver al rango: se cierra
  /// registrando la intervención (HU-05).
  Future<Severidad?> registrarLectura({
    required String estanqueId,
    required String parametro,
    required double valor,
    required DateTime medidoEn,
    required Usuario usuario,
  }) async {
    if (!lecturaValida(parametro, valor)) return null; // RF-04: se descarta
    final ref = _estanques.doc(estanqueId);

    return _db.runTransaction<Severidad?>((tx) async {
      // En una transacción todas las lecturas van antes que las escrituras.
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('El estanque ya no existe.');
      final e = Estanque.desdeDoc(snap);
      final idAbierta = e.alertasAbiertas[parametro];
      final alertaAbierta = idAbierta == null ? null : await tx.get(_alertas.doc(idAbierta));

      final ts = Timestamp.fromDate(medidoEn);
      tx.set(_lecturas(estanqueId, parametro).doc(), {
        'valor': valor,
        'medido_en': ts,
        'registrado_por': usuario.id,
      });

      final cambios = <String, dynamic>{};
      final previa = e.ultimas[parametro];
      // Una lectura reenviada del búfer, más antigua, no pisa a la última.
      if (previa == null || !medidoEn.isBefore(previa.$2)) {
        cambios['ultimas.$parametro'] = {'valor': valor, 'medido_en': ts};
      }

      final umbral = e.umbrales[parametro];
      final sev = evaluar(valor, umbral);
      if (sev != null && umbral != null) {
        if (alertaAbierta != null && alertaAbierta.exists && alertaAbierta.data()?['estado'] == 'abierta') {
          tx.update(alertaAbierta.reference, {
            'ultimo_valor': valor,
            'actualizada_en': ts,
            if (sev == Severidad.critica) 'severidad': 'critica',
          });
        } else {
          final nueva = _alertas.doc();
          tx.set(nueva, {
            'estanque_id': e.id,
            'estanque_codigo': e.codigo,
            'parametro': parametro,
            'severidad': sev.name,
            'estado': 'abierta',
            'valor_detectado': valor,
            'umbral_violado': umbralViolado(valor, umbral),
            'ultimo_valor': valor,
            'generada_en': ts,
            'actualizada_en': ts,
          });
          cambios['alertas_abiertas.$parametro'] = nueva.id;
        }
      }

      if (cambios.isNotEmpty) tx.update(ref, cambios);
      return sev;
    });
  }

  /// Registra la intervención y cierra la alerta (HU-05).
  Future<ResultadoAtencion> atenderAlerta({
    required Alerta alerta,
    required String accion,
    String? observacion,
    required Usuario usuario,
  }) async {
    final ref = _alertas.doc(alerta.id);
    final refEstanque = _estanques.doc(alerta.estanqueId);
    try {
      return await _db.runTransaction<ResultadoAtencion>((tx) async {
        final snap = await tx.get(ref);
        final est = await tx.get(refEstanque);
        final datos = snap.data();
        if (datos == null) return const AtencionFallida('La alerta ya no existe.');
        if (datos['estado'] != 'abierta') {
          return AtencionYaExistente(Atencion.desdeMapa(datos['atencion']));
        }
        final ahora = DateTime.now();
        final atencion = {
          'accion': accion,
          'observacion': observacion,
          'usuario_id': usuario.id,
          'usuario_nombre': usuario.nombre,
          'registrada_en': Timestamp.fromDate(ahora),
        };
        tx.update(ref, {'estado': 'atendida', 'atencion': atencion, 'actualizada_en': Timestamp.fromDate(ahora)});
        final abiertas = (est.data()?['alertas_abiertas'] as Map?) ?? const {};
        if (est.exists && abiertas[alerta.parametro] == alerta.id) {
          tx.update(refEstanque, {'alertas_abiertas.${alerta.parametro}': FieldValue.delete()});
        }
        return AtencionRegistrada(Atencion(
          accion: accion,
          observacion: observacion,
          usuarioNombre: usuario.nombre,
          registradaEn: ahora,
        ));
      });
    } on FirebaseException catch (e) {
      return AtencionFallida(_mensajeFirestore(e));
    } catch (e) {
      return AtencionFallida(mensajeDeError(e));
    }
  }

  // ── Simulador de nodos IoT (mientras no haya sensores reales) ────────────

  final _azar = Random();

  /// Una ronda de lecturas para todos los estanques: lo que haría el gateway
  /// cada 5 minutos. Con [probabilidadAnomalia] algún valor sale de rango.
  Future<int> simularRonda(Usuario usuario, {double probabilidadAnomalia = 0.12}) async {
    final lista = await _estanques.get();
    var alertas = 0;
    final ahora = DateTime.now();
    for (final doc in lista.docs) {
      final e = Estanque.desdeDoc(doc);
      for (final p in parametros) {
        final u = e.umbrales[p] ?? umbralesSugeridos[p]!;
        final centro = (u.min + u.max) / 2;
        final semi = (u.max - u.min) / 2;
        double valor;
        if (_azar.nextDouble() < probabilidadAnomalia) {
          final exceso = u.margen * (0.3 + _azar.nextDouble() * 1.4);
          valor = _azar.nextBool() ? u.max + exceso : u.min - exceso;
        } else {
          final previo = e.ultimas[p]?.$1 ?? centro;
          // Paseo aleatorio suave hacia el centro del rango.
          valor = previo + (centro - previo) * 0.3 + (_azar.nextDouble() - 0.5) * semi * 0.4;
        }
        final r = rangosFisicos[p]!;
        valor = double.parse(valor.clamp(r.$1, r.$2).toStringAsFixed(2));
        final sev = await registrarLectura(
          estanqueId: e.id,
          parametro: p,
          valor: valor,
          medidoEn: ahora,
          usuario: usuario,
        );
        if (sev != null) alertas++;
      }
    }
    return alertas;
  }

  /// Carga una piscigranja de ejemplo con 24 h de historia: un estanque
  /// normal, uno en advertencia, uno crítico y uno sin comunicación.
  Future<void> cargarDemostracion(Usuario usuario) async {
    final ahora = DateTime.now();
    const paso = Duration(minutes: 20);
    const puntos = 72; // 24 h

    final definicion = [
      ('EST-01', 'engorde', 150.0, 1650.0, 0.0, null),
      ('EST-02', 'juvenil', 90.0, 600.0, 0.3, 'temp_alta'),
      ('EST-03', 'engorde', 180.0, 2100.0, 0.6, 'od_bajo'),
      ('EST-04', 'alevino', 40.0, 120.0, 0.9, 'sin_senal'),
    ];

    final escrituras = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[];

    for (final (codigo, etapa, volumen, biomasa, fase, caso) in definicion) {
      final ref = _estanques.doc(codigo);
      final ultimas = <String, dynamic>{};
      final abiertas = <String, dynamic>{};
      // EST-04 dejó de reportar hace 45 minutos.
      final fin = caso == 'sin_senal' ? ahora.subtract(const Duration(minutes: 45)) : ahora;

      for (final p in parametros) {
        final u = umbralesSugeridos[p]!;
        double ultimoValor = 0;
        DateTime ultimoT = fin;
        for (var i = 0; i < puntos; i++) {
          final t = fin.subtract(paso * (puntos - 1 - i));
          final h = t.hour + t.minute / 60;
          final onda = sin(2 * pi * (h / 24) + fase);
          final ruido = (_azar.nextDouble() - 0.5);
          double v = switch (p) {
            'od_mgl' => 8.6 - 1.1 * onda + ruido * 0.3,
            'temp_c' => 13.0 + 1.6 * onda + ruido * 0.25,
            _ => 7.35 + 0.18 * onda + ruido * 0.06,
          };
          final faltan = puntos - 1 - i; // puntos que faltan para el final
          if (caso == 'od_bajo' && p == 'od_mgl' && faltan < 7) v = 6.4 - (6 - faltan) * 0.3; // hasta ~4.6
          if (caso == 'temp_alta' && p == 'temp_c' && faltan < 9) v = 15.2 + (8 - faltan) * 0.2; // hasta ~16.8
          v = double.parse(v.toStringAsFixed(2));
          escrituras.add((
            ref.collection('series').doc(p).collection('lecturas').doc(),
            {'valor': v, 'medido_en': Timestamp.fromDate(t), 'registrado_por': usuario.id},
          ));
          ultimoValor = v;
          ultimoT = t;
        }
        ultimas[p] = {'valor': ultimoValor, 'medido_en': Timestamp.fromDate(ultimoT)};

        final sev = evaluar(ultimoValor, u);
        if (sev != null) {
          final alerta = _alertas.doc();
          final generada = Timestamp.fromDate(ultimoT.subtract(const Duration(minutes: 40)));
          escrituras.add((
            alerta,
            {
              'estanque_id': codigo,
              'estanque_codigo': codigo,
              'parametro': p,
              'severidad': sev.name,
              'estado': 'abierta',
              'valor_detectado': ultimoValor + (p == 'od_mgl' ? 0.9 : -0.6),
              'umbral_violado': umbralViolado(ultimoValor, u),
              'ultimo_valor': ultimoValor,
              'generada_en': generada,
              'actualizada_en': Timestamp.fromDate(ultimoT),
            },
          ));
          abiertas[p] = alerta.id;
        }
      }

      escrituras.add((
        ref,
        {
          'codigo': codigo,
          'volumen_m3': volumen,
          'biomasa_kg': biomasa,
          'etapa': etapa,
          'umbrales': umbralesSugeridos.map((k, v) => MapEntry(k, v.aMapa())),
          'ultimas': ultimas,
          'alertas_abiertas': abiertas,
          'creado_por': usuario.id,
          'creado_en': FieldValue.serverTimestamp(),
        },
      ));
    }

    // Una alerta ya atendida, para que el historial no empiece vacío.
    final hace6h = Timestamp.fromDate(ahora.subtract(const Duration(hours: 6)));
    escrituras.add((
      _alertas.doc(),
      {
        'estanque_id': 'EST-01',
        'estanque_codigo': 'EST-01',
        'parametro': 'ph',
        'severidad': 'advertencia',
        'estado': 'atendida',
        'valor_detectado': 8.62,
        'umbral_violado': 8.5,
        'ultimo_valor': 8.62,
        'generada_en': hace6h,
        'actualizada_en': Timestamp.fromDate(ahora.subtract(const Duration(hours: 5, minutes: 30))),
        'atencion': {
          'accion': 'Recambio parcial de agua',
          'observacion': 'Se renovó el 20 % del volumen; el pH volvió a 7.9.',
          'usuario_id': usuario.id,
          'usuario_nombre': usuario.nombre,
          'registrada_en': Timestamp.fromDate(ahora.subtract(const Duration(hours: 5, minutes: 30))),
        },
      },
    ));

    // Firestore admite 500 operaciones por lote.
    for (var i = 0; i < escrituras.length; i += 450) {
      final lote = _db.batch();
      for (final (ref, datos) in escrituras.skip(i).take(450)) {
        lote.set(ref, datos);
      }
      await lote.commit();
    }
  }
}
