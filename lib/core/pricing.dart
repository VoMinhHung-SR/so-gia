import '../data/db/tables.dart';
import 'money.dart';

enum RoundMode { up, nearest }

/// Round a VND amount to [step] (e.g. 500 or 1000).
int roundPrice(
  int amount, {
  int step = 500,
  RoundMode mode = RoundMode.up,
}) {
  if (step <= 0) return amount;
  if (amount <= 0) return 0;
  final q = amount ~/ step;
  final rem = amount % step;
  if (rem == 0) return amount;
  return switch (mode) {
    RoundMode.up => (q + 1) * step,
    RoundMode.nearest => rem * 2 >= step ? (q + 1) * step : q * step,
  };
}

/// Markup on cost: sell = cost × (1 + pct/100), then round.
int suggestedSellPrice({
  required int costPrice,
  required double markupPct,
  int step = 500,
  RoundMode mode = RoundMode.up,
}) {
  if (costPrice <= 0) return 0;
  final raw = (costPrice * (1 + markupPct / 100)).round();
  return roundPrice(raw, step: step, mode: mode);
}

int profitPerUnit(int sellPrice, int costPrice) => sellPrice - costPrice;

/// Margin on sell price (informational): (sell − cost) / sell × 100.
double marginOnSellPct(int sellPrice, int costPrice) {
  if (sellPrice <= 0) return 0;
  return (sellPrice - costPrice) / sellPrice * 100;
}

/// Convert package size to liters (ml/l) or null if not volume.
double? sizeInLiters(double? unitSize, UnitType unitType) {
  if (unitSize == null || unitSize <= 0) return null;
  return switch (unitType) {
    UnitType.ml => unitSize / 1000,
    UnitType.l => unitSize,
    _ => null,
  };
}

/// Convert package size to kilograms (g/kg) or null if not mass.
double? sizeInKg(double? unitSize, UnitType unitType) {
  if (unitSize == null || unitSize <= 0) return null;
  return switch (unitType) {
    UnitType.g => unitSize / 1000,
    UnitType.kg => unitSize,
    _ => null,
  };
}

/// đ/lít from a package price, or null when unit size missing / wrong type.
int? pricePerLiter(int price, double? unitSize, UnitType unitType) {
  final liters = sizeInLiters(unitSize, unitType);
  if (liters == null || liters <= 0) return null;
  return (price / liters).round();
}

/// đ/kg from a package price.
int? pricePerKg(int price, double? unitSize, UnitType unitType) {
  final kg = sizeInKg(unitSize, unitType);
  if (kg == null || kg <= 0) return null;
  return (price / kg).round();
}

/// đ/100g from a package price.
int? pricePer100g(int price, double? unitSize, UnitType unitType) {
  final perKg = pricePerKg(price, unitSize, unitType);
  if (perKg == null) return null;
  return (perKg / 10).round();
}

/// Format helper lines for UI (only non-null conversions).
List<String> unitPriceLabels({
  required int price,
  required double? unitSize,
  required UnitType unitType,
}) {
  final out = <String>[];
  final perL = pricePerLiter(price, unitSize, unitType);
  if (perL != null) out.add('${formatVnd(perL)}/lít');
  final perKg = pricePerKg(price, unitSize, unitType);
  if (perKg != null) out.add('${formatVnd(perKg)}/kg');
  final per100 = pricePer100g(price, unitSize, unitType);
  if (per100 != null) out.add('${formatVnd(per100)}/100g');
  if (unitType == UnitType.piece) {
    out.add('${formatVnd(price)}/cái');
  }
  return out;
}
