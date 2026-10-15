import 'package:flutter_test/flutter_test.dart';
import 'package:so_gia/core/money.dart';

void main() {
  group('parseVnd', () {
    test('plain and separators', () {
      expect(parseVnd('25000'), 25000);
      expect(parseVnd('25.000'), 25000);
      expect(parseVnd('25,000'), 25000);
      expect(parseVnd('25 000'), 25000);
    });

    test('k suffix', () {
      expect(parseVnd('25k'), 25000);
      expect(parseVnd('25K'), 25000);
      expect(parseVnd('1.5k'), isNull); // not supported — digits only before k
    });

    test('invalid', () {
      expect(parseVnd(''), isNull);
      expect(parseVnd('abc'), isNull);
    });
  });

  test('formatVnd', () {
    expect(formatVnd(25000), '25.000đ');
    expect(formatVnd(500), '500đ');
  });
}
