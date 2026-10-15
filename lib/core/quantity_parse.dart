import '../data/db/tables.dart';

class ParsedQuantity {
  const ParsedQuantity({required this.size, required this.unitType});

  final double size;
  final UnitType unitType;
}

/// Parse Open Food Facts `quantity` strings like `500 ml`, `1.5L`, `400g`, `1 kg`.
ParsedQuantity? parseQuantity(String? raw) {
  if (raw == null) return null;
  final s = raw.trim().toLowerCase().replaceAll(',', '.');
  if (s.isEmpty) return null;

  final match = RegExp(
    r'^(\d+(?:\.\d+)?)\s*(ml|milliliters?|l|liters?|litres?|g|grams?|kg|kilograms?|pcs?|pieces?)?\b',
  ).firstMatch(s);
  if (match == null) return null;

  final size = double.tryParse(match.group(1)!);
  if (size == null || size <= 0) return null;

  final unitRaw = match.group(2);
  final unit = switch (unitRaw) {
    'ml' || 'milliliter' || 'milliliters' => UnitType.ml,
    'l' || 'liter' || 'liters' || 'litre' || 'litres' => UnitType.l,
    'g' || 'gram' || 'grams' => UnitType.g,
    'kg' || 'kilogram' || 'kilograms' => UnitType.kg,
    'pc' || 'pcs' || 'piece' || 'pieces' => UnitType.piece,
    null => null,
    _ => null,
  };

  if (unit == null) {
    // Bare number with no unit — not enough to store.
    return null;
  }

  return ParsedQuantity(size: size, unitType: unit);
}
