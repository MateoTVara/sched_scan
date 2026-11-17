import 'package:flutter/material.dart';

/// The brand orange: the app's `primary` in both brightnesses.
const brandPrimary = Color(0xFFFF6600);

/// Black on the brand orange. At 7.1:1 it is the readable pairing — white
/// would sit at 3.0:1, not enough for the AppBar title and the chip labels.
const _onBrand = Colors.black;

/// The one theme builder: [Brightness.light] and [Brightness.dark] both start
/// from the brand's seeded Material 3 palette, so surfaces, containers and
/// text roles stay in harmony, and both pin `primary` to the exact orange
/// rather than the palette's tonal approximation.
ThemeData buildAppTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: brandPrimary,
    brightness: brightness,
  ).copyWith(primary: brandPrimary, onPrimary: _onBrand);

  return ThemeData(
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      // Keep the bar the plain brand colour: with an elevation tint the
      // pinned/solid bar would blend towards `surfaceTint` once the list
      // scrolls under it.
      scrolledUnderElevation: 0,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
    ),
  );
}
