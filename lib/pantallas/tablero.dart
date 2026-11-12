import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api.dart';
import '../escucha_alertas.dart';
import '../formato.dart';
import '../modelos.dart';
import '../notificaciones.dart';
import '../tema.dart';
import '../widgets/resumen.dart';
import '../widgets/tarjeta_alerta.dart';
import '../widgets/tarjeta_estanque.dart';
import '../widgets/trucha.dart';
import 'alta_estanque.dart';
import 'detalle_estanque.dart';
import 'simulador.dart';

enum _Pestana { alertas, estanques, nuevo }

/// Pantalla operativa (HU-03). El orden de las pestañas responde a la
/// pregunta de cada rol, igual que el orden de secciones en la web.
class PantallaTablero extends StatefulWidget {
  final Usuario usuario;
  const PantallaTablero({super.key, required this.usuario});

  @override
  State<PantallaTablero> createState() => _PantallaTableroState();
}

class _PantallaTableroState extends State<PantallaTablero> {
  List<Estanque> _estanques = const [];
  List<Alerta> _alertas = const [];
  bool _cargandoEstanques = true;
  bool _cargandoAlertas = true;
  String? _error;
  DateTime _ahora = DateTime.now();
  int _indice = 0;
  bool _verAtendidas = false;
  bool _cargandoDemo = false;

  StreamSubscription<List<Estanque>>? _subEstanques;
  StreamSubscription<List<Alerta>>? _subAlertas;
  Timer? _reloj;
  final _detector = DetectorAlertasNuevas();

  Usuario get _u => widget.usuario;

  List<_Pestana> get _pestanas => switch (_u.rol) {
        Rol.operador => const [_Pestana.alertas, _Pestana.estanques],
        Rol.tecnico => const [_Pestana.alertas, _Pestana.estanques, _Pestana.nuevo],
        Rol.veterinario => const [_Pestana.estanques, _Pestana.alertas],
      };

  @override
  void initState() {
    super.initState();
    _subEstanques = Api.instancia.estanques().listen(
      (lista) => setState(() {
        _estanques = lista;
        _cargandoEstanques = false;
        _error = null;
      }),
      onError: (Object e) => setState(() {
        _cargandoEstanques = false;
        _error = Api.instancia.mensajeDeError(e);
      }),
    );
    _subAlertas = Api.instancia.alertasAbiertas().listen(
      (lista) {
        final nuevas = _detector.nuevas(lista);
        setState(() {
          _alertas = lista;
          _cargandoAlertas = false;
        });
        if (nuevas.isNotEmpty) _avisar(nuevas);
      },
      onError: (Object e) => setState(() {
        _cargandoAlertas = false;
        _error = Api.instancia.mensajeDeError(e);
      }),
    );
    // Android 13+ exige pedir permiso para mostrar notificaciones.
    Notificaciones.pedirPermiso();
    // La antigüedad y el «sin comunicación» dependen de la hora: se recalculan.
    _reloj = Timer.periodic(const Duration(seconds: 30), (_) => setState(() => _ahora = DateTime.now()));
  }

  @override
  void dispose() {
    _subEstanques?.cancel();
    _subAlertas?.cancel();
    _reloj?.cancel();
    super.dispose();
  }

