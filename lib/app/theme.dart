import 'package:flutter/material.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1B7F3B));
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    // Large tap targets: the app is used one-handed at a market stall.
    visualDensity: VisualDensity.standard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 52)),
    ),
  );
}
