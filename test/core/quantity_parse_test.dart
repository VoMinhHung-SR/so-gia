import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/quantity_parse.dart';
import 'package:so_gia/data/db/tables.dart';

void main() {
  test('parses common OFF quantity strings', () {
    expect(parseQuantity('500 ml')!.size, 500);
    expect(parseQuantity('500 ml')!.unitType, UnitType.ml);
    expect(parseQuantity('1.5L')!.unitType, UnitType.l);
    expect(parseQuantity('1.5L')!.size, 1.5);
    expect(parseQuantity('400g')!.unitType, UnitType.g);
    expect(parseQuantity('1 kg')!.unitType, UnitType.kg);
  });

  test('returns null when unusable', () {
    expect(parseQuantity(null), isNull);
    expect(parseQuantity(''), isNull);
    expect(parseQuantity('unknown'), isNull);
  });
}