  void _avisar(List<Alerta> nuevas) {
    // Notificación del sistema (se ve también con la app en segundo plano).
    for (final a in nuevas.take(5)) {
      Notificaciones.alerta(a);
    }
    HapticFeedback.heavyImpact();
    final critica = nuevas.any((a) => a.severidad == Severidad.critica);
    final primera = nuevas.first;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: critica ? Paleta.critico : const Color(0xFFB7791F),
      duration: const Duration(seconds: 6),
      content: Text(nuevas.length == 1
          ? '${critica ? 'Alerta crítica' : 'Nueva alerta'}: ${primera.estanqueCodigo} · ${primera.nombreParametro}'
          : '${nuevas.length} alertas nuevas'),
      action: SnackBarAction(
        label: 'Ver',
        textColor: Colors.white,
        onPressed: () => setState(() {
          _indice = _pestanas.indexOf(_Pestana.alertas);
          _verAtendidas = false;
        }),
      ),
    ));
  }

  Future<void> _cargarDemostracion() async {
    setState(() => _cargandoDemo = true);
    try {
      await Api.instancia.cargarDemostracion(_u);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Piscigranja de ejemplo cargada: 4 estanques con 24 h de lecturas.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(Api.instancia.mensajeDeError(e)), backgroundColor: Paleta.critico),
      );
    } finally {
      if (mounted) setState(() => _cargandoDemo = false);
    }
  }

  Future<void> _menuPerfil() async {
    final info = roles[_u.rol]!;
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Paleta.acento(_u.rol),
              child: Text(_u.iniciales, style: const TextStyle(color: Colors.white)),
            ),
            title: Text(_u.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${info.nombre} · ${_u.email}'),
          ),
          const Divider(),
          if (_u.esTecnico)
            ListTile(
              leading: const Icon(Icons.sensors),
              title: const Text('Simulador de sensores'),
              subtitle: const Text('Envía lecturas como lo harían los nodos IoT'),
              onTap: () => Navigator.pop(c, 'simulador'),
            ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Acerca de SIPPT'),
            onTap: () => Navigator.pop(c, 'acerca'),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: Paleta.critico),
            title: const Text('Cerrar sesión', style: TextStyle(color: Paleta.critico)),
            onTap: () => Navigator.pop(c, 'salir'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!mounted) return;
    switch (opcion) {
      case 'simulador':
        Navigator.push(context, MaterialPageRoute(builder: (_) => PantallaSimulador(usuario: _u)));
      case 'acerca':
        showAboutDialog(
          context: context,
          applicationName: 'SIPPT',
          applicationVersion: '1.0.0',
          applicationIcon: const Trucha(ancho: 64),
          children: const [
            Text('Sistema Inteligente para la Optimización de la Producción Piscícola de Trucha.\n\n'
                'Procesos de Software (ASUC01702) — Universidad Continental, Huancayo.'),
          ],
        );
      case 'salir':
        await Api.instancia.cerrarSesion();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pestanas = _pestanas;
    if (_indice >= pestanas.length) _indice = 0;
    final actual = pestanas[_indice];

    return Scaffold(
      body: actual == _Pestana.nuevo
          ? SafeArea(
              child: PantallaAltaEstanque(
                usuario: _u,
                alCrear: () => setState(() => _indice = _pestanas.indexOf(_Pestana.estanques)),
              ),
            )
          : _contenido(actual),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indice,
        onDestinationSelected: (i) => setState(() => _indice = i),
        destinations: pestanas.map((p) {
          return switch (p) {
            _Pestana.alertas => NavigationDestination(
                icon: Badge(
                  isLabelVisible: _alertas.isNotEmpty,
                  label: Text('${_alertas.length}'),
                  backgroundColor: Paleta.critico,
                  child: const Icon(Icons.notifications_outlined),
                ),
                selectedIcon: Badge(
                  isLabelVisible: _alertas.isNotEmpty,
                  label: Text('${_alertas.length}'),
                  backgroundColor: Paleta.critico,
                  child: const Icon(Icons.notifications),
                ),
                label: 'Alertas',
              ),
            _Pestana.estanques => const NavigationDestination(
                icon: Icon(Icons.water_outlined),
                selectedIcon: Icon(Icons.water),
                label: 'Estanques',
              ),
            _Pestana.nuevo => const NavigationDestination(
                icon: Icon(Icons.add_box_outlined),
                selectedIcon: Icon(Icons.add_box),
                label: 'Nuevo',
              ),
          };
        }).toList(),
      ),
    );
  }

  Widget _contenido(_Pestana actual) {
    final criticos = _estanques.where((e) => e.semaforo(_ahora) == Semaforo.critico).length;
    final incomunicados = _estanques.where((e) => e.incomunicado(_ahora)).length;
    final cargando = _cargandoEstanques || _cargandoAlertas;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _Cabecera(
            usuario: _u,
            alTocarPerfil: _menuPerfil,
            resumen: ResumenTablero(
              cargando: cargando,
              estanques: _estanques.length,
              alertas: _alertas.length,
              criticos: criticos,
              incomunicados: incomunicados,
            ),
          ),
        ),
        if (_error != null)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Aviso(icono: Icons.cloud_off, texto: _error!, color: Paleta.critico),
            ),
          ),
        if (cargando) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
              child: _Titulo(actual == _Pestana.alertas ? 'Alertas abiertas' : 'Estado de los estanques'),
            ),
          ),
          SliverToBoxAdapter(
            child: Semantics(
              label: actual == _Pestana.alertas ? 'Cargando alertas' : 'Cargando estanques',
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _Esqueletos(cantidad: 3),
              ),
            ),
          ),
        ]
        else if (actual == _Pestana.alertas)
          ..._seccionAlertas()
        else
          ..._seccionEstanques(),
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
      ],
    );
  }

  List<Widget> _seccionAlertas() {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: Row(children: [
            Expanded(child: _Titulo(_verAtendidas ? 'Historial de atenciones' : 'Alertas abiertas')),
            SegmentedButton<bool>(
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: false, label: Text('Abiertas')),
                ButtonSegment(value: true, label: Text('Atendidas')),
              ],
              selected: {_verAtendidas},
              onSelectionChanged: (s) => setState(() => _verAtendidas = s.first),
            ),
          ]),
        ),
      ),
      if (_verAtendidas)
        SliverToBoxAdapter(child: _Historial(ahora: _ahora))
      else if (_alertas.isEmpty)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _Aviso(
              icono: Icons.check_circle_outline,
              texto: 'Ninguna alerta abierta. Todos los parámetros están dentro de rango.',
              color: Paleta.normal,
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.separated(
            itemCount: _alertas.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _AparecerSuave(
              key: ValueKey('alerta-${_alertas[i].id}'),
              retraso: i,
              child: TarjetaAlerta(alerta: _alertas[i], usuario: _u),
            ),
          ),
        ),
    ];
  }

  List<Widget> _seccionEstanques() {
    if (_estanques.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _EstadoVacio(
              esTecnico: _u.esTecnico,
              cargando: _cargandoDemo,
              alCargarDemo: _cargarDemostracion,
              alNuevo: () => setState(() => _indice = _pestanas.indexOf(_Pestana.nuevo)),
            ),
          ),
        ),
      ];
    }
    // El crítico primero: es el que necesita al operador.
    int peso(Estanque e) {
      final s = e.semaforo(_ahora);
      if (s == Semaforo.critico) return 3;
      if (e.incomunicado(_ahora)) return 2;
      if (s == Semaforo.advertencia) return 1;
      return 0;
    }

    final ordenados = [..._estanques]..sort((a, b) => peso(b).compareTo(peso(a)));
    return [
      const SliverToBoxAdapter(
        child: Padding(padding: EdgeInsets.fromLTRB(16, 18, 16, 10), child: _Titulo('Estado de los estanques')),
      ),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverList.separated(
          itemCount: ordenados.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final e = ordenados[i];
            return _AparecerSuave(
              key: ValueKey('estanque-${e.id}'),
              retraso: i,
              child: TarjetaEstanque(
                estanque: e,
                ahora: _ahora,
                alTocar: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => PantallaDetalleEstanque(estanqueId: e.id, codigo: e.codigo)),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }
}

/// Cabecera con degradado de agua, saludo, rol y resumen.
class _Cabecera extends StatelessWidget {
  final Usuario usuario;
  final VoidCallback alTocarPerfil;
  final Widget resumen;
  const _Cabecera({required this.usuario, required this.alTocarPerfil, required this.resumen});

  @override
  Widget build(BuildContext context) {
    final info = roles[usuario.rol]!;
    final acento = Paleta.acento(usuario.rol);
    final hora = DateTime.now().hour;
    final saludo = hora < 12 ? 'Buenos días' : (hora < 19 ? 'Buenas tardes' : 'Buenas noches');
    final nombre = usuario.nombre.split(' ').first;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Paleta.aguaProfunda, Color.lerp(Paleta.aguaMedia, acento, 0.35)!],
        ),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Trucha(ancho: 46, angulo: -0.15),
                const SizedBox(width: 8),
                const Text('SIPPT',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 4, fontSize: 16)),
                const Spacer(),
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: alTocarPerfil,
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: Text(usuario.iniciales,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text('$saludo, $nombre',
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text('${info.nombre} · ${info.vista}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 8),
                const _EnVivo(),
              ]),
              const SizedBox(height: 8),
              Text(info.enfoque, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 13)),
              const SizedBox(height: 14),
              resumen,
            ],
          ),
        ),
      ),
    );
  }
}

