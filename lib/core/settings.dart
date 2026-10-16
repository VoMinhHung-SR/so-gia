import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'pricing.dart';
import 'vietnamese.dart';

/// Default markup % by loose category label (lowercase, diacritics stripped by caller).
const Map<String, double> kDefaultCategoryMarkups = {
  'nuoc giai khat': 15,
  'nuoc': 15,
  'rau': 30,
  'gia vi': 25,
  'banh keo': 20,
  'sua': 15,
};

const _kDefaultMarkup = 'default_markup_pct';
const _kRoundStep = 'round_step';
const _kRoundMode = 'round_mode';

class AppSettings {
  AppSettings(this._prefs);

  final SharedPreferences _prefs;

  double get defaultMarkupPct =>
      _prefs.getDouble(_kDefaultMarkup) ?? 20;

  Future<void> setDefaultMarkupPct(double v) =>
      _prefs.setDouble(_kDefaultMarkup, v);

  int get roundStep => _prefs.getInt(_kRoundStep) ?? 500;

  Future<void> setRoundStep(int v) => _prefs.setInt(_kRoundStep, v);

  RoundMode get roundMode {
    final raw = _prefs.getString(_kRoundMode);
    return raw == 'nearest' ? RoundMode.nearest : RoundMode.up;
  }

  Future<void> setRoundMode(RoundMode mode) => _prefs.setString(
        _kRoundMode,
        mode == RoundMode.nearest ? 'nearest' : 'up',
      );

  /// Resolve markup for an item category; falls back to global default.
  double markupForCategory(String? category) {
    if (category == null || category.trim().isEmpty) return defaultMarkupPct;
    final key = removeDiacritics(category);
    for (final entry in kDefaultCategoryMarkups.entries) {
      if (key.contains(entry.key) || entry.key.contains(key)) {
        return entry.value;
      }
    }
    return defaultMarkupPct;
  }
}

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Override sharedPreferencesProvider in main()');
});

final appSettingsProvider = Provider<AppSettings>((ref) {
  return AppSettings(ref.watch(sharedPreferencesProvider));
});
