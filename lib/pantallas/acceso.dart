import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../api.dart';
import '../formato.dart';
import '../modelos.dart';
import '../tema.dart';
import '../widgets/agua.dart';
import '../widgets/trucha.dart';

/// Acceso (RF-09): iniciar sesión o crear cuenta con Firebase Auth, sobre el
/// fondo animado de agua. Al entrar, el resto lo decide el flujo de perfil.
class PantallaAcceso extends StatefulWidget {
  const PantallaAcceso({super.key});

  @override
  State<PantallaAcceso> createState() => _PantallaAccesoState();
}

class _PantallaAccesoState extends State<PantallaAcceso> {
  final _nombre = TextEditingController();
  final _email = TextEditingController();
  final _clave = TextEditingController();
  bool _registro = false;
  bool _enviando = false;
  bool _verClave = false;
  Rol _rol = Rol.operador;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _email.dispose();
    _clave.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final email = _email.text.trim();
    final clave = _clave.text;
    final nombre = _nombre.text.trim();
    if (email.isEmpty || clave.isEmpty || (_registro && nombre.isEmpty)) {
      setState(() => _error = _registro ? 'Completa nombre, correo y contraseña.' : 'Ingresa tu correo y tu contraseña.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _error = null;
    });
    final error = _registro
        ? await Api.instancia.registrar(nombre: nombre, email: email, clave: clave, rol: _rol)
        : await Api.instancia.iniciarSesion(email, clave);
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _error = error;
    });
  }

  Future<void> _olvide() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Escribe tu correo y vuelve a tocar «¿Olvidaste tu contraseña?».');
      return;
    }
    final error = await Api.instancia.restablecerClave(email);
    if (!mounted) return;
    if (error != null) {
      setState(() => _error = error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Te enviamos un enlace a $email para cambiar la contraseña.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: temaSippt(null, Brightness.light),
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        body: FondoAgua(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      const Trucha(ancho: 110, angulo: -0.12),
                      const SizedBox(height: 6),
                      const Text(
                        'SIPPT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 34,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 8,
                          shadows: [Shadow(color: Color(0x66000000), blurRadius: 14, offset: Offset(0, 3))],
                        ),
                      ),
                      const Text(
                        'Monitoreo inteligente de trucha',
                        style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 14, letterSpacing: 0.8),
                      ),
                      const SizedBox(height: 24),
                      _Vidrio(child: _formulario(context)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _formulario(BuildContext context) {
    final tema = Theme.of(context);
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Ingresar'), icon: Icon(Icons.login)),
              ButtonSegment(value: true, label: Text('Crear cuenta'), icon: Icon(Icons.person_add_alt)),
            ],
            selected: {_registro},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() {
              _registro = s.first;
              _error = null;
            }),
          ),
          const SizedBox(height: 18),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            child: _registro
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextField(
                      controller: _nombre,
                      maxLength: 80,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Nombre completo', prefixIcon: Icon(Icons.badge_outlined)),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(labelText: 'Correo', prefixIcon: Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _clave,
            obscureText: !_verClave,
            autofillHints: [_registro ? AutofillHints.newPassword : AutofillHints.password],
            onSubmitted: (_) => _enviar(),
            decoration: InputDecoration(
              labelText: 'Contraseña',
              helperText: _registro ? 'Mínimo 6 caracteres' : null,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_verClave ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _verClave = !_verClave),
              ),
            ),
          ),
          if (_registro) ...[
            const SizedBox(height: 16),
            Text('¿Cuál es tu rol en la piscigranja?', style: tema.textTheme.labelLarge),
            const SizedBox(height: 8),
            ...Rol.values.map((r) => _OpcionRol(
                  rol: r,
                  elegido: _rol == r,
                  alTocar: () => setState(() => _rol = r),
                )),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Paleta.critico.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline, color: Paleta.critico, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: const TextStyle(color: Paleta.critico))),
              ]),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _enviando ? null : _enviar,
            child: _enviando
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : Text(_registro ? 'Crear cuenta' : 'Ingresar'),
          ),
          if (!_registro)
            TextButton(onPressed: _enviando ? null : _olvide, child: const Text('¿Olvidaste tu contraseña?')),
        ],
      ),
    );
  }
}

class _OpcionRol extends StatelessWidget {
  final Rol rol;
  final bool elegido;
  final VoidCallback alTocar;
  const _OpcionRol({required this.rol, required this.elegido, required this.alTocar});

  static const _iconos = {
    Rol.operador: Icons.engineering_outlined,
    Rol.tecnico: Icons.science_outlined,
    Rol.veterinario: Icons.medical_services_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final color = Paleta.acento(rol);
    final info = roles[rol]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: alTocar,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: elegido ? color.withValues(alpha: 0.10) : Colors.transparent,
            border: Border.all(color: elegido ? color : const Color(0x22000000), width: elegido ? 1.6 : 1),
          ),
          child: Row(children: [
            Icon(_iconos[rol], color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(info.enfoque, style: const TextStyle(fontSize: 12, color: Paleta.tintaApagada)),
              ]),
            ),
            if (elegido) Icon(Icons.check_circle, color: color),
          ]),
        ),
      ),
    );
  }
}

/// Tarjeta translúcida tipo vidrio esmerilado sobre el agua.
class _Vidrio extends StatelessWidget {
  final Widget child;
  const _Vidrio({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 30, offset: Offset(0, 12))],
          ),
          child: child,
        ),
      ),
    );
  }
}
