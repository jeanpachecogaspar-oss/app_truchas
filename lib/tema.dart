import 'package:flutter/material.dart';

import 'formato.dart';
import 'modelos.dart';

/// Paleta del tablero (tomada de dashboard/app/globals.css) más los tonos de
/// agua de la marca.
///
/// El acento cambia por rol; la paleta de estado NO: el rojo crítico significa
/// lo mismo en el celular de cualquiera.
class Paleta {
  static const normal = Color(0xFF0CA30C);
  static const advertencia = Color(0xFFFAB219);
  static const critico = Color(0xFFD03B3B);
  static const sinDatos = Color(0xFF898781);
  static const serie = Color(0xFF2A78D6);
  static const serieTenue = Color(0xFFCDE2FB);
  static const tintaApagada = Color(0xFF898781);

  static const aguaProfunda = Color(0xFF041C2B);
  static const aguaMedia = Color(0xFF0C4F6C);
  static const aguaClara = Color(0xFF1C8BA3);
  static const acentoBase = Color(0xFF0E6A78);

  static Color acento(Rol? rol) => switch (rol) {
        Rol.operador => const Color(0xFF1F6FB2),
        Rol.tecnico => const Color(0xFF5847C2),
        Rol.veterinario => const Color(0xFF93407A),
        null => acentoBase,
      };

  static Color deEstado(EstadoVisual e) => switch (e) {
        EstadoVisual.normal => normal,
        EstadoVisual.advertencia => advertencia,
        EstadoVisual.critico => critico,
        EstadoVisual.sinDatos => sinDatos,
      };
}

ThemeData temaSippt(Rol? rol, Brightness brillo) {
  final oscuro = brillo == Brightness.dark;
  final acento = Paleta.acento(rol);
  final esquema = ColorScheme.fromSeed(seedColor: acento, brightness: brillo).copyWith(
    primary: oscuro ? Color.lerp(acento, Colors.white, 0.25)! : acento,
    surface: oscuro ? const Color(0xFF15191B) : const Color(0xFFFCFCFB),
  );
  final borde = oscuro ? const Color(0x1AFFFFFF) : const Color(0x140B0B0B);

  return ThemeData(
    useMaterial3: true,
    colorScheme: esquema,
    scaffoldBackgroundColor: oscuro ? const Color(0xFF0B0E10) : const Color(0xFFF3F5F4),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: esquema.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: borde)),
    ),
    appBarTheme: const AppBarTheme(centerTitle: false, scrolledUnderElevation: 0),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: oscuro ? const Color(0xFF1C2124) : const Color(0xFFF5F7F7),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borde)),
      enabledBorder:
          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borde)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: esquema.primary, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      indicatorColor: acento.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ),
  );
}
