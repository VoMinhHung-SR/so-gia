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
const _kLastBackupAt = 'last_backup_at';
const _kLargeText = 'large_text';
const _kHighContrast = 'high_contrast';
const _kStartOnScan = 'start_on_scan';
const _kCurrentStoreId = 'current_store_id';

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

  DateTime? get lastBackupAt {
    final raw = _prefs.getString(_kLastBackupAt);
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> markBackupNow() =>
      _prefs.setString(_kLastBackupAt, DateTime.now().toUtc().toIso8601String());

  bool get needsBackupReminder {
    final last = lastBackupAt;
    if (last == null) return true;
    return DateTime.now().toUtc().difference(last).inDays >= 7;
  }

  bool get largeText => _prefs.getBool(_kLargeText) ?? false;

  Future<void> setLargeText(bool v) => _prefs.setBool(_kLargeText, v);

  bool get highContrast => _prefs.getBool(_kHighContrast) ?? false;

  Future<void> setHighContrast(bool v) => _prefs.setBool(_kHighContrast, v);

  /// Cold start opens scan/lookup screen (useful at the stall).
  bool get startOnScan => _prefs.getBool(_kStartOnScan) ?? false;

  Future<void> setStartOnScan(bool v) => _prefs.setBool(_kStartOnScan, v);

  String? get currentStoreId => _prefs.getString(_kCurrentStoreId);

  Future<void> setCurrentStoreId(String id) =>
      _prefs.setString(_kCurrentStoreId, id);

  /// Resolve markup for an item category label; falls back to global default.
  /// Prefer [markupForCategoryId] when store DB margins are available.
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

/// Bumps when UX prefs change so [MaterialApp] rebuilds theme / initial route.
class UiPrefs extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final uiPrefsProvider = NotifierProvider<UiPrefs, int>(UiPrefs.new);
