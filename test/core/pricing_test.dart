import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/pricing.dart';
import 'package:so_gia/data/db/tables.dart';

void main() {
  group('roundPrice', () {
    test('round up to 500', () {
      expect(roundPrice(12200, step: 500), 12500);
      expect(roundPrice(12500, step: 500), 12500);
      expect(roundPrice(12001, step: 500), 12500);
    });

    test('round up to 1000', () {
      expect(roundPrice(12200, step: 1000), 13000);
      expect(roundPrice(13000, step: 1000), 13000);
    });

    test('nearest', () {
      expect(roundPrice(12200, step: 500, mode: RoundMode.nearest), 12000);
      expect(roundPrice(12300, step: 500, mode: RoundMode.nearest), 12500);
    });
  });

  group('suggestedSellPrice markup', () {
    test('20% on 10000 → 12000 (already on step)', () {
      expect(
        suggestedSellPrice(costPrice: 10000, markupPct: 20, step: 500),
        12000,
      );
    });

    test('15% on 7000 → 8050 → round up 8500', () {
      expect(
        suggestedSellPrice(costPrice: 7000, markupPct: 15, step: 500),
        8500,
      );
    });
  });

  test('marginOnSellPct', () {
    expect(marginOnSellPct(12000, 10000), closeTo(16.666, 0.01));
  });

  group('unit prices', () {
    test('500ml bottle', () {
      expect(pricePerLiter(10000, 500, UnitType.ml), 20000);
      expect(pricePerKg(10000, 500, UnitType.ml), isNull);
    });

    test('400g pack', () {
      expect(pricePerKg(20000, 400, UnitType.g), 50000);
      expect(pricePer100g(20000, 400, UnitType.g), 5000);
    });

    test('missing size', () {
      expect(pricePerLiter(10000, null, UnitType.ml), isNull);
      expect(unitPriceLabels(price: 10000, unitSize: null, unitType: UnitType.ml), isEmpty);
    });

    test('piece', () {
      expect(
        unitPriceLabels(price: 5000, unitSize: null, unitType: UnitType.piece),
        ['5.000đ/cái'],
      ); // formatVnd + /cái
    });
  });
}
