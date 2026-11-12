import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'api.dart';
import 'firebase_options.dart';
import 'modelos.dart';
import 'pantallas/acceso.dart';
import 'pantallas/bienvenida.dart';
import 'pantallas/tablero.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  await initializeDateFormatting('es');

  Object? errorFirebase;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    errorFirebase = e;
  }
  runApp(AppSippt(errorFirebase: errorFirebase));
}

class AppSippt extends StatefulWidget {
  final Object? errorFirebase;
  const AppSippt({super.key, this.errorFirebase});

  @override
  State<AppSippt> createState() => _AppSipptState();
}

class _AppSipptState extends State<AppSippt> {
  bool _introVista = false;
  Stream<Usuario?>? _perfil;

  @override
  void initState() {
    super.initState();
    if (widget.errorFirebase == null) _perfil = Api.instancia.perfil();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Usuario?>(
      stream: _perfil,
      builder: (context, snap) {
        final usuario = snap.data;
        final rol = usuario?.rol;

        Widget inicio;
        if (!_introVista) {
          inicio = PantallaBienvenida(
            key: const ValueKey('intro'),
            alTerminar: () => setState(() => _introVista = true),
          );
        } else if (widget.errorFirebase != null) {
          inicio = _FirebaseSinConfigurar(error: widget.errorFirebase!);
        } else if (snap.connectionState == ConnectionState.waiting) {
          inicio = const Scaffold(
            key: ValueKey('cargando'),
            backgroundColor: Paleta.aguaProfunda,
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        } else if (usuario == null) {
          inicio = const PantallaAcceso(key: ValueKey('acceso'));
        } else {
          inicio = PantallaTablero(key: ValueKey('tablero-${usuario.id}'), usuario: usuario);
        }

        return MaterialApp(
          title: 'SIPPT',
          debugShowCheckedModeBanner: false,
          theme: temaSippt(rol, Brightness.light),
          darkTheme: temaSippt(rol, Brightness.dark),
          locale: const Locale('es', 'PE'),
          supportedLocales: const [Locale('es', 'PE'), Locale('es')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 600),
            switchInCurve: Curves.easeOutCubic,
            child: inicio,
          ),
        );
      },
    );
  }
}

/// Se muestra si todavía no se ejecutó «flutterfire configure».
class _FirebaseSinConfigurar extends StatelessWidget {
  final Object error;
  const _FirebaseSinConfigurar({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Paleta.aguaProfunda,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_off, color: Colors.white, size: 48),
              const SizedBox(height: 16),
              const Text('Falta conectar Firebase',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              const Text(
                'En la carpeta del proyecto ejecuta:\n\n'
                '  flutterfire configure\n\n'
                'y vuelve a lanzar la app. Los pasos completos están en README.md.',
                style: TextStyle(color: Color(0xDDFFFFFF), fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              Text('$error', style: const TextStyle(color: Color(0x88FFFFFF), fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