/// Punto que late: los datos llegan en tiempo real desde Firestore.
class _EnVivo extends StatefulWidget {
  const _EnVivo();
  @override
  State<_EnVivo> createState() => _EnVivoState();
}

class _EnVivoState extends State<_EnVivo> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      FadeTransition(
        opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
        child: Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(color: Color(0xFF4ADE80), shape: BoxShape.circle),
        ),
      ),
      const SizedBox(width: 5),
      const Text('En vivo', style: TextStyle(color: Colors.white, fontSize: 12)),
    ]);
  }
}

class _Historial extends StatefulWidget {
  final DateTime ahora;
  const _Historial({required this.ahora});

  @override
  State<_Historial> createState() => _HistorialState();
}

class _HistorialState extends State<_Historial> {
  // Se crea una vez: si se creara en build, cada refresco reabriría la consulta.
  late final Stream<List<Alerta>> _atendidas = Api.instancia.alertasAtendidas();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Alerta>>(
      stream: _atendidas,
      builder: (context, snap) {
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _Aviso(icono: Icons.error_outline, texto: Api.instancia.mensajeDeError(snap.error!), color: Paleta.critico),
          );
        }
        if (!snap.hasData) {
          return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
        }
        final lista = snap.data!;
        if (lista.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: _Aviso(icono: Icons.history, texto: 'Todavía no se registró ninguna atención.', color: Paleta.sinDatos),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: lista
                .map((a) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: TarjetaAlerta(alerta: a, usuario: null),
                    ))
                .toList(),
          ),
        );
      },
    );
  }
}

