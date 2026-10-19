import 'package:flutter/material.dart';

ThemeData buildAppTheme({
  bool largeText = false,
  bool highContrast = false,
}) {
  final seed = highContrast ? const Color(0xFF064E2A) : const Color(0xFF1B7F3B);
  final scheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.light,
  ).copyWith(
    // Stronger ink on bright outdoor screens.
    onSurface: highContrast ? const Color(0xFF000000) : null,
    surface: highContrast ? const Color(0xFFFFFFF8) : null,
  );

  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 52)),
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 12),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );

  if (!largeText && !highContrast) return base;

  // Large text is applied via MediaQuery textScaler in SoGiaApp — do not call
  // TextTheme.apply(fontSizeFactor:) (asserts when fontSize is null on M3).
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: highContrast ? scheme.primary : null,
      foregroundColor: highContrast ? scheme.onPrimary : null,
      titleTextStyle: TextStyle(
        fontSize: largeText ? 22 : 20,
        fontWeight: FontWeight.w600,
        color: highContrast ? scheme.onPrimary : scheme.onSurface,
      ),
    ),
  );
}