class _EstadoVacio extends StatelessWidget {
  final bool esTecnico;
  final bool cargando;
  final VoidCallback alCargarDemo;
  final VoidCallback alNuevo;
  const _EstadoVacio({
    required this.esTecnico,
    required this.cargando,
    required this.alCargarDemo,
    required this.alNuevo,
  });

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          const Trucha(ancho: 120, angulo: 0.05),
          const SizedBox(height: 14),
          Text('Aún no hay estanques', style: tema.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            esTecnico
                ? 'Registra tus estanques con sus umbrales, o carga una piscigranja de ejemplo para probar la app.'
                : 'Cuando el técnico acuícola registre los estanques, aparecerán aquí con su estado en vivo.',
            textAlign: TextAlign.center,
            style: tema.textTheme.bodyMedium?.copyWith(color: Paleta.tintaApagada),
          ),
          if (esTecnico) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: cargando ? null : alCargarDemo,
                icon: cargando
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.auto_awesome),
                label: Text(cargando ? 'Cargando…' : 'Cargar datos de demostración'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: cargando ? null : alNuevo,
                icon: const Icon(Icons.add),
                label: const Text('Registrar estanque'),
              ),
            ),
          ],
        ]),
      ),
    );
  }
}

class _Titulo extends StatelessWidget {
  final String texto;
  const _Titulo(this.texto);

  @override
  Widget build(BuildContext context) =>
      Text(texto, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800));
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;
  const _Aviso({required this.icono, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(icono, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(texto)),
        ]),
      );
}

/// Tarjetas «fantasma» con la silueta de TarjetaEstanque y un brillo que las
/// recorre, mientras llegan los datos de Firestore. Sin paquetes: un
/// AnimationController y un ShaderMask.
class _Esqueletos extends StatefulWidget {
  final int cantidad;
  const _Esqueletos({required this.cantidad});

  @override
  State<_Esqueletos> createState() => _EsqueletosState();
}

class _EsqueletosState extends State<_Esqueletos> with SingleTickerProviderStateMixin {
  late final AnimationController _brillo =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _brillo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final oscuro = Theme.of(context).brightness == Brightness.dark;
    final base = oscuro ? const Color(0xFF262B2E) : const Color(0xFFE6EAE8);
    final luz = oscuro ? const Color(0xFF3A4246) : const Color(0xFFF7F9F8);

    return Column(
      children: List.generate(
        widget.cantidad,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _EsqueletoTarjeta(color: base, luz: luz, brillo: _brillo),
        ),
      ),
    );
  }
}

class _EsqueletoTarjeta extends StatelessWidget {
  final Color color;
  final Color luz;
  final Animation<double> brillo;
  const _EsqueletoTarjeta({required this.color, required this.luz, required this.brillo});

  Widget _bloque(double ancho, double alto, {double radio = 6}) => Container(
        width: ancho,
        height: alto,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(radio)),
      );

  @override
  Widget build(BuildContext context) {
    // El brillo se aplica solo a los bloques: el fondo de la tarjeta es
    // transparente para el ShaderMask, así se conserva la silueta.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AnimatedBuilder(
        animation: brillo,
        builder: (context, hijo) {
          // La franja de luz viaja de -1 a 2 para entrar y salir por completo.
          final t = brillo.value * 3 - 1;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [color, luz, color],
              stops: [(t - 0.3).clamp(0.0, 1.0), t.clamp(0.0, 1.0), (t + 0.3).clamp(0.0, 1.0)],
            ).createShader(rect),
            child: hijo,
          );
        },
        child: Container(
        decoration: BoxDecoration(border: Border(left: BorderSide(color: color, width: 5))),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _bloque(40, 40, radio: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _bloque(90, 16),
                  const SizedBox(height: 6),
                  _bloque(150, 11),
                ]),
              ),
              _bloque(78, 26, radio: 999),
            ]),
            const SizedBox(height: 16),
            for (var i = 0; i < 3; i++) ...[
              Row(children: [
                _bloque(12, 12, radio: 999),
                const SizedBox(width: 6),
                _bloque(110, 12),
                const Spacer(),
                _bloque(64, 14),
              ]),
              const SizedBox(height: 7),
              _bloque(double.infinity, 6, radio: 3),
              const SizedBox(height: 6),
              _bloque(170, 10),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
      ),
    );
  }
}

/// Aparición suave (opacidad + leve subida) de una tarjeta real, escalonada
/// según su posición, para reemplazar a los esqueletos sin saltos.
class _AparecerSuave extends StatelessWidget {
  final int retraso;
  final Widget child;
  const _AparecerSuave({super.key, required this.retraso, required this.child});

  @override
  Widget build(BuildContext context) {
    final ms = 350 + (retraso.clamp(0, 6)) * 70;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: ms),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, v, hijo) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 14 * (1 - v)), child: hijo),
      ),
    );
  }
}
